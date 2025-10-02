#!/usr/bin/env python3
# -*- coding: utf-8 -*-
# Weekly shop scheduler using Google OR-Tools CP-SAT
# Requirements:
#   - Core: pip install ortools
#   - For Flask route usage: pip install flask
#
# CLI:
#   python schedule.py --input input.json --output schedule.json
#
# Flask:
#   from routes.schedule import schedule_bp
#   app.register_blueprint(schedule_bp)

import json
import argparse
import math
import os
from datetime import datetime, timedelta, timezone
from collections import defaultdict
from typing import Dict, List, Tuple, Optional
from ortools.sat.python import cp_model

# Optional Flask imports (kept lazy-safe for CLI usage)
try:
    from flask import Blueprint, request, jsonify
except Exception:
    Blueprint = None
    request = None
    jsonify = None

# Optional DB imports (used when running via Flask route)
try:
    from dotenv import load_dotenv
    import psycopg
    from psycopg.rows import dict_row
except Exception:
    load_dotenv = None
    psycopg = None
    dict_row = None

ISO_WEEKDAYS = ["monday","tuesday","wednesday","thursday","friday","saturday","sunday"]

def parse_time_token(tok: str) -> int:
    s = tok.strip().lower()
    s = s.replace(" ", "")
    s = s.replace(".", ":")
    ampm = None
    if s.endswith("am") or s.endswith("pm"):
        ampm = s[-2:]
        s = s[:-2]
    if ":" not in s:
        s += ":00"
    hh, mm = s.split(":")
    h = int(hh)
    m = int(mm)
    if ampm == "am":
        if h == 12: h = 0
    elif ampm == "pm":
        if h != 12: h += 12
    return h * 60 + m

def parse_time_range(text: str) -> Tuple[int,int]:
    t = text.lower().replace("to","-")
    parts = [p for p in t.split("-") if p.strip()]
    if len(parts) != 2:
        raise ValueError(f"Bad time range: {text}")
    start = parse_time_token(parts[0])
    end = parse_time_token(parts[1])
    if end <= start:
        end += 0
    return start, end

def hhmm(minutes: int) -> str:
    h = minutes // 60
    m = minutes % 60
    return f"{h:02d}:{m:02d}"

def availability_slots_for_day(av: List[List[str]], day_open_m: int, day_close_m: int, slot_size: int = 60):
    """Build availability bit-vector (per slot) for a single day.
    av: list of [start,end] strings like [["09:00","17:00"], ...] or strings "09:00-17:00".
    """
    S = max(0, math.ceil((day_close_m - day_open_m) / slot_size))
    slots = [0] * S
    if not av:
        return slots
    for win in av:
        if not win:
            continue
        if isinstance(win, str):
            a, b = parse_time_range(win)
        else:
            a = parse_time_token(win[0]); b = parse_time_token(win[1])
        # clamp to day window
        a = max(a, day_open_m)
        b = min(b, day_close_m)
        if b <= a:
            continue
        a_slot = max(0, (a - day_open_m) // slot_size)
        b_slot = max(a_slot, math.ceil((b - day_open_m) / slot_size))
        for s in range(int(a_slot), min(int(b_slot), S)):
            slots[s] = 1
    return slots

def build_coverage_for_day(day_cfg: dict, roles: List[str], slot_min: int, slot_size: int = 60):
        """Build per-slot coverage for a day relative to that day's start.

        Returns:
            cov: list of dicts for slots [0..S-1] where S = end_slot - start_slot
            start_slot: absolute slot index of day open (relative to global slot_min)
            end_slot: absolute slot index of day close (relative to global slot_min)
        """
        open_m = parse_time_token(day_cfg["open"])
        close_m = parse_time_token(day_cfg["close"])
        start_slot = max(0, (open_m - slot_min) // slot_size)
        end_slot_abs = max(start_slot, math.ceil((close_m - slot_min) / slot_size))
        S = int(end_slot_abs - start_slot)
        base = {r: day_cfg["roles"].get(r, 0) for r in roles}
        cov = [dict(base) for _ in range(S)]
        # Add peak extras, aligning to the day's relative slot 0
        for p in day_cfg.get("peaks", []):
                ps, pe = parse_time_range(f'{p["start"]}-{p["end"]}')
                ps_slot_abs = max(0, (ps - slot_min) // slot_size)
                pe_slot_abs = max(ps_slot_abs, math.ceil((pe - slot_min) / slot_size))
                # Convert absolute to day-relative indices
                ps_rel = max(0, int(ps_slot_abs - start_slot))
                pe_rel = max(ps_rel, int(pe_slot_abs - start_slot))
                extra = p.get("extra", {})
                for s in range(ps_rel, min(pe_rel, S)):
                        for r, x in extra.items():
                                cov[s][r] = cov[s].get(r, 0) + int(x)
        return cov, start_slot, end_slot_abs

def availability_slots(av: List[List[str]], slot_min: int, slot_max: int, slot_size: int = 60):
    slots = [0] * ((slot_max - slot_min) // slot_size)
    for win in av:
        if not win: 
            continue
        if isinstance(win, str):
            a, b = parse_time_range(win)
        else:
            a = parse_time_token(win[0]); b = parse_time_token(win[1])
        a_slot = max(0, (a - slot_min) // slot_size)
        b_slot = max(a_slot, math.ceil((b - slot_min) / slot_size))
        for s in range(a_slot, min(b_slot, len(slots))):
            slots[s] = 1
    return slots

def merge_shift_blocks_by_role(assign_role_slots: List[List[str]], slot_min: int, slot_size: int = 60):
    out_by_role = defaultdict(list)
    for r_index, per_slot in enumerate(assign_role_slots):
        prev_set = None
        prev_start = None
        for s, names in enumerate(per_slot + [None]):  # sentinel
            cur_set = tuple(sorted(names)) if names is not None else None
            if cur_set != prev_set:
                if prev_set is not None and prev_start is not None:
                    start_m = slot_min + prev_start * slot_size
                    end_m = slot_min + s * slot_size
                    out_by_role[r_index].append({
                        "start": hhmm(start_m),
                        "end": hhmm(end_m),
                        "employees": list(prev_set)
                    })
                prev_set = cur_set
                prev_start = s
    return out_by_role

def to_day_blocks_from_role_blocks(role_blocks: Dict[int, List[dict]]):
    intervals = []
    for blocks in role_blocks.values():
        for b in blocks:
            intervals.append({"start": b["start"], "end": b["end"]})
    intervals.sort(key=lambda x: (x["start"], x["end"]))
    merged = []
    for iv in intervals:
        if not merged or merged[-1]["end"] != iv["start"]:
            merged.append(dict(iv))
        else:
            merged[-1]["end"] = iv["end"]
    return merged

def contiguous_intervals_from_slots(slots_on: List[int], slot_min: int, slot_size: int = 60):
    intervals = []
    in_run = False
    start = 0
    for i, v in enumerate(slots_on + [0]):
        if v and not in_run:
            in_run = True
            start = i
        elif not v and in_run:
            in_run = False
            s_m = slot_min + start * slot_size
            e_m = slot_min + i * slot_size
            intervals.append((hhmm(s_m), hhmm(e_m)))
    return intervals

def group_slack_intervals(slack_list: List[int], slot_min: int, slot_size: int = 60):
    groups = []
    cur_start = None
    cur_max = 0
    for i, v in enumerate(slack_list + [0]):
        if v > 0 and cur_start is None:
            cur_start = i
            cur_max = v
        elif v > 0 and cur_start is not None:
            cur_max = max(cur_max, v)
        elif v == 0 and cur_start is not None:
            s_m = slot_min + cur_start * slot_size
            e_m = slot_min + i * slot_size
            groups.append({"start": hhmm(s_m), "end": hhmm(e_m), "needed": int(cur_max)})
            cur_start = None
            cur_max = 0
    return groups

def solve_schedule(data: dict, output_minimal: bool = False, time_limit_s: int = 10):
    # Roles across week
    roles = set()
    for _, cfg in data["week"].items():
        for r in cfg["roles"]:
            roles.add(r)
        for p in cfg.get("peaks", []):
            for r in p.get("extra", {}).keys():
                roles.add(r)
    roles = sorted(roles)
    role_index = {r:i for i,r in enumerate(roles)}

    # Days present in input, normalized and ISO-ordered (holidays omitted if not present)
    present_days = [d.strip().lower() for d in data["week"].keys()]
    present_days.sort(key=lambda d: ISO_WEEKDAYS.index(d) if d in ISO_WEEKDAYS else len(ISO_WEEKDAYS))
    if not present_days:
        return {"status": "NO_DAYS"}

    # Global earliest open and latest close
    slot_size = 60
    earliest = min(parse_time_token(data["week"][d]["open"]) for d in present_days)
    latest = max(parse_time_token(data["week"][d]["close"]) for d in present_days)

    # Coverage
    day_cov = {}
    day_slot_bounds = {}
    for d in present_days:
        cov, s0, s1 = build_coverage_for_day(data["week"][d], roles, earliest, slot_size)
        day_cov[d] = cov
        day_slot_bounds[d] = (s0, s1)

    # Employees
    employees = data.get("employees", [])
    E = len(employees)
    if E == 0:
        return {"status": "NO_EMPLOYEES"}

    # Availability matrix
    emp_avail = {d: [[0]* (day_slot_bounds[d][1] - day_slot_bounds[d][0]) for _ in range(E)] for d in present_days}
    for e_i, emp in enumerate(employees):
        av_map = emp.get("availability", {})
        for d in present_days:
            day_slots = day_slot_bounds[d][1] - day_slot_bounds[d][0]
            if d in av_map:
                av_slots = availability_slots(av_map[d], earliest, latest, slot_size)
                s0, s1 = day_slot_bounds[d]
                emp_avail[d][e_i] = av_slots[s0:s1]
            else:
                emp_avail[d][e_i] = [0]*day_slots

    # Role qualification
    emp_can_role = [[1]*len(roles) for _ in range(E)]
    for e_i, emp in enumerate(employees):
        if "roles" in emp and emp["roles"]:
            allowed = set(emp["roles"])
            for r_i, r in enumerate(roles):
                emp_can_role[e_i][r_i] = 1 if r in allowed else 0

    # Model
    model = cp_model.CpModel()

    # Decision vars: assign[e][d][s][r] in {0,1}
    assign = {d: [[[model.NewBoolVar(f"a_e{e}_d{d}_s{s}_r{r}")
                    for r in range(len(roles))]
                   for s in range(day_slot_bounds[d][1] - day_slot_bounds[d][0])]
                  for e in range(E)]
             for d in present_days}

    # Slack (unmet demand) per day/slot/role to enable diagnostics when coverage cannot be met
    slack = {d: [[model.NewIntVar(0, 1000, f"slack_d{d}_s{s}_r{r}")
                  for r in range(len(roles))]
                 for s in range(day_slot_bounds[d][1] - day_slot_bounds[d][0])]
             for d in present_days}

    # Coverage with slack: sum(assign) + slack == demand
    for d in present_days:
        cov = day_cov[d]
        for s, need in enumerate(cov):
            for r_name, req in need.items():
                r = role_index[r_name]
                model.Add(sum(assign[d][e][s][r] for e in range(E)) + slack[d][s][r] == int(req))

    # Availability, one-role-per-slot, qualification
    for d in present_days:
        S = day_slot_bounds[d][1] - day_slot_bounds[d][0]
        for e in range(E):
            for s in range(S):
                if emp_avail[d][e][s] == 0:
                    for r in range(len(roles)):
                        model.Add(assign[d][e][s][r] == 0)
                model.Add(sum(assign[d][e][s][r] for r in range(len(roles))) <= 1)
                for r in range(len(roles)):
                    if emp_can_role[e][r] == 0:
                        model.Add(assign[d][e][s][r] == 0)

    # Weekly max hours per employee (slot_size=60 ⇒ 1 slot = 1 hour)
    max_week = [int(emp.get("max_weekly_hours", 40)) for emp in employees]
    emp_hours = []
    BIG_M = int((latest - earliest) / 60 * max(1, len(present_days)) + max(max_week, default=40))
    for e in range(E):
        var = model.NewIntVar(0, BIG_M, f"hours_e{e}")
        emp_hours.append(var)
        total_slots = []
        for d in present_days:
            S = day_slot_bounds[d][1] - day_slot_bounds[d][0]
            for s in range(S):
                for r in range(len(roles)):
                    total_slots.append(assign[d][e][s][r])
        model.Add(var == sum(total_slots))
        model.Add(var <= int(max_week[e]))

    # Break rule: In any 7 consecutive hours within a day, at least one hour off
    window = 7
    for d in present_days:
        S = day_slot_bounds[d][1] - day_slot_bounds[d][0]
        for e in range(E):
            for start in range(0, max(0, S - window + 1)):
                on_slots = []
                for s in range(start, start + window):
                    on_slots.append(sum(assign[d][e][s][r] for r in range(len(roles))))
                model.Add(sum(on_slots) <= 6)

    # Fairness helpers
    min_hours = model.NewIntVar(0, BIG_M, "min_hours")
    max_hours = model.NewIntVar(0, BIG_M, "max_hours")
    for e in range(E):
        model.Add(emp_hours[e] >= min_hours)
        model.Add(emp_hours[e] <= max_hours)
    worked = [model.NewBoolVar(f"worked_e{e}") for e in range(E)]
    for e in range(E):
        model.Add(emp_hours[e] >= 1).OnlyEnforceIf(worked[e])
        model.Add(emp_hours[e] <= 0).OnlyEnforceIf(worked[e].Not())

    # Objective: First minimize total slack (unmet demand), then promote fairness
    SLACK_W = 1_000_000
    W_MIN = 1000
    W_USED = 10
    W_RANGE = 1
    total_slack = sum(slack[d][s][r]
                      for d in present_days
                      for s in range(day_slot_bounds[d][1] - day_slot_bounds[d][0])
                      for r in range(len(roles)))
    model.Minimize(SLACK_W * total_slack - (W_MIN * min_hours + W_USED * sum(worked)) + W_RANGE * max_hours)

    # Solve
    solver = cp_model.CpSolver()
    time_limit_s = int(time_limit_s or 0)
    if time_limit_s:
        solver.parameters.max_time_in_seconds = float(time_limit_s)
    solver.parameters.num_search_workers = 8
    status = solver.Solve(model)
    if status not in (cp_model.OPTIMAL, cp_model.FEASIBLE):
        return {"status": "INFEASIBLE"}

    # Build per-day per-role assignments and minimal day blocks
    out = {"status": "FEASIBLE" if status == cp_model.FEASIBLE else "OPTIMAL"}
    schedule = {}
    assignment_debug = {}
    unmet_by_day = {}
    # Precompute employee names list for convenience
    emp_names = [employees[e]["name"] for e in range(E)]
    emp_ids = [employees[e].get("id") for e in range(E)]
    for d in present_days:
        day_open_m = parse_time_token(data["week"][d]["open"])
        S = day_slot_bounds[d][1] - day_slot_bounds[d][0]
        per_role_slots = []
        per_role_slack = []
        for r in range(len(roles)):
            names_per_slot = []
            slack_per_slot = []
            for s in range(S):
                names = []
                for e in range(E):
                    if solver.Value(assign[d][e][s][r]) == 1:
                        names.append(employees[e]["name"])
                names_per_slot.append(names)
                slack_per_slot.append(int(solver.Value(slack[d][s][r])))
            per_role_slots.append(names_per_slot)
            per_role_slack.append(slack_per_slot)

        role_blocks = merge_shift_blocks_by_role(per_role_slots, day_open_m, slot_size)
        day_blocks = to_day_blocks_from_role_blocks(role_blocks)
        schedule[d] = day_blocks

        # Compute per-slot assignment occupancy for backup checks
        assigned_any = [[0]*S for _ in range(E)]
        for e in range(E):
            for s in range(S):
                if any(solver.Value(assign[d][e][s][r]) == 1 for r in range(len(roles))):
                    assigned_any[e][s] = 1

        # Compute backup staff for each role block
        role_blocks_with_backups = {}
        # Remaining weekly capacity for ranking (optional)
        hours_used_week = [int(solver.Value(emp_hours[e])) for e in range(E)]
        remaining_week = [int(max_week[e] - hours_used_week[e]) for e in range(E)]
        for r_idx, blocks in role_blocks.items():
            r_name = roles[r_idx]
            new_blocks = []
            for b in blocks:
                # Convert time window to slot indices
                b_start = parse_time_token(b["start"]) 
                b_end = parse_time_token(b["end"]) 
                s0 = max(0, (b_start - day_open_m) // slot_size)
                s1 = max(s0, (b_end - day_open_m + (slot_size-1)) // slot_size)
                duration_slots = int(s1 - s0)
                candidates = []
                assigned_set = set(b.get("employees", []))
                for e in range(E):
                    nm = emp_names[e]
                    eid = emp_ids[e]
                    if nm in assigned_set:
                        continue
                    if emp_can_role[e][r_idx] == 0:
                        continue
                    # Available and not already assigned over the whole block
                    if s1 > S:
                        continue
                    if all(emp_avail[d][e][s] == 1 for s in range(int(s0), int(s1))) and \
                       all(assigned_any[e][s] == 0 for s in range(int(s0), int(s1))):
                        candidates.append((remaining_week[e], -hours_used_week[e], nm, eid))
                # Sort: more remaining capacity, then fewer hours used, then name
                candidates.sort(key=lambda x: (-x[0], x[1], x[2]))
                backups = [{"id": eid, "name": nm} for _,__, nm, eid in candidates[:5]]
                nb = dict(b)
                nb["backups"] = backups
                new_blocks.append(nb)
            role_blocks_with_backups[r_name] = new_blocks

        assignment_debug[d] = role_blocks_with_backups

        # Unmet demand intervals per role
        unmet_day = {}
        for r_name, r_idx in role_index.items():
            groups = group_slack_intervals(per_role_slack[r_idx], day_open_m, slot_size)
            if groups:
                unmet_day[r_name] = groups
        if unmet_day:
            unmet_by_day[d] = unmet_day

    # Attendance per employee: day intervals where assigned to any role
    attendance = {}
    for e in range(E):
        name = employees[e]["name"]
        attendance[name] = {}
        for d in present_days:
            day_open_m = parse_time_token(data["week"][d]["open"])
            S = day_slot_bounds[d][1] - day_slot_bounds[d][0]
            on = [0]*S
            for s in range(S):
                assigned_any = any(solver.Value(assign[d][e][s][r]) == 1 for r in range(len(roles)))
                on[s] = 1 if assigned_any else 0
            intervals = contiguous_intervals_from_slots(on, day_open_m, slot_size)
            if intervals:
                attendance[name][d] = [{"start": a, "end": b} for a, b in intervals]

    # Diagnostics: quick capacity checks and reasons
    diagnostics = {"days": {}}
    # Pre-compute availability capacity per day/role
    for d in present_days:
        S = day_slot_bounds[d][1] - day_slot_bounds[d][0]
        reasons = []
        for r_name, r_idx in role_index.items():
            demand_slots = sum(day_cov[d][s].get(r_name, 0) for s in range(S))
            available_slots = 0
            for e in range(E):
                if emp_can_role[e][r_idx] == 1:
                    available_slots += sum(emp_avail[d][e][s] for s in range(S))
            if demand_slots > available_slots:
                reasons.append({
                    "role": r_name,
                    "issue": "insufficient availability or headcount",
                    "demand_slots": int(demand_slots),
                    "available_slots": int(available_slots),
                    "suggested_extra_slots": int(demand_slots - available_slots)
                })
        if d in unmet_by_day:
            diagnostics["days"][d] = {
                "status": "NOT_FULLY_COVERED",
                "unmet_intervals": unmet_by_day[d],
                "reasons": reasons if reasons else [{"note": "coverage shortfall due to weekly caps or break constraints"}]
            }
        else:
            diagnostics["days"][d] = {"status": "COVERED"}

    out["schedule"] = schedule if output_minimal else {"days": schedule, "by_role_assignments": assignment_debug}
    out["attendance"] = attendance
    out["unmet_demand"] = unmet_by_day
    out["diagnostics"] = diagnostics
    out["fairness_summary"] = {
        "min_hours": int(solver.Value(min_hours)),
        "max_hours": int(solver.Value(max_hours)),
        "emp_hours": {employees[e]["name"]: int(solver.Value(emp_hours[e])) for e in range(E)},
        "employees_used": int(sum(int(solver.Value(w)) for w in worked)),
        "total_unmet": int(solver.Value(total_slack))
    }
    return out

def solve_single_day(data: dict, day_label: str = "day", time_limit_s: int = 10, slot_size: int = 60):
    """Solve staffing for a single day.
    Expected input:
    {
      "day": {"open":"09:00","close":"22:00","roles":{role:int},"peaks":[{"start":"..","end":"..","extra":{role:int}}]},
      "employees": [
         {"name":"N","roles":[..],"max_weekly_hours":40,"prev_hours":10,
          "availability":[["09:00","17:00"], ...]}
      ]
    }
    """
    day_cfg = data["day"]
    employees = data.get("employees", [])
    if not employees:
        return {"status": "NO_EMPLOYEES"}

    # Roles
    roles = set(day_cfg.get("roles", {}).keys())
    for p in day_cfg.get("peaks", []):
        for r in p.get("extra", {}).keys():
            roles.add(r)
    roles = sorted(roles)
    role_index = {r: i for i, r in enumerate(roles)}

    # Time bounds
    day_open_m = parse_time_token(day_cfg["open"])
    day_close_m = parse_time_token(day_cfg["close"])
    cov, s0, s1 = build_coverage_for_day(day_cfg, roles, day_open_m, slot_size)
    assert s0 == 0, "Coverage should start at day open"
    S = len(cov)

    # Availability and qualifications
    E = len(employees)
    emp_avail = [[0] * S for _ in range(E)]
    emp_can_role = [[1] * len(roles) for _ in range(E)]
    max_week = []
    prev_hours = []
    names = []
    ids = []
    for e_i, emp in enumerate(employees):
        names.append(emp.get("name", f"emp{e_i}"))
        ids.append(emp.get("id"))
        max_week.append(int(emp.get("max_weekly_hours", 40)))
        prev_hours.append(max(0, int(emp.get("prev_hours", 0))))
        av = emp.get("availability", [])
        # Accept either list of windows or dict (ignore keys, use the value if list)
        if isinstance(av, dict):
            # Try common keys first, else flatten all values
            if day_label in av:
                av_windows = av[day_label]
            else:
                # merge all windows across keys
                av_windows = []
                for v in av.values():
                    if isinstance(v, list):
                        av_windows.extend(v)
        else:
            av_windows = av
        emp_avail[e_i] = availability_slots_for_day(av_windows, day_open_m, day_close_m, slot_size)
        if "roles" in emp and emp["roles"]:
            allowed = set(emp["roles"])
            for r_i, r in enumerate(roles):
                emp_can_role[e_i][r_i] = 1 if r in allowed else 0

    # Model
    model = cp_model.CpModel()
    assign = [[[model.NewBoolVar(f"a_e{e}_s{s}_r{r}") for r in range(len(roles))]
               for s in range(S)] for e in range(E)]
    slack = [[model.NewIntVar(0, 1000, f"slack_s{s}_r{r}") for r in range(len(roles))] for s in range(S)]

    # Coverage with slack
    for s in range(S):
        for r_name, req in cov[s].items():
            r = role_index[r_name]
            model.Add(sum(assign[e][s][r] for e in range(E)) + slack[s][r] == int(req))

    # Availability, one-role-per-slot, qualification
    for e in range(E):
        for s in range(S):
            if emp_avail[e][s] == 0:
                for r in range(len(roles)):
                    model.Add(assign[e][s][r] == 0)
            model.Add(sum(assign[e][s][r] for r in range(len(roles))) <= 1)
            for r in range(len(roles)):
                if emp_can_role[e][r] == 0:
                    model.Add(assign[e][s][r] == 0)

    # Hours today and weekly cap remaining
    BIG_M = max(1000, int((day_close_m - day_open_m) / 60 + max(max_week or [40])))
    hours_today = [model.NewIntVar(0, BIG_M, f"hours_e{e}") for e in range(E)]
    for e in range(E):
        model.Add(hours_today[e] == sum(assign[e][s][r] for s in range(S) for r in range(len(roles))))
        remaining_cap = max(0, int(max_week[e] - prev_hours[e]))
        model.Add(hours_today[e] <= remaining_cap)

    # Cumulative hours (prev + today) for fairness
    cum_hours = [model.NewIntVar(0, BIG_M, f"cum_e{e}") for e in range(E)]
    for e in range(E):
        # cum = hours_today + prev (constant)
        model.Add(cum_hours[e] == hours_today[e] + int(prev_hours[e]))

    min_cum = model.NewIntVar(0, BIG_M, "min_cum")
    max_cum = model.NewIntVar(0, BIG_M, "max_cum")
    for e in range(E):
        model.Add(cum_hours[e] >= min_cum)
        model.Add(cum_hours[e] <= max_cum)
    worked = [model.NewBoolVar(f"worked_e{e}") for e in range(E)]
    for e in range(E):
        model.Add(hours_today[e] >= 1).OnlyEnforceIf(worked[e])
        model.Add(hours_today[e] <= 0).OnlyEnforceIf(worked[e].Not())

    # Objective: minimize slack, then prefer fairness on cumulative hours and use more employees
    SLACK_W = 1_000_000
    W_MIN = 1000
    W_USED = 10
    W_RANGE = 1
    total_slack = sum(slack[s][r] for s in range(S) for r in range(len(roles)))
    model.Minimize(SLACK_W * total_slack - (W_MIN * min_cum + W_USED * sum(worked)) + W_RANGE * max_cum)

    solver = cp_model.CpSolver()
    time_limit_s = int(time_limit_s or 0)
    if time_limit_s:
        solver.parameters.max_time_in_seconds = float(time_limit_s)
    solver.parameters.num_search_workers = 8
    status = solver.Solve(model)
    if status not in (cp_model.OPTIMAL, cp_model.FEASIBLE):
        return {"status": "INFEASIBLE"}

    # Build outputs
    # Per-role assignments per slot -> merged blocks
    per_role_slots = []
    per_role_slack = []
    for r in range(len(roles)):
        names_per_slot = []
        slack_per_slot = []
        for s in range(S):
            assigned_names = [names[e] for e in range(E) if solver.Value(assign[e][s][r]) == 1]
            names_per_slot.append(assigned_names)
            slack_per_slot.append(int(solver.Value(slack[s][r])))
        per_role_slots.append(names_per_slot)
        per_role_slack.append(slack_per_slot)

    role_blocks = merge_shift_blocks_by_role(per_role_slots, day_open_m, slot_size)
    day_blocks = to_day_blocks_from_role_blocks(role_blocks)

    # Precompute assignment occupancy per employee per slot for backup checks
    assigned_any = [[0]*S for _ in range(E)]
    for e in range(E):
        for s in range(S):
            if any(solver.Value(assign[e][s][r]) == 1 for r in range(len(roles))):
                assigned_any[e][s] = 1

    # Get numeric values for fairness metrics to help rank backups
    hours_today_val = [int(solver.Value(hours_today[e])) for e in range(E)]
    cum_hours_val = [int(solver.Value(hours_today[e]) + prev_hours[e]) for e in range(E)]

    # Compute backups for each role block: list up to 5 candidates qualified, available, and unassigned for full block
    role_blocks_with_backups = {}
    for r_idx, blocks in role_blocks.items():
        r_name = roles[r_idx]
        new_blocks = []
        for b in blocks:
            b_start = parse_time_token(b["start"]) 
            b_end = parse_time_token(b["end"]) 
            s0 = max(0, (b_start - day_open_m) // slot_size)
            s1 = max(s0, (b_end - day_open_m + (slot_size-1)) // slot_size)
            assigned_set = set(b.get("employees", []))
            candidates = []
            for e in range(E):
                nm = names[e]
                eid = ids[e]
                if nm in assigned_set:
                    continue
                if emp_can_role[e][r_idx] == 0:
                    continue
                if all(emp_avail[e][s] == 1 for s in range(int(s0), int(s1))) and \
                   all(assigned_any[e][s] == 0 for s in range(int(s0), int(s1))):
                    remaining_cap = int(max(0, max_week[e] - prev_hours[e] - hours_today_val[e]))
                    candidates.append((remaining_cap, cum_hours_val[e], nm, eid))
            # Sort: more remaining capacity first, then lower cumulative hours for fairness, then name
            candidates.sort(key=lambda x: (-x[0], x[1], x[2]))
            backups = [{"id": eid, "name": nm} for _,__, nm, eid in candidates[:5]]
            nb = dict(b)
            nb["backups"] = backups
            new_blocks.append(nb)
        role_blocks_with_backups[r_name] = new_blocks

    # By-employee intervals for the day
    by_employee = {}
    for e in range(E):
        on = [1 if any(solver.Value(assign[e][s][r]) == 1 for r in range(len(roles))) else 0 for s in range(S)]
        intervals = contiguous_intervals_from_slots(on, day_open_m, slot_size)
        if intervals:
            by_employee[names[e]] = [{"start": a, "end": b} for a, b in intervals]

    # Unmet intervals (by role)
    unmet = {}
    for r_name, r_idx in role_index.items():
        groups = group_slack_intervals(per_role_slack[r_idx], day_open_m, slot_size)
        if groups:
            unmet[r_name] = groups

    out = {
        "status": "FEASIBLE" if status == cp_model.FEASIBLE else "OPTIMAL",
        "day_label": day_label,
        "schedule": {
            "days": {day_label: day_blocks},
            "by_role_assignments": {day_label: role_blocks_with_backups},
        },
        "by_day": {day_label: {"employees": by_employee}},
        "by_employee": {name: {day_label: by_employee.get(name, [])} for name in names},
        "unmet_demand": {day_label: unmet} if unmet else {},
        "fairness_summary": {
            "min_cum_hours": int(solver.Value(min_cum)),
            "max_cum_hours": int(solver.Value(max_cum)),
            "emp_hours_today": {names[e]: int(solver.Value(hours_today[e])) for e in range(E)},
            "prev_hours": {names[e]: int(prev_hours[e]) for e in range(E)},
            "cum_hours": {names[e]: int(solver.Value(hours_today[e]) + prev_hours[e]) for e in range(E)},
            "employees_used": int(sum(int(solver.Value(w)) for w in worked)),
            "total_unmet": int(solver.Value(total_slack))
        }
    }
    return out

def print_attendance(attendance: Dict[str, Dict[str, List[dict]]]):
    # Pretty print attendance like: "Adarsh: Mon 14:00-16:00; Tue 10:00-12:00"
    order = ISO_WEEKDAYS
    for emp, days in attendance.items():
        lines = []
        for d in order:
            if d in days:
                slots = "; ".join([f'{iv["start"]}-{iv["end"]}' for iv in days[d]])
                lines.append(f'{d[:3]} {slots}')
        if lines:
            print(f'{emp}: ' + " | ".join(lines))

# ---------- Flask integration ----------

def _pick_iso_first_day(days: List[str]) -> str:
    # Pick first in ISO order; if none match, return the first key
    iso = [d for d in ISO_WEEKDAYS if d in days]
    if iso:
        return iso[0]
    return sorted(days)[0] if days else "day"

def _normalize_to_single_day_payload(body: dict, day_label: str) -> Tuple[dict, str]:
    """
    Accepts inputs:
      - {"day": {...}, "employees":[...]}
      - {"week": {...}, "employees":[...]} plus day_label (query or body) to select a day
      - Or a flattened {"open":..,"close":..,"roles":..,"peaks":[...], "employees":[...]}
    Returns (single_day_payload, resolved_day_label)
    """
    if "day" in body and "employees" in body:
        return {"day": body["day"], "employees": body.get("employees", [])}, day_label or "day"

    if "week" in body and isinstance(body["week"], dict):
        week = body["week"]
        pick = day_label if day_label in week else _pick_iso_first_day(list(week.keys()))
        return {"day": week[pick], "employees": body.get("employees", [])}, pick

    # Flattened form
    if all(k in body for k in ("open", "close", "roles")):
        day = {k: body[k] for k in ("open", "close", "roles")}
        if "peaks" in body:
            day["peaks"] = body["peaks"]
        employees = body.get("employees", [])
        return {"day": day, "employees": employees}, (day_label or "day")

    raise ValueError("Invalid payload. Provide {day,...,employees} or {week,...,employees} or a flattened {open,close,roles,employees} object.")

# ---------- DB helpers for route mode ----------

def _load_env():
    if load_dotenv:
        try:
            load_dotenv()
        except Exception:
            pass

def _get_dburl() -> Optional[str]:
    return os.getenv("DBURL")

def _conn():
    dburl = _get_dburl()
    if not dburl:
        raise RuntimeError("DBURL missing in env")
    if not psycopg:
        raise RuntimeError("psycopg not available")
    return psycopg.connect(dburl)

def _weekday_to_iso(label: str) -> str:
    s = (label or "").strip().lower()
    if not s:
        return "day"
    # Accept short forms
    mapping = {
        "mon": "monday", "monday": "monday",
        "tue": "tuesday", "tues": "tuesday", "tuesday": "tuesday",
        "wed": "wednesday", "weds": "wednesday", "wednesday": "wednesday",
        "thu": "thursday", "thur": "thursday", "thurs": "thursday", "thursday": "thursday",
        "fri": "friday", "friday": "friday",
        "sat": "saturday", "saturday": "saturday",
        "sun": "sunday", "sunday": "sunday",
    }
    return mapping.get(s, s)

def _normalize_availability_for_day(av_json: any, day_label: str) -> List[str]:
    """Return list of "HH:MM-HH:MM" ranges for the requested day from heterogeneous JSON shapes."""
    if not av_json:
        return []

    def norm_key(k: str) -> Optional[str]:
        if not isinstance(k, str):
            return None
        k = k.strip().lower()
        # Map 3-letter keys to long
        map3 = {"mon": "monday", "tue": "tuesday", "tues": "tuesday", "wed": "wednesday", "weds": "wednesday", "thu": "thursday", "thur": "thursday", "thurs": "thursday", "fri": "friday", "sat": "saturday", "sun": "sunday"}
        return map3.get(k, k)

    wanted = _weekday_to_iso(day_label)
    # If dict of days
    if isinstance(av_json, dict):
        # Normalize keys
        norm = {}
        for k, v in av_json.items():
            nk = norm_key(k)
            if nk:
                norm[nk] = v
        raw = norm.get(wanted)
        if raw is None:
            return []
        # If already list of ranges
        if isinstance(raw, list):
            out: List[str] = []
            for r in raw:
                if isinstance(r, str):
                    rs = r.strip()
                    if rs:
                        out.append(rs)
                elif isinstance(r, (list, tuple)) and len(r) == 2:
                    out.append(f"{str(r[0]).strip()}-{str(r[1]).strip()}")
            return out
        # If single dict with start/end
        if isinstance(raw, dict):
            s = str(raw.get("start") or "").strip()
            e = str(raw.get("end") or "").strip()
            if s and e:
                return [f"{s}-{e}"]
            return []
        return []
    # If list assumed to already be ranges for the day
    if isinstance(av_json, list):
        out: List[str] = []
        for r in av_json:
            if isinstance(r, str):
                rs = r.strip()
                if rs:
                    out.append(rs)
            elif isinstance(r, (list, tuple)) and len(r) == 2:
                out.append(f"{str(r[0]).strip()}-{str(r[1]).strip()}")
        return out
    return []

def _fetch_staff_for_shop(shop_id: int, day_label: str, role_names: List[str], date_iso: Optional[str]) -> List[dict]:
    """Fetch staff rows and adapt to solver employees format. Optionally compute prev_hours if date is provided (YYYY-MM-DD)."""
    _load_env()
    sql = """
        SELECT id, name, availability, max_hours_per_week
        FROM staff
        WHERE shop_id = %s
        ORDER BY name;
    """
    staff_rows: List[dict] = []
    with _conn() as conn, conn.cursor(row_factory=dict_row) as cur:
        cur.execute(sql, (int(shop_id),))
        staff_rows = cur.fetchall() or []

        # Optionally compute previous hours for the same ISO week up to the given date (exclusive)
        prev_by_id: Dict[int, float] = {}
        if date_iso:
            try:
                day_dt = datetime.fromisoformat(date_iso)
                if day_dt.tzinfo is None:
                    day_dt = day_dt.replace(tzinfo=timezone.utc)
            except Exception:
                day_dt = None
            if day_dt is not None:
                # Week starts on Monday
                weekday_idx = (day_dt.weekday())  # 0=Mon
                week_start = (day_dt - timedelta(days=weekday_idx)).replace(hour=0, minute=0, second=0, microsecond=0)
                # Sum all shifts from week_start to day_dt (exclusive)
                ids = [r["id"] for r in staff_rows if r and "id" in r]
                if ids:
                    # Use ANY array param for IN
                    cur.execute(
                        """
                        SELECT staff_id, SUM(EXTRACT(EPOCH FROM (shift_end - shift_start))/3600.0) AS hours
                        FROM shifts
                        WHERE staff_id = ANY(%s)
                          AND shift_start >= %s
                          AND shift_start < %s
                        GROUP BY staff_id
                        """,
                        (ids, week_start, day_dt)
                    )
                    for row in cur.fetchall() or []:
                        if row.get("staff_id") is not None:
                            prev_by_id[int(row["staff_id"])] = float(row.get("hours") or 0.0)

    # Build employees array for solver
    employees: List[dict] = []
    iso_day = _weekday_to_iso(day_label)
    for r in staff_rows:
        avail_raw = r.get("availability")
        day_ranges = _normalize_availability_for_day(avail_raw, iso_day)
        employees.append({
            "id": int(r["id"]),
            "name": r.get("name") or f"staff-{r['id']}",
            # Eligible for all provided roles (adjust if you add a mapping later)
            "roles": list(role_names),
            "max_weekly_hours": int(r.get("max_hours_per_week") or 40),
            "prev_hours": float(0.0 if not date_iso else (prev_by_id.get(int(r["id"])) or 0.0)),
            # Provide a dict keyed by the actual day label so the solver picks it
            "availability": {iso_day: day_ranges}
        })
    return employees

# Create blueprint if Flask is available
if Blueprint is not None:
    # Use unique blueprint name and prefix under /api
    solve_bp = Blueprint("solve_bp", __name__, url_prefix="/api")

    @solve_bp.post("/solve")
    def schedule_endpoint():
        """
        POST /api/solve
        Minimal JSON body (single day; employees auto-fetched from DB):
        {
          "shop_id": 1,
          "weekday": "monday",           # or "day_label": "mon"
          "open": "09:00",
          "close": "22:00",
          "roles": {"cashier": 1, "helper": 2},
          "peaks": [ {"start":"10:00","end":"12:00","extra":{"cashier":1}} ],  # optional
          "date": "2025-09-27"           # optional; if provided, previous hours are computed
        }

        Optional query/body:
          - day_label/weekday: which weekday to solve (e.g., monday)
          - time_limit: solver time limit seconds (default 10)
        """
        if not request.is_json:
            return jsonify({"error": "Content-Type must be application/json"}), 415

        body = request.get_json(silent=True) or {}
        # Accept both weekday and day_label
        weekday = request.args.get("weekday") or body.get("weekday") or request.args.get("day_label") or body.get("day_label")
        open_t = body.get("open")
        close_t = body.get("close")
        roles = body.get("roles")
        peaks = body.get("peaks") or []
        shop_id = body.get("shop_id")
        date_iso = body.get("date")  # optional; ISO like YYYY-MM-DD
        time_limit = request.args.get("time_limit", body.get("time_limit", 10))

        # Validate minimal payload
        errors = []
        if not isinstance(shop_id, int):
            errors.append("shop_id must be int")
        if not isinstance(open_t, str):
            errors.append("open must be HH:MM string")
        if not isinstance(close_t, str):
            errors.append("close must be HH:MM string")
        if not isinstance(roles, dict) or not roles:
            errors.append("roles must be a non-empty object {role:int}")
        if not isinstance(peaks, list) and peaks is not None:
            errors.append("peaks must be a list")
        if not isinstance(weekday, str) or not weekday.strip():
            errors.append("weekday (or day_label) must be provided")
        if errors:
            return jsonify({"error": "validation_failed", "details": errors}), 400

        iso_day = _weekday_to_iso(weekday)

        # Assemble day config
        day_cfg = {"open": open_t, "close": close_t, "roles": roles}
        if peaks:
            day_cfg["peaks"] = peaks

        try:
            # Build employees automatically from DB
            employees = _fetch_staff_for_shop(int(shop_id), iso_day, list(roles.keys()), date_iso)
        except Exception as ex:
            return jsonify({"error": "db_error", "detail": str(ex)}), 500

        # Prepare payload for solver
        single_day_payload = {"day": day_cfg, "employees": employees}
        try:
            result = solve_single_day(single_day_payload, day_label=iso_day, time_limit_s=int(time_limit))
        except Exception as ex:
            return jsonify({"error": "Failed to compute schedule", "detail": str(ex)}), 500

        return jsonify(result), 200
else:
    schedule_bp = None  # Flask not installed; CLI usage still works.

# ---------- CLI entrypoint ----------

def main():
    parser = argparse.ArgumentParser()
    parser.add_argument("--input", type=str, default="", help="Path to input JSON (single day preferred)")
    parser.add_argument("--output", type=str, default="", help="Path to write output JSON")
    parser.add_argument("--day_label", type=str, default="day", help="Label for the day (e.g., monday or 2025-09-26)")
    parser.add_argument("--time_limit", type=int, default=10, help="Solver time limit (s)")
    args = parser.parse_args()

    if args.input:
        with open(args.input, "r", encoding="utf-8") as f:
            data = json.load(f)
        # If legacy weekly format is provided, pick the requested day or the first one
        if "day" not in data and "week" in data:
            week = data["week"]
            pick = args.day_label if args.day_label in week else sorted(week.keys(), key=lambda d: ISO_WEEKDAYS.index(d) if d in ISO_WEEKDAYS else 99)[0]
            data = {"day": week[pick], "employees": data.get("employees", [])}
    else:
        # Minimal single-day example
        data = {
            "day": {
                "open": "09:00",
                "close": "22:00",
                "roles": {"cashier": 1, "helper": 2},
                "peaks": [
                    {"start": "10:00", "end": "12:00", "extra": {"cashier": 1, "helper": 1}},
                    {"start": "18:00", "end": "21:00", "extra": {"helper": 1}}
                ]
            },
            "employees": [
                {"name": "Asha", "roles": ["cashier"], "max_weekly_hours": 20, "prev_hours": 4, "availability": [["09:00", "15:00"]]},
                {"name": "Bharat", "roles": ["helper"], "max_weekly_hours": 28, "prev_hours": 10, "availability": [["09:00", "22:00"]]},
                {"name": "Chitra", "roles": ["helper", "cashier"], "max_weekly_hours": 24, "prev_hours": 8, "availability": [["10:00", "18:00"],["11:00","20:00"]]},
                {"name": "Jay", "roles": ["helper", "cashier"], "max_weekly_hours": 30, "prev_hours": 12, "availability": [["09:00", "22:00"]]}
            ]
        }

    result = solve_single_day(data, day_label=args.day_label, time_limit_s=args.time_limit)

    # Print compact per-employee summary for the day
    if "by_employee" in result and "fairness_summary" in result:
        print(f"Shifts for {result.get('day_label','day')}:")
        day_label = result.get("day_label", "day")
        for name, days in result["by_employee"].items():
            ivs = days.get(day_label, [])
            if ivs:
                slots = "; ".join([f"{iv['start']}-{iv['end']}" for iv in ivs])
            else:
                slots = "-"
            today = result["fairness_summary"]["emp_hours_today"].get(name, 0)
            prev = result["fairness_summary"]["prev_hours"].get(name, 0)
            cum = result["fairness_summary"]["cum_hours"].get(name, today + prev)
            print(f"{name}: {slots}  (today {today}h, prev {prev}h, cum {cum}h)")

    text = json.dumps(result, indent=2, ensure_ascii=False)
    # CLI write or print
    # For route usage, nothing below runs.
    if args.output:
        with open(args.output, "w", encoding="utf-8") as f:
            f.write(text)
    else:
        print(text)

if __name__ == "__main__":
    main()