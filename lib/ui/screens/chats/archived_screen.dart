import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:wrytte/components/chats_components/chat_item.dart';
import 'package:wrytte/services/chat_service.dart';
import 'package:wrytte/services/user_service.dart';
import 'package:wrytte/services/contact_service.dart';
import 'package:wrytte/ui/screens/message_screen.dart';

class ArchivedScreen extends StatefulWidget {
  const ArchivedScreen({super.key});

  @override
  State<ArchivedScreen> createState() => _ArchivedScreenState();
}

class _ArchivedScreenState extends State<ArchivedScreen> {
  final ChatService _chatService = ChatService();
  final UserService _userService = UserService();
  final ContactService _contactService = ContactService();
  final FirebaseAuth _auth = FirebaseAuth.instance;

  Stream<List<QueryDocumentSnapshot<Map<String, dynamic>>>>?
  _archivedChatsStream;
  final Map<String, Map<String, dynamic>> _userCache = {};
  final Map<String, String> _contactNameCache = {};
  bool _isLoading = true;
  bool _contactsLoaded = false;

  // Selection mode state
  bool _isSelectionMode = false;
  final Set<String> _selectedChatIds = {};
  final Map<String, String> _selectedChatNames = {};

  @override
  void initState() {
    super.initState();
    _initializeArchivedChats();
    _loadDeviceContacts();
  }

  void _initializeArchivedChats() {
    final currentUserId = _auth.currentUser?.uid;
    if (currentUserId != null) {
      try {
        setState(() {
          _archivedChatsStream = _chatService.getArchivedChats(currentUserId);
          _isLoading = false;
        });
      } catch (e) {
        print('❌ Error initializing archived chats: $e');
        setState(() {
          _archivedChatsStream = null;
          _isLoading = false;
        });
      }
    } else {
      setState(() {
        _isLoading = false;
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

      print('✅ Loaded ${_contactNameCache.length} contact names from device');
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
      print('⚠️ Error fetching user data for $userId: $e');
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
        return participant.toString();
      }
    }
    return '';
  }

  void _toggleSelectionMode() {
    setState(() {
      _isSelectionMode = !_isSelectionMode;
      if (!_isSelectionMode) {
        _selectedChatIds.clear();
        _selectedChatNames.clear();
      }
    });
  }

  void _handleChatSelection(String chatId, String chatName, bool isSelected) {
    setState(() {
      if (isSelected) {
        _selectedChatIds.add(chatId);
        _selectedChatNames[chatId] = chatName;
      } else {
        _selectedChatIds.remove(chatId);
        _selectedChatNames.remove(chatId);
      }

      if (_selectedChatIds.isEmpty && _isSelectionMode) {
        _isSelectionMode = false;
      } else if (_selectedChatIds.isNotEmpty && !_isSelectionMode) {
        _isSelectionMode = true;
      }
    });
  }

  Future<void> _handleUnarchive() async {
    if (_selectedChatIds.isEmpty) return;

    final currentUserId = _auth.currentUser?.uid;
    if (currentUserId == null) return;

    try {
      for (final chatId in _selectedChatIds) {
        await _chatService.unarchiveChat(chatId, currentUserId);
      }

      _showSnackBar(
        '${_selectedChatIds.length} chat${_selectedChatIds.length > 1 ? 's' : ''} unarchived',
        Colors.green,
      );

      _exitSelectionMode();
    } catch (e) {
      print('❌ Error unarchiving chats: $e');
      _showSnackBar('Failed to unarchive chats', Colors.red);
    }
  }

  Future<void> _handleDelete() async {
    if (_selectedChatIds.isEmpty) return;

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
                          'Delete ${_selectedChatIds.length} archived chat${_selectedChatIds.length > 1 ? 's' : ''}?',
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
                      await _performDelete(deleteForEveryone: true);
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
                      await _performDelete(deleteForEveryone: false);
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

  Future<void> _performDelete({required bool deleteForEveryone}) async {
    final currentUserId = _auth.currentUser?.uid;
    if (currentUserId == null) return;

    try {
      if (deleteForEveryone) {
        for (final chatId in _selectedChatIds) {
          await _chatService.deleteChatForEveryone(chatId);
        }

        _showSnackBar(
          'Deleted ${_selectedChatIds.length} chat${_selectedChatIds.length > 1 ? 's' : ''} for everyone',
          Colors.red,
        );
      } else {
        for (final chatId in _selectedChatIds) {
          await _chatService.deleteChatForUser(chatId, currentUserId);
        }

        _showSnackBar(
          'Deleted ${_selectedChatIds.length} chat${_selectedChatIds.length > 1 ? 's' : ''}',
          Colors.red,
        );
      }

      _exitSelectionMode();
    } catch (e) {
      print('❌ Error deleting chats: $e');
      _showSnackBar('Failed to delete chats', Colors.red);
    }
  }

  void _exitSelectionMode() {
    setState(() {
      _isSelectionMode = false;
      _selectedChatIds.clear();
      _selectedChatNames.clear();
    });
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

  Widget _buildArchivedChatsTab() {
    final currentUserId = _auth.currentUser?.uid;

    if (currentUserId == null) {
      return _buildErrorState('Please sign in to view archived chats');
    }

    if (!_contactsLoaded) {
      return _buildLoadingState();
    }

    return StreamBuilder<List<QueryDocumentSnapshot<Map<String, dynamic>>>>(
      stream: _archivedChatsStream,
      builder: (context, snapshot) {
        if (snapshot.hasError) {
          return _buildErrorState(
            'Error loading archived chats: ${snapshot.error}',
          );
        }

        if (snapshot.connectionState == ConnectionState.waiting) {
          return _buildLoadingState();
        }

        if (!snapshot.hasData || snapshot.data == null) {
          return _buildEmptyState();
        }

        final chats = snapshot.data!;

        if (chats.isEmpty) {
          return _buildEmptyState();
        }

        return ListView.builder(
          physics: const BouncingScrollPhysics(),
          itemCount: chats.length,
          itemBuilder: (context, index) {
            return _buildChatItem(chats[index], currentUserId);
          },
        );
      },
    );
  }

  Widget _buildChatItem(
    QueryDocumentSnapshot<Map<String, dynamic>> chatDoc,
    String currentUserId,
  ) {
    final chatData = chatDoc.data();
    final participants = List<String>.from(
      chatData['participants']?.map((p) => p.toString()) ?? [],
    );
    final otherUserId = _getOtherParticipant(participants, currentUserId);
    final lastMessage = chatData['lastMessage']?.toString() ?? '';
    final lastMessageTime = chatData['lastMessageTime'] as Timestamp?;
    final lastMessageSender = chatData['lastMessageSender']?.toString() ?? '';
    final unreadCount =
        (chatData['unreadCount'] as Map<String, dynamic>?)?[currentUserId] ?? 0;
    final isMuted = chatData['isMuted'] == true;
    final isArchived = chatData['isArchived'] == true;

    return FutureBuilder<Map<String, dynamic>>(
      future: _getUserData(otherUserId),
      builder: (context, userSnapshot) {
        if (userSnapshot.connectionState == ConnectionState.waiting) {
          return _buildChatSkeleton();
        }

        final userData = userSnapshot.data ?? {};
        final userPhone = userData['phone']?.toString() ?? '';

        final displayName = _getDisplayName(userData, userPhone);
        final avatarUrl = userData['profileImage']?.toString();
        final isOnline = userData['isOnline'] == true;

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
          isPinned: false,
          isArchived: isArchived,
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
          onSelectionChanged: (isSelected) {
            _handleChatSelection(chatDoc.id, displayName, isSelected);
          },
        );
      },
    );
  }

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
    );
  }

  Widget _buildLoadingState() {
    return ListView.builder(
      itemCount: 3,
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
          Icon(Icons.archive_outlined, size: 80, color: Colors.grey[600]),
          const SizedBox(height: 16),
          const Text(
            'No archived chats',
            style: TextStyle(
              color: Colors.grey,
              fontSize: 18,
              fontWeight: FontWeight.w500,
            ),
          ),
          const SizedBox(height: 8),
          const Text(
            'Archived chats will appear here',
            style: TextStyle(color: Colors.grey, fontSize: 14),
            textAlign: TextAlign.center,
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
          const Text(
            'Unable to load archived chats',
            style: TextStyle(
              color: Colors.grey,
              fontSize: 16,
              fontWeight: FontWeight.w500,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            message,
            style: const TextStyle(color: Colors.grey, fontSize: 14),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 20),
          ElevatedButton(
            onPressed: _initializeArchivedChats,
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

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        backgroundColor: const Color(0xFF0C1D2C),
        title:
            _isSelectionMode
                ? Text(
                  '${_selectedChatIds.length} selected',
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                  ),
                )
                : const Text(
                  'Archived',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                  ),
                ),
        leading:
            _isSelectionMode
                ? IconButton(
                  icon: const Icon(Icons.close, color: Colors.white),
                  onPressed: _exitSelectionMode,
                )
                : IconButton(
                  icon: const Icon(Icons.arrow_back, color: Colors.white),
                  onPressed: () => Navigator.pop(context),
                ),
        actions:
            _isSelectionMode
                ? [
                  IconButton(
                    icon: const Icon(Icons.unarchive, color: Colors.white),
                    tooltip: 'Unarchive',
                    onPressed: _handleUnarchive,
                  ),
                  IconButton(
                    icon: const Icon(Icons.delete, color: Colors.white),
                    tooltip: 'Delete',
                    onPressed: _handleDelete,
                  ),
                ]
                : null,
        elevation: 0,
      ),
      body: _isLoading ? _buildLoadingState() : _buildArchivedChatsTab(),
    );
  }
}
