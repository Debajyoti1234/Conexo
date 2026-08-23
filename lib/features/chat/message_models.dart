library;

/// Immutable message + group models for Phase 6.2 messaging.
///
/// UI/demo-data only — no persistence, no backend, no realtime. Designed so a
/// future Firebase/Supabase/Appwrite/Socket.io repository can supply the same
/// shapes without changing any widget.

/// Who authored a message. The bubble derives its appearance from this alone.
enum MessageAuthor {
  /// The current user (right-aligned bubble).
  me,

  /// The other person / a participant (left-aligned bubble).
  them,

  /// A system event (centered, chip-styled — joined/left/goal/memory).
  system,
}

/// The kind of content a message carries.
enum MessageType {
  text,
  system,
  shared,
}

/// UI-only delivery state for sent messages.
enum MessageDeliveryStatus {
  sending,
  sent,
  delivered,
  read,
}

/// The kind of embedded shared content. Kept generic for future types.
enum SharedContentType {
  plan,
  memory,
  event,
}

/// A generic embedded content preview (plan, memory, or future event).
///
/// Intentionally free of type-specific fields so [SharedContentCard] never
/// needs a redesign when new content types arrive.
class SharedContentPreview {
  const SharedContentPreview({
    required this.id,
    required this.title,
    required this.subtitle,
    required this.type,
    this.thumbnailAsset,
  });

  final String id;
  final String title;
  final String subtitle;
  final SharedContentType type;
  final String? thumbnailAsset;
}

/// A single message in a conversation.
///
/// Stored in chronological order by the repository; the UI reverses the list.
/// [id] is always stable (never an index) so entrance animations stay correct.
class Message {
  const Message({
    required this.id,
    required this.author,
    required this.timestamp,
    this.type = MessageType.text,
    this.text = '',
    this.senderName,
    this.senderAvatar,
    this.deliveryStatus = MessageDeliveryStatus.read,
    this.sharedContent,
    this.isDeleted = false,
  });

  /// Stable identifier.
  final String id;

  /// Who sent it (drives bubble alignment + styling).
  final MessageAuthor author;

  /// When it was sent.
  final DateTime timestamp;

  /// The content kind.
  final MessageType type;

  /// The message body (empty for shared/system-only messages).
  final String text;

  /// Display name of the sender (used in group chats for received bubbles).
  final String? senderName;

  /// Optional sender avatar asset (group received bubbles).
  final String? senderAvatar;

  /// UI-only delivery state (only meaningful for [MessageAuthor.me]).
  final MessageDeliveryStatus deliveryStatus;

  /// Optional embedded shared content (when [type] is [MessageType.shared]).
  final SharedContentPreview? sharedContent;

  /// Whether this message was soft-deleted (backend `messages.deleted_at`).
  /// A deleted message keeps its position + timestamp in the timeline but its
  /// original content/media is never shown; the bubble renders a subtle
  /// "This message was deleted" placeholder instead.
  final bool isDeleted;

  /// Returns a copy with selected fields overridden. Used to flip a message
  /// into its deleted state locally after a successful soft delete without
  /// rebuilding the whole list from the backend.
  Message copyWith({
    bool? isDeleted,
    MessageDeliveryStatus? deliveryStatus,
  }) {
    return Message(
      id: id,
      author: author,
      timestamp: timestamp,
      type: type,
      text: text,
      senderName: senderName,
      senderAvatar: senderAvatar,
      deliveryStatus: deliveryStatus ?? this.deliveryStatus,
      sharedContent: sharedContent,
      isDeleted: isDeleted ?? this.isDeleted,
    );
  }
}

/// A participant in a group conversation.
class Participant {
  const Participant({
    required this.id,
    required this.name,
    required this.avatarAsset,
    this.isHost = false,
    this.isVerified = false,
    this.isOnline = false,
  });

  final String id;
  final String name;
  final String avatarAsset;
  final bool isHost;
  final bool isVerified;
  final bool isOnline;
}

/// Metadata describing a group (plan) conversation.
///
/// Loaded separately from [ConversationPreview] to keep the inbox lightweight.
class GroupMetadata {
  const GroupMetadata({
    required this.conversationId,
    required this.title,
    required this.hostId,
    required this.participants,
    this.goal,
  });

  final String conversationId;
  final String title;
  final String hostId;
  final List<Participant> participants;

  /// An optional shared goal line shown in the group header.
  final String? goal;

  int get participantCount => participants.length;
}

/// A pure-data description of an overflow-menu entry.
///
/// No callbacks live here — [ConversationScreen] decides what each selected
/// [id] does. This keeps menus declarative and Phase 6.3-friendly.
class ChatMenuAction {
  const ChatMenuAction({
    required this.id,
    required this.label,
    required this.icon,
    this.isDestructive = false,
  });

  /// Stable action key (e.g. 'view_profile', 'block', 'report').
  final String id;

  /// Human label.
  final String label;

  /// Icon code point resolved by the widget layer.
  final int icon;

  /// Whether the entry should read as destructive (e.g. Block/Report).
  final bool isDestructive;
}
