import 'dart:async';
import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:wrytte/components/user_avatar.dart';
import 'package:wrytte/models/chat_models/chat_message.dart';
import 'package:wrytte/models/user_models/user_profile_service.dart';
import 'package:wrytte/services/chat/chat_local_db.dart';
import 'package:wrytte/services/chat/firebase_chat_service.dart';
import 'package:wrytte/services/user/user_profile_service.dart';
import 'package:wrytte/state/chat/chat_state.dart';
import 'package:wrytte/ui/screens/chats/widgets/message_bubble.dart';
import 'package:wrytte/ui/screens/chats/widgets/message_input.dart';
import 'package:wrytte/ui/screens/profile_screen.dart';

class ChatScreen extends StatefulWidget {
  final String conversationId;
  final String receiverId;
  final String currentUserId;
  final String title;
  final ChatState? chatState;
  final String? avatarUrl;

  const ChatScreen({
    super.key,
    required this.conversationId,
    required this.receiverId,
    required this.currentUserId,
    required this.title,
    this.chatState,
    this.avatarUrl,
  });

  @override
  State<ChatScreen> createState() => _ChatScreenState();
}

class _ChatScreenState extends State<ChatScreen> {
  final TextEditingController _controller = TextEditingController();
  final ScrollController _scrollController = ScrollController();
  final FocusNode _focusNode = FocusNode();

  late final FirebaseChatService _firebaseChat;
  StreamSubscription<List<ChatMessage>>? _messagesSub;
  final List<ChatMessage> _firebaseMessages = [];
  final ChatLocalDb _localDb = ChatLocalDb.instance;

  UserProfile? _receiverProfile;

  bool get _isFirebaseMode =>
      widget.chatState == null && widget.currentUserId.isNotEmpty;

  bool _isSending = false;

  // ── Message selection state ──────────────────────────────────────────────
  bool _isMessageSelectionMode = false;
  final Set<String> _selectedMessageIds = {};

  void _onMessageLongPress(String messageId) {
    setState(() {
      _isMessageSelectionMode = true;
      _selectedMessageIds.add(messageId);
    });
  }

  void _onMessageTap(String messageId) {
    if (!_isMessageSelectionMode) return;
    setState(() {
      _selectedMessageIds.contains(messageId)
          ? _selectedMessageIds.remove(messageId)
          : _selectedMessageIds.add(messageId);
      if (_selectedMessageIds.isEmpty) _isMessageSelectionMode = false;
    });
  }

  void _exitMessageSelection() => setState(() {
        _isMessageSelectionMode = false;
        _selectedMessageIds.clear();
      });
  // ────────────────────────────────────────────────────────────────────────

  // Header pill height — slightly larger so avatar can overflow nicely
  static const double _kHeaderPillHeight = 48.0;
  // Input pill height — thinner than header
  static const double _kInputPillHeight = 40.0;

  @override
  void initState() {
    super.initState();
    if (_isFirebaseMode) {
      _initFirebase();
    } else if (widget.chatState != null) {
      _initLegacyChat();
    }
    _loadReceiverProfile();
    WidgetsBinding.instance.addPostFrameCallback((_) => _scrollToBottom());
  }

  Future<void> _loadReceiverProfile() async {
    final profile = await UserProfileService.instance.getProfileByUid(
      widget.receiverId,
    );
    if (mounted) setState(() => _receiverProfile = profile);
  }

  Future<void> _initFirebase() async {
    _firebaseChat = FirebaseChatService();
    await _firebaseChat.connect();
    await _firebaseChat.ensureConversation(widget.receiverId);
    await _firebaseChat.markConversationAsRead(widget.conversationId);
    await _localDb.markConversationRead(widget.conversationId);

    final cached = await _localDb.loadMessages(widget.conversationId);
    if (mounted && cached.isNotEmpty) {
      setState(() {
        _firebaseMessages
          ..clear()
          ..addAll(cached);
      });
      WidgetsBinding.instance.addPostFrameCallback((_) => _scrollToBottom());
    }

    _messagesSub = _firebaseChat
        .getMessagesStream(widget.conversationId)
        .listen((messages) async {
      await _localDb.saveMessages(messages);
      if (!mounted) return;
      setState(() {
        _firebaseMessages
          ..clear()
          ..addAll(messages);
      });
      WidgetsBinding.instance.addPostFrameCallback(
        (_) => _scrollToBottom(),
      );
    });
  }

  Future<void> _initLegacyChat() async {
    await widget.chatState!.initialize();
    await widget.chatState!.loadConversation(widget.conversationId);
    WidgetsBinding.instance.addPostFrameCallback((_) => _scrollToBottom());
  }

  Future<void> _send() async {
    final text = _controller.text.trim();
    if (text.isEmpty || _isSending) return;

    _controller.clear();

    if (_isFirebaseMode) {
      setState(() => _isSending = true);
      try {
        final message = ChatMessage(
          id: DateTime.now().millisecondsSinceEpoch.toString(),
          conversationId: widget.conversationId,
          senderId: widget.currentUserId,
          receiverId: widget.receiverId,
          content: text,
          timestamp: DateTime.now(),
          status: MessageStatus.sending,
        );
        await _localDb.saveMessage(message);
        if (mounted) {
          setState(() => _firebaseMessages.add(message));
          Future.delayed(const Duration(milliseconds: 80), _scrollToBottom);
        }
        await _firebaseChat.sendMessage(message);
      } catch (e) {
        debugPrint('Send error: $e');
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Failed to send: $e'),
              backgroundColor: Colors.redAccent,
            ),
          );
        }
      } finally {
        if (mounted) setState(() => _isSending = false);
      }
      return;
    }

    final message = ChatMessage(
      id: DateTime.now().millisecondsSinceEpoch.toString(),
      conversationId: widget.conversationId,
      senderId: widget.currentUserId,
      receiverId: widget.receiverId,
      content: text,
      timestamp: DateTime.now(),
      status: MessageStatus.sending,
    );
    widget.chatState!.sendMessage(message);
    Future.delayed(const Duration(milliseconds: 80), _scrollToBottom);
  }

  void _scrollToBottom() {
    if (_scrollController.hasClients) {
      _scrollController.animateTo(
        _scrollController.position.maxScrollExtent,
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeOut,
      );
    }
  }

  @override
  void dispose() {
    _messagesSub?.cancel();
    _controller.dispose();
    _scrollController.dispose();
    _focusNode.dispose();
    super.dispose();
  }

  // ── Build ──────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    final double statusBarHeight = MediaQuery.of(context).padding.top;
    final double appBarHeight = statusBarHeight + kToolbarHeight;

    return Scaffold(
      backgroundColor: const Color(0xFF08090B),
      extendBodyBehindAppBar: true,
      extendBody: true,
      body: Stack(
        children: [
          // ── Layer 1: message list + input ────────────────────────────
          Column(
            children: [
              SizedBox(height: appBarHeight),
              Expanded(child: _buildMessageList()),
              MessageInputField(
                controller: _controller,
                focusNode: _focusNode,
                isSending: _isSending,
                onSend: _send,
                inputPillHeight: _kInputPillHeight,
              ),
            ],
          ),

          // ── Layer 2: top gradient scrim ───────────────────────────────
          Positioned(
            top: 0,
            left: 0,
            right: 0,
            height: appBarHeight + 20,
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

          // ── Layer 3: app bar ──────────────────────────────────────────
          Positioned(
            top: 0,
            left: 0,
            right: 0,
            child: _buildAppBar(statusBarHeight),
          ),
        ],
      ),
    );
  }

  Widget _buildMessageList() {
    if (_isFirebaseMode) return _buildFirebaseMessages();
    return _buildLegacyMessages();
  }

  // ── App bar ────────────────────────────────────────────────────────────────

  Widget _buildAppBar(double statusBarHeight) {
    // ── Switch to selection bar when in selection mode ──────────────────────
    if (_isMessageSelectionMode) return _buildSelectionBar(statusBarHeight);

    final String displayName = _receiverProfile?.displayName ?? widget.title;

    return Padding(
      padding: EdgeInsets.only(top: statusBarHeight),
      child: SizedBox(
        height: kToolbarHeight,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 12),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              // ── Back pill ────────────────────────────────────────────
              _glassPill(
                width: _kHeaderPillHeight,
                height: _kHeaderPillHeight,
                child: const Icon(
                  Icons.arrow_back_ios_new,
                  color: Colors.white,
                  size: 16,
                ),
                onTap: () => Navigator.pop(context),
              ),

              const SizedBox(width: 8),

              // ── Name + avatar pill ────────────────────────────────────────
              Expanded(
                child: GestureDetector(
                  onTap: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (_) => ProfileScreen(uid: widget.receiverId),
                      ),
                    );
                  },
                  child: SizedBox(
                    height: _kHeaderPillHeight,
                    child: Stack(
                      clipBehavior: Clip.none,
                      children: [
                        // The pill itself — full width
                        Positioned.fill(
                          child: ClipRRect(
                            borderRadius: BorderRadius.circular(24),
                            child: BackdropFilter(
                              filter: ImageFilter.blur(sigmaX: 24, sigmaY: 24),
                              child: Container(
                                decoration: BoxDecoration(
                                  color: const Color(
                                    0xFF23262C,
                                  ).withOpacity(0.30),
                                  borderRadius: BorderRadius.circular(24),
                                  border: Border.all(
                                    color: const Color(0xFF23262C),
                                    width: 1.0,
                                  ),
                                ),
                              ),
                            ),
                          ),
                        ),

                        // Avatar — overflows top and bottom
                        Positioned(
                          left: 2,
                          top: -2,
                          bottom: -2,
                          child: AspectRatio(
                            aspectRatio: 1,
                            child: UserAvatar(
                              size: _kHeaderPillHeight + 12,
                              imageUrl:
                                  _receiverProfile?.hasProfileImage == true
                                      ? _receiverProfile!.profileImage
                                      : widget.avatarUrl,
                              name: displayName,
                            ),
                          ),
                        ),

                        // Name + status
                        Positioned(
                          left: _kHeaderPillHeight + 14,
                          top: 0,
                          bottom: 0,
                          right: 12,
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                displayName,
                                style: const TextStyle(
                                  color: Colors.white,
                                  fontSize: 15,
                                  fontWeight: FontWeight.w600,
                                ),
                                overflow: TextOverflow.ellipsis,
                              ),
                              Text(
                                'Online',
                                style: TextStyle(
                                  color: Colors.white.withOpacity(0.5),
                                  fontSize: 12,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),

              const SizedBox(width: 8),

              // ── Video pill — separate ─────────────────────────────────
              _glassPill(
                width: _kHeaderPillHeight,
                height: _kHeaderPillHeight,
                child: const Icon(
                  Icons.videocam_outlined,
                  color: Colors.white,
                  size: 20,
                ),
                onTap: () {},
              ),

              const SizedBox(width: 8),

              // ── Call pill — separate ──────────────────────────────────
              _glassPill(
                width: _kHeaderPillHeight,
                height: _kHeaderPillHeight,
                child: const Icon(
                  Icons.call_outlined,
                  color: Colors.white,
                  size: 20,
                ),
                onTap: () {},
              ),
            ],
          ),
        ),
      ),
    );
  }

  // ── Selection bar — replaces app bar when messages are selected ────────────

  Widget _buildSelectionBar(double statusBarHeight) {
    return Padding(
      padding: EdgeInsets.only(top: statusBarHeight),
      child: SizedBox(
        height: kToolbarHeight,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 12),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              // ── Close pill ───────────────────────────────────────────
              _glassPill(
                width: _kHeaderPillHeight,
                height: _kHeaderPillHeight,
                child: const Icon(Icons.close, color: Colors.white, size: 18),
                onTap: _exitMessageSelection,
              ),

              const SizedBox(width: 12),

              // ── Selected count ───────────────────────────────────────
              Expanded(
                child: Text(
                  '${_selectedMessageIds.length}',
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 17,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),

              // ── Reply pill ───────────────────────────────────────────
              _glassPill(
                width: _kHeaderPillHeight,
                height: _kHeaderPillHeight,
                child: const Icon(Icons.reply, color: Colors.white, size: 20),
                onTap: () {}, // TODO: implement reply
              ),

              const SizedBox(width: 8),

              // ── Star pill ────────────────────────────────────────────
              _glassPill(
                width: _kHeaderPillHeight,
                height: _kHeaderPillHeight,
                child: const Icon(
                  Icons.star_border,
                  color: Colors.white,
                  size: 20,
                ),
                onTap: () {}, // TODO: implement star
              ),

              const SizedBox(width: 8),

              // ── Delete pill ──────────────────────────────────────────
              _glassPill(
                width: _kHeaderPillHeight,
                height: _kHeaderPillHeight,
                child: const Icon(
                  Icons.delete_outline,
                  color: Colors.white,
                  size: 20,
                ),
                onTap: () {}, // TODO: implement delete
              ),

              const SizedBox(width: 8),

              // ── Forward pill ─────────────────────────────────────────
              _glassPill(
                width: _kHeaderPillHeight,
                height: _kHeaderPillHeight,
                child: const Icon(
                  Icons.forward,
                  color: Colors.white,
                  size: 20,
                ),
                onTap: () {}, // TODO: implement forward
              ),
            ],
          ),
        ),
      ),
    );
  }

  // ── Firebase messages ──────────────────────────────────────────────────────

  Widget _buildFirebaseMessages() {
    if (_firebaseMessages.isEmpty) {
      return Center(
        child: Text(
          'No messages yet.\nSay hello! 👋',
          textAlign: TextAlign.center,
          style: TextStyle(
            color: Colors.white.withOpacity(0.3),
            fontSize: 15,
            height: 1.6,
          ),
        ),
      );
    }

    return ListView.builder(
      controller: _scrollController,
      padding: const EdgeInsets.only(top: 12, bottom: 8),
      physics: const BouncingScrollPhysics(),
      itemCount: _firebaseMessages.length,
      itemBuilder: (context, index) {
        final msg = _firebaseMessages[index];
        final isMine = msg.senderId == widget.currentUserId;
        final prev = index > 0 ? _firebaseMessages[index - 1] : null;
        final showTail =
            prev == null || (prev.senderId == widget.currentUserId) != isMine;
        final isSelected = _selectedMessageIds.contains(msg.id);

        return Column(
          children: [
            if (index == 0) _buildDateDivider('Today'),
            // ── GestureDetector wraps bubble for long-press + tap ─────
            GestureDetector(
              onLongPress: () => _onMessageLongPress(msg.id),
              onTap: () => _onMessageTap(msg.id),
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 150),
                color: isSelected
                    ? Colors.white.withOpacity(0.08)
                    : Colors.transparent,
                child: MessageBubble(
                  content: msg.content,
                  time: _formatTime(msg.timestamp),
                  isMine: isMine,
                  showTail: showTail,
                  status: isMine ? msg.status : null,
                ),
              ),
            ),
          ],
        );
      },
    );
  }

  // ── Legacy messages ────────────────────────────────────────────────────────

  Widget _buildLegacyMessages() {
    return StreamBuilder<List<ChatMessage>>(
      stream: widget.chatState!.messagesStream,
      builder: (context, snapshot) {
        final messages = (snapshot.data ?? [])
            .where((m) => m.conversationId == widget.conversationId)
            .toList();
        WidgetsBinding.instance.addPostFrameCallback((_) => _scrollToBottom());
        return ListView.builder(
          controller: _scrollController,
          padding: const EdgeInsets.only(top: 12, bottom: 8),
          physics: const BouncingScrollPhysics(),
          itemCount: messages.length,
          itemBuilder: (context, index) {
            final msg = messages[index];
            final isMine = msg.senderId == widget.currentUserId;
            final prev = index > 0 ? messages[index - 1] : null;
            final showTail =
                prev == null ||
                (prev.senderId == widget.currentUserId) != isMine;
            final isSelected = _selectedMessageIds.contains(msg.id);

            return Column(
              children: [
                if (index == 0) _buildDateDivider('Today'),
                // ── GestureDetector wraps bubble for long-press + tap ─
                GestureDetector(
                  onLongPress: () => _onMessageLongPress(msg.id),
                  onTap: () => _onMessageTap(msg.id),
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 150),
                    color: isSelected
                        ? Colors.white.withOpacity(0.08)
                        : Colors.transparent,
                    child: MessageBubble(
                      content: msg.content,
                      time: _formatTime(msg.timestamp),
                      isMine: isMine,
                      showTail: showTail,
                      status: isMine ? msg.status : null,
                    ),
                  ),
                ),
              ],
            );
          },
        );
      },
    );
  }

  String _formatTime(DateTime dt) {
    final h = dt.hour % 12 == 0 ? 12 : dt.hour % 12;
    final m = dt.minute.toString().padLeft(2, '0');
    final period = dt.hour >= 12 ? 'PM' : 'AM';
    return '$h:$m $period';
  }

  // ── Date divider ───────────────────────────────────────────────────────────

  Widget _buildDateDivider(String label) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 12),
      child: Row(
        children: [
          Expanded(
            child: Divider(color: Colors.white.withOpacity(0.08), height: 1),
          ),
          const SizedBox(width: 10),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
            decoration: BoxDecoration(
              color: const Color(0xFF23262C).withOpacity(0.60),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Text(
              label,
              style: TextStyle(
                color: Colors.white.withOpacity(0.5),
                fontSize: 12,
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Divider(color: Colors.white.withOpacity(0.08), height: 1),
          ),
        ],
      ),
    );
  }

  // ── Shared glass pill builder ──────────────────────────────────────────────

  Widget _glassPill({
    required double width,
    required double height,
    required Widget child,
    VoidCallback? onTap,
  }) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(height / 2),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 24, sigmaY: 24),
        child: GestureDetector(
          onTap: onTap,
          child: Container(
            width: width,
            height: height,
            decoration: BoxDecoration(
              color: const Color(0xFF23262C).withOpacity(0.30),
              borderRadius: BorderRadius.circular(height / 2),
              border: Border.all(color: const Color(0xFF23262C), width: 1.0),
            ),
            child: Center(child: child),
          ),
        ),
      ),
    );
  }
}