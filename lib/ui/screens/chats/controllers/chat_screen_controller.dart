import 'package:wrytte/models/auth_models/auth_user.dart';
import 'package:wrytte/models/chat_models/chat_message.dart';
import 'package:wrytte/services/chat/chat_service.dart';
import 'package:wrytte/state/chat/chat_state.dart';

class ChatScreenController {
  final String conversationId;
  final AuthUser currentUser;
  final String receiverId;

  late final ChatState _chatState;

  ChatScreenController({
    required this.conversationId,
    required this.currentUser,
    required this.receiverId,
  }) {
    _chatState = ChatState(ChatService());
  }

  Stream<List<ChatMessage>> get messagesStream => _chatState.messagesStream;

  Stream<bool> get loadingStream => _chatState.loadingStream;

  Stream<String?> get errorStream => _chatState.errorStream;

  Future<void> initialize() async {
    await _chatState.initialize();
  }

  Future<void> sendMessage(String content) async {
    if (content.trim().isEmpty) return;

    final message = ChatMessage(
      id: DateTime.now().millisecondsSinceEpoch.toString(),
      conversationId: conversationId,
      senderId: currentUser.userId,
      receiverId: receiverId,
      content: content.trim(),
      timestamp: DateTime.now(),
      status: MessageStatus.sending,
    );

    await _chatState.sendMessage(message);
  }

  bool isMine(ChatMessage message) {
    return message.senderId == currentUser.userId;
  }

  void dispose() {
    _chatState.dispose();
  }
}
