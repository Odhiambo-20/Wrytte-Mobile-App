import 'dart:async';
import 'package:flutter/material.dart';
import 'package:wrytte/models/chat_models/chat_conversation.dart';
import 'package:wrytte/services/auth/auth_service.dart';
import 'package:wrytte/services/chat/chat_service.dart';
import 'package:wrytte/state/chat/chat_state.dart';
import 'package:wrytte/ui/screens/chats/chat_screen.dart';
import 'package:wrytte/ui/screens/chats/widgets/top_bar.dart';
import 'package:wrytte/ui/screens/chats/widgets/conversation_tile.dart';
import 'package:wrytte/ui/screens/select_contact_screen.dart';
import 'widgets/search_bar.dart' as local_widgets;
import 'widgets/tab_bar_section.dart';

class ConversationsScreen extends StatefulWidget {
  final Function(int)? onUnreadCountUpdated;

  const ConversationsScreen({super.key, this.onUnreadCountUpdated});

  @override
  State<ConversationsScreen> createState() => _ConversationsScreenState();
}

class _ConversationsScreenState extends State<ConversationsScreen> {
  bool _isLoading = true;

  late final ChatService _chatService;

  List<ChatConversation> _conversations = [];

  String _currentUserId = "";

  StreamSubscription<List<ChatConversation>>? _conversationSubscription;

  @override
  void initState() {
    super.initState();
    _chatService = ChatService();
    _initialize();
  }

  Future<void> _initialize() async {
    try {
      // 1️⃣ Get current user ID
      _currentUserId = await AuthService.instance.getCurrentUserId() ?? "";

      // 2️⃣ Connect chat service (starts socket + autosync)
      await _chatService.connect();

      // 3️⃣ Listen for conversation updates
      _conversationSubscription = _chatService.conversationsStream.listen((
        conversations,
      ) {
        final convs = conversations.cast<ChatConversation>();

        setState(() {
          _conversations = convs;
          _isLoading = false;
        });

        int unreadTotal = 0;
        for (var conv in convs) {
          unreadTotal += conv.unreadCount;
        }

        widget.onUnreadCountUpdated?.call(unreadTotal);
      });

      // 4️⃣ Load initial messages (this builds conversations)
      await _chatService.fetchMessages(maxCount: 20);

      setState(() {
        _isLoading = false;
      });
    } catch (e) {
      debugPrint("Conversation init error $e");
      setState(() {
        _isLoading = false;
      });
    }
  }

  Widget _buildConversationItem(ChatConversation conversation) {
    final otherUserId = conversation.participants.firstWhere(
      (id) => id != _currentUserId,
      orElse: () => "",
    );

    return ConversationTile(
      name: "User $otherUserId",
      lastMessage: conversation.lastMessage,
      time: conversation.lastMessageTime.toLocal().toString().split(' ')[1],
      avatarUrl: null,
      unreadCount: conversation.unreadCount,
      onTap: () async {
        final chatState = ChatState(_chatService);

        await chatState.initialize();

        Navigator.push(
          context,
          MaterialPageRoute(
            builder:
                (_) => ChatScreen(
                  conversationId: conversation.conversationId,
                  receiverId: otherUserId,
                  currentUserId: _currentUserId,
                  title: "User $otherUserId",
                  chatState: chatState,
                ),
          ),
        );
      },
    );
  }

  Widget _buildChatsTab() {
    if (_conversations.isEmpty) {
      return const Center(
        child: Text(
          "No conversations yet",
          style: TextStyle(color: Colors.grey),
        ),
      );
    }

    return RefreshIndicator(
      onRefresh: () async {
        setState(() {
          _isLoading = true;
        });

        await _chatService.fetchMessages(maxCount: 20);

        setState(() {
          _isLoading = false;
        });
      },
      child: ListView.builder(
        physics: const BouncingScrollPhysics(),
        itemCount: _conversations.length,
        itemBuilder: (context, index) {
          return _buildConversationItem(_conversations[index]);
        },
      ),
    );
  }

  Widget _buildLoadingState() {
    return const Center(
      child: CircularProgressIndicator(color: Color(0xFF4DA3FF)),
    );
  }

  @override
  void dispose() {
    _conversationSubscription?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF0F1013),
      appBar: TopBar(),
      floatingActionButton: FloatingActionButton(
        onPressed: () {
          Navigator.push(
            context,
            MaterialPageRoute(builder: (_) => const SelectContactScreen()),
          );
        },
        backgroundColor: const Color(0xFF4DA3FF),
        child: const Icon(Icons.edit_square, color: Colors.black),
      ),
      body: DefaultTabController(
        length: 3,
        child: SafeArea(
          child: Column(
            children: [
              Container(
                color: const Color(0xFF0F1013),
                child: Column(
                  children: [local_widgets.SearchBar(), const TabBarSection()],
                ),
              ),
              const SizedBox(height: 8),
              Expanded(
                child: TabBarView(
                  children: [
                    _isLoading ? _buildLoadingState() : _buildChatsTab(),
                    const Center(
                      child: Text(
                        'Channels coming soon',
                        style: TextStyle(color: Colors.grey),
                      ),
                    ),
                    const Center(
                      child: Text(
                        'Groups coming soon',
                        style: TextStyle(color: Colors.grey),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
