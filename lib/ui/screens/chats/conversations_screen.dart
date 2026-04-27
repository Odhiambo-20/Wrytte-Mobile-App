import 'dart:async';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:wrytte/models/chat_models/chat_conversation.dart';
import 'package:wrytte/services/chat/chat_local_db.dart';
import 'package:wrytte/services/chat/firebase_chat_service.dart';
import 'package:wrytte/ui/screens/chats/chat_screen.dart';
import 'package:wrytte/ui/screens/chats/widgets/mini_chat_window.dart';
import 'package:wrytte/ui/screens/chats/widgets/top_bar.dart';
import 'package:wrytte/ui/screens/chats/widgets/conversation_tile.dart';
import 'package:wrytte/ui/screens/firebase_new_chat_screen.dart';
import 'widgets/search_bar.dart' as local_widgets;
import 'widgets/tab_bar_section.dart';

const double _kSearchBarHeight = 60.0;
const double _kTabBarHeight = 56.0;

class ConversationsScreen extends StatefulWidget {
  final Function(int)? onUnreadCountUpdated;

  const ConversationsScreen({
    super.key,
    this.onUnreadCountUpdated,
    required String currentUserId,
  });

  @override
  State<ConversationsScreen> createState() => _ConversationsScreenState();
}

class _ConversationsScreenState extends State<ConversationsScreen> {
  bool _isSyncing = false;

  final FirebaseChatService _firebaseChat = FirebaseChatService();
  final ChatLocalDb _localDb = ChatLocalDb.instance;

  List<ChatConversation> _conversations = [];

  // ── Selection state ───────────────────────────────────────────────────────
  bool _isSelectionMode = false;
  final Set<String> _selectedIds = {};

  String _currentUserId = '';
  StreamSubscription<List<ChatConversation>>? _conversationsSub;

  final ScrollController _scrollController = ScrollController();
  double _searchBarProgress = 0.0;

  @override
  void initState() {
    super.initState();
    _scrollController.addListener(_onScroll);
    _initialize();
  }

  void _onScroll() {
    final offset = _scrollController.offset;
    final progress = (offset / _kSearchBarHeight).clamp(0.0, 1.0);
    if ((progress - _searchBarProgress).abs() > 0.005) {
      setState(() => _searchBarProgress = progress);
    }
  }

  Future<void> _initialize() async {
    _currentUserId = FirebaseAuth.instance.currentUser?.uid ?? '';

    final cached = await _localDb.loadConversations();
    if (mounted && cached.isNotEmpty) {
      setState(() => _conversations = cached);
      _notifyUnread(cached);
    }

    try {
      await _firebaseChat.connect();

      _conversationsSub = _firebaseChat.conversationsStream.listen((
        conversations,
      ) async {
        await _localDb.saveConversations(conversations);
        final enriched = await _enrichWithUserInfo(conversations);

        if (!mounted) return;
        setState(() {
          _conversations = enriched;
          _isSyncing = false;
        });
        _notifyUnread(enriched);
      });
    } catch (e) {
      debugPrint('ConversationsScreen Firebase error: $e');
      if (mounted) setState(() => _isSyncing = false);
    }
  }

  Future<List<ChatConversation>> _enrichWithUserInfo(
    List<ChatConversation> conversations,
  ) async {
    final unknownIds =
        conversations
            .where((c) => c.otherUserId.isNotEmpty && c.otherUserName == null)
            .map((c) => c.otherUserId)
            .toSet()
            .toList();

    if (unknownIds.isEmpty) return conversations;

    final nameMap = <String, String>{};
    final avatarMap = <String, String?>{};

    const chunkSize = 30;
    for (int i = 0; i < unknownIds.length; i += chunkSize) {
      final chunk = unknownIds.sublist(
        i,
        (i + chunkSize).clamp(0, unknownIds.length),
      );
      try {
        final snap =
            await FirebaseFirestore.instance
                .collection('users')
                .where(FieldPath.documentId, whereIn: chunk)
                .get();

        for (final doc in snap.docs) {
          final data = doc.data();
          final name =
              data['name']?.toString() ??
              data['displayName']?.toString() ??
              data['username']?.toString() ??
              'Unknown';
          final avatar =
              data['profileImage']?.toString() ?? data['photoUrl']?.toString();

          nameMap[doc.id] = name;
          avatarMap[doc.id] = avatar;

          await _localDb.updateConversationUserInfo(
            conversationId:
                conversations.firstWhere((c) => c.otherUserId == doc.id).id,
            name: name,
            avatar: avatar,
          );
        }
      } catch (e) {
        debugPrint('Error enriching user info: $e');
      }
    }

    return conversations.map((c) {
      if (nameMap.containsKey(c.otherUserId)) {
        return c.copyWith(
          otherUserName: nameMap[c.otherUserId],
          otherUserAvatar: avatarMap[c.otherUserId],
        );
      }
      return c;
    }).toList();
  }

  void _notifyUnread(List<ChatConversation> conversations) {
    final total = conversations.fold(0, (sum, c) => sum + c.unreadCount);
    widget.onUnreadCountUpdated?.call(total);
  }

  // ── Selection ─────────────────────────────────────────────────────────────

  void _enterSelectionMode() => setState(() {
    _isSelectionMode = true;
    _selectedIds.clear();
  });
  void _exitSelectionMode() => setState(() {
    _isSelectionMode = false;
    _selectedIds.clear();
  });

  void _toggleSelection(String id) {
    setState(() {
      if (_selectedIds.contains(id)) {
        _selectedIds.remove(id);
      } else {
        _selectedIds.add(id);
      }
    });
  }

  // ── Action stubs ──────────────────────────────────────────────────────────

  void _onPin() => debugPrint('Pin: ${_selectedIds.toList()}');
  void _onMarkAsRead() => debugPrint('MarkAsRead: ${_selectedIds.toList()}');
  void _onMute() => debugPrint('Mute: ${_selectedIds.toList()}');
  void _onArchive() => debugPrint('Archive: ${_selectedIds.toList()}');
  void _onDelete() => debugPrint('Delete: ${_selectedIds.toList()}');

  // ── Time ──────────────────────────────────────────────────────────────────

  String _formatTime(DateTime dt) {
    final now = DateTime.now();
    final local = dt.toLocal();
    final isToday =
        local.year == now.year &&
        local.month == now.month &&
        local.day == now.day;
    if (isToday) {
      final h = local.hour % 12 == 0 ? 12 : local.hour % 12;
      final m = local.minute.toString().padLeft(2, '0');
      return '$h:$m ${local.hour >= 12 ? 'PM' : 'AM'}';
    }
    final yesterday = now.subtract(const Duration(days: 1));
    if (local.year == yesterday.year &&
        local.month == yesterday.month &&
        local.day == yesterday.day)
      return 'Yesterday';
    if (now.difference(local).inDays < 7) {
      const days = ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'];
      return days[local.weekday - 1];
    }
    return '${local.day}/${local.month}/${local.year}';
  }

  // ── Tile builder ──────────────────────────────────────────────────────────

  Widget _buildConversationItem(ChatConversation conversation) {
    final otherId = conversation.otherUserId;
    final name = conversation.otherUserName ?? 'Loading...';
    final avatar = conversation.otherUserAvatar;
    final selected = _selectedIds.contains(conversation.id);

    return ConversationTile(
      name: name,
      lastMessage:
          conversation.lastMessage.isEmpty
              ? 'Say hello! 👋'
              : conversation.lastMessage,
      time: _formatTime(conversation.lastMessageTime),
      avatarUrl: avatar,
      unreadCount: conversation.unreadCount,

      isSelectionMode: _isSelectionMode,
      isSelected: selected,
      onSelectionToggle: () => _toggleSelection(conversation.id),

      onLongPress: () {
        showGeneralDialog(
          context: context,
          barrierDismissible: true,
          barrierLabel: "Preview",
          barrierColor: Colors.transparent,
          pageBuilder: (_, __, ___) {
            return MiniChatPreview(
              conversationId: conversation.id,
              name: name,
              avatarUrl: avatar,
              currentUserId: _currentUserId,
              receiverId: otherId,
            );
          },
        );
      },

      onTap: () async {
        if (_isSelectionMode) {
          _toggleSelection(conversation.id);
          return;
        }

        await _localDb.markConversationRead(conversation.id);

        if (mounted) {
          setState(() {
            _conversations =
                _conversations
                    .map(
                      (c) =>
                          c.id == conversation.id
                              ? c.copyWith(unreadCount: 0)
                              : c,
                    )
                    .toList();
          });
          _notifyUnread(_conversations);
        }

        if (!mounted) return;

        Navigator.push(
          context,
          MaterialPageRoute(
            builder:
                (_) => ChatScreen(
                  conversationId: conversation.id,
                  receiverId: otherId,
                  currentUserId: _currentUserId,
                  title: name,
                  avatarUrl: avatar,
                ),
          ),
        );
      },
    );
  }

  // ── Chats tab ─────────────────────────────────────────────────────────────

  Widget _buildChatsTab(double topPadding) {
    if (_conversations.isEmpty) {
      return ListView(
        controller: _scrollController,
        padding: EdgeInsets.only(top: topPadding, bottom: 120),
        physics: const BouncingScrollPhysics(),
        children: [
          const SizedBox(height: 60),
          Center(
            child: Column(
              children: [
                Icon(
                  Icons.chat_bubble_outline_rounded,
                  size: 64,
                  color: Colors.white.withOpacity(0.12),
                ),
                const SizedBox(height: 16),
                Text(
                  'No conversations yet',
                  style: TextStyle(
                    color: Colors.white.withOpacity(0.35),
                    fontSize: 16,
                    fontWeight: FontWeight.w500,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  'Tap the pencil icon to start a new chat',
                  style: TextStyle(
                    color: Colors.white.withOpacity(0.2),
                    fontSize: 13,
                  ),
                ),
              ],
            ),
          ),
        ],
      );
    }

    return RefreshIndicator(
      color: const Color(0xFF4DA3FF),
      backgroundColor: Colors.transparent,
      onRefresh: () async {
        final fresh = await _localDb.loadConversations();
        if (mounted) setState(() => _conversations = fresh);
      },
      child: ListView.builder(
        controller: _scrollController,
        physics: const BouncingScrollPhysics(),
        padding: EdgeInsets.only(top: topPadding, bottom: 120),
        itemCount: _conversations.length,
        itemBuilder: (_, i) => _buildConversationItem(_conversations[i]),
      ),
    );
  }

  @override
  void dispose() {
    _conversationsSub?.cancel();
    _scrollController.removeListener(_onScroll);
    _scrollController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final double statusBarHeight = MediaQuery.of(context).padding.top;
    final double bottomNavHeight =
        80 + MediaQuery.of(context).padding.bottom + 16;
    final double headerHeight =
        statusBarHeight +
        kToolbarHeight +
        _kSearchBarHeight +
        _kTabBarHeight +
        8.0;
    final double searchBarOffset = _kSearchBarHeight * _searchBarProgress;
    final double gradientHeight = headerHeight - searchBarOffset;

    return Scaffold(
      backgroundColor: Colors.transparent,
      extendBody: true,
      extendBodyBehindAppBar: true,
      floatingActionButton:
          _isSelectionMode
              ? null
              : Padding(
                padding: EdgeInsets.only(bottom: bottomNavHeight - 80),
                child: FloatingActionButton(
                  onPressed: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (_) => const FirebaseNewChatScreen(),
                      ),
                    );
                  },
                  backgroundColor: const Color(0xFF4DA3FF),
                  child: const Icon(Icons.edit_square, color: Colors.black),
                ),
              ),
      floatingActionButtonLocation: FloatingActionButtonLocation.endFloat,
      body: DefaultTabController(
        length: 3,
        child: Stack(
          children: [
            // ── Layer 1: tab content ───────────────────────────────────────
            Positioned.fill(
              child: TabBarView(
                children: [
                  _buildChatsTab(headerHeight),
                  Center(
                    child: Padding(
                      padding: EdgeInsets.only(top: headerHeight),
                      child: const Text(
                        'Channels coming soon',
                        style: TextStyle(color: Colors.grey),
                      ),
                    ),
                  ),
                  Center(
                    child: Padding(
                      padding: EdgeInsets.only(top: headerHeight),
                      child: const Text(
                        'Groups coming soon',
                        style: TextStyle(color: Colors.grey),
                      ),
                    ),
                  ),
                ],
              ),
            ),

            // ── Layer 2: gradient ──────────────────────────────────────────
            Positioned(
              top: 0,
              left: 0,
              right: 0,
              height: gradientHeight,
              child: IgnorePointer(
                child: Container(
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.topCenter,
                      end: Alignment.bottomCenter,
                      stops: const [0.0, 0.6, 1.0],
                      colors: [
                        const Color(0xFF08090B).withOpacity(0.95),
                        const Color(0xFF08090B).withOpacity(0.75),
                        const Color(0xFF08090B).withOpacity(0.0),
                      ],
                    ),
                  ),
                ),
              ),
            ),

            // ── Layer 3: sticky header ─────────────────────────────────────
            Positioned(
              top: 0,
              left: 0,
              right: 0,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  TopBar(
                    isSelectionMode: _isSelectionMode,
                    selectedCount: _selectedIds.length,
                    onEditPressed: _enterSelectionMode,
                    onSelectionClose: _exitSelectionMode,
                    onMarkAsRead: _onMarkAsRead,
                    onPin: _onPin,
                    onMute: _onMute,
                    onArchive: _onArchive,
                    onDelete: _onDelete,
                  ),
                  Transform.translate(
                    offset: Offset(0, -searchBarOffset),
                    child: Opacity(
                      opacity: (1.0 - _searchBarProgress).clamp(0.0, 1.0),
                      child: SizedBox(
                        height: _kSearchBarHeight,
                        child: local_widgets.SearchBar(),
                      ),
                    ),
                  ),
                  Transform.translate(
                    offset: Offset(0, -searchBarOffset),
                    child: const TabBarSection(),
                  ),
                  const SizedBox(height: 8),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
