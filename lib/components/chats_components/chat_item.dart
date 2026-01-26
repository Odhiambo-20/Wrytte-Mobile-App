import 'package:flutter/material.dart';
import 'package:wrytte/components/user_avatar.dart';
import 'package:wrytte/services/chat_service.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:wrytte/ui/screens/chats/widgets/mini_chat_window.dart';

class ChatItem extends StatefulWidget {
  final String name;
  final String lastMessage;
  final String time;
  final String? avatarUrl;
  final bool isRead;
  final bool isOnline;
  final int unreadCount;
  final String chatId;
  final String otherUserId;
  final String? userPhone;
  final VoidCallback? onTap;
  final bool isSelectionMode;
  final bool isSelected;
  final bool isMuted;
  final bool isPinned;
  final bool isArchived;
  final ValueChanged<bool>? onSelectionChanged;
  final Function(bool)? onMuteChanged;
  final Function(bool)? onArchiveChanged;
  final Function()? onDelete;

  const ChatItem({
    super.key,
    required this.name,
    required this.lastMessage,
    required this.time,
    this.avatarUrl,
    this.isRead = true,
    this.isOnline = false,
    this.unreadCount = 0,
    required this.chatId,
    required this.otherUserId,
    this.userPhone,
    this.onTap,
    this.isSelectionMode = false,
    this.isSelected = false,
    this.isMuted = false,
    this.isPinned = false,
    this.isArchived = false,
    this.onSelectionChanged,
    this.onMuteChanged,
    this.onArchiveChanged,
    this.onDelete,
  });

  @override
  State<ChatItem> createState() => _ChatItemState();
}

class _ChatItemState extends State<ChatItem> {
  bool _isSelected = false;
  bool _isMuted = false;
  bool _isArchived = false;
  final ChatService _chatService = ChatService();
  final FirebaseAuth _auth = FirebaseAuth.instance;

  @override
  void initState() {
    super.initState();
    _isSelected = widget.isSelected;
    _isMuted = widget.isMuted;
    _isArchived = widget.isArchived;
  }

  @override
  void didUpdateWidget(covariant ChatItem oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.isSelected != widget.isSelected) {
      setState(() {
        _isSelected = widget.isSelected;
      });
    }
    if (oldWidget.isMuted != widget.isMuted) {
      setState(() {
        _isMuted = widget.isMuted;
      });
    }
    if (oldWidget.isArchived != widget.isArchived) {
      setState(() {
        _isArchived = widget.isArchived;
      });
    }
  }

  void _handleTap() {
    if (widget.isSelectionMode) {
      setState(() {
        _isSelected = !_isSelected;
      });
      widget.onSelectionChanged?.call(_isSelected);
    } else {
      widget.onTap?.call();
    }
  }

  void _handleLongPress() {
    if (!widget.isSelectionMode) {
      _showMiniChatWindow();
    }
  }

  void _showMiniChatWindow() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) {
        return MiniChatWindow(
          chatId: widget.chatId,
          otherUserId: widget.otherUserId,
          userName: widget.name,
          userAvatar: widget.avatarUrl,
          onMarkAsRead: (marked) {
            Navigator.pop(context);
            if (marked) {
              _markAsRead(context);
            }
          },
          onMuteChanged: (muted) {
            Navigator.pop(context);
            if (muted) {
              _showMuteDurationDialog(context);
            }
          },
          onPinChanged: (pinned) {
            Navigator.pop(context);
            _togglePin(context, pinned);
          },
          onDelete: () {
            Navigator.pop(context);
            _deleteChat(context);
          },
          onBlock: () {
            Navigator.pop(context);
            _showBlockConfirmation(context);
          },
        );
      },
    );
  }

  Future<void> _markAsRead(BuildContext context) async {
    final currentUserId = _auth.currentUser?.uid;
    if (currentUserId == null) return;

    try {
      await _chatService.markMessagesAsRead(widget.chatId, currentUserId);
      _showSnackBar(context, 'Marked as read', Colors.green);
    } catch (e) {
      print('Error marking as read: $e');
      _showSnackBar(context, 'Failed to mark as read', Colors.red);
    }
  }

  Future<void> _togglePin(BuildContext context, bool shouldPin) async {
    final currentUserId = _auth.currentUser?.uid;
    if (currentUserId == null) return;

    try {
      await _chatService.togglePinChat(
        widget.chatId,
        currentUserId,
        !shouldPin,
      );

      _showSnackBar(
        context,
        shouldPin ? 'Chat pinned' : 'Chat unpinned',
        Colors.blue,
      );
    } catch (e) {
      print('Error toggling pin: $e');
      _showSnackBar(context, 'Failed to pin/unpin chat', Colors.red);
    }
  }

  void _showBlockConfirmation(BuildContext context) {
    showDialog(
      context: context,
      builder:
          (context) => AlertDialog(
            backgroundColor: const Color(0xFF1E1E1E),
            title: const Text(
              'Block User',
              style: TextStyle(color: Colors.white),
            ),
            content: Text(
              'Block ${widget.name}? You will no longer receive messages from this user.',
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
                  await _performBlock(context);
                },
                child: const Text('Block', style: TextStyle(color: Colors.red)),
              ),
            ],
          ),
    );
  }

  Future<void> _performBlock(BuildContext context) async {
    // TODO: Implement block functionality
    // This would typically update Firestore or your backend
    _showSnackBar(context, 'User blocked', Colors.red);
  }

  Future<void> _muteChat(BuildContext context) async {
    final currentUserId = _auth.currentUser?.uid;
    if (currentUserId == null) return;

    try {
      final isMuted = await _chatService.isChatMuted(
        widget.chatId,
        currentUserId,
      );

      if (isMuted) {
        _showUnmuteConfirmation(context);
      } else {
        _showMuteDurationDialog(context);
      }
    } catch (e) {
      print('Error checking mute status: $e');
      _showSnackBar(context, 'Failed to check mute status', Colors.red);
    }
  }

  void _showUnmuteConfirmation(BuildContext context) {
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
              'Unmute chat with ${widget.name}?',
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
                  _performUnmute(context);
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

  Future<void> _performUnmute(BuildContext context) async {
    final currentUserId = _auth.currentUser?.uid;
    if (currentUserId == null) return;

    try {
      await _chatService.unmuteChat(widget.chatId, currentUserId);

      setState(() {
        _isMuted = false;
      });
      widget.onMuteChanged?.call(false);

      _showSnackBar(context, 'Unmuted chat with ${widget.name}', Colors.green);
    } catch (e) {
      print('Error unmuting chat: $e');
      _showSnackBar(context, 'Failed to unmute chat', Colors.red);
    }
  }

  void _showMuteDurationDialog(BuildContext context) {
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
                  'Mute chat with ${widget.name}',
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
                      await _performMute(
                        context,
                        durations[_selectedDuration]!,
                      );
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

  Future<void> _performMute(BuildContext context, Duration duration) async {
    final currentUserId = _auth.currentUser?.uid;
    if (currentUserId == null) return;

    try {
      await _chatService.muteChatWithDuration(
        widget.chatId,
        currentUserId,
        duration,
      );

      setState(() {
        _isMuted = true;
      });
      widget.onMuteChanged?.call(true);

      _showSnackBar(context, 'Muted chat with ${widget.name}', Colors.blue);
    } catch (e) {
      print('Error muting chat: $e');
      _showSnackBar(context, 'Failed to mute chat', Colors.red);
    }
  }

  Future<void> _deleteChat(BuildContext context) async {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder:
          (context) => Container(
            decoration: const BoxDecoration(
              color: Color(0xFF1E1E1E),
              borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
            ),
            child: SafeArea(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Container(
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      children: [
                        const Icon(
                          Icons.delete_outline,
                          color: Colors.red,
                          size: 48,
                        ),
                        const SizedBox(height: 12),
                        Text(
                          'Delete chat with ${widget.name}?',
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 18,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                        const SizedBox(height: 8),
                        const Text(
                          'This will also delete all messages in this chat.',
                          style: TextStyle(color: Colors.grey, fontSize: 14),
                          textAlign: TextAlign.center,
                        ),
                      ],
                    ),
                  ),

                  ListTile(
                    leading: const Icon(
                      Icons.delete_forever,
                      color: Colors.red,
                    ),
                    title: const Text(
                      'Delete for everyone',
                      style: TextStyle(color: Colors.red),
                    ),
                    subtitle: const Text(
                      'Delete from your device and other people\'s devices',
                      style: TextStyle(color: Colors.grey, fontSize: 12),
                    ),
                    onTap: () async {
                      Navigator.pop(context);
                      await _performDelete(context, deleteForEveryone: true);
                    },
                  ),

                  ListTile(
                    leading: const Icon(Icons.delete, color: Colors.orange),
                    title: const Text(
                      'Delete for me',
                      style: TextStyle(color: Colors.orange),
                    ),
                    subtitle: const Text(
                      'Delete only from your device',
                      style: TextStyle(color: Colors.grey, fontSize: 12),
                    ),
                    onTap: () async {
                      Navigator.pop(context);
                      await _performDelete(context, deleteForEveryone: false);
                    },
                  ),

                  const Divider(color: Colors.grey, height: 1),

                  ListTile(
                    leading: const Icon(Icons.cancel, color: Colors.grey),
                    title: const Text(
                      'Cancel',
                      style: TextStyle(color: Colors.grey),
                    ),
                    onTap: () => Navigator.pop(context),
                  ),

                  const SizedBox(height: 8),
                ],
              ),
            ),
          ),
    );
  }

  Future<void> _performDelete(
    BuildContext context, {
    required bool deleteForEveryone,
  }) async {
    final currentUserId = _auth.currentUser?.uid;
    if (currentUserId == null) return;

    try {
      if (deleteForEveryone) {
        await _chatService.deleteChatForEveryone(widget.chatId);
        _showSnackBar(
          context,
          'Deleted chat with ${widget.name} for everyone',
          Colors.red,
        );
      } else {
        await _chatService.deleteChatForUser(widget.chatId, currentUserId);
        _showSnackBar(context, 'Deleted chat with ${widget.name}', Colors.red);
      }

      widget.onDelete?.call();
    } catch (e) {
      print('Error deleting chat: $e');
      _showSnackBar(context, 'Failed to delete chat', Colors.red);
    }
  }

  Future<void> _archiveChat(BuildContext context) async {
    final currentUserId = _auth.currentUser?.uid;
    if (currentUserId == null) return;

    try {
      if (_isArchived) {
        await _chatService.unarchiveChat(widget.chatId, currentUserId);
        setState(() {
          _isArchived = false;
        });
        widget.onArchiveChanged?.call(false);
        _showSnackBar(
          context,
          'Unarchived chat with ${widget.name}',
          Colors.green,
        );
      } else {
        await _chatService.archiveChat(widget.chatId, currentUserId);
        setState(() {
          _isArchived = true;
        });
        widget.onArchiveChanged?.call(true);
        _showSnackBar(
          context,
          'Archived chat with ${widget.name}',
          Colors.green,
        );
      }
    } catch (e) {
      print('Error toggling archive: $e');
      _showSnackBar(context, 'Failed to archive/unarchive chat', Colors.red);
    }
  }

  void _showSnackBar(BuildContext context, String message, Color color) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: color,
        duration: const Duration(seconds: 2),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: _handleTap,
      onLongPress: _handleLongPress,
      child: Container(
        color:
            _isSelected ? Colors.black.withOpacity(0.15) : Colors.transparent,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 12.0, vertical: 8.0),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              Stack(
                children: [
                  UserAvatar(
                    size: 60,
                    imageUrl: widget.avatarUrl,
                    name: widget.name,
                  ),

                  if (widget.isOnline && !widget.isSelectionMode)
                    Positioned(
                      bottom: 2,
                      right: 2,
                      child: Container(
                        width: 12,
                        height: 12,
                        decoration: BoxDecoration(
                          color: Colors.green,
                          shape: BoxShape.circle,
                          border: Border.all(color: Colors.white, width: 2),
                        ),
                      ),
                    ),

                  if (widget.isSelectionMode)
                    Positioned(
                      bottom: 2,
                      right: 2,
                      child: Container(
                        width: 22,
                        height: 22,
                        decoration: BoxDecoration(
                          color:
                              _isSelected ? Colors.blue : Colors.grey.shade800,
                          shape: BoxShape.circle,
                          border: Border.all(
                            color: Colors.white,
                            width: _isSelected ? 0 : 2,
                          ),
                        ),
                        child:
                            _isSelected
                                ? const Icon(
                                  Icons.check,
                                  color: Colors.white,
                                  size: 14,
                                )
                                : null,
                      ),
                    ),
                ],
              ),
              const SizedBox(width: 12),

              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Expanded(
                          child: Row(
                            children: [
                              Expanded(
                                child: Text(
                                  widget.name,
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: TextStyle(
                                    fontWeight: FontWeight.w500,
                                    fontSize: 16,
                                    color:
                                        _isSelected
                                            ? Colors.blue
                                            : Colors.white,
                                  ),
                                ),
                              ),
                              if (_isMuted && !widget.isSelectionMode)
                                const Padding(
                                  padding: EdgeInsets.only(left: 4),
                                  child: Icon(
                                    Icons.volume_off,
                                    size: 14,
                                    color: Colors.grey,
                                  ),
                                ),
                              if (widget.isPinned && !widget.isSelectionMode)
                                const Padding(
                                  padding: EdgeInsets.only(left: 4),
                                  child: Icon(
                                    Icons.push_pin,
                                    size: 14,
                                    color: Colors.blue,
                                  ),
                                ),
                              if (_isArchived && !widget.isSelectionMode)
                                const Padding(
                                  padding: EdgeInsets.only(left: 4),
                                  child: Icon(
                                    Icons.archive,
                                    size: 14,
                                    color: Colors.grey,
                                  ),
                                ),
                            ],
                          ),
                        ),
                        Text(
                          widget.time,
                          style: TextStyle(
                            fontSize: 12,
                            color: _isSelected ? Colors.blue : Colors.grey[400],
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 2),

                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            widget.lastMessage,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                              fontSize: 14,
                              color:
                                  _isSelected
                                      ? Colors.blue.withOpacity(0.8)
                                      : widget.isRead
                                      ? Colors.grey[400]
                                      : Colors.white,
                              fontWeight:
                                  widget.isRead
                                      ? FontWeight.normal
                                      : FontWeight.w500,
                            ),
                          ),
                        ),
                        if (widget.unreadCount > 0 && !widget.isSelectionMode)
                          Container(
                            margin: const EdgeInsets.only(left: 4),
                            padding: const EdgeInsets.symmetric(
                              horizontal: 6,
                              vertical: 2,
                            ),
                            decoration: BoxDecoration(
                              color: Colors.blue,
                              borderRadius: BorderRadius.circular(10),
                            ),
                            child: Text(
                              widget.unreadCount > 99
                                  ? '99+'
                                  : widget.unreadCount.toString(),
                              style: const TextStyle(
                                color: Colors.white,
                                fontSize: 10,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ),
                      ],
                    ),
                    const SizedBox(height: 15),

                    Divider(
                      color:
                          _isSelected
                              ? Colors.blue.withOpacity(0.3)
                              : Colors.grey.withOpacity(0.3),
                      thickness: 0.5,
                      height: 0,
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
