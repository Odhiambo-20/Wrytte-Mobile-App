import 'dart:async';
import 'package:wrytte/models/chat_models/chat_conversation.dart';
import 'package:wrytte/models/chat_models/chat_message.dart';
import 'package:wrytte/services/chat/chat_service.dart';

class ChatState {
  final ChatService _chatService;

  final List<ChatMessage> _messages = [];
  final List<ChatConversation> _conversations = [];

  String? _activeConversationId;

  final StreamController<List<ChatMessage>> _messagesController =
      StreamController<List<ChatMessage>>.broadcast();
  final StreamController<List<ChatConversation>> _conversationsController =
      StreamController<List<ChatConversation>>.broadcast();
  final StreamController<bool> _loadingController =
      StreamController<bool>.broadcast();
  final StreamController<String?> _errorController =
      StreamController<String?>.broadcast();

  Stream<List<ChatMessage>> get messagesStream => _messagesController.stream;
  Stream<List<ChatConversation>> get conversationsStream =>
      _conversationsController.stream;
  Stream<bool> get loadingStream => _loadingController.stream;
  Stream<String?> get errorStream => _errorController.stream;

  StreamSubscription<ChatMessage>? _messageSubscription;
  StreamSubscription<String>? _errorSubscription;
  StreamSubscription<bool>? _connectionSubscription;
  StreamSubscription<List<ChatConversation>>? _conversationsSubscription;

  ChatState(this._chatService);

  /// INITIALIZE SOCKET & LOAD CONVERSATIONS

  Future<void> initialize() async {
    _loadingController.add(true);

    try {
      _messageSubscription = _chatService.messageStream.listen(
        _handleIncomingMessage,
      );

      _errorSubscription = _chatService.errorStream.listen(_handleError);

      _connectionSubscription = _chatService.connectionStream.listen((
        isConnected,
      ) {
        if (!isConnected) {
          _handleError("Connection lost. Attempting reconnect...");
        }
      });

      _conversationsSubscription = _chatService.conversationsStream.listen((
        convs,
      ) {
        _conversations
          ..clear()
          ..addAll(convs);

        _conversationsController.add(List.unmodifiable(_conversations));

        if (_activeConversationId != null) {
          _updateActiveConversationMessages();
        }
      });

      // Load initial messages which builds conversations
      await _chatService.fetchMessages();

      _loadingController.add(false);
    } catch (e) {
      _loadingController.add(false);
      _handleError("Failed to initialize chat: $e");
    }
  }

  /// LOAD A CONVERSATION

  Future<void> loadConversation(String conversationId) async {
    _activeConversationId = conversationId;
    _updateActiveConversationMessages();
  }

  /// UPDATE ACTIVE CONVERSATION MESSAGES

  void _updateActiveConversationMessages() {
    if (_activeConversationId == null) return;

    final messages = _chatService.getConversationMessages(
      _activeConversationId!,
    );

    _messages
      ..clear()
      ..addAll(messages);

    _messagesController.add(List.unmodifiable(_messages));
  }

  /// HANDLE INCOMING MESSAGE

  void _handleIncomingMessage(ChatMessage message) {
    if (message.conversationId == _activeConversationId) {
      if (!_messages.any((m) => m.id == message.id)) {
        _messages.add(message);
        _messages.sort((a, b) => a.timestamp.compareTo(b.timestamp));
        _messagesController.add(List.unmodifiable(_messages));
      }
    }
  }

  /// SEND MESSAGE

  Future<void> sendMessage(ChatMessage message) async {
    try {
      await _chatService.sendMessage(message);

      if (message.conversationId == _activeConversationId) {
        if (!_messages.any((m) => m.id == message.id)) {
          _messages.add(message);
          _messages.sort((a, b) => a.timestamp.compareTo(b.timestamp));
          _messagesController.add(List.unmodifiable(_messages));
        }
      }
    } catch (e) {
      _handleError("Failed to send message: $e");
    }
  }

  /// ERROR HANDLING

  void _handleError(String error) {
    _errorController.add(error);
  }

  /// CLEAR MESSAGES

  void clearMessages() {
    _messages.clear();
    _messagesController.add([]);
  }

  /// DISCONNECT

  Future<void> disconnect() async {
    await _chatService.disconnect();
  }

  /// DISPOSE

  void dispose() {
    _messageSubscription?.cancel();
    _errorSubscription?.cancel();
    _connectionSubscription?.cancel();
    _conversationsSubscription?.cancel();

    _messagesController.close();
    _conversationsController.close();
    _loadingController.close();
    _errorController.close();
  }
}
