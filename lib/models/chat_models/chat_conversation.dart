import 'chat_message.dart';

class ChatConversation {
  final String conversationId;
  final List<String> participants; // sender + receiver
  final String lastMessage;
  final DateTime lastMessageTime;
  final int unreadCount;

  ChatConversation({
    required this.conversationId,
    required this.participants,
    required this.lastMessage,
    required this.lastMessageTime,
    this.unreadCount = 0,
  });

  /// Create conversation from a single ChatMessage
  factory ChatConversation.fromMessage(
    ChatMessage message,
    String currentUserId,
  ) {
    final unread = message.receiverId == currentUserId ? 1 : 0;
    return ChatConversation(
      conversationId: message.conversationId,
      participants: [message.senderId, message.receiverId],
      lastMessage: message.content,
      lastMessageTime: message.timestamp,
      unreadCount: unread,
    );
  }

  /// Update conversation with a new message
  ChatConversation updateWithMessage(
    ChatMessage message,
    String currentUserId,
  ) {
    return ChatConversation(
      conversationId: conversationId,
      participants: [message.senderId, message.receiverId],
      lastMessage:
          message.timestamp.isAfter(lastMessageTime)
              ? message.content
              : lastMessage,
      lastMessageTime:
          message.timestamp.isAfter(lastMessageTime)
              ? message.timestamp
              : lastMessageTime,
      unreadCount: unreadCount + (message.receiverId == currentUserId ? 1 : 0),
    );
  }
}
