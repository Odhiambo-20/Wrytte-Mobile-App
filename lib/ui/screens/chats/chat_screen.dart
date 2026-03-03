import 'package:flutter/material.dart';
import 'package:wrytte/models/chat_models/chat_message.dart';
import 'package:wrytte/state/chat/chat_state.dart';

class ChatScreen extends StatefulWidget {
  final String conversationId;
  final String receiverId;
  final String currentUserId;
  final String title;
  final ChatState chatState;

  const ChatScreen({
    super.key,
    required this.conversationId,
    required this.receiverId,
    required this.currentUserId,
    required this.title,
    required this.chatState,
  });

  @override
  State<ChatScreen> createState() => _ChatScreenState();
}

class _ChatScreenState extends State<ChatScreen> {
  final TextEditingController _controller = TextEditingController();
  final ScrollController _scrollController = ScrollController();

  @override
  void initState() {
    super.initState();
    _initializeChat();
  }

  Future<void> _initializeChat() async {
    // ChatState is initialized before loading messages
    await widget.chatState.initialize();

    /// LOAD MESSAGES FOR THIS CONVERSATION
    await widget.chatState.loadConversation(widget.conversationId);

    // Scroll to bottom after initial load
    WidgetsBinding.instance.addPostFrameCallback((_) => _scrollToBottom());
  }

  void _send() async {
    final text = _controller.text.trim();
    if (text.isEmpty) return;

    final message = ChatMessage(
      id: DateTime.now().millisecondsSinceEpoch.toString(),
      conversationId: widget.conversationId,
      senderId: widget.currentUserId,
      receiverId: widget.receiverId,
      content: text,
      timestamp: DateTime.now(),
      status: MessageStatus.sending,
    );

    await widget.chatState.sendMessage(message);

    _controller.clear();
    _scrollToBottom();
  }

  void _scrollToBottom() {
    Future.delayed(const Duration(milliseconds: 100), () {
      if (_scrollController.hasClients) {
        _scrollController.animateTo(
          _scrollController.position.maxScrollExtent,
          duration: const Duration(milliseconds: 250),
          curve: Curves.easeOut,
        );
      }
    });
  }

  Widget _buildMessage(ChatMessage message) {
    final isMine = message.senderId == widget.currentUserId;

    return Align(
      alignment: isMine ? Alignment.centerRight : Alignment.centerLeft,
      child: Container(
        margin: const EdgeInsets.symmetric(vertical: 4, horizontal: 10),
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: isMine ? const Color(0xFF4DA3FF) : const Color(0xFF2A2B30),
          borderRadius: BorderRadius.circular(10),
        ),
        child: Text(
          message.content,
          style: const TextStyle(color: Colors.white),
        ),
      ),
    );
  }

  Widget _buildMessages() {
    return StreamBuilder<List<ChatMessage>>(
      stream: widget.chatState.messagesStream,
      builder: (context, snapshot) {
        final messages = snapshot.data ?? [];

        /// FILTER BY CONVERSATION ID
        final conversationMessages =
            messages
                .where((m) => m.conversationId == widget.conversationId)
                .toList();

        /// AUTO SCROLL WHEN MESSAGE ARRIVES
        WidgetsBinding.instance.addPostFrameCallback((_) => _scrollToBottom());

        return ListView.builder(
          controller: _scrollController,
          padding: const EdgeInsets.only(top: 10),
          itemCount: conversationMessages.length,
          itemBuilder: (context, index) {
            return _buildMessage(conversationMessages[index]);
          },
        );
      },
    );
  }

  Widget _buildInput() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
      color: const Color(0xFF1A1B1E),
      child: Row(
        children: [
          Expanded(
            child: TextField(
              controller: _controller,
              style: const TextStyle(color: Colors.white),
              decoration: const InputDecoration(
                hintText: "Type a message...",
                hintStyle: TextStyle(color: Colors.white54),
                border: InputBorder.none,
              ),
              onSubmitted: (_) => _send(),
            ),
          ),
          IconButton(
            onPressed: _send,
            icon: const Icon(Icons.send, color: Color(0xFF4DA3FF)),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF0F1013),
      appBar: AppBar(
        title: Text(widget.title),
        backgroundColor: const Color(0xFF0F1013),
      ),
      body: Column(
        children: [Expanded(child: _buildMessages()), _buildInput()],
      ),
    );
  }
}
