enum ChatEventType { inserted, updated, deleted }

class ChatConversation {
  ChatConversation({
    required this.id,
    required this.type,
    this.planId,
    required this.createdAt,
    required this.updatedAt,
  });

  factory ChatConversation.fromJson(Map<String, dynamic> json) {
    return ChatConversation(
      id: json['id'] as String,
      type: json['type'] as String,
      planId: json['plan_id'] as String?,
      createdAt: DateTime.parse(json['created_at'] as String),
      updatedAt: DateTime.parse(json['updated_at'] as String),
    );
  }

  final String id;
  final String type;
  final String? planId;
  final DateTime createdAt;
  final DateTime updatedAt;
}

class ChatMessage {
  ChatMessage({
    required this.id,
    required this.conversationId,
    required this.senderId,
    required this.type,
    required this.content,
    this.mediaUrl,
    required this.createdAt,
    this.deletedAt,
  });

  factory ChatMessage.fromJson(Map<String, dynamic> json) {
    return ChatMessage(
      id: json['id'] as String,
      conversationId: json['conversation_id'] as String,
      senderId: json['sender_id'] as String,
      type: json['type'] as String,
      content: json['content'] as String,
      mediaUrl: json['media_url'] as String?,
      createdAt: DateTime.parse(json['created_at'] as String),
      deletedAt: json['deleted_at'] == null
          ? null
          : DateTime.parse(json['deleted_at'] as String),
    );
  }

  final String id;
  final String conversationId;
  final String senderId;
  final String type;
  final String content;
  final String? mediaUrl;
  final DateTime createdAt;
  final DateTime? deletedAt;
}

class ChatMessageEvent {
  ChatMessageEvent({
    required this.messageId,
    required this.type,
    this.message,
  });

  final String messageId;
  final ChatEventType type;
  final ChatMessage? message;
}
