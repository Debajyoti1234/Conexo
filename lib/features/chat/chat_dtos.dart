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

/// A lightweight projection of a Plan group conversation for the Chat → Plans
/// inbox. Carries just enough to render a tile: the conversation id, the plan
/// id, the plan title, and the raw plan cover storage path (to be signed).
class PlanConversationSummary {
  const PlanConversationSummary({
    required this.conversationId,
    required this.planId,
    required this.title,
    this.coverPath,
  });

  final String conversationId;
  final String planId;
  final String title;

  /// Raw `plans.cover_url` value (a `plan-covers` storage path or a local
  /// asset). Signed by the caller via the existing cover-signing pipeline.
  final String? coverPath;
}
