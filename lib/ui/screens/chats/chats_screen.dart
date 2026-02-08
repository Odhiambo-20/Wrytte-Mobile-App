import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:rxdart/rxdart.dart';
import 'package:wrytte/components/chats_components/chat_item.dart';
import 'package:wrytte/services/chat_service.dart';
import 'package:wrytte/services/user_service.dart';
import 'package:wrytte/services/contact_service.dart';
import 'package:wrytte/ui/screens/chats/archived_screen.dart';
import 'package:wrytte/ui/screens/chats/widgets/top_bar.dart';
import 'package:wrytte/ui/screens/message_screen.dart';
import 'package:wrytte/ui/screens/select_contact_screen.dart';
import 'widgets/search_bar.dart' as local_widgets;
import 'widgets/tab_bar_section.dart';

class ChatsScreen extends StatefulWidget {
  final Function(int)? onUnreadCountUpdated;
  const ChatsScreen({super.key, this.onUnreadCountUpdated});

  @override
  State<ChatsScreen> createState() => _ChatsScreenState();
}

class _ChatsScreenState extends State<ChatsScreen> {
  final ChatService _chatService = ChatService();
  final UserService _userService = UserService();
  final ContactService _contactService = ContactService();
  final FirebaseAuth _auth = FirebaseAuth.instance;

  // Used BehaviorSubject for shared streams
  final BehaviorSubject<List<QueryDocumentSnapshot<Map<String, dynamic>>>>
  _chatsSubject =
      BehaviorSubject<List<QueryDocumentSnapshot<Map<String, dynamic>>>>();
  Stream<List<QueryDocumentSnapshot<Map<String, dynamic>>>>? _chatsStream;
  Stream<int>? _archivedCountStream;
  final Map<String, Map<String, dynamic>> _userCache = {};
  final Map<String, String> _contactNameCache = {};
  bool _isLoading = true;
  bool _contactsLoaded = false;

  // Selection mode state
  bool _isSelectionMode = false;
  final Set<String> _selectedChatIds = {};
  int _totalUnreadCount = 0;
  bool _isAllSelected = false;

  @override
  void initState() {
    super.initState();
    _initializeChats();
    _initializeArchivedCount();
    _loadDeviceContacts();
  }

  @override
  void dispose() {
    _chatsSubject.close();
    super.dispose();
  }

  void _initializeChats() {
    final currentUserId = _auth.currentUser?.uid;
    if (currentUserId != null) {
      final chatStream = _chatService
          .getUserChats(currentUserId)
          .asBroadcastStream(onCancel: (subscription) => subscription.cancel());

      chatStream.listen(
        (chats) {
          if (!_chatsSubject.isClosed) {
            _chatsSubject.add(chats);
            // Calculate and update total unread count
            _updateTotalUnreadCount(chats, currentUserId);
          }
        },
        onError: (error) {
          if (!_chatsSubject.isClosed) {
            _chatsSubject.addError(error);
          }
        },
      );

      _chatsStream = _chatsSubject.stream;

      setState(() {
        _isLoading = false;
      });
    } else {
      setState(() {
        _isLoading = false;
      });
    }
  }

  void _toggleSelectAll() {
    setState(() {
      if (_isAllSelected) {
        // Deselect all
        _selectedChatIds.clear();
        _isAllSelected = false;
      } else {
        // Select all visible chats
        for (final chat in _processChats(
          _chatsSubject.valueOrNull ?? [],
          _auth.currentUser!.uid,
        )) {
          _selectedChatIds.add(chat.id);
        }
        _isAllSelected = true;
      }
      // Ensure selection mode stays active
      _isSelectionMode = true;
    });
  }

  void _updateTotalUnreadCount(
    List<QueryDocumentSnapshot<Map<String, dynamic>>> chats,
    String currentUserId,
  ) {
    int total = 0;
    for (final chat in chats) {
      final chatData = chat.data() as Map<String, dynamic>;

      // Skip archived chats
      final isArchived = chatData['isArchived'] ?? false;
      if (isArchived) continue;

      // Skip chats deleted by current user
      final deletedBy = List<String>.from(chatData['deletedBy'] ?? []);
      if (deletedBy.contains(currentUserId)) continue;

      final unreadCount =
          (chatData['unreadCount'] as Map<String, dynamic>?)?[currentUserId] ??
          0;
      total += (unreadCount as int);
    }

    if (mounted) {
      setState(() {
        _totalUnreadCount = total;
      });

      // Send the updated count to HomeScreen
      if (widget.onUnreadCountUpdated != null) {
        widget.onUnreadCountUpdated!(total);
      }
    }
  }

  void _initializeArchivedCount() {
    final currentUserId = _auth.currentUser?.uid;
    if (currentUserId != null) {
      setState(() {
        _archivedCountStream =
            Stream<int>.periodic(const Duration(seconds: 5), (_) => 0)
                .asyncMap(
                  (_) => _chatService.getArchivedChatsCount(currentUserId),
                )
                .asBroadcastStream();
      });
    }
  }

  void _loadDeviceContacts() async {
    try {
      final deviceContacts = await _contactService.getDeviceContacts();

      for (var contact in deviceContacts) {
        for (var phone in contact.phones) {
          _contactNameCache[phone] = contact.displayName ?? 'Unknown';
        }
      }

      setState(() {
        _contactsLoaded = true;
      });

      print(' Loaded ${_contactNameCache.length} contact names from device');
    } catch (e) {
      print('⚠️ Error loading device contacts: $e');
      setState(() {
        _contactsLoaded = true;
      });
    }
  }

  Future<Map<String, dynamic>> _getUserData(String userId) async {
    if (_userCache.containsKey(userId)) {
      return _userCache[userId]!;
    }

    try {
      final userData = await _userService.getUserData(userId);
      _userCache[userId] = userData;
      return userData;
    } catch (e) {
      return {
        'name': 'Unknown User',
        'profileImage': null,
        'isOnline': false,
        'phone': '',
      };
    }
  }

  String _getDisplayName(Map<String, dynamic> userData, String phoneNumber) {
    final String userPhone = userData['phone']?.toString() ?? '';

    if (_contactNameCache.containsKey(userPhone)) {
      final contactName = _contactNameCache[userPhone]!;
      return contactName;
    }

    final String dbName = userData['name']?.toString() ?? '';
    if (dbName.isNotEmpty && dbName != 'Unknown User') {
      return dbName;
    }

    return userPhone.isNotEmpty ? userPhone : 'Unknown';
  }

  String _formatLastMessageTime(Timestamp? timestamp) {
    if (timestamp == null) return '';

    final now = DateTime.now();
    final messageTime = timestamp.toDate();
    final difference = now.difference(messageTime);

    if (difference.inDays == 0) {
      return '${messageTime.hour.toString().padLeft(2, '0')}:${messageTime.minute.toString().padLeft(2, '0')}';
    } else if (difference.inDays == 1) {
      return 'Yesterday';
    } else if (difference.inDays < 7) {
      return '${difference.inDays}d ago';
    } else {
      return '${messageTime.day}/${messageTime.month}/${messageTime.year}';
    }
  }

  String _getOtherParticipant(
    List<dynamic> participants,
    String currentUserId,
  ) {
    for (var participant in participants) {
      if (participant != currentUserId) {
        return participant;
      }
    }
    return '';
  }

  void _toggleSelectionMode() {
    setState(() {
      _isSelectionMode = !_isSelectionMode;
      if (!_isSelectionMode) {
        _selectedChatIds.clear();
      }
    });
  }

  void _handleChatSelection(String chatId, bool isSelected) {
    setState(() {
      if (isSelected) {
        _selectedChatIds.add(chatId);
      } else {
        _selectedChatIds.remove(chatId);
      }

      if (_selectedChatIds.isEmpty && _isSelectionMode) {
        _isSelectionMode = false;
      } else if (_selectedChatIds.isNotEmpty && !_isSelectionMode) {
        _isSelectionMode = true;
      }
    });
  }

  void _handleMarkAsRead() async {
    final currentUserId = _auth.currentUser?.uid;
    if (currentUserId == null || _selectedChatIds.isEmpty) return;

    try {
      final batch = FirebaseFirestore.instance.batch();
      for (final chatId in _selectedChatIds) {
        final chatRef = FirebaseFirestore.instance
            .collection('chats')
            .doc(chatId);
        batch.update(chatRef, {
          'unreadCount.$currentUserId': 0,
          'lastRead.$currentUserId': FieldValue.serverTimestamp(),
        });
      }

      await batch.commit();

      // Force a refresh to update the total unread count
      _initializeChats();

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'Marked ${_selectedChatIds.length} chat${_selectedChatIds.length > 1 ? 's' : ''} as read',
          ),
          backgroundColor: Colors.green,
          duration: const Duration(seconds: 2),
        ),
      );

      setState(() {
        _selectedChatIds.clear();
        _isSelectionMode = false;
      });
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Failed to mark chats as read: $e'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  void _handlePin() async {
    final currentUserId = _auth.currentUser?.uid;
    if (currentUserId == null || _selectedChatIds.isEmpty) return;

    try {
      int pinnedCount = 0;
      int unpinnedCount = 0;

      final chatDocs = await Future.wait(
        _selectedChatIds.map(
          (chatId) =>
              FirebaseFirestore.instance.collection('chats').doc(chatId).get(),
        ),
      );

      final batch = FirebaseFirestore.instance.batch();

      for (int i = 0; i < _selectedChatIds.length; i++) {
        final chatId = _selectedChatIds.elementAt(i);
        final chatDoc = chatDocs[i];
        final isCurrentlyPinned = chatDoc.data()?['isPinned'] ?? false;

        final chatRef = FirebaseFirestore.instance
            .collection('chats')
            .doc(chatId);

        if (isCurrentlyPinned) {
          batch.update(chatRef, {
            'isPinned': false,
            'pinnedAt': FieldValue.delete(),
            'pinnedBy': FieldValue.delete(),
          });
          unpinnedCount++;
        } else {
          batch.update(chatRef, {
            'isPinned': true,
            'pinnedAt': FieldValue.serverTimestamp(),
            'pinnedBy': currentUserId,
          });
          pinnedCount++;
        }
      }

      await batch.commit();

      String message;
      if (pinnedCount > 0 && unpinnedCount > 0) {
        message =
            'Pinned $pinnedCount and unpinned $unpinnedCount chat${unpinnedCount > 1 ? 's' : ''}';
      } else if (pinnedCount > 0) {
        message = 'Pinned $pinnedCount chat${pinnedCount > 1 ? 's' : ''}';
      } else {
        message = 'Unpinned $unpinnedCount chat${unpinnedCount > 1 ? 's' : ''}';
      }

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(message),
          backgroundColor: Colors.blue,
          duration: const Duration(seconds: 2),
        ),
      );

      setState(() {
        _selectedChatIds.clear();
        _isSelectionMode = false;
      });
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Failed to pin/unpin chats: $e'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  void _handleMute() async {
    final currentUserId = _auth.currentUser?.uid;
    if (currentUserId == null || _selectedChatIds.isEmpty) return;

    final muteChecks = await Future.wait(
      _selectedChatIds.map(
        (chatId) => _chatService.isChatMuted(chatId, currentUserId),
      ),
    );

    final anyMuted = muteChecks.any((isMuted) => isMuted);
    final anyUnmuted = muteChecks.any((isMuted) => !isMuted);

    if (anyMuted && anyUnmuted) {
      _showMixedMuteOptions();
    } else if (anyMuted) {
      _showUnmuteConfirmation();
    } else {
      _showMuteDurationDialog();
    }
  }

  void _showMixedMuteOptions() {
    showDialog(
      context: context,
      builder:
          (context) => AlertDialog(
            backgroundColor: const Color(0xFF1E1E1E),
            title: const Text(
              'Chats Selection',
              style: TextStyle(color: Colors.white),
            ),
            content: Text(
              '${_selectedChatIds.length} chats selected. Some are muted, some are not.',
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
                  _showMuteDurationDialog();
                },
                child: const Text(
                  'Mute All',
                  style: TextStyle(color: Colors.blue),
                ),
              ),
              TextButton(
                onPressed: () {
                  Navigator.pop(context);
                  _performUnmute();
                },
                child: const Text(
                  'Unmute All',
                  style: TextStyle(color: Colors.green),
                ),
              ),
            ],
          ),
    );
  }

  void _showUnmuteConfirmation() {
    showDialog(
      context: context,
      builder:
          (context) => AlertDialog(
            backgroundColor: const Color(0xFF1E1E1E),
            title: const Text(
              'Unmute Chats',
              style: TextStyle(color: Colors.white),
            ),
            content: Text(
              'Unmute ${_selectedChatIds.length} chat${_selectedChatIds.length > 1 ? 's' : ''}?',
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
      final batch = FirebaseFirestore.instance.batch();
      for (final chatId in _selectedChatIds) {
        final chatRef = FirebaseFirestore.instance
            .collection('chats')
            .doc(chatId);
        batch.update(chatRef, {
          'isMuted': false,
          'mutedUntil': FieldValue.delete(),
          'mutedAt': FieldValue.delete(),
          'mutedBy': FieldValue.delete(),
        });
      }

      await batch.commit();

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'Unmuted ${_selectedChatIds.length} chat${_selectedChatIds.length > 1 ? 's' : ''}',
          ),
          backgroundColor: Colors.green,
        ),
      );

      setState(() {
        _selectedChatIds.clear();
        _isSelectionMode = false;
      });
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Failed to unmute chats: $e'),
          backgroundColor: Colors.red,
        ),
      );
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
                  'Mute ${_selectedChatIds.length} chat${_selectedChatIds.length > 1 ? 's' : ''}',
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
                      'You can unmute them anytime from chat info.',
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

                      final currentUserId = _auth.currentUser?.uid;
                      if (currentUserId == null) return;

                      try {
                        final selectedDuration = durations[_selectedDuration]!;
                        final muteUntil = DateTime.now().add(selectedDuration);

                        final batch = FirebaseFirestore.instance.batch();
                        for (final chatId in _selectedChatIds) {
                          final chatRef = FirebaseFirestore.instance
                              .collection('chats')
                              .doc(chatId);
                          batch.update(chatRef, {
                            'isMuted': true,
                            'mutedUntil': muteUntil,
                            'mutedAt': FieldValue.serverTimestamp(),
                            'mutedBy': currentUserId,
                          });
                        }

                        await batch.commit();

                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(
                            content: Text(
                              'Muted ${_selectedChatIds.length} chat${_selectedChatIds.length > 1 ? 's' : ''} for $_selectedDuration',
                            ),
                            backgroundColor: Colors.blue,
                          ),
                        );

                        setState(() {
                          _selectedChatIds.clear();
                          _isSelectionMode = false;
                        });
                      } catch (e) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(
                            content: Text('Failed to mute chats: $e'),
                            backgroundColor: Colors.red,
                          ),
                        );
                      }
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

  void _handleArchive() async {
    final currentUserId = _auth.currentUser?.uid;
    if (currentUserId == null || _selectedChatIds.isEmpty) return;

    final archiveChecks = await Future.wait(
      _selectedChatIds.map((chatId) async {
        final chatDoc =
            await FirebaseFirestore.instance
                .collection('chats')
                .doc(chatId)
                .get();
        return chatDoc.data()?['isArchived'] ?? false;
      }),
    );

    final anyArchived = archiveChecks.any((isArchived) => isArchived);
    final anyUnarchived = archiveChecks.any((isArchived) => !isArchived);

    if (anyArchived && anyUnarchived) {
      _showMixedArchiveOptions();
    } else if (anyArchived) {
      _showUnarchiveConfirmation();
    } else {
      _showArchiveConfirmation();
    }
  }

  void _showMixedArchiveOptions() {
    showDialog(
      context: context,
      builder:
          (context) => AlertDialog(
            backgroundColor: const Color(0xFF1E1E1E),
            title: const Text(
              'Chats Selection',
              style: TextStyle(color: Colors.white),
            ),
            content: Text(
              '${_selectedChatIds.length} chats selected. Some are archived, some are not.',
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
                  _showArchiveConfirmation();
                },
                child: const Text(
                  'Archive All',
                  style: TextStyle(color: Colors.blue),
                ),
              ),
              TextButton(
                onPressed: () {
                  Navigator.pop(context);
                  _performUnarchive();
                },
                child: const Text(
                  'Unarchive All',
                  style: TextStyle(color: Colors.green),
                ),
              ),
            ],
          ),
    );
  }

  void _showArchiveConfirmation() {
    showDialog(
      context: context,
      builder:
          (context) => AlertDialog(
            backgroundColor: const Color(0xFF1E1E1E),
            title: const Text(
              'Archive Chats',
              style: TextStyle(color: Colors.white),
            ),
            content: Text(
              'Archive ${_selectedChatIds.length} chat${_selectedChatIds.length > 1 ? 's' : ''}? Archived chats can be found in the Archived section.',
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
                  await _performArchive();
                },
                child: const Text(
                  'Archive',
                  style: TextStyle(color: Colors.blue),
                ),
              ),
            ],
          ),
    );
  }

  Future<void> _performArchive() async {
    final currentUserId = _auth.currentUser?.uid;
    if (currentUserId == null) return;

    try {
      final batch = FirebaseFirestore.instance.batch();
      for (final chatId in _selectedChatIds) {
        final chatRef = FirebaseFirestore.instance
            .collection('chats')
            .doc(chatId);
        batch.update(chatRef, {
          'isArchived': true,
          'archivedAt': FieldValue.serverTimestamp(),
          'archivedBy': currentUserId,
        });
      }

      await batch.commit();

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'Archived ${_selectedChatIds.length} chat${_selectedChatIds.length > 1 ? 's' : ''}',
          ),
          backgroundColor: Colors.green,
        ),
      );

      setState(() {
        _selectedChatIds.clear();
        _isSelectionMode = false;
      });
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Failed to archive chats: $e'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  void _showUnarchiveConfirmation() {
    showDialog(
      context: context,
      builder:
          (context) => AlertDialog(
            backgroundColor: const Color(0xFF1E1E1E),
            title: const Text(
              'Unarchive Chats',
              style: TextStyle(color: Colors.white),
            ),
            content: Text(
              'Unarchive ${_selectedChatIds.length} chat${_selectedChatIds.length > 1 ? 's' : ''}?',
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
                  _performUnarchive();
                },
                child: const Text(
                  'Unarchive',
                  style: TextStyle(color: Colors.green),
                ),
              ),
            ],
          ),
    );
  }

  Future<void> _performUnarchive() async {
    final currentUserId = _auth.currentUser?.uid;
    if (currentUserId == null) return;

    try {
      final batch = FirebaseFirestore.instance.batch();
      for (final chatId in _selectedChatIds) {
        final chatRef = FirebaseFirestore.instance
            .collection('chats')
            .doc(chatId);
        batch.update(chatRef, {
          'isArchived': false,
          'archivedAt': FieldValue.delete(),
          'archivedBy': FieldValue.delete(),
        });
      }

      await batch.commit();

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'Unarchived ${_selectedChatIds.length} chat${_selectedChatIds.length > 1 ? 's' : ''}',
          ),
          backgroundColor: Colors.green,
        ),
      );

      setState(() {
        _selectedChatIds.clear();
        _isSelectionMode = false;
      });
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Failed to unarchive chats: $e'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  void _handleDelete() {
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
                          'Delete ${_selectedChatIds.length} chat${_selectedChatIds.length > 1 ? 's' : ''}?',
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 18,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                        const SizedBox(height: 8),
                        const Text(
                          'This will also delete all messages in these chats.',
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
                      await _deleteChats(deleteForEveryone: true);
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
                      await _deleteChats(deleteForEveryone: false);
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

  Future<void> _deleteChats({required bool deleteForEveryone}) async {
    final currentUserId = _auth.currentUser?.uid;
    if (currentUserId == null) return;

    try {
      if (deleteForEveryone) {
        for (final chatId in _selectedChatIds) {
          await _chatService.deleteChatForEveryone(chatId);
        }

        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              'Deleted ${_selectedChatIds.length} chat${_selectedChatIds.length > 1 ? 's' : ''} for everyone',
            ),
            backgroundColor: Colors.red,
          ),
        );
      } else {
        for (final chatId in _selectedChatIds) {
          await _chatService.deleteChatForUser(chatId, currentUserId);
        }

        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              'Deleted ${_selectedChatIds.length} chat${_selectedChatIds.length > 1 ? 's' : ''}',
            ),
            backgroundColor: Colors.red,
          ),
        );
      }

      setState(() {
        _selectedChatIds.clear();
        _isSelectionMode = false;
      });
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Failed to delete chats: $e'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  void _exitSelectionMode() {
    setState(() {
      _isSelectionMode = false;
      _selectedChatIds.clear();
    });
  }

  void _navigateToArchivedScreen() {
    Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => const ArchivedScreen()),
    );
  }

  Widget _buildArchivedItem(int archivedCount) {
    return InkWell(
      onTap: _navigateToArchivedScreen,
      child: Container(
        color: Colors.transparent,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 12.0, vertical: 8.0),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              Container(
                width: 60,
                height: 60,
                decoration: BoxDecoration(
                  color: Colors.grey[800],
                  shape: BoxShape.circle,
                ),
                child: const Icon(
                  Icons.archive_outlined,
                  color: Colors.grey,
                  size: 28,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        const Expanded(
                          child: Text(
                            'Archived',
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                              fontWeight: FontWeight.w500,
                              fontSize: 16,
                              color: Colors.white,
                            ),
                          ),
                        ),
                        Text(
                          archivedCount.toString(),
                          style: const TextStyle(
                            fontSize: 14,
                            color: Colors.grey,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 2),
                    const Text(
                      'Archived chats',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(fontSize: 14, color: Colors.grey),
                    ),
                    const SizedBox(height: 15),
                    Divider(
                      color: Colors.grey.withOpacity(0.3),
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

  // Helper method to sort and filter chats
  List<QueryDocumentSnapshot<Map<String, dynamic>>> _processChats(
    List<QueryDocumentSnapshot<Map<String, dynamic>>> chats,
    String currentUserId,
  ) {
    // Filter out deleted chats and archived chats
    final filteredChats =
        chats.where((chat) {
          final chatData = chat.data() as Map<String, dynamic>;
          final deletedBy = List<String>.from(chatData['deletedBy'] ?? []);
          final isArchived = chatData['isArchived'] ?? false;

          return !deletedBy.contains(currentUserId) && !isArchived;
        }).toList();

    // Sort chats: pinned first, then by last message time
    filteredChats.sort((a, b) {
      final aData = a.data() as Map<String, dynamic>;
      final bData = b.data() as Map<String, dynamic>;

      final aIsPinned = aData['isPinned'] ?? false;
      final bIsPinned = bData['isPinned'] ?? false;

      if (aIsPinned && !bIsPinned) return -1;
      if (!aIsPinned && bIsPinned) return 1;

      if (aIsPinned && bIsPinned) {
        final aPinnedAt = aData['pinnedAt'] as Timestamp?;
        final bPinnedAt = bData['pinnedAt'] as Timestamp?;
        if (aPinnedAt != null && bPinnedAt != null) {
          return bPinnedAt.compareTo(aPinnedAt); // Newer pins first
        }
      }

      final aTime = aData['lastMessageTime'] as Timestamp?;
      final bTime = bData['lastMessageTime'] as Timestamp?;

      if (aTime != null && bTime != null) {
        return bTime.compareTo(aTime); // Newer messages first
      }

      return 0;
    });

    return filteredChats;
  }

  Widget _buildChatsTab() {
    final currentUserId = _auth.currentUser?.uid;

    if (currentUserId == null) {
      return _buildErrorState('Please sign in to view chats');
    }

    if (!_contactsLoaded) {
      return _buildLoadingState();
    }

    return StreamBuilder<List<QueryDocumentSnapshot<Map<String, dynamic>>>>(
      stream: _chatsStream,
      builder: (context, snapshot) {
        if (snapshot.hasError) {
          return _buildErrorState('Error loading chats: ${snapshot.error}');
        }

        if (snapshot.connectionState == ConnectionState.waiting) {
          return _buildLoadingState();
        }

        final allChats = snapshot.data ?? [];
        final processedChats = _processChats(allChats, currentUserId);

        return StreamBuilder<int>(
          stream: _archivedCountStream,
          builder: (context, archivedSnapshot) {
            final archivedCount = archivedSnapshot.data ?? 0;

            if (processedChats.isEmpty && archivedCount == 0) {
              return _buildEmptyState();
            }

            return ListView.builder(
              physics: const BouncingScrollPhysics(),
              itemCount:
                  archivedCount > 0
                      ? processedChats.length + 1 + (_isSelectionMode ? 1 : 0)
                      : processedChats.length + (_isSelectionMode ? 1 : 0),
              itemBuilder: (context, index) {
                // Select All row (only in selection mode)
                if (_isSelectionMode && index == 0) {
                  return _buildSelectAllRow();
                }

                // Archived item
                if (archivedCount > 0 && index == (_isSelectionMode ? 1 : 0)) {
                  return _buildArchivedItem(archivedCount);
                }

                final chatIndex =
                    archivedCount > 0
                        ? index - 1 - (_isSelectionMode ? 1 : 0)
                        : index - (_isSelectionMode ? 1 : 0);

                return _buildChatItem(processedChats[chatIndex], currentUserId);
              },
            );
          },
        );
      },
    );
  }

  Widget _buildChatItem(
    QueryDocumentSnapshot<Map<String, dynamic>> chatDoc,
    String currentUserId,
  ) {
    final chatData = chatDoc.data() as Map<String, dynamic>;
    final participants = List<String>.from(chatData['participants'] ?? []);
    final otherUserId = _getOtherParticipant(participants, currentUserId);
    final lastMessage = chatData['lastMessage'] ?? '';
    final lastMessageTime = chatData['lastMessageTime'] as Timestamp?;
    final lastMessageSender = chatData['lastMessageSender'] ?? '';
    final unreadCount =
        (chatData['unreadCount'] as Map<String, dynamic>?)?[currentUserId] ?? 0;
    final isPinned = chatData['isPinned'] ?? false;
    final isMuted = chatData['isMuted'] ?? false;

    return FutureBuilder<Map<String, dynamic>>(
      future: _getUserData(otherUserId),
      builder: (context, userSnapshot) {
        if (userSnapshot.connectionState == ConnectionState.waiting) {
          return _buildChatSkeleton();
        }

        final userData = userSnapshot.data ?? {};
        final userPhone = userData['phone']?.toString() ?? '';

        final displayName = _getDisplayName(userData, userPhone);
        final avatarUrl = userData['profileImage'];
        final isOnline = userData['isOnline'] ?? false;

        final isLastMessageFromMe = lastMessageSender == currentUserId;
        final displayMessage =
            lastMessage.isNotEmpty
                ? (isLastMessageFromMe ? 'You: $lastMessage' : lastMessage)
                : 'Start a conversation';

        return ChatItem(
          name: displayName,
          lastMessage: displayMessage,
          time: _formatLastMessageTime(lastMessageTime),
          avatarUrl: avatarUrl,
          isRead: unreadCount == 0,
          isOnline: isOnline,
          unreadCount: unreadCount,
          chatId: chatDoc.id,
          otherUserId: otherUserId,
          userPhone: userPhone,
          isSelectionMode: _isSelectionMode,
          isSelected: _selectedChatIds.contains(chatDoc.id),
          isMuted: isMuted,
          isPinned: isPinned,
          isArchived: false,
          onSelectionChanged: (isSelected) {
            _handleChatSelection(chatDoc.id, isSelected);
          },
          onTap: () {
            if (!_isSelectionMode) {
              _navigateToChat(
                context,
                displayName,
                avatarUrl,
                isOnline,
                otherUserId,
                chatDoc.id,
              );
            }
          },
        );
      },
    );
  }

  // Update the _navigateToChat method in ChatsScreen
  void _navigateToChat(
    BuildContext context,
    String name,
    String? avatarUrl,
    bool isOnline,
    String receiverId,
    String chatId,
  ) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder:
            (_) => MessageScreen(
              name: name,
              avatarUrl: avatarUrl,
              isOnline: isOnline,
              receiverId: receiverId,
              chatId: chatId,
            ),
      ),
    ).then((_) {
      // Refresh chats when returning from message screen
      if (mounted) {
        _initializeChats();
      }
    });
  }

  Widget _buildLoadingState() {
    return ListView.builder(
      itemCount: 6,
      itemBuilder: (context, index) {
        return _buildChatSkeleton();
      },
    );
  }

  Widget _buildChatSkeleton() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 12.0, vertical: 8.0),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          Container(
            width: 60,
            height: 60,
            decoration: BoxDecoration(
              color: Colors.grey[800],
              shape: BoxShape.circle,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Container(
                      width: 120,
                      height: 16,
                      decoration: BoxDecoration(
                        color: Colors.grey[800],
                        borderRadius: BorderRadius.circular(4),
                      ),
                    ),
                    Container(
                      width: 40,
                      height: 12,
                      decoration: BoxDecoration(
                        color: Colors.grey[800],
                        borderRadius: BorderRadius.circular(4),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                Container(
                  width: double.infinity,
                  height: 14,
                  decoration: BoxDecoration(
                    color: Colors.grey[800],
                    borderRadius: BorderRadius.circular(4),
                  ),
                ),
                const SizedBox(height: 15),
                Divider(
                  color: Colors.grey.withOpacity(0.3),
                  thickness: 0.5,
                  height: 0,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.chat_bubble_outline, size: 80, color: Colors.grey[600]),
          const SizedBox(height: 16),
          Text(
            'No chats yet',
            style: TextStyle(
              color: Colors.grey[400],
              fontSize: 18,
              fontWeight: FontWeight.w500,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'Start a conversation with your contacts',
            style: TextStyle(color: Colors.grey[500], fontSize: 14),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 20),
          ElevatedButton(
            onPressed: () {
              showModalBottomSheet(
                context: context,
                isScrollControlled: true,
                backgroundColor: Colors.transparent,
                builder: (_) => const SelectContactScreen(),
              );
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.blue,
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
            ),
            child: const Text('Find Contacts'),
          ),
        ],
      ),
    );
  }

  Widget _buildErrorState(String message) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.error_outline, size: 60, color: Colors.red[400]),
          const SizedBox(height: 16),
          Text(
            'Unable to load chats',
            style: TextStyle(
              color: Colors.grey[300],
              fontSize: 16,
              fontWeight: FontWeight.w500,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            message,
            style: TextStyle(color: Colors.grey[500], fontSize: 14),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 20),
          ElevatedButton(
            onPressed: _initializeChats,
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.blue,
              foregroundColor: Colors.white,
            ),
            child: const Text('Try Again'),
          ),
        ],
      ),
    );
  }

  Widget _buildSelectAllRow() {
    return InkWell(
      onTap: _toggleSelectAll,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 12.0),
        child: Row(
          children: [
            Container(
              width: 22,
              height: 22,
              decoration: BoxDecoration(
                color: _isAllSelected ? Colors.blue : Colors.grey.shade800,
                shape: BoxShape.circle,
                border: Border.all(
                  color: Colors.white,
                  width: _isAllSelected ? 0 : 2,
                ),
              ),
              child:
                  _isAllSelected
                      ? const Icon(Icons.check, color: Colors.white, size: 14)
                      : null,
            ),
            const SizedBox(width: 16),
            Text(
              'Select all',
              style: TextStyle(
                color: _isAllSelected ? Colors.blue : Colors.white,
                fontSize: 16,
                fontWeight: FontWeight.w500,
              ),
            ),
          ],
        ),
      ),
    );
  }

  // In ChatsScreen or my main screen
  int calculateTotalUnreadCount(
    List<QueryDocumentSnapshot<Map<String, dynamic>>> chats,
  ) {
    final currentUserId = FirebaseAuth.instance.currentUser?.uid;
    if (currentUserId == null) return 0;

    int total = 0;
    for (final chat in chats) {
      final chatData = chat.data() as Map<String, dynamic>;
      final unreadCount =
          (chatData['unreadCount'] as Map<String, dynamic>?)?[currentUserId] ??
          0;
      total += (unreadCount as int);
    }
    return total;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      floatingActionButton: Padding(
        padding: const EdgeInsets.only(bottom: 12.0, right: 12.0),
        child: FloatingActionButton(
          onPressed: () {
            Navigator.push(
              context,
              MaterialPageRoute(builder: (_) => const SelectContactScreen()),
            );
          },
          backgroundColor: Colors.lightBlue,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16.0),
          ),
          child: const Icon(Icons.edit_square, color: Colors.black, size: 28.0),
        ),
      ),
      body: DefaultTabController(
        length: 3,
        child: SafeArea(
          child: Column(
            children: [
              Container(
                color: const Color.fromARGB(255, 19, 18, 18),
                child: Column(
                  children: [
                    TopBar(
                      isSelectionMode: _isSelectionMode,
                      selectedCount: _selectedChatIds.length,
                      onEditPressed: _toggleSelectionMode,
                      onSelectionClose: _exitSelectionMode,
                      onMarkAsRead: _handleMarkAsRead,
                      onPin: _handlePin,
                      onMute: _handleMute,
                      onArchive: _handleArchive,
                      onDelete: _handleDelete,
                    ),
                    // ALWAYS SHOW SEARCH BAR
                    local_widgets.SearchBar(),
                    const TabBarSection(),
                  ],
                ),
              ),
              const SizedBox(height: 8),
              Expanded(
                child: Container(
                  color: Colors.black,
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
              ),
            ],
          ),
        ),
      ),
    );
  }
}
