// lib/chatbot.dart — sends shop_id, staff_id, role_id, and message
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';

class ChatbotPage extends StatefulWidget {
  const ChatbotPage({Key? key}) : super(key: key);

  @override
  State<ChatbotPage> createState() => _ChatbotPageState();
}

class _ChatbotPageState extends State<ChatbotPage> {
  final _controller = TextEditingController();
  final _scrollController = ScrollController();
  final List<ChatMessage> _messages = [];
  bool _isLoading = false;

  static const String _endpoint =
      "https://techmaharajas.onrender.com/api/agent";

  // REQUIRED by backend:
  static const int _shopId = 1;   // set real values
  static const int _staffId = 1;
  static const int _roleId  = 1;

  Map<String, dynamic> _buildPayload(String user) => {
        "shop_id": _shopId,
        "staff_id": _staffId,
        "role_id": _roleId,
        "message": user, // <-- backend expects 'message'
      };

  String _extractAnswer(dynamic json) {
    if (json is Map) {
      for (final k in ["answer", "message", "output", "text", "reply"]) {
        final v = json[k];
        if (v is String && v.trim().isNotEmpty) return v;
      }
      final err = json["error"];
      if (err is String && err.isNotEmpty) return "Error: $err";
    }
    if (json is String && json.trim().isNotEmpty) return json;
    return "I couldn’t process that.";
  }

  @override
  void initState() {
    super.initState();
    _messages.add(ChatMessage(
      text: "Hello! 👋 I’m your AI assistant. How can I help?",
      isUser: false,
      time: DateTime.now(),
    ));
  }

  Future<void> _sendMessage() async {
    final text = _controller.text.trim();
    if (text.isEmpty || _isLoading) return;

    setState(() {
      _messages.add(ChatMessage(text: text, isUser: true, time: DateTime.now()));
      _isLoading = true;
    });

    _controller.clear();
    _scrollToBottom();

    try {
      final res = await http.post(
        Uri.parse(_endpoint),
        headers: {
          "Content-Type": "application/json",
          "Accept": "application/json",
        },
        body: jsonEncode(_buildPayload(text)),
      );

      if (res.statusCode == 200) {
        dynamic bodyJson;
        try { bodyJson = jsonDecode(res.body); } catch (_) { bodyJson = res.body; }
        final reply = _extractAnswer(bodyJson);
        setState(() => _messages.add(ChatMessage(text: reply, isUser: false, time: DateTime.now())));
      } else {
        String serverText = res.reasonPhrase ?? 'Bad Request';
        if (res.body.isNotEmpty) {
          try {
            final j = jsonDecode(res.body);
            if (j is Map && j["error"] is String) serverText = j["error"];
            else serverText = res.body;
          } catch (_) { serverText = res.body; }
        }
        setState(() => _messages.add(ChatMessage(text: "Error ${res.statusCode}: $serverText", isUser: false, time: DateTime.now())));
      }
    } catch (e) {
      setState(() => _messages.add(ChatMessage(text: "⚠️ Network error: $e", isUser: false, time: DateTime.now())));
    } finally {
      setState(() => _isLoading = false);
      _scrollToBottom();
    }
  }

  void _scrollToBottom() {
    Future.delayed(const Duration(milliseconds: 100), () {
      if (_scrollController.hasClients) {
        _scrollController.jumpTo(_scrollController.position.maxScrollExtent);
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text("AI Chatbot")),
      body: Column(
        children: [
          Expanded(
            child: ListView.builder(
              controller: _scrollController,
              padding: const EdgeInsets.all(12),
              itemCount: _messages.length,
              itemBuilder: (_, i) => _buildBubble(_messages[i]),
            ),
          ),
          _buildInputArea(),
        ],
      ),
    );
  }

  Widget _buildBubble(ChatMessage m) => Align(
        alignment: m.isUser ? Alignment.centerRight : Alignment.centerLeft,
        child: Container(
          margin: const EdgeInsets.symmetric(vertical: 6),
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: m.isUser ? Colors.deepPurple : Colors.grey.shade200,
            borderRadius: BorderRadius.circular(16),
          ),
          child: Text(m.text, style: TextStyle(color: m.isUser ? Colors.white : Colors.black87)),
        ),
      );

  Widget _buildInputArea() => SafeArea(
        child: Row(
          children: [
            Expanded(
              child: TextField(
                controller: _controller,
                decoration: const InputDecoration(
                  hintText: "Type a message...",
                  border: OutlineInputBorder(),
                ),
                onSubmitted: (_) => _sendMessage(),
              ),
            ),
            IconButton(
              icon: _isLoading
                  ? const CircularProgressIndicator()
                  : const Icon(Icons.send, color: Colors.deepPurple),
              onPressed: _sendMessage,
            ),
          ],
        ),
      );

  @override
  void dispose() {
    _controller.dispose();
    _scrollController.dispose();
    super.dispose();
  }
}

class ChatMessage {
  final String text;
  final bool isUser;
  final DateTime time;
  ChatMessage({required this.text, required this.isUser, required this.time});
}
