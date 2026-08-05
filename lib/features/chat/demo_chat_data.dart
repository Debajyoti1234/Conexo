import 'chat_models.dart';
import 'message_models.dart';

/// Premium demo data for the Connections inbox + messaging (Phases 6.1–6.2).
///
/// Static, local data only — reuses the existing portrait assets so no new
/// files are introduced. Organised into three clearly-labelled sections:
///
///   1. Conversation previews  ([demoConversations])
///   2. Message threads keyed by conversationId  ([demoMessageThreads])
///   3. Group metadata keyed by conversationId  ([demoGroupMetadata])
///
/// Messages are stored in chronological order (oldest → newest); the UI
/// reverses the list for display. Every message carries a stable id.

// Existing local portraits, cycled across the demo set.
const _p1 = 'assets/images/portraits/demo1.jpeg';
const _p2 = 'assets/images/portraits/demo2.jpeg';
const _p3 = 'assets/images/portraits/demo3.jpeg';
const _p4 = 'assets/images/portraits/demo4.jpeg';
const _p5 = 'assets/images/portraits/demo5.jpeg';
const _p6 = 'assets/images/portraits/demo6.jpeg';

/// The curated demo inbox. Pinned entries are listed first for clarity, but
/// the UI groups pinned vs recent independently.
const List<ConversationPreview> demoConversations = [
  // ── Pinned ──────────────────────────────────────────────────────────
  ConversationPreview(
    id: 'c1',
    name: 'Maya Rao',
    avatarAsset: _p1,
    lastMessage: 'is typing…',
    timestamp: 'now',
    status: ConversationStatus.online,
    isTyping: true,
    isPinned: true,
    isVerified: true,
  ),
  ConversationPreview(
    id: 'c2',
    name: 'Arjun Mehta',
    avatarAsset: _p2,
    lastMessage: 'I found the perfect spot for the walk.',
    timestamp: '14m',
    status: ConversationStatus.online,
    lastMessageType: LastMessageType.plan,
    unreadCount: 2,
    isPinned: true,
  ),

  // ── Recent ──────────────────────────────────────────────────────────
  ConversationPreview(
    id: 'c3',
    name: 'Nora Fielding',
    avatarAsset: _p3,
    lastMessage: 'I can bring a few records along.',
    timestamp: '1h',
    unreadCount: 4,
    isVerified: true,
  ),

  // ── Group chats (plans) ─────────────────────────────────────────────
  ConversationPreview(
    id: 'g1',
    name: 'Hiking Weekend',
    avatarAsset: _p2,
    lastMessage: 'Priya: I’ll bring the trail snacks 🥨',
    timestamp: '22m',
    type: ConversationType.group,
    status: ConversationStatus.online,
    lastMessageType: LastMessageType.plan,
    unreadCount: 3,
    isPinned: true,
  ),
  ConversationPreview(
    id: 'g2',
    name: 'Goa Trip',
    avatarAsset: _p5,
    lastMessage: 'Devon added a memory',
    timestamp: '2h',
    type: ConversationType.group,
    lastMessageType: LastMessageType.photo,
  ),
  ConversationPreview(
    id: 'g3',
    name: 'Startup Meetup',
    avatarAsset: _p6,
    lastMessage: 'Goal updated: finalise the demo deck',
    timestamp: 'Wed',
    type: ConversationType.group,
    lastMessageType: LastMessageType.plan,
    isMuted: true,
  ),
  ConversationPreview(
    id: 'g4',
    name: 'Football Night',
    avatarAsset: _p4,
    lastMessage: 'Leo: kickoff at 8, don’t be late!',
    timestamp: 'Sat',
    type: ConversationType.group,
    status: ConversationStatus.online,
  ),

  ConversationPreview(
    id: 'c4',
    name: 'Devon Clarke',
    avatarAsset: _p4,
    lastMessage: 'You’re now connected. Say hello 👋',
    timestamp: '2h',
    status: ConversationStatus.recentlyConnected,
    lastMessageType: LastMessageType.connectionAccepted,
  ),
  ConversationPreview(
    id: 'c5',
    name: 'Priya Nair',
    avatarAsset: _p5,
    lastMessage: 'Sent a voice note',
    timestamp: '3h',
    status: ConversationStatus.online,
    lastMessageType: LastMessageType.voiceNote,
    unreadCount: 1,
  ),
  ConversationPreview(
    id: 'c6',
    name: 'The Sunday Studio',
    avatarAsset: _p6,
    lastMessage: 'Shared a photo',
    timestamp: '5h',
    lastMessageType: LastMessageType.photo,
    isMuted: true,
  ),
  ConversationPreview(
    id: 'c7',
    name: 'Leo Marchetti',
    avatarAsset: _p2,
    lastMessage: 'Thanks for hosting — that was lovely.',
    timestamp: 'Tue',
    isVerified: true,
  ),
  ConversationPreview(
    id: 'c8',
    name: 'Camille Beaumont',
    avatarAsset: _p3,
    lastMessage: 'Let’s pick a time this weekend.',
    timestamp: 'Mon',
    lastMessageType: LastMessageType.plan,
    isMuted: true,
  ),
  ConversationPreview(
    id: 'c9',
    name: 'Ishaan Kapoor',
    avatarAsset: _p1,
    lastMessage: 'You’re now connected. Say hello 👋',
    timestamp: 'Sun',
    status: ConversationStatus.recentlyConnected,
    lastMessageType: LastMessageType.connectionAccepted,
  ),
  ConversationPreview(
    id: 'c10',
    name: 'Sofia Alvarez',
    avatarAsset: _p4,
    lastMessage: 'See you there!',
    timestamp: 'Fri',
    status: ConversationStatus.online,
  ),
];

// ────────────────────────────────────────────────────────────────────────────
// MESSAGE THREADS (keyed by conversationId)
// ────────────────────────────────────────────────────────────────────────────

/// Demo message threads stored in chronological order. The UI reverses them.
final Map<String, List<Message>> demoMessageThreads = {
  'c1': _mayaThread,
  'c2': _arjunThread,
  'c4': _devonThread,
  'g1': _hikingWeekendThread,
  'g2': _goaTripThread,
};

final _now = DateTime.now();

final _mayaThread = <Message>[
  Message(
    id: 'm1_1',
    author: MessageAuthor.system,
    timestamp: _now.subtract(const Duration(hours: 3)),
    type: MessageType.system,
    text: 'You\'re now connected. Say hello 👋',
  ),
  Message(
    id: 'm1_2',
    author: MessageAuthor.them,
    timestamp: _now.subtract(const Duration(minutes: 45)),
    text: 'Hey! I saw your profile — love the camera walk idea.',
    senderName: 'Maya Rao',
    senderAvatar: _p1,
  ),
  Message(
    id: 'm1_3',
    author: MessageAuthor.me,
    timestamp: _now.subtract(const Duration(minutes: 42)),
    text: 'Thanks! Always looking for good spots around the city.',
    deliveryStatus: MessageDeliveryStatus.read,
  ),
  Message(
    id: 'm1_4',
    author: MessageAuthor.them,
    timestamp: _now.subtract(const Duration(minutes: 38)),
    text: 'Same here. Maybe we could do one together sometime?',
    senderName: 'Maya Rao',
    senderAvatar: _p1,
  ),
  Message(
    id: 'm1_5',
    author: MessageAuthor.me,
    timestamp: _now.subtract(const Duration(minutes: 35)),
    text: 'Definitely! I\'m free this weekend.',
    deliveryStatus: MessageDeliveryStatus.read,
  ),
];

final _arjunThread = <Message>[
  Message(
    id: 'm2_1',
    author: MessageAuthor.them,
    timestamp: _now.subtract(const Duration(hours: 5)),
    text: 'Are you still up for that coffee walk tomorrow?',
    senderName: 'Arjun Mehta',
    senderAvatar: _p2,
  ),
  Message(
    id: 'm2_2',
    author: MessageAuthor.me,
    timestamp: _now.subtract(const Duration(hours: 4, minutes: 55)),
    text: 'Absolutely! What time works for you?',
    deliveryStatus: MessageDeliveryStatus.read,
  ),
  Message(
    id: 'm2_3',
    author: MessageAuthor.them,
    timestamp: _now.subtract(const Duration(hours: 4, minutes: 50)),
    text: '9 AM? There\'s a great trail near the park.',
    senderName: 'Arjun Mehta',
    senderAvatar: _p2,
  ),
  Message(
    id: 'm2_4',
    author: MessageAuthor.me,
    timestamp: _now.subtract(const Duration(hours: 4, minutes: 45)),
    text: 'Perfect. Send me the location?',
    deliveryStatus: MessageDeliveryStatus.read,
  ),
  Message(
    id: 'm2_5',
    author: MessageAuthor.them,
    timestamp: _now.subtract(const Duration(minutes: 14)),
    type: MessageType.shared,
    text: '',
    senderName: 'Arjun Mehta',
    senderAvatar: _p2,
    sharedContent: const SharedContentPreview(
      id: 'plan_001',
      title: 'Morning Coffee & Camera Walk',
      subtitle: 'Tomorrow at 9:00 AM • Riverside Park',
      type: SharedContentType.plan,
    ),
  ),
];

final _devonThread = <Message>[
  Message(
    id: 'm4_1',
    author: MessageAuthor.system,
    timestamp: _now.subtract(const Duration(hours: 2)),
    type: MessageType.system,
    text: 'You\'re now connected. Say hello 👋',
  ),
];

final _hikingWeekendThread = <Message>[
  Message(
    id: 'mg1_1',
    author: MessageAuthor.system,
    timestamp: _now.subtract(const Duration(days: 2)),
    type: MessageType.system,
    text: 'Devon created this group',
  ),
  Message(
    id: 'mg1_2',
    author: MessageAuthor.system,
    timestamp: _now.subtract(const Duration(days: 2, minutes: -5)),
    type: MessageType.system,
    text: 'Priya joined',
  ),
  Message(
    id: 'mg1_3',
    author: MessageAuthor.system,
    timestamp: _now.subtract(const Duration(days: 2, minutes: -10)),
    type: MessageType.system,
    text: 'You joined',
  ),
  Message(
    id: 'mg1_4',
    author: MessageAuthor.them,
    timestamp: _now.subtract(const Duration(days: 1, hours: 8)),
    text: 'Looking forward to this! What time should we meet?',
    senderName: 'Priya',
    senderAvatar: _p5,
  ),
  Message(
    id: 'mg1_5',
    author: MessageAuthor.them,
    timestamp: _now.subtract(const Duration(days: 1, hours: 7)),
    text: 'How about 7 AM at the trailhead?',
    senderName: 'Devon',
    senderAvatar: _p4,
  ),
  Message(
    id: 'mg1_6',
    author: MessageAuthor.me,
    timestamp: _now.subtract(const Duration(days: 1, hours: 6)),
    text: 'Sounds good. I\'ll bring water and snacks.',
    deliveryStatus: MessageDeliveryStatus.read,
  ),
  Message(
    id: 'mg1_7',
    author: MessageAuthor.them,
    timestamp: _now.subtract(const Duration(minutes: 22)),
    text: 'I\'ll bring the trail snacks 🥨',
    senderName: 'Priya',
    senderAvatar: _p5,
  ),
];

final _goaTripThread = <Message>[
  Message(
    id: 'mg2_1',
    author: MessageAuthor.system,
    timestamp: _now.subtract(const Duration(days: 7)),
    type: MessageType.system,
    text: 'Leo created this group',
  ),
  Message(
    id: 'mg2_2',
    author: MessageAuthor.them,
    timestamp: _now.subtract(const Duration(days: 6)),
    text: 'Can\'t wait! Beach time 🏖️',
    senderName: 'Sofia',
    senderAvatar: _p4,
  ),
  Message(
    id: 'mg2_3',
    author: MessageAuthor.them,
    timestamp: _now.subtract(const Duration(hours: 2)),
    type: MessageType.shared,
    text: '',
    senderName: 'Devon',
    senderAvatar: _p4,
    sharedContent: const SharedContentPreview(
      id: 'memory_001',
      title: 'Sunset at Anjuna Beach',
      subtitle: 'Added by Devon • 3 photos',
      type: SharedContentType.memory,
    ),
  ),
];

// ────────────────────────────────────────────────────────────────────────────
// GROUP METADATA (keyed by conversationId)
// ────────────────────────────────────────────────────────────────────────────

/// Group metadata loaded separately to keep inbox previews lightweight.
final Map<String, GroupMetadata> demoGroupMetadata = {
  'g1': const GroupMetadata(
    conversationId: 'g1',
    title: 'Hiking Weekend',
    hostId: 'devon_id',
    participants: [
      Participant(
        id: 'devon_id',
        name: 'Devon',
        avatarAsset: _p4,
        isHost: true,
        isOnline: true,
      ),
      Participant(
        id: 'priya_id',
        name: 'Priya',
        avatarAsset: _p5,
        isOnline: true,
      ),
      Participant(
        id: 'me_id',
        name: 'You',
        avatarAsset: _p1,
      ),
    ],
    goal: 'Summit by noon, picnic at the top',
  ),
  'g2': const GroupMetadata(
    conversationId: 'g2',
    title: 'Goa Trip',
    hostId: 'leo_id',
    participants: [
      Participant(
        id: 'leo_id',
        name: 'Leo',
        avatarAsset: _p2,
        isHost: true,
      ),
      Participant(
        id: 'sofia_id',
        name: 'Sofia',
        avatarAsset: _p4,
        isOnline: true,
      ),
      Participant(
        id: 'devon_id',
        name: 'Devon',
        avatarAsset: _p4,
      ),
      Participant(
        id: 'me_id',
        name: 'You',
        avatarAsset: _p1,
      ),
    ],
  ),
  'g3': const GroupMetadata(
    conversationId: 'g3',
    title: 'Startup Meetup',
    hostId: 'ishaan_id',
    participants: [
      Participant(
        id: 'ishaan_id',
        name: 'Ishaan',
        avatarAsset: _p1,
        isHost: true,
      ),
      Participant(
        id: 'camille_id',
        name: 'Camille',
        avatarAsset: _p3,
      ),
      Participant(
        id: 'me_id',
        name: 'You',
        avatarAsset: _p1,
      ),
    ],
    goal: 'Finalise the demo deck',
  ),
  'g4': const GroupMetadata(
    conversationId: 'g4',
    title: 'Football Night',
    hostId: 'leo_id',
    participants: [
      Participant(
        id: 'leo_id',
        name: 'Leo',
        avatarAsset: _p2,
        isHost: true,
        isOnline: true,
      ),
      Participant(
        id: 'arjun_id',
        name: 'Arjun',
        avatarAsset: _p2,
      ),
      Participant(
        id: 'me_id',
        name: 'You',
        avatarAsset: _p1,
      ),
    ],
  ),
};
