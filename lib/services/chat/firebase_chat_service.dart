import 'dart:async';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';
import 'package:wrytte/models/chat_models/chat_message.dart';
import 'package:wrytte/models/chat_models/chat_conversation.dart';

/// FirebaseChatService
///
/// A self-contained chat service that uses Cloud Firestore as the backend.
/// It mirrors the API surface of [ChatService] so the rest of the app can
/// swap between the two without touching UI code.
///
/// Firestore structure (matches existing schema):
///   /chats/{conversationId}
///       participants        : List<String>   [uid1, uid2]
///       participantsKey     : String         "uid1_uid2" (sorted, joined with _)
///       lastMessage         : String
///       lastMessageSender   : String
///       lastMessageTime     : Timestamp
///       lastMessageType     : String         "text" | "image" | …
///       unreadCount         : Map<uid, int>
///       isArchived          : bool
///       isMuted             : bool
///       isPinned            : bool
///       mutedUntil          : Timestamp?
///       lastSeen            : Map<uid, Timestamp>
///       createdAt           : Timestamp
///       deletedAt           : Timestamp?
///       deletedBy           : List<String>
///
///   /chats/{conversationId}/messages/{messageId}
///       from        : String   senderId
///       to          : String   receiverId
///       msg         : String   text content
///       ts          : Timestamp
///       msgType     : String   "text" | "image" | …
///       attachmentUrl  : String?
///       attachmentType : String?
///       seenBy      : List<String>
class FirebaseChatService {
  // ── Singleton ──────────────────────────────────────────────────────────────

  FirebaseChatService._internal();
  static final FirebaseChatService _instance = FirebaseChatService._internal();
  factory FirebaseChatService() => _instance;

  // ── Firebase references ────────────────────────────────────────────────────

  final FirebaseFirestore _db = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;

  // ── State ──────────────────────────────────────────────────────────────────

  String? _currentUserId;
  bool _initialized = false;

  // Active listeners – keyed by conversationId
  final Map<String, StreamSubscription> _messageListeners = {};

  // ── Stream controllers ─────────────────────────────────────────────────────

  final StreamController<ChatMessage> _messageController =
      StreamController<ChatMessage>.broadcast();

  final StreamController<String> _errorController =
      StreamController<String>.broadcast();

  final StreamController<bool> _connectionController =
      StreamController<bool>.broadcast();

  final StreamController<List<ChatConversation>> _conversationsController =
      StreamController<List<ChatConversation>>.broadcast();

  // ── Public streams (same surface as ChatService) ───────────────────────────

  Stream<ChatMessage> get messageStream => _messageController.stream;
  Stream<String> get errorStream => _errorController.stream;
  Stream<bool> get connectionStream => _connectionController.stream;
  Stream<List<ChatConversation>> get conversationsStream =>
      _conversationsController.stream;

  // ── Helpers ────────────────────────────────────────────────────────────────

  String get currentUserId => _currentUserId ?? '';

  /// Deterministic conversation ID: sorted UIDs joined with "-"
  static String buildConversationId(String uid1, String uid2) {
    final parts = [uid1, uid2]..sort();
    return '${parts[0]}-${parts[1]}';
  }

  /// Deterministic participants key for Firestore queries
  static String buildParticipantsKey(String uid1, String uid2) {
    final parts = [uid1, uid2]..sort();
    return '${parts[0]}_${parts[1]}';
  }

  // ── Connect ────────────────────────────────────────────────────────────────

  Future<void> connect() async {
    if (_initialized) return;

    try {
      final user = _auth.currentUser;
      if (user == null) {
        _errorController.add('User not authenticated');
        _connectionController.add(false);
        return;
      }

      _currentUserId = user.uid;
      _initialized = true;
      _connectionController.add(true);

      // Start listening to the conversations list
      _listenToConversations();

      debugPrint('FirebaseChatService connected as $_currentUserId');
    } catch (e) {
      debugPrint('FirebaseChatService connect error: $e');
      _errorController.add('Connection failed: $e');
      _connectionController.add(false);
    }
  }

  // ── Conversations listener ─────────────────────────────────────────────────

  StreamSubscription? _conversationsSub;

  void _listenToConversations() {
    _conversationsSub?.cancel();

    _conversationsSub = _db
        .collection('chats')
        .where('participants', arrayContains: _currentUserId)
        .orderBy('lastMessageTime', descending: true)
        .snapshots()
        .listen(
          (snapshot) {
            final conversations =
                snapshot.docs
                    .map((doc) => _conversationFromDoc(doc))
                    .where((c) => c != null)
                    .cast<ChatConversation>()
                    .toList();

            _conversationsController.add(conversations);
          },
          onError: (e) {
            debugPrint('Conversations listener error: $e');
            _errorController.add('Conversations error: $e');
          },
        );
  }

  ChatConversation? _conversationFromDoc(DocumentSnapshot doc) {
    try {
      final data = doc.data() as Map<String, dynamic>?;
      if (data == null) return null;

      final participants = List<String>.from(data['participants'] ?? []);
      final otherId = participants.firstWhere(
        (p) => p != _currentUserId,
        orElse: () => '',
      );

      if (otherId.isEmpty) return null;

      final lastMessageTime =
          (data['lastMessageTime'] as Timestamp?)?.toDate() ?? DateTime.now();

      final unreadMap = Map<String, dynamic>.from(data['unreadCount'] ?? {});
      final unreadCount = (unreadMap[_currentUserId] as int?) ?? 0;

      return ChatConversation(
        id: doc.id,
        otherUserId: otherId,
        lastMessage: data['lastMessage']?.toString() ?? '',
        lastMessageTime: lastMessageTime,
        lastMessageSenderId: data['lastMessageSender']?.toString() ?? '',
        unreadCount: unreadCount,
        participants: [],
      );
    } catch (e) {
      debugPrint('Error parsing conversation doc: $e');
      return null;
    }
  }

  // ── Messages listener for a single conversation ────────────────────────────

  /// Call this when the user opens a chat screen.
  /// Returns a stream of [ChatMessage] for [conversationId].
  Stream<List<ChatMessage>> getMessagesStream(String conversationId) {
    return _db
        .collection('chats')
        .doc(conversationId)
        .collection('messages')
        .orderBy('ts', descending: false)
        .snapshots()
        .map(
          (snapshot) =>
              snapshot.docs
                  .map((doc) => _messageFromDoc(doc, conversationId))
                  .where((m) => m != null)
                  .cast<ChatMessage>()
                  .toList(),
        );
  }

  ChatMessage? _messageFromDoc(DocumentSnapshot doc, String conversationId) {
    try {
      final data = doc.data() as Map<String, dynamic>?;
      if (data == null) return null;

      final ts = data['ts'];
      DateTime timestamp;
      if (ts is Timestamp) {
        timestamp = ts.toDate();
      } else if (ts is String) {
        timestamp = DateTime.tryParse(ts) ?? DateTime.now();
      } else {
        timestamp = DateTime.now();
      }

      return ChatMessage(
        id: doc.id,
        conversationId: conversationId,
        senderId: data['from']?.toString() ?? '',
        receiverId: data['to']?.toString() ?? '',
        content: data['msg']?.toString() ?? '',
        timestamp: timestamp,
        status: MessageStatus.sent,
        attachmentUrl: data['attachmentUrl']?.toString(),
        attachmentType: data['attachmentType']?.toString(),
      );
    } catch (e) {
      debugPrint('Error parsing message doc: $e');
      return null;
    }
  }

  // ── Send message ───────────────────────────────────────────────────────────

  Future<void> sendMessage(ChatMessage message) async {
    if (_currentUserId == null) {
      throw Exception('FirebaseChatService not connected');
    }

    final conversationId = message.conversationId;
    final convRef = _db.collection('chats').doc(conversationId);
    final messagesRef = convRef.collection('messages');

    final now = FieldValue.serverTimestamp();
    final clientNow = DateTime.now();

    final batch = _db.batch();

    // 1. Write the message document
    final msgRef = messagesRef.doc(message.id);
    batch.set(msgRef, {
      'from': message.senderId,
      'to': message.receiverId,
      'msg': message.content,
      'ts': Timestamp.fromDate(clientNow),
      'msgType': 'text',
      if (message.attachmentUrl != null) 'attachmentUrl': message.attachmentUrl,
      if (message.attachmentType != null)
        'attachmentType': message.attachmentType,
      'seenBy': [message.senderId],
    });

    // 2. Upsert the conversation document
    batch.set(convRef, {
      'participants': [message.senderId, message.receiverId]..sort(),
      'participantsKey': buildParticipantsKey(
        message.senderId,
        message.receiverId,
      ),
      'lastMessage': message.content,
      'lastMessageSender': message.senderId,
      'lastMessageTime': now,
      'lastMessageType': 'text',
      'isArchived': false,
      'isMuted': false,
      'isPinned': false,
      'mutedUntil': null,
      // Increment receiver's unread count
      'unreadCount.${message.receiverId}': FieldValue.increment(1),
      'createdAt': now,
    }, SetOptions(merge: true));

    try {
      await batch.commit();
      debugPrint('Message sent: ${message.id}');
    } catch (e) {
      debugPrint('sendMessage error: $e');
      _errorController.add('Send failed: $e');
      rethrow;
    }
  }

  // ── Ensure conversation exists ─────────────────────────────────────────────

  /// Creates a conversation document if it doesn't exist yet.
  /// Call before opening a new chat for the first time.
  Future<String> ensureConversation(String otherUserId) async {
    final myId = _currentUserId!;
    final convId = buildConversationId(myId, otherUserId);
    final convRef = _db.collection('chats').doc(convId);

    final snap = await convRef.get();
    if (!snap.exists) {
      await convRef.set({
        'participants': [myId, otherUserId]..sort(),
        'participantsKey': buildParticipantsKey(myId, otherUserId),
        'lastMessage': '',
        'lastMessageSender': '',
        'lastMessageTime': FieldValue.serverTimestamp(),
        'lastMessageType': 'text',
        'unreadCount': {myId: 0, otherUserId: 0},
        'isArchived': false,
        'isMuted': false,
        'isPinned': false,
        'mutedUntil': null,
        'lastSeen': {},
        'createdAt': FieldValue.serverTimestamp(),
        'deletedAt': null,
        'deletedBy': [],
      });
    }

    return convId;
  }

  // ── Mark messages as seen ──────────────────────────────────────────────────

  Future<void> markConversationAsRead(String conversationId) async {
    final myId = _currentUserId;
    if (myId == null) return;

    try {
      await _db.collection('chats').doc(conversationId).set({
        'unreadCount.$myId': 0,
        'lastSeen.$myId': FieldValue.serverTimestamp(),
      }, SetOptions(merge: true));
    } catch (e) {
      debugPrint('markAsRead error: $e');
    }
  }

  // ── Fetch conversations (one-shot) ─────────────────────────────────────────

  Future<List<ChatConversation>> fetchConversations() async {
    try {
      final snap =
          await _db
              .collection('chats')
              .where('participants', arrayContains: _currentUserId)
              .orderBy('lastMessageTime', descending: true)
              .get();

      return snap.docs
          .map((doc) => _conversationFromDoc(doc))
          .where((c) => c != null)
          .cast<ChatConversation>()
          .toList();
    } catch (e) {
      debugPrint('fetchConversations error: $e');
      return [];
    }
  }

  // ── Disconnect / dispose ───────────────────────────────────────────────────

  Future<void> disconnect() async {
    _conversationsSub?.cancel();
    for (final sub in _messageListeners.values) {
      await sub.cancel();
    }
    _messageListeners.clear();
    _initialized = false;
    _currentUserId = null;
    _connectionController.add(false);
  }

  void dispose() {
    disconnect();
    _messageController.close();
    _errorController.close();
    _connectionController.close();
    _conversationsController.close();
  }
}
