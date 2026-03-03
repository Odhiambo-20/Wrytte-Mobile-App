import 'dart:convert';

enum MessageStatus { sending, sent, delivered, read, failed }

MessageStatus _statusFromString(String? value) {
  switch (value) {
    case "sent":
      return MessageStatus.sent;
    case "delivered":
      return MessageStatus.delivered;
    case "read":
      return MessageStatus.read;
    case "failed":
      return MessageStatus.failed;
    case "sending":
    default:
      return MessageStatus.sending;
  }
}

String _statusToString(MessageStatus status) {
  return status.name;
}

class ChatMessage {
  final String id;
  final String conversationId;

  /// Sender userId
  final String senderId;

  /// Receiver userId (used by socket "to")
  final String receiverId;

  final String content;
  final DateTime timestamp;
  final MessageStatus status;
  final String? attachmentUrl;
  final String? attachmentType;
  final int unreadCount;

  const ChatMessage({
    required this.id,
    required this.conversationId,
    required this.senderId,
    required this.receiverId,
    required this.content,
    required this.timestamp,
    this.status = MessageStatus.sending,
    this.attachmentUrl,
    this.attachmentType,
    this.unreadCount = 0,
  });

  // FROM JSON (Backend)

  factory ChatMessage.fromJson(Map<String, dynamic> json) {
    return ChatMessage(
      id: json["id"]?.toString() ?? "",
      conversationId: json["conversationId"]?.toString() ?? "",
      senderId: json["senderId"]?.toString() ?? "",
      receiverId: json["receiverId"]?.toString() ?? "",
      content: json["content"]?.toString() ?? "",
      timestamp:
          json["timestamp"] != null
              ? DateTime.tryParse(json["timestamp"].toString()) ??
                  DateTime.now()
              : DateTime.now(),
      status: _statusFromString(json["status"]?.toString()),
      attachmentUrl: json["attachmentUrl"]?.toString(),
      attachmentType: json["attachmentType"]?.toString(),
    );
  }

  // TO JSON (HTTP / Local DB)

  Map<String, dynamic> toJson() {
    return {
      "id": id,
      "conversationId": conversationId,
      "senderId": senderId,
      "receiverId": receiverId,
      "content": content,
      "timestamp": timestamp.toUtc().toIso8601String(),
      "status": _statusToString(status),
      if (attachmentUrl != null) "attachmentUrl": attachmentUrl,
      if (attachmentType != null) "attachmentType": attachmentType,
    };
  }

  // COPY WITH

  ChatMessage copyWith({
    String? id,
    String? conversationId,
    String? senderId,
    String? receiverId,
    String? content,
    DateTime? timestamp,
    MessageStatus? status,
    String? attachmentUrl,
    String? attachmentType,
  }) {
    return ChatMessage(
      id: id ?? this.id,
      conversationId: conversationId ?? this.conversationId,
      senderId: senderId ?? this.senderId,
      receiverId: receiverId ?? this.receiverId,
      content: content ?? this.content,
      timestamp: timestamp ?? this.timestamp,
      status: status ?? this.status,
      attachmentUrl: attachmentUrl ?? this.attachmentUrl,
      attachmentType: attachmentType ?? this.attachmentType,
    );
  }

  // HELPER METHODS

  bool isMine(String currentUserId) {
    return senderId == currentUserId;
  }

  bool get hasAttachment => attachmentUrl != null;

  // LOCAL SERIALIZATION

  String toRaw() => jsonEncode(toJson());

  factory ChatMessage.fromRaw(String source) {
    final decoded = jsonDecode(source);
    if (decoded is Map<String, dynamic>) {
      return ChatMessage.fromJson(decoded);
    }
    throw const FormatException("Invalid ChatMessage format");
  }

  @override
  String toString() {
    return "ChatMessage(id: $id, senderId: $senderId, receiverId: $receiverId, content: $content, status: $status)";
  }
}
