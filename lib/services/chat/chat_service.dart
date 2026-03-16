import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:wrytte/models/auth_models/auth_user.dart';
import 'package:wrytte/models/chat_models/chat_message.dart';
import 'package:wrytte/models/chat_models/chat_conversation.dart';
import 'package:wrytte/models/chat_models/socket_message.dart';
import 'package:wrytte/services/auth/auth_service.dart';
import 'package:wrytte/services/auth/api_service.dart';
import 'package:wrytte/services/chat/websocket_service.dart';

class ChatService {
  // SINGLETON

  ChatService._internal();
  static final ChatService _instance = ChatService._internal();
  factory ChatService() => _instance;

  final WebSocketService _socket = WebSocketService();
  final AuthService _authService = AuthService.instance;

  // STREAM CONTROLLERS

  final StreamController<ChatMessage> _messageController =
      StreamController<ChatMessage>.broadcast();
  final StreamController<String> _errorController =
      StreamController<String>.broadcast();
  final StreamController<bool> _connectionController =
      StreamController<bool>.broadcast();
  final StreamController<List<ChatConversation>> _conversationsController =
      StreamController<List<ChatConversation>>.broadcast();

  // PUBLIC STREAMS

  Stream<ChatMessage> get messageStream => _messageController.stream;
  Stream<String> get errorStream => _errorController.stream;
  Stream<bool> get connectionStream => _connectionController.stream;
  Stream<List<ChatConversation>> get conversationsStream =>
      _conversationsController.stream;

  AuthUser? _currentUser;
  StreamSubscription? _socketSub;

  bool _initialized = false;
  bool _isConnected = false;

  /// Prevent overlapping API calls
  bool _isFetchingMessages = false;

  // CLIENT SIDE CACHE

  final Map<String, ChatConversation> _conversationsMap = {};
  final Map<String, List<ChatMessage>> _messagesCache = {};

  // AUTO SYNC

  Timer? _autoSyncTimer;
  final Duration _syncInterval = const Duration(seconds: 15);

  // CONNECT

  Future<void> connect() async {
    if (_initialized) return;

    try {
      _currentUser = await _authService.getCurrentUser();

      if (_currentUser == null) {
        _errorController.add("User not authenticated");
        return;
      }

      final token = _currentUser!.token;

      if (token == null || token.isEmpty) {
        _errorController.add("Missing auth token");
        return;
      }

      await _socket.connect(token: token);

      _socketSub = _socket.messages.listen(
        _handleSocketMessage,
        onError: (error) {
          _errorController.add("Socket error: $error");
          _handleDisconnect();
        },
        onDone: () {
          _handleDisconnect();
        },
      );

      _isConnected = true;
      _initialized = true;

      _connectionController.add(true);

      debugPrint("ChatService connected");

      _startAutoSync();
    } catch (e) {
      debugPrint("Connection failed $e");
      _errorController.add("Connection failed: $e");
      _connectionController.add(false);
    }
  }

  // AUTO SYNC

  void _startAutoSync() {
    _autoSyncTimer?.cancel();

    _autoSyncTimer = Timer.periodic(_syncInterval, (_) async {
      try {
        if (!_isConnected || _currentUser == null) return;

        if (_isFetchingMessages) return;

        String? lastMessageId;

        final allMessages = _messagesCache.values.expand((e) => e).toList();

        if (allMessages.isNotEmpty) {
          allMessages.sort((a, b) => b.timestamp.compareTo(a.timestamp));
          lastMessageId = allMessages.first.id;
        }

        await fetchMessages(messageId: lastMessageId);
      } catch (e) {
        debugPrint("Auto sync error $e");
      }
    });
  }

  // HANDLE SOCKET MESSAGE

  void _handleSocketMessage(Map<String, dynamic> raw) {
    try {
      final socketMessage = SocketMessage.fromMap(raw);

      switch (socketMessage.type) {
        case SocketMessageType.message:
          _handleIncomingChatMessage(socketMessage);
          break;

        case SocketMessageType.typing:
        case SocketMessageType.presence:
        case SocketMessageType.system:
          break;

        case SocketMessageType.error:
          _errorController.add(socketMessage.message ?? "Server error");
          break;

        default:
          debugPrint("Unknown socket message");
      }
    } catch (e) {
      debugPrint("Socket parse error $e");
    }
  }

  // HANDLE INCOMING MESSAGE

  void _handleIncomingChatMessage(SocketMessage socketMessage) {
    final payload = socketMessage.payload;

    if (payload is! Map) return;

    final senderId = payload["from"]?.toString() ?? "";
    final receiverId = payload["to"]?.toString() ?? "";

    final conversationId =
        (senderId.compareTo(receiverId) < 0)
            ? "$senderId-$receiverId"
            : "$receiverId-$senderId";

    final chatMessage = ChatMessage(
      id: payload["msgId"]?.toString() ?? "",
      conversationId: conversationId,
      senderId: senderId,
      receiverId: receiverId,
      content: payload["msg"]?.toString() ?? "",
      timestamp:
          payload["ts"] != null
              ? DateTime.tryParse(payload["ts"].toString()) ?? DateTime.now()
              : DateTime.now(),
      status: MessageStatus.sent,
      attachmentUrl: payload["attachmentUrl"]?.toString(),
      attachmentType: payload["attachmentType"]?.toString(),
    );

    _messageController.add(chatMessage);

    _updateConversations(chatMessage);
  }

  // UPDATE CONVERSATION CACHE

  void _updateConversations(ChatMessage message) {
    final convId = message.conversationId;

    final currentUserId = _currentUser?.userId ?? "";

    if (_conversationsMap.containsKey(convId)) {
      final existing = _conversationsMap[convId]!;

      _conversationsMap[convId] = existing.updateWithMessage(
        message,
        currentUserId,
      );
    } else {
      _conversationsMap[convId] = ChatConversation.fromMessage(
        message,
        currentUserId,
      );
    }

    _messagesCache.putIfAbsent(convId, () => []);

    if (!_messagesCache[convId]!.any((m) => m.id == message.id)) {
      _messagesCache[convId]!.add(message);
    }

    final sorted =
        _conversationsMap.values.toList()
          ..sort((a, b) => b.lastMessageTime.compareTo(a.lastMessageTime));

    _conversationsController.add(sorted);
  }

  // SEND MESSAGE

  Future<void> sendMessage(ChatMessage message) async {
    if (_currentUser == null || !_isConnected) {
      throw Exception("Socket not connected");
    }

    final socketPayload = {
      "cmd": "sendMsg",
      "msgType": "1:1",
      "msgId": message.id,
      "to": message.receiverId,
      "msg": message.content,
      "ts": message.timestamp.toUtc().toIso8601String(),
    };

    _socket.send(socketPayload);
  }

  // FETCH MESSAGES FROM API

  Future<List<ChatMessage>> fetchMessages({
    String? messageId,
    DateTime? time,
    int maxCount = 100,
  }) async {
    if (_isFetchingMessages) {
      debugPrint("Fetch already running, skipping");
      return [];
    }

    _isFetchingMessages = true;

    try {
      final response = await ApiService.post(
        "/api/Message/GetMessages",
        queryParameters: {
          "maxCount": maxCount.toString(),
        }, // ✅ convert to String
        body: {"time": time?.toUtc().toIso8601String(), "messageId": messageId},
      );

      debugPrint("API GetMessages response: $response");

      if (response == null) {
        debugPrint("Response is null");
        return [];
      }

      if (response is! Map) {
        debugPrint("Unexpected response type: ${response.runtimeType}");
        return [];
      }

      final dynamic rawMessages = response["messages"];

      if (rawMessages == null) {
        debugPrint("API returned null messages");
        return [];
      }

      if (rawMessages is! List) {
        debugPrint(
          "API 'messages' field is not a list: ${rawMessages.runtimeType}",
        );
        return [];
      }

      final List<ChatMessage> messages = [];

      for (final item in rawMessages) {
        if (item == null || item is! Map) {
          debugPrint("Skipping invalid message item: $item");
          continue;
        }

        final msg = Map<String, dynamic>.from(item);

        final sender = msg["from"]?.toString() ?? "";
        final receiver = msg["to"]?.toString() ?? "";

        if (sender.isEmpty || receiver.isEmpty) {
          debugPrint("Skipping message with missing sender/receiver");
          continue;
        }

        final convId =
            (sender.compareTo(receiver) < 0)
                ? "$sender-$receiver"
                : "$receiver-$sender";

        DateTime timestamp = DateTime.now();

        if (msg["ts"] != null) {
          final parsed = DateTime.tryParse(msg["ts"].toString());
          if (parsed != null) timestamp = parsed;
        }

        final message = ChatMessage(
          id: msg["msgId"]?.toString() ?? "",
          conversationId: convId,
          senderId: sender,
          receiverId: receiver,
          content: msg["msg"]?.toString() ?? "",
          timestamp: timestamp,
          status: MessageStatus.sent,
          attachmentUrl: msg["attachmentUrl"]?.toString(),
          attachmentType: msg["attachmentType"]?.toString(),
        );

        messages.add(message);
      }

      // Update conversations
      for (final msg in messages) {
        _updateConversations(msg);
      }

      debugPrint("Fetched ${messages.length} messages");

      return messages;
    } catch (e, stack) {
      debugPrint("Fetch messages error: $e");
      debugPrint(stack.toString());
      return [];
    } finally {
      _isFetchingMessages = false;
    }
  }

  // GET CONVERSATION MESSAGES

  List<ChatMessage> getConversationMessages(String conversationId) {
    final messages = _messagesCache[conversationId] ?? [];
    messages.sort((a, b) => a.timestamp.compareTo(b.timestamp));
    return messages;
  }

  // DISCONNECT

  Future<void> disconnect() async {
    await _socket.disconnect();
    await _socketSub?.cancel();
    _autoSyncTimer?.cancel();
    _handleDisconnect();
  }

  void _handleDisconnect() {
    if (!_isConnected) return;

    _isConnected = false;
    _initialized = false;

    _connectionController.add(false);
  }

  // DISPOSE

  void dispose() {
    disconnect();

    _messageController.close();
    _errorController.close();
    _connectionController.close();
    _conversationsController.close();
  }
}
