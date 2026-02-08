import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'dart:io';

class ChatService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseStorage _storage = FirebaseStorage.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;

  // Get or create a chat ID between two users
  Future<String> getOrCreateChatId(String user1, String user2) async {
    try {
      // Sort user IDs to ensure consistent chat ID
      final participants = [user1, user2]..sort();
      final chatId = '${participants[0]}_${participants[1]}';

      // Check if chat already exists
      final chatDoc = await _firestore.collection('chats').doc(chatId).get();

      if (!chatDoc.exists) {
        // Create new chat document
        await _firestore.collection('chats').doc(chatId).set({
          'participants': participants,
          'createdAt': FieldValue.serverTimestamp(),
          'lastMessage': '',
          'lastMessageTime': FieldValue.serverTimestamp(),
          'lastMessageType': 'text',
          'unreadCount': {user1: 0, user2: 0},
          'isPinned': false,
          'pinnedAt': null,
          'pinnedBy': null,
          'isMuted': false,
          'mutedUntil': null,
          'isArchived': false,
          'archivedAt': null,
          'archivedBy': null,
          'deletedBy': [], // Array of user IDs who deleted the chat
          'deletedAt': null,
        });
      } else {
        // Chat exists, check if either user has deleted it
        final chatData = chatDoc.data() as Map<String, dynamic>;
        final deletedBy = List<String>.from(chatData['deletedBy'] ?? []);

        // Prepare update data
        final updateData = <String, dynamic>{};

        // If user1 has deleted this chat, restore it
        if (deletedBy.contains(user1)) {
          updateData['deletedBy'] = FieldValue.arrayRemove([user1]);
        }

        // If user2 has deleted this chat, restore it
        if (deletedBy.contains(user2)) {
          if (updateData.containsKey('deletedBy')) {
            // If we already have an arrayRemove for user1, we need to handle this differently
            // Get current deletedBy array
            final currentDeletedBy = List<String>.from(deletedBy);
            currentDeletedBy.remove(user1);
            currentDeletedBy.remove(user2);
            updateData['deletedBy'] = currentDeletedBy;
          } else {
            updateData['deletedBy'] = FieldValue.arrayRemove([user2]);
          }
        }

        // ensuring chat is not archived for either user
        updateData['isArchived'] = false;
        updateData['archivedAt'] = FieldValue.delete();
        updateData['archivedBy'] = FieldValue.delete();

        // If we have updates to make, apply them
        if (updateData.isNotEmpty) {
          await _firestore.collection('chats').doc(chatId).update(updateData);
          print('✅ Restored chat $chatId for users before sending message');
        }
      }

      return chatId;
    } catch (e) {
      // ignore: avoid_print
      print(' Error creating/getting chat ID: $e');
      rethrow;
    }
  }

  // Send a text message
  Future<void> sendMessage(
    String chatId,
    String text,
    String senderId,
    String receiverId, {
    Map<String, dynamic>? replyData,
  }) async {
    try {
      final timestamp = FieldValue.serverTimestamp();

      // First, ensuring chat is restored for both users
      await _restoreChatForUsers(chatId, senderId, receiverId);

      // Creating the message document with optional reply data
      final messageData = {
        'text': text,
        'senderId': senderId,
        'receiverId': receiverId,
        'timestamp': timestamp,
        'isRead': false,
        'chatId': chatId,
        'messageType': 'text',
        if (replyData != null) 'replyTo': replyData,
      };

      // Adding message to messages subcollection
      await _firestore
          .collection('chats')
          .doc(chatId)
          .collection('messages')
          .add(messageData);

      // Updating chat document with last message info
      await _firestore.collection('chats').doc(chatId).update({
        'lastMessage': text,
        'lastMessageTime': timestamp,
        'lastMessageSender': senderId,
        'lastMessageType': 'text',
        // Ensuring chat is not archived when sending new message
        'isArchived': false,
        'archivedAt': FieldValue.delete(),
        'archivedBy': FieldValue.delete(),
        // Increment unread count for receiver
        'unreadCount.$receiverId': FieldValue.increment(1),
      });

      // ignore: avoid_print
      print(' Message sent successfully to chat: $chatId');
    } catch (e) {
      // ignore: avoid_print
      print(' Error sending message: $e');
      rethrow;
    }
  }

  // Helper method to restore chat for users
  Future<void> _restoreChatForUsers(
    String chatId,
    String user1,
    String user2,
  ) async {
    try {
      final chatDoc = await _firestore.collection('chats').doc(chatId).get();
      if (!chatDoc.exists) return;

      final chatData = chatDoc.data() as Map<String, dynamic>;
      final deletedBy = List<String>.from(chatData['deletedBy'] ?? []);

      // Prepare update data
      final updateData = <String, dynamic>{};

      // Check if either user has deleted the chat
      final shouldRestoreForUser1 = deletedBy.contains(user1);
      final shouldRestoreForUser2 = deletedBy.contains(user2);

      if (shouldRestoreForUser1 || shouldRestoreForUser2) {
        // Build new deletedBy array without these users
        final newDeletedBy =
            deletedBy
                .where((userId) => userId != user1 && userId != user2)
                .toList();
        updateData['deletedBy'] = newDeletedBy;

        // Also remove deletedAt if array becomes empty
        if (newDeletedBy.isEmpty) {
          updateData['deletedAt'] = FieldValue.delete();
        }

        // Ensure chat is not archived
        updateData['isArchived'] = false;
        updateData['archivedAt'] = FieldValue.delete();
        updateData['archivedBy'] = FieldValue.delete();

        await _firestore.collection('chats').doc(chatId).update(updateData);
        print('✅ Restored chat $chatId for users $user1 and $user2');
      }
    } catch (e) {
      print(' Error restoring chat for users: $e');
    }
  }

  // Send an image message
  Future<void> sendImageMessage(
    String chatId,
    File imageFile,
    String senderId,
    String receiverId, {
    Map<String, dynamic>? replyData,
  }) async {
    try {
      // First, ensure chat is restored for both users
      await _restoreChatForUsers(chatId, senderId, receiverId);

      // Upload image to Firebase Storage
      final fileName = '${DateTime.now().millisecondsSinceEpoch}.jpg';
      final ref = _storage.ref().child('chat_images/$chatId/$fileName');
      final uploadTask = await ref.putFile(imageFile);
      final imageUrl = await uploadTask.ref.getDownloadURL();

      final timestamp = FieldValue.serverTimestamp();

      // Create the message document
      final messageData = {
        'imageUrl': imageUrl,
        'senderId': senderId,
        'receiverId': receiverId,
        'timestamp': timestamp,
        'isRead': false,
        'chatId': chatId,
        'messageType': 'image',
        'fileName': fileName,
        if (replyData != null) 'replyTo': replyData,
      };

      // Add message to messages subcollection
      await _firestore
          .collection('chats')
          .doc(chatId)
          .collection('messages')
          .add(messageData);

      // Update chat document with last message info
      await _firestore.collection('chats').doc(chatId).update({
        'lastMessage': '📷 Photo',
        'lastMessageTime': timestamp,
        'lastMessageSender': senderId,
        'lastMessageType': 'image',
        // Ensure chat is not archived when sending new message
        'isArchived': false,
        'archivedAt': FieldValue.delete(),
        'archivedBy': FieldValue.delete(),
        // Increment unread count for receiver
        'unreadCount.$receiverId': FieldValue.increment(1),
      });

      // ignore: avoid_print
      print(' Image message sent successfully to chat: $chatId');
    } catch (e) {
      // ignore: avoid_print
      print(' Error sending image message: $e');
      rethrow;
    }
  }

  // Send a voice message
  Future<void> sendVoiceMessage(
    String chatId,
    File audioFile,
    String senderId,
    String receiverId,
    Duration duration, {
    Map<String, dynamic>? replyData,
  }) async {
    try {
      // First, ensure chat is restored for both users
      await _restoreChatForUsers(chatId, senderId, receiverId);

      // Upload audio to Firebase Storage
      final fileName = '${DateTime.now().millisecondsSinceEpoch}.m4a';
      final ref = _storage.ref().child('voice_messages/$chatId/$fileName');
      final uploadTask = await ref.putFile(audioFile);
      final audioUrl = await uploadTask.ref.getDownloadURL();

      final timestamp = FieldValue.serverTimestamp();

      // Create the message document
      final messageData = {
        'audioUrl': audioUrl,
        'senderId': senderId,
        'receiverId': receiverId,
        'timestamp': timestamp,
        'isRead': false,
        'chatId': chatId,
        'messageType': 'audio',
        'fileName': fileName,
        'duration': duration.inMilliseconds,
        if (replyData != null) 'replyTo': replyData,
      };

      // Add message to messages subcollection
      await _firestore
          .collection('chats')
          .doc(chatId)
          .collection('messages')
          .add(messageData);

      // Update chat document with last message info
      await _firestore.collection('chats').doc(chatId).update({
        'lastMessage': '🎤 Voice message',
        'lastMessageTime': timestamp,
        'lastMessageSender': senderId,
        'lastMessageType': 'audio',
        // Ensure chat is not archived when sending new message
        'isArchived': false,
        'archivedAt': FieldValue.delete(),
        'archivedBy': FieldValue.delete(),
        // Increment unread count for receiver
        'unreadCount.$receiverId': FieldValue.increment(1),
      });

      // ignore: avoid_print
      print('✅ Voice message sent successfully to chat: $chatId');
    } catch (e) {
      // ignore: avoid_print
      print(' Error sending voice message: $e');
      rethrow;
    }
  }

  Future<void> forwardMessages({
    required List<String> targetChatIds,
    required List<Map<String, dynamic>> selectedMessages,
    String? additionalMessage,
    required String senderId,
  }) async {
    try {
      final timestamp = FieldValue.serverTimestamp();
      final batch = _firestore.batch();

      for (final chatId in targetChatIds) {
        // Get receiver ID for this chat
        final chatDoc = await _firestore.collection('chats').doc(chatId).get();
        final chatData = chatDoc.data() as Map<String, dynamic>;
        final participants = List<String>.from(chatData['participants'] ?? []);
        final receiverId = participants.firstWhere(
          (id) => id != senderId,
          orElse: () => '',
        );

        if (receiverId.isEmpty) continue;

        // Send additional message if provided
        if (additionalMessage != null && additionalMessage.isNotEmpty) {
          final additionalMessageData = {
            'text': additionalMessage,
            'senderId': senderId,
            'receiverId': receiverId,
            'timestamp': timestamp,
            'isRead': false,
            'chatId': chatId,
            'messageType': 'text',
          };

          final additionalMessageRef =
              _firestore
                  .collection('chats')
                  .doc(chatId)
                  .collection('messages')
                  .doc();
          batch.set(additionalMessageRef, additionalMessageData);
        }

        // Forward each selected message
        for (final originalMessage in selectedMessages) {
          final messageData = {
            ...originalMessage,
            'senderId': senderId,
            'receiverId': receiverId,
            'timestamp': timestamp,
            'isRead': false,
            'chatId': chatId,
            'isForwarded': true,
            'forwardedFrom': originalMessage['senderId'],
            'forwardedAt': timestamp,
            // Store original message details for display
            'originalMessageId': originalMessage['id'],
            'originalTimestamp': originalMessage['timestamp'],
          };

          // Remove original ID if present
          messageData.remove('id');

          final messageRef =
              _firestore
                  .collection('chats')
                  .doc(chatId)
                  .collection('messages')
                  .doc();
          batch.set(messageRef, messageData);
        }

        // Update chat document with last message info
        final lastMessage =
            selectedMessages.isNotEmpty
                ? selectedMessages.last['messageType'] == 'text'
                    ? selectedMessages.last['text']
                    : selectedMessages.last['messageType'] == 'image'
                    ? '📷 Photo'
                    : '🎤 Voice message'
                : additionalMessage ?? '';

        batch.update(_firestore.collection('chats').doc(chatId), {
          'lastMessage': lastMessage,
          'lastMessageTime': timestamp,
          'lastMessageSender': senderId,
          'lastMessageType':
              selectedMessages.isNotEmpty
                  ? selectedMessages.last['messageType']
                  : 'text',
          'isArchived': false,
          'archivedAt': FieldValue.delete(),
          'archivedBy': FieldValue.delete(),
          // Increment unread count for receiver
          'unreadCount.$receiverId': FieldValue.increment(1),
        });
      }

      await batch.commit();
      print(
        ' ${selectedMessages.length} message(s) forwarded to ${targetChatIds.length} chat(s)',
      );
    } catch (e) {
      print(' Error forwarding messages: $e');
      rethrow;
    }
  }

  // Get messages stream for a chat
  Stream<QuerySnapshot> getMessages(String chatId) {
    try {
      return _firestore
          .collection('chats')
          .doc(chatId)
          .collection('messages')
          .orderBy('timestamp', descending: false)
          .snapshots();
    } catch (e) {
      // ignore: avoid_print
      print('Error getting messages stream: $e');
      rethrow;
    }
  }

  // Get pinned message for a chat
  Stream<DocumentSnapshot?> getPinnedMessageStream(String chatId) {
    return _firestore.collection('chats').doc(chatId).snapshots().asyncMap((
      chatDoc,
    ) async {
      final chatData = chatDoc.data();
      if (chatData == null) return null;

      final pinnedMessageId = chatData['pinnedMessageId'] as String?;
      if (pinnedMessageId == null || pinnedMessageId.isEmpty) return null;

      try {
        final messageDoc =
            await _firestore
                .collection('chats')
                .doc(chatId)
                .collection('messages')
                .doc(pinnedMessageId)
                .get();

        return messageDoc.exists ? messageDoc : null;
      } catch (e) {
        print('Error getting pinned message: $e');
        return null;
      }
    });
  }

  // Mark messages as read
  Future<void> markMessagesAsRead(String chatId, String userId) async {
    try {
      // Reset unread count for this user
      await _firestore.collection('chats').doc(chatId).update({
        'unreadCount.$userId': 0,
      });

      // Mark all unread messages from other users as read
      final unreadMessages =
          await _firestore
              .collection('chats')
              .doc(chatId)
              .collection('messages')
              .where('senderId', isNotEqualTo: userId)
              .where('isRead', isEqualTo: false)
              .get();

      final batch = _firestore.batch();
      for (final doc in unreadMessages.docs) {
        batch.update(doc.reference, {'isRead': true});
      }

      if (unreadMessages.docs.isNotEmpty) {
        await batch.commit();
      }
    } catch (e) {
      // ignore: avoid_print
      print('Error marking messages as read: $e');
      rethrow;
    }
  }

  // Get all chats for a user - ORDERED BY PINNED FIRST, THEN LAST MESSAGE TIME
  Stream<List<QueryDocumentSnapshot<Map<String, dynamic>>>> getUserChats(
    String userId,
  ) {
    try {
      return _firestore
          .collection('chats')
          .where('participants', arrayContains: userId)
          .snapshots()
          .map((snapshot) {
            final docs = snapshot.docs;

            // Filter out chats deleted by current user
            final filteredDocs =
                docs.where((doc) {
                  final data = doc.data() as Map<String, dynamic>;
                  final deletedBy = List<String>.from(data['deletedBy'] ?? []);
                  return !deletedBy.contains(userId);
                }).toList();

            // Sort chats: pinned first (by pinnedAt descending), then by lastMessageTime descending
            filteredDocs.sort((a, b) {
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

            return filteredDocs;
          });
    } catch (e) {
      // ignore: avoid_print
      print('Error getting user chats: $e');
      rethrow;
    }
  }

  // Get archived chats for a user
  Stream<List<QueryDocumentSnapshot<Map<String, dynamic>>>> getArchivedChats(
    String userId,
  ) {
    try {
      return _firestore
          .collection('chats')
          .where('participants', arrayContains: userId)
          .where('isArchived', isEqualTo: true)
          .orderBy('lastMessageTime', descending: true)
          .snapshots()
          .map((snapshot) {
            final docs = snapshot.docs;

            // Filter out chats deleted by current user
            final filteredDocs =
                docs.where((doc) {
                  final data = doc.data() as Map<String, dynamic>;
                  final deletedBy = List<String>.from(data['deletedBy'] ?? []);
                  return !deletedBy.contains(userId);
                }).toList();

            return filteredDocs;
          });
    } catch (e) {
      // ignore: avoid_print
      print('Error getting archived chats: $e');
      rethrow;
    }
  }

  // Delete a message (legacy method - use new deleteMessageWithOptions instead)
  Future<void> deleteMessage(
    String chatId,
    String messageId,
    String uid,
    bool forEveryone,
  ) async {
    try {
      final messageDoc =
          await _firestore
              .collection('chats')
              .doc(chatId)
              .collection('messages')
              .doc(messageId)
              .get();

      final messageData = messageDoc.data();

      // Delete associated files from storage
      if (messageData?['messageType'] == 'image') {
        final imageUrl = messageData?['imageUrl'];
        if (imageUrl != null) {
          await _storage.refFromURL(imageUrl).delete();
        }
      } else if (messageData?['messageType'] == 'audio') {
        final audioUrl = messageData?['audioUrl'];
        if (audioUrl != null) {
          await _storage.refFromURL(audioUrl).delete();
        }
      }

      await _firestore
          .collection('chats')
          .doc(chatId)
          .collection('messages')
          .doc(messageId)
          .delete();
    } catch (e) {
      // ignore: avoid_print
      print('Error deleting message: $e');
      rethrow;
    }
  }

  // NEW: Delete message with options (for me or for everyone)
  Future<void> deleteMessageWithOptions(
    String chatId,
    String messageId,
    String userId,
    bool forEveryone,
  ) async {
    try {
      final messageRef = _firestore
          .collection('chats')
          .doc(chatId)
          .collection('messages')
          .doc(messageId);

      if (forEveryone) {
        // Delete for everyone - remove message completely
        final messageDoc = await messageRef.get();
        final messageData = messageDoc.data();

        // Delete associated files from storage
        if (messageData?['messageType'] == 'image') {
          final imageUrl = messageData?['imageUrl'];
          if (imageUrl != null) {
            await _storage.refFromURL(imageUrl).delete();
          }
        } else if (messageData?['messageType'] == 'audio') {
          final audioUrl = messageData?['audioUrl'];
          if (audioUrl != null) {
            await _storage.refFromURL(audioUrl).delete();
          }
        }

        await messageRef.delete();
        print(' Message deleted for everyone');
      } else {
        // Delete for me only - mark as deleted for this user
        await messageRef.update({
          'deletedFor': FieldValue.arrayUnion([userId]),
        });
        print(' Message deleted for user $userId');
      }
    } catch (e) {
      print(' Error deleting message: $e');
      rethrow;
    }
  }

  // NEW: Edit message
  Future<void> editMessage(
    String chatId,
    String messageId,
    String newText,
    String userId,
  ) async {
    try {
      // First check if user owns this message
      final messageDoc =
          await _firestore
              .collection('chats')
              .doc(chatId)
              .collection('messages')
              .doc(messageId)
              .get();

      final messageData = messageDoc.data() as Map<String, dynamic>?;
      if (messageData == null) {
        throw Exception('Message not found');
      }

      if (messageData['senderId'] != userId) {
        throw Exception('You can only edit your own messages');
      }

      await _firestore
          .collection('chats')
          .doc(chatId)
          .collection('messages')
          .doc(messageId)
          .update({
            'text': newText,
            'isEdited': true,
            'editedAt': FieldValue.serverTimestamp(),
          });

      // Update chat's last message if this was the last message
      final timestamp = messageData['timestamp'] as Timestamp?;

      // Check if this is the last message
      final lastMessages =
          await _firestore
              .collection('chats')
              .doc(chatId)
              .collection('messages')
              .orderBy('timestamp', descending: true)
              .limit(1)
              .get();

      if (lastMessages.docs.isNotEmpty &&
          lastMessages.docs[0].id == messageId) {
        await _firestore.collection('chats').doc(chatId).update({
          'lastMessage': newText,
          'lastMessageTime': timestamp,
        });
      }

      print(' Message edited successfully');
    } catch (e) {
      print(' Error editing message: $e');
      rethrow;
    }
  }

  // NEW: Pin a specific message (not to be confused with pinning a chat)
  Future<void> pinMessage(
    String chatId,
    String messageId,
    String userId,
  ) async {
    try {
      // First, unpin any currently pinned message in this chat
      await _firestore.collection('chats').doc(chatId).update({
        'pinnedMessageId': messageId,
        'pinnedMessageAt': FieldValue.serverTimestamp(),
        'pinnedMessageBy': userId,
      });

      // Also mark the message itself as pinned
      await _firestore
          .collection('chats')
          .doc(chatId)
          .collection('messages')
          .doc(messageId)
          .update({'isPinned': true, 'pinnedAt': FieldValue.serverTimestamp()});

      print('✅ Message pinned successfully');
    } catch (e) {
      print('❌ Error pinning message: $e');
      rethrow;
    }
  }

  // NEW: Unpin a message
  Future<void> unpinMessage(String chatId, String messageId) async {
    try {
      // Clear the pinned message from chat
      await _firestore.collection('chats').doc(chatId).update({
        'pinnedMessageId': FieldValue.delete(),
        'pinnedMessageAt': FieldValue.delete(),
        'pinnedMessageBy': FieldValue.delete(),
      });

      // Also update the message itself
      await _firestore
          .collection('chats')
          .doc(chatId)
          .collection('messages')
          .doc(messageId)
          .update({'isPinned': false, 'pinnedAt': FieldValue.delete()});

      print(' Message unpinned successfully');
    } catch (e) {
      print(' Error unpinning message: $e');
      rethrow;
    }
  }

  // NEW: Forward message to multiple chats
  Future<void> forwardMessage(
    List<String> targetChatIds,
    Map<String, dynamic> originalMessage,
    String senderId,
  ) async {
    try {
      final timestamp = FieldValue.serverTimestamp();
      final batch = _firestore.batch();

      for (final chatId in targetChatIds) {
        // Ensure chat exists for sender
        await _restoreChatForUsers(chatId, senderId, senderId);

        final messageData = {
          ...originalMessage,
          'senderId': senderId,
          'timestamp': timestamp,
          'isForwarded': true,
          'forwardedFrom': originalMessage['senderId'],
          'forwardedAt': timestamp,
          'isRead': false,
        };

        // Remove original ID if present
        messageData.remove('id');

        final messageRef =
            _firestore
                .collection('chats')
                .doc(chatId)
                .collection('messages')
                .doc();

        batch.set(messageRef, messageData);

        // Update chat document
        final lastMessage =
            originalMessage['messageType'] == 'text'
                ? originalMessage['text']
                : originalMessage['messageType'] == 'image'
                ? '📷 Photo'
                : '🎤 Voice message';

        batch.update(_firestore.collection('chats').doc(chatId), {
          'lastMessage': lastMessage,
          'lastMessageTime': timestamp,
          'lastMessageSender': senderId,
          'lastMessageType': originalMessage['messageType'],
          'isArchived': false,
          'archivedAt': FieldValue.delete(),
          'archivedBy': FieldValue.delete(),
        });
      }

      await batch.commit();
      print(' Message forwarded to ${targetChatIds.length} chats');
    } catch (e) {
      print(' Error forwarding message: $e');
      rethrow;
    }
  }

  // NEW: Get message text for copying
  String getMessageText(Map<String, dynamic> messageData) {
    final messageType = messageData['messageType'] ?? 'text';

    if (messageType == 'text') {
      return messageData['text'] ?? '';
    } else if (messageType == 'image') {
      return '📷 Photo';
    } else if (messageType == 'audio') {
      return '🎤 Voice message';
    }

    return '';
  }

  // NEW: Get message by ID
  Future<DocumentSnapshot> getMessageById(
    String chatId,
    String messageId,
  ) async {
    try {
      return await _firestore
          .collection('chats')
          .doc(chatId)
          .collection('messages')
          .doc(messageId)
          .get();
    } catch (e) {
      print('Error getting message by ID: $e');
      rethrow;
    }
  }

  // NEW: Check if message is deleted for a specific user
  bool isMessageDeletedForUser(
    Map<String, dynamic> messageData,
    String userId,
  ) {
    final deletedFor = List<String>.from(messageData['deletedFor'] ?? []);
    return deletedFor.contains(userId);
  }

  // NEW: Get pinned message for a chat
  Future<DocumentSnapshot?> getPinnedMessage(String chatId) async {
    try {
      final chatDoc = await _firestore.collection('chats').doc(chatId).get();
      final chatData = chatDoc.data() as Map<String, dynamic>?;

      if (chatData == null) return null;

      final pinnedMessageId = chatData['pinnedMessageId'] as String?;
      if (pinnedMessageId == null) return null;

      return await getMessageById(chatId, pinnedMessageId);
    } catch (e) {
      print('Error getting pinned message: $e');
      return null;
    }
  }

  // NEW: Star/unstar a message
  Future<void> toggleStarMessage(
    String chatId,
    String messageId,
    String userId,
    bool isStarred,
  ) async {
    try {
      await _firestore
          .collection('chats')
          .doc(chatId)
          .collection('messages')
          .doc(messageId)
          .update({
            'isStarred': isStarred,
            'starredAt':
                isStarred ? FieldValue.serverTimestamp() : FieldValue.delete(),
            'starredBy': isStarred ? userId : FieldValue.delete(),
          });

      print(' Message ${isStarred ? 'starred' : 'unstarred'} successfully');
    } catch (e) {
      print(' Error toggling star message: $e');
      rethrow;
    }
  }

  // NEW: Get starred messages for a user in a chat
  Stream<QuerySnapshot> getStarredMessages(String chatId, String userId) {
    try {
      return _firestore
          .collection('chats')
          .doc(chatId)
          .collection('messages')
          .where('isStarred', isEqualTo: true)
          .where('starredBy', isEqualTo: userId)
          .orderBy('starredAt', descending: true)
          .snapshots();
    } catch (e) {
      print('Error getting starred messages: $e');
      rethrow;
    }
  }

  // NEW: React to a message
  Future<void> reactToMessage(
    String chatId,
    String messageId,
    String userId,
    String emoji,
  ) async {
    try {
      await _firestore
          .collection('chats')
          .doc(chatId)
          .collection('messages')
          .doc(messageId)
          .update({
            'reactions.$userId': emoji,
            'lastReactionAt': FieldValue.serverTimestamp(),
          });

      print(' Reacted to message with $emoji');
    } catch (e) {
      print(' Error reacting to message: $e');
      rethrow;
    }
  }

  // NEW: Remove reaction from message
  Future<void> removeReaction(
    String chatId,
    String messageId,
    String userId,
  ) async {
    try {
      await _firestore
          .collection('chats')
          .doc(chatId)
          .collection('messages')
          .doc(messageId)
          .update({'reactions.$userId': FieldValue.delete()});

      print(' Reaction removed from message');
    } catch (e) {
      print(' Error removing reaction: $e');
      rethrow;
    }
  }

  // NEW: Get message reactions
  Future<Map<String, String>> getMessageReactions(
    String chatId,
    String messageId,
  ) async {
    try {
      final messageDoc =
          await _firestore
              .collection('chats')
              .doc(chatId)
              .collection('messages')
              .doc(messageId)
              .get();

      final data = messageDoc.data();
      final reactions = data?['reactions'] as Map<String, dynamic>? ?? {};

      // Convert to Map<String, String>
      return reactions.map((key, value) => MapEntry(key, value.toString()));
    } catch (e) {
      print('Error getting message reactions: $e');
      return {};
    }
  }

  // Pin/Unpin chat (keep existing)
  Future<void> togglePinChat(
    String chatId,
    String userId,
    bool isPinned,
  ) async {
    try {
      if (isPinned) {
        // Unpin the chat
        await _firestore.collection('chats').doc(chatId).update({
          'isPinned': false,
          'pinnedAt': FieldValue.delete(),
          'pinnedBy': FieldValue.delete(),
        });
      } else {
        // Pin the chat
        await _firestore.collection('chats').doc(chatId).update({
          'isPinned': true,
          'pinnedAt': FieldValue.serverTimestamp(),
          'pinnedBy': userId,
        });
      }
    } catch (e) {
      print('Error toggling pin: $e');
      rethrow;
    }
  }

  // Mute chat with duration
  Future<void> muteChatWithDuration(
    String chatId,
    String userId,
    Duration duration,
  ) async {
    try {
      final muteUntil = DateTime.now().add(duration);
      await _firestore.collection('chats').doc(chatId).update({
        'isMuted': true,
        'mutedUntil': muteUntil,
        'mutedAt': FieldValue.serverTimestamp(),
        'mutedBy': userId,
      });
    } catch (e) {
      print('Error muting chat: $e');
      rethrow;
    }
  }

  // Unmute chat
  Future<void> unmuteChat(String chatId, String userId) async {
    try {
      await _firestore.collection('chats').doc(chatId).update({
        'isMuted': false,
        'mutedUntil': FieldValue.delete(),
        'mutedAt': FieldValue.delete(),
        'mutedBy': FieldValue.delete(),
      });
    } catch (e) {
      print('Error unmuting chat: $e');
      rethrow;
    }
  }

  // Archive chat
  Future<void> archiveChat(String chatId, String userId) async {
    try {
      await _firestore.collection('chats').doc(chatId).update({
        'isArchived': true,
        'archivedAt': FieldValue.serverTimestamp(),
        'archivedBy': userId,
      });
    } catch (e) {
      print('Error archiving chat: $e');
      rethrow;
    }
  }

  // Unarchive chat
  Future<void> unarchiveChat(String chatId, String userId) async {
    try {
      await _firestore.collection('chats').doc(chatId).update({
        'isArchived': false,
        'archivedAt': FieldValue.delete(),
        'archivedBy': FieldValue.delete(),
      });
    } catch (e) {
      print('Error unarchiving chat: $e');
      rethrow;
    }
  }

  // Restore chat that was previously deleted for me
  Future<void> restoreDeletedChat(String chatId, String userId) async {
    try {
      final chatDoc = await _firestore.collection('chats').doc(chatId).get();
      if (!chatDoc.exists) return;

      final chatData = chatDoc.data() as Map<String, dynamic>;
      final deletedBy = List<String>.from(chatData['deletedBy'] ?? []);

      if (deletedBy.contains(userId)) {
        final newDeletedBy = deletedBy.where((id) => id != userId).toList();

        final updateData = {
          'deletedBy': newDeletedBy,
          'isArchived': false,
          'archivedAt': FieldValue.delete(),
          'archivedBy': FieldValue.delete(),
        };

        if (newDeletedBy.isEmpty) {
          updateData['deletedAt'] = FieldValue.delete();
        }

        await _firestore.collection('chats').doc(chatId).update(updateData);
        print('✅ Chat restored for user $userId');
      }
    } catch (e) {
      print('❌ Error restoring chat: $e');
      rethrow;
    }
  }

  // Check if chat is currently muted
  Future<bool> isChatMuted(String chatId, String userId) async {
    try {
      final chatDoc = await _firestore.collection('chats').doc(chatId).get();
      final data = chatDoc.data();

      if (data == null) return false;

      final isMuted = data['isMuted'] ?? false;
      if (!isMuted) return false;

      final mutedUntil = data['mutedUntil'] as Timestamp?;
      if (mutedUntil == null) return true;

      final now = DateTime.now();
      final muteUntilTime = mutedUntil.toDate();

      return now.isBefore(muteUntilTime);
    } catch (e) {
      print('Error checking mute status: $e');
      return false;
    }
  }

  // Delete a chat for current user only
  Future<void> deleteChatForUser(String chatId, String userId) async {
    try {
      await _firestore.collection('chats').doc(chatId).update({
        'deletedBy': FieldValue.arrayUnion([userId]),
        'deletedAt': FieldValue.serverTimestamp(),
      });
    } catch (e) {
      print('Error deleting chat for user: $e');
      rethrow;
    }
  }

  // Delete a chat for everyone (hard delete)
  Future<void> deleteChatForEveryone(String chatId) async {
    try {
      // First delete all messages in the chat
      final messages =
          await _firestore
              .collection('chats')
              .doc(chatId)
              .collection('messages')
              .get();

      final batch = _firestore.batch();
      for (final doc in messages.docs) {
        batch.delete(doc.reference);
      }

      // Then delete the chat document
      batch.delete(_firestore.collection('chats').doc(chatId));

      await batch.commit();
      print('Chat and all messages deleted for everyone');
    } catch (e) {
      print('Error deleting chat for everyone: $e');
      rethrow;
    }
  }

  // Get unread messages count for a user across all chats
  Future<int> getTotalUnreadCount(String userId) async {
    try {
      final chats =
          await _firestore
              .collection('chats')
              .where('participants', arrayContains: userId)
              .get();

      int totalUnread = 0;
      for (final chat in chats.docs) {
        final data = chat.data();
        final deletedBy = List<String>.from(data['deletedBy'] ?? []);

        // Skip chats deleted by user
        if (deletedBy.contains(userId)) continue;

        final unreadCount =
            (data['unreadCount'] as Map<String, dynamic>?)?[userId] ?? 0;
        totalUnread += unreadCount as int;
      }

      return totalUnread;
    } catch (e) {
      print('Error getting total unread count: $e');
      return 0;
    }
  }

  // Check if chat exists between two users
  Future<bool> doesChatExist(String user1, String user2) async {
    try {
      final participants = [user1, user2]..sort();
      final chatId = '${participants[0]}_${participants[1]}';

      final chatDoc = await _firestore.collection('chats').doc(chatId).get();
      return chatDoc.exists;
    } catch (e) {
      print('Error checking if chat exists: $e');
      return false;
    }
  }

  // Get chat document by ID
  Future<DocumentSnapshot> getChatById(String chatId) async {
    try {
      return await _firestore.collection('chats').doc(chatId).get();
    } catch (e) {
      print('Error getting chat by ID: $e');
      rethrow;
    }
  }

  // Update chat last message (useful for system messages)
  Future<void> updateLastMessage(
    String chatId,
    String message,
    String senderId,
    String messageType,
  ) async {
    try {
      // First, restore chat if sender has deleted it
      await _restoreChatForUsers(chatId, senderId, senderId);

      await _firestore.collection('chats').doc(chatId).update({
        'lastMessage': message,
        'lastMessageTime': FieldValue.serverTimestamp(),
        'lastMessageSender': senderId,
        'lastMessageType': messageType,
        // Ensure chat is not archived when updating
        'isArchived': false,
        'archivedAt': FieldValue.delete(),
        'archivedBy': FieldValue.delete(),
      });
    } catch (e) {
      print('❌ Error updating last message: $e');
      rethrow;
    }
  }

  // Get archived chats count for a user
  Future<int> getArchivedChatsCount(String userId) async {
    try {
      final chats =
          await _firestore
              .collection('chats')
              .where('participants', arrayContains: userId)
              .where('isArchived', isEqualTo: true)
              .get();

      // Filter out chats deleted by current user
      int count = 0;
      for (final chat in chats.docs) {
        final data = chat.data();
        final deletedBy = List<String>.from(data['deletedBy'] ?? []);
        if (!deletedBy.contains(userId)) {
          count++;
        }
      }

      return count;
    } catch (e) {
      print('Error getting archived chats count: $e');
      return 0;
    }
  }
}
