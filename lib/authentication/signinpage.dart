// lib/authentication/signin page.dart
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

class SignInPage extends StatefulWidget {
  const SignInPage({super.key});
  @override
  State<SignInPage> createState() => _SignInPageState();
}

class _SignInPageState extends State<SignInPage> {
  final _form = GlobalKey<FormState>();
  final _shop = TextEditingController();
  final _pass = TextEditingController();
  TimeOfDay? start = const TimeOfDay(hour: 9, minute: 0);
  TimeOfDay? end = const TimeOfDay(hour: 18, minute: 0);

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Scaffold(
      appBar: AppBar(
        title: const Text('Register Shop'),
        backgroundColor: cs.surface, // blends with surface containers
        elevation: 0,
      ),
      body: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            colors: [cs.surface, cs.surfaceContainerLowest], // soft neutral backdrop
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
          ),
        ),
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 720),
            child: Card(
              elevation: 0,
              color: cs.surfaceContainerHighest, // M3 tone-based container
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
              child: Padding(
                padding: const EdgeInsets.fromLTRB(24, 28, 24, 24),
                child: Form(
                  key: _form,
                  child: Column(mainAxisSize: MainAxisSize.min, children: [
                    Row(
                      children: [
                        CircleAvatar(
                          radius: 28,
                          backgroundColor: cs.primary,
                          child: Icon(Icons.store, color: cs.onPrimary, size: 28),
                        ),
                        const SizedBox(width: 12),
                        Text(
                          'Create your shop profile',
                          style: Theme.of(context).textTheme.titleLarge,
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),
                    TextFormField(
                      controller: _shop,
                      decoration: InputDecoration(
                        labelText: 'Shop Name',
                        prefixIcon: const Icon(Icons.storefront),
                        filled: true,
                        fillColor: cs.surfaceContainerHigh, // subtle fill on focus
                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                      ),
                      validator: (v) => v!.isEmpty ? 'Enter shop name' : null,
                    ),
                    const SizedBox(height: 12),
                    Row(children: [
                      Expanded(
                        child: _TimeTile(
                          label: 'Start',
                          time: start!,
                          onPick: (t) => setState(() => start = t),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: _TimeTile(
                          label: 'End',
                          time: end!,
                          onPick: (t) => setState(() => end = t),
                        ),
                      ),
                    ]),
                    const SizedBox(height: 12),
                    TextFormField(
                      controller: _pass,
                      obscureText: true,
                      decoration: InputDecoration(
                        labelText: 'Password',
                        prefixIcon: const Icon(Icons.lock),
                        filled: true,
                        fillColor: cs.surfaceContainerHigh,
                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                      ),
                      validator: (v) => v!.isEmpty ? 'Enter password' : null,
                    ),
                    const SizedBox(height: 18),
                    SizedBox(
                      width: double.infinity,
                      child: FilledButton(
                        style: FilledButton.styleFrom(
                          backgroundColor: cs.primary, // strong blue CTA
                          foregroundColor: cs.onPrimary,
                          padding: const EdgeInsets.symmetric(vertical: 16),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                        ),
                        onPressed: () {
                          if (!_form.currentState!.validate()) return;
                          context.go('/');
                        },
                        child: const Text('Save & Continue'),
                      ),
                    ),
                    const SizedBox(height: 8),
                    Divider(color: cs.outlineVariant),
                    const SizedBox(height: 4),
                    Text(
                      'Tip: These settings seed your shift hours and can be changed later.',
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(color: cs.onSurfaceVariant),
                      textAlign: TextAlign.center,
                    ),
                  ]),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _TimeTile extends StatelessWidget {
  final String label;
  final TimeOfDay time;
  final ValueChanged<TimeOfDay> onPick;
  const _TimeTile({required this.label, required this.time, required this.onPick});

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return InkWell(
      borderRadius: BorderRadius.circular(12),
      onTap: () async {
        final t = await showTimePicker(context: context, initialTime: time);
        if (t != null) onPick(t);
      },
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        decoration: BoxDecoration(
          color: cs.surfaceContainerHigh,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: cs.outlineVariant),
        ),
        child: Row(
          children: [
            Icon(Icons.schedule, color: cs.primary),
            const SizedBox(width: 10),
            Text('$label: ${time.format(context)}'),
          ],
        ),
      ),
    );
  }
}
