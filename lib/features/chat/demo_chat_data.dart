import 'chat_models.dart';

/// Premium demo conversations for the Connections inbox (Phase 6.1).
///
/// Static, local data only — reuses the existing portrait assets so no new
/// files are introduced. Curated to showcase every inbox state: online,
/// recently connected, typing, verified, muted, pinned, unread, and varied
/// timestamps + preview lines.

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
