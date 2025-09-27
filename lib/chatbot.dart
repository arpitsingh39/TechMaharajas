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

  final String _apiUrl = "https://studious-space-cod-7qjp49qj756fg74-5000.app.github.dev/api/agent";

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
        Uri.parse(_apiUrl),
        headers: {"Content-Type": "application/json"},
        body: jsonEncode({"query": text}),
      );

      final reply = res.statusCode == 200
          ? (jsonDecode(res.body)["answer"] ?? "I couldn’t process that.")
          : "Error: ${res.statusCode} ${res.reasonPhrase}";

      setState(() => _messages.add(
        ChatMessage(text: reply, isUser: false, time: DateTime.now()),
      ));
    } catch (e) {
      setState(() => _messages.add(
        ChatMessage(text: "⚠️ Network error: $e", isUser: false, time: DateTime.now()),
      ));
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
      child: Text(
        m.text,
        style: TextStyle(color: m.isUser ? Colors.white : Colors.black87),
      ),
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
