import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:wrytte/components/message_components/message_bubble.dart';
import 'package:wrytte/components/user_avatar.dart';
import 'package:wrytte/services/chat_service.dart';
import 'package:wrytte/services/user_service.dart';
import 'package:audioplayers/audioplayers.dart';
import 'package:wrytte/ui/screens/message_screen.dart';

class MiniChatWindow extends StatefulWidget {
  final String chatId;
  final String otherUserId;
  final String userName;
  final String? userAvatar;
  final Function(bool)? onMarkAsRead;
  final Function(bool)? onMuteChanged;
  final Function(bool)? onPinChanged;
  final Function()? onDelete;
  final Function()? onBlock;
  final Function(bool)? onArchiveChanged;

  const MiniChatWindow({
    super.key,
    required this.chatId,
    required this.otherUserId,
    required this.userName,
    this.userAvatar,
    this.onMarkAsRead,
    this.onMuteChanged,
    this.onPinChanged,
    this.onDelete,
    this.onBlock,
    this.onArchiveChanged,
  });

  @override
  State<MiniChatWindow> createState() => _MiniChatWindowState();
}

class _MiniChatWindowState extends State<MiniChatWindow> {
  final ChatService _chatService = ChatService();
  final UserService _userService = UserService();
  final FirebaseAuth _auth = FirebaseAuth.instance;
  late Stream<QuerySnapshot> _messagesStream;
  final ScrollController _scrollController = ScrollController();
  final AudioPlayer _audioPlayer = AudioPlayer();
  bool _isPlaying = false;
  String? _currentlyPlayingUrl;
  bool _isArchived = false; // Track archive state

  @override
  void initState() {
    super.initState();
    _messagesStream = _chatService.getMessages(widget.chatId);
    _scrollToBottom();
    _checkArchiveStatus();
  }

  @override
  void dispose() {
    _audioPlayer.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  void _scrollToBottom() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_scrollController.hasClients) {
        _scrollController.animateTo(
          _scrollController.position.maxScrollExtent,
          duration: const Duration(milliseconds: 300),
          curve: Curves.easeOut,
        );
      }
    });
  }

  Future<void> _checkArchiveStatus() async {
    try {
      final chatDoc =
          await FirebaseFirestore.instance
              .collection('chats')
              .doc(widget.chatId)
              .get();

      if (chatDoc.exists) {
        final chatData = chatDoc.data() as Map<String, dynamic>;
        setState(() {
          _isArchived = chatData['isArchived'] ?? false;
        });
      }
    } catch (e) {
      debugPrint('Error checking archive status: $e');
    }
  }

  Future<void> _playVoiceMessage(String audioUrl) async {
    try {
      if (_currentlyPlayingUrl == audioUrl && _isPlaying) {
        await _audioPlayer.pause();
        setState(() => _isPlaying = false);
      } else {
        if (_currentlyPlayingUrl != null) {
          await _audioPlayer.stop();
        }

        await _audioPlayer.play(UrlSource(audioUrl));
        setState(() {
          _currentlyPlayingUrl = audioUrl;
          _isPlaying = true;
        });

        _audioPlayer.onPlayerComplete.listen((event) {
          setState(() => _isPlaying = false);
        });
      }
    } catch (e) {
      debugPrint('Error playing voice message: $e');
    }
  }

  Widget _buildMessageItem(QueryDocumentSnapshot messageDoc) {
    final messageData = messageDoc.data() as Map<String, dynamic>;
    final senderId = messageData['senderId'] ?? '';
    final timestamp = messageData['timestamp'] as Timestamp?;
    final messageType = messageData['messageType'] ?? 'text';

    final isMe = senderId == _auth.currentUser!.uid;
    final time =
        timestamp != null
            ? '${timestamp.toDate().hour.toString().padLeft(2, '0')}:${timestamp.toDate().minute.toString().padLeft(2, '0')}'
            : '';

    return MessageBubble(
      text: messageData['text'] ?? '',
      time: time,
      isMe: isMe,
      isRead: true,
      messageType: messageType,
      imageUrl: messageData['imageUrl'],
      audioUrl: messageData['audioUrl'],
      audioDuration:
          messageData['duration'] != null
              ? Duration(milliseconds: messageData['duration'])
              : null,
      isPlaying: messageData['audioUrl'] == _currentlyPlayingUrl && _isPlaying,
      onVoicePlayPressed:
          messageData['audioUrl'] != null
              ? () => _playVoiceMessage(messageData['audioUrl'])
              : null,
      onReply: null,
      onReplyTap: null,
      messageId: '',
    );
  }

  /// Archive Chat Functionality
  Future<void> _archiveChat() async {
    final currentUserId = _auth.currentUser?.uid;
    if (currentUserId == null) return;

    showDialog(
      context: context,
      builder:
          (context) => AlertDialog(
            backgroundColor: const Color(0xFF1E1E1E),
            title: Text(
              _isArchived ? 'Unarchive Chat' : 'Archive Chat',
              style: const TextStyle(color: Colors.white),
            ),
            content: Text(
              _isArchived
                  ? 'Unarchive chat with ${widget.userName}?'
                  : 'Archive chat with ${widget.userName}? Archived chats can be found in the Archived section.',
              style: const TextStyle(color: Colors.grey),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context),
                child: const Text(
                  'Cancel',
                  style: TextStyle(color: Colors.grey),
                ),
              ),
              TextButton(
                onPressed: () async {
                  Navigator.pop(context);
                  await _performArchiveToggle(currentUserId);
                },
                child: Text(
                  _isArchived ? 'Unarchive' : 'Archive',
                  style: TextStyle(
                    color: _isArchived ? Colors.green : Colors.blue,
                  ),
                ),
              ),
            ],
          ),
    );
  }

  Future<void> _performArchiveToggle(String currentUserId) async {
    try {
      if (_isArchived) {
        await _chatService.unarchiveChat(widget.chatId, currentUserId);
        setState(() {
          _isArchived = false;
        });
        widget.onArchiveChanged?.call(false);

        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Unarchived chat with ${widget.userName}'),
            backgroundColor: Colors.green,
            duration: const Duration(seconds: 2),
          ),
        );
      } else {
        await _chatService.archiveChat(widget.chatId, currentUserId);
        setState(() {
          _isArchived = true;
        });
        widget.onArchiveChanged?.call(true);

        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Archived chat with ${widget.userName}'),
            backgroundColor: Colors.blue,
            duration: const Duration(seconds: 2),
          ),
        );
      }

      // Close the mini window after archiving
      if (mounted) {
        Navigator.pop(context);
      }
    } catch (e) {
      debugPrint('Error toggling archive: $e');
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'Failed to ${_isArchived ? 'unarchive' : 'archive'} chat',
          ),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  /// Block User Functionality
  Future<void> _blockUser() async {
    final currentUserId = _auth.currentUser?.uid;
    if (currentUserId == null) return;

    showDialog(
      context: context,
      builder:
          (context) => AlertDialog(
            backgroundColor: const Color(0xFF1E1E1E),
            title: const Text(
              'Block User',
              style: TextStyle(color: Colors.white),
            ),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Block ${widget.userName}?',
                  style: const TextStyle(color: Colors.white, fontSize: 16),
                ),
                const SizedBox(height: 8),
                Text(
                  '• ${widget.userName} will no longer be able to call you or send you messages',
                  style: const TextStyle(color: Colors.grey, fontSize: 12),
                ),
                const SizedBox(height: 4),
                Text(
                  '• You will not receive notifications from ${widget.userName}',
                  style: const TextStyle(color: Colors.grey, fontSize: 12),
                ),
                const SizedBox(height: 4),
                Text(
                  '• You will not see ${widget.userName}\'s online status or last seen',
                  style: const TextStyle(color: Colors.grey, fontSize: 12),
                ),
                const SizedBox(height: 8),
                const Text(
                  'You can unblock them anytime from Settings.',
                  style: TextStyle(color: Colors.grey, fontSize: 12),
                ),
              ],
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context),
                child: const Text(
                  'Cancel',
                  style: TextStyle(color: Colors.grey),
                ),
              ),
              TextButton(
                onPressed: () async {
                  Navigator.pop(context);
                  await _performBlock(currentUserId);
                },
                child: const Text('Block', style: TextStyle(color: Colors.red)),
              ),
            ],
          ),
    );
  }

  Future<void> _performBlock(String currentUserId) async {
    try {
      // 1. Add to blocked users in Firestore
      await FirebaseFirestore.instance
          .collection('users')
          .doc(currentUserId)
          .update({
            'blockedUsers': FieldValue.arrayUnion([widget.otherUserId]),
            'blockedAt': FieldValue.serverTimestamp(),
          });

      // 2. Archive the chat automatically
      await _chatService.archiveChat(widget.chatId, currentUserId);

      // 3. Mark all messages as read
      await _chatService.markMessagesAsRead(widget.chatId, currentUserId);

      // 4. Update local archive state
      setState(() {
        _isArchived = true;
      });

      // 5. Show success message
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Blocked ${widget.userName}'),
          backgroundColor: Colors.red,
          duration: const Duration(seconds: 2),
        ),
      );

      // 6. Call the callback if provided
      widget.onBlock?.call();
      widget.onArchiveChanged?.call(true);

      // 7. Close the mini window
      if (mounted) {
        Navigator.pop(context);
      }
    } catch (e) {
      debugPrint('Error blocking user: $e');
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Failed to block user: $e'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  /// Mute Functionality
  Future<void> _muteChat() async {
    final currentUserId = _auth.currentUser?.uid;
    if (currentUserId == null) return;

    try {
      final isMuted = await _chatService.isChatMuted(
        widget.chatId,
        currentUserId,
      );

      if (isMuted) {
        _showUnmuteConfirmation();
      } else {
        _showMuteDurationDialog();
      }
    } catch (e) {
      debugPrint('Error checking mute status: $e');
      _showSnackBar('Failed to check mute status', Colors.red);
    }
  }

  void _showUnmuteConfirmation() {
    showDialog(
      context: context,
      builder:
          (context) => AlertDialog(
            backgroundColor: const Color(0xFF1E1E1E),
            title: const Text(
              'Unmute Chat',
              style: TextStyle(color: Colors.white),
            ),
            content: Text(
              'Unmute chat with ${widget.userName}?',
              style: const TextStyle(color: Colors.grey),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context),
                child: const Text(
                  'Cancel',
                  style: TextStyle(color: Colors.grey),
                ),
              ),
              TextButton(
                onPressed: () {
                  Navigator.pop(context);
                  _performUnmute();
                },
                child: const Text(
                  'Unmute',
                  style: TextStyle(color: Colors.green),
                ),
              ),
            ],
          ),
    );
  }

  Future<void> _performUnmute() async {
    final currentUserId = _auth.currentUser?.uid;
    if (currentUserId == null) return;

    try {
      await _chatService.unmuteChat(widget.chatId, currentUserId);
      widget.onMuteChanged?.call(false);

      _showSnackBar('Unmuted chat with ${widget.userName}', Colors.green);
    } catch (e) {
      debugPrint('Error unmuting chat: $e');
      _showSnackBar('Failed to unmute chat', Colors.red);
    }
  }

  void _showMuteDurationDialog() {
    showDialog(
      context: context,
      builder:
          (context) => StatefulBuilder(
            builder: (context, setState) {
              String _selectedDuration = '8 hours';
              final Map<String, Duration> durations = {
                '8 hours': const Duration(hours: 8),
                '1 week': const Duration(days: 7),
                'Always': const Duration(days: 365 * 100),
              };

              return AlertDialog(
                backgroundColor: const Color(0xFF1E1E1E),
                title: Text(
                  'Mute chat with ${widget.userName}',
                  style: const TextStyle(color: Colors.white),
                ),
                content: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Text(
                      'Mute notifications for:',
                      style: TextStyle(color: Colors.grey),
                    ),
                    const SizedBox(height: 16),
                    ...durations.keys.map((duration) {
                      return RadioListTile<String>(
                        title: Text(
                          duration,
                          style: const TextStyle(color: Colors.white),
                        ),
                        value: duration,
                        groupValue: _selectedDuration,
                        onChanged: (value) {
                          setState(() {
                            _selectedDuration = value!;
                          });
                        },
                        activeColor: Colors.blue,
                        contentPadding: EdgeInsets.zero,
                      );
                    }).toList(),
                    const SizedBox(height: 8),
                    const Text(
                      'You can unmute anytime from chat info.',
                      style: TextStyle(color: Colors.grey, fontSize: 12),
                    ),
                  ],
                ),
                actions: [
                  TextButton(
                    onPressed: () => Navigator.pop(context),
                    child: const Text(
                      'Cancel',
                      style: TextStyle(color: Colors.grey),
                    ),
                  ),
                  TextButton(
                    onPressed: () async {
                      Navigator.pop(context);
                      await _performMute(durations[_selectedDuration]!);
                    },
                    child: const Text(
                      'Mute',
                      style: TextStyle(color: Colors.blue),
                    ),
                  ),
                ],
              );
            },
          ),
    );
  }

  Future<void> _performMute(Duration duration) async {
    final currentUserId = _auth.currentUser?.uid;
    if (currentUserId == null) return;

    try {
      await _chatService.muteChatWithDuration(
        widget.chatId,
        currentUserId,
        duration,
      );
      widget.onMuteChanged?.call(true);

      _showSnackBar('Muted chat with ${widget.userName}', Colors.blue);
    } catch (e) {
      debugPrint('Error muting chat: $e');
      _showSnackBar('Failed to mute chat', Colors.red);
    }
  }

  /// Mark as Read Functionality
  Future<void> _markAsRead() async {
    final currentUserId = _auth.currentUser?.uid;
    if (currentUserId == null) return;

    try {
      await _chatService.markMessagesAsRead(widget.chatId, currentUserId);
      widget.onMarkAsRead?.call(true);

      _showSnackBar('Marked as read', Colors.green);
    } catch (e) {
      debugPrint('Error marking as read: $e');
      _showSnackBar('Failed to mark as read', Colors.red);
    }
  }

  /// Pin/Unpin Functionality
  Future<void> _pinChat() async {
    final currentUserId = _auth.currentUser?.uid;
    if (currentUserId == null) return;

    try {
      final chatDoc =
          await FirebaseFirestore.instance
              .collection('chats')
              .doc(widget.chatId)
              .get();

      if (chatDoc.exists) {
        final chatData = chatDoc.data() as Map<String, dynamic>;
        final isCurrentlyPinned = chatData['isPinned'] ?? false;

        await _chatService.togglePinChat(
          widget.chatId,
          currentUserId,
          isCurrentlyPinned,
        );

        widget.onPinChanged?.call(!isCurrentlyPinned);

        _showSnackBar(
          isCurrentlyPinned ? 'Chat unpinned' : 'Chat pinned',
          Colors.blue,
        );
      }
    } catch (e) {
      debugPrint('Error toggling pin: $e');
      _showSnackBar('Failed to pin/unpin chat', Colors.red);
    }
  }

  void _showSnackBar(String message, Color color) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: color,
        duration: const Duration(seconds: 2),
      ),
    );
  }

  /// ANDROID STYLE ACTION MENU
  Widget _buildTopActionMenu() {
    return Column(
      children: [
        Container(
          height: 56,
          decoration: BoxDecoration(
            color: Colors.grey[900],
            borderRadius: const BorderRadius.only(
              topLeft: Radius.circular(16),
              topRight: Radius.circular(16),
            ),
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
            children: [
              _actionIcon(Icons.mark_chat_read_outlined, _markAsRead),
              _actionIcon(Icons.push_pin_outlined, _pinChat),
              _actionIcon(Icons.volume_off_outlined, _muteChat),
              _actionIcon(
                _isArchived ? Icons.unarchive_outlined : Icons.archive_outlined,
                _archiveChat,
              ),
              _actionIcon(Icons.block_outlined, _blockUser),
              _actionIcon(
                Icons.delete_outlined,
                widget.onDelete,
                color: Colors.red,
              ),
            ],
          ),
        ),

        // Thin divider (exactly like image)
        Container(height: 0.5, color: Colors.grey[700]),
      ],
    );
  }

  Widget _actionIcon(
    IconData icon,
    VoidCallback? onTap, {
    Color color = Colors.white,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Icon(icon, color: color, size: 22),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: Stack(
        children: [
          GestureDetector(
            onTap: () => Navigator.pop(context),
            child: Container(color: Colors.black.withOpacity(0.8)),
          ),

          Center(
            child: GestureDetector(
              onTap: () {
                // Navigate to MessageScreen when mini window is tapped
                Navigator.pop(context); // Close the mini window first
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder:
                        (context) => MessageScreen(
                          name: widget.userName,
                          receiverId: widget.otherUserId,
                          avatarUrl: widget.userAvatar,
                          chatId: widget.chatId,
                          isOnline: false,
                        ),
                  ),
                );
              },
              child: Container(
                width: MediaQuery.of(context).size.width * 0.95,
                constraints: BoxConstraints(maxWidth: 500),
                height: MediaQuery.of(context).size.height * 0.75,
                decoration: BoxDecoration(
                  color: Colors.black,
                  borderRadius: BorderRadius.circular(16),
                ),
                child: Column(
                  children: [
                    // Android action menu
                    _buildTopActionMenu(),

                    // Header
                    Container(
                      height: 60,
                      decoration: BoxDecoration(color: Colors.grey[900]),
                      child: Center(
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            UserAvatar(
                              size: 36,
                              imageUrl: widget.userAvatar,
                              name: widget.userName,
                            ),
                            const SizedBox(width: 12),
                            Text(
                              widget.userName,
                              style: const TextStyle(
                                color: Colors.white,
                                fontSize: 16,
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),

                    // Messages
                    Expanded(
                      child: Container(
                        decoration: const BoxDecoration(
                          image: DecorationImage(
                            image: AssetImage(
                              "assets/images/chat_wallpaper.jpg",
                            ),
                            fit: BoxFit.cover,
                          ),
                        ),
                        child: StreamBuilder<QuerySnapshot>(
                          stream: _messagesStream,
                          builder: (context, snapshot) {
                            if (!snapshot.hasData) {
                              return const Center(
                                child: CircularProgressIndicator(
                                  color: Colors.white,
                                ),
                              );
                            }

                            final messages = snapshot.data!.docs;

                            return ListView.builder(
                              controller: _scrollController,
                              padding: const EdgeInsets.all(16),
                              itemCount: messages.length,
                              itemBuilder:
                                  (context, index) =>
                                      _buildMessageItem(messages[index]),
                            );
                          },
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
