import 'package:flutter/material.dart';

import '../home_discovery_animations.dart';
import 'chat_models.dart';
import 'chat_widgets.dart';

/// Composed UI sections for the Connections inbox (Phase 6.1).
///
/// No business logic — sections receive already-filtered lists and only lay
/// them out. Each conversation exposes an [onOpen] intent; the inbox screen
/// owns navigation.

/// The large, premium chat home header.
///
/// Reused across both tabs — the [title] and [subtitle] change while the
/// premium type + spacing stay identical. Defaults to the Connections copy.
class ConnectionsHeader extends StatelessWidget {
  const ConnectionsHeader({
    super.key,
    this.title = 'Connections',
    this.subtitle = 'Your private conversations, in one calm place.',
  });

  final String title;
  final String subtitle;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(4, 4, 4, 0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: const TextStyle(
              fontSize: 30,
              fontWeight: FontWeight.w800,
              letterSpacing: -0.6,
              color: Colors.white,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            subtitle,
            style: const TextStyle(fontSize: 14, color: Color(0xFFB9C3DC)),
          ),
        ],
      ),
    );
  }
}

/// A small, quiet section label (e.g. "Pinned").
class _SectionLabel extends StatelessWidget {
  const _SectionLabel(this.text);

  final String text;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(4, 0, 4, 8),
      child: Text(
        text.toUpperCase(),
        style: const TextStyle(
          fontSize: 11.5,
          fontWeight: FontWeight.w800,
          letterSpacing: 1.1,
          color: Color(0xFF7E8BAB),
        ),
      ),
    );
  }
}

/// The pinned conversations section — the only conversations that live inside
/// a glass card, so they read as "kept close".
class PinnedConversationsSection extends StatelessWidget {
  const PinnedConversationsSection({
    required this.conversations,
    required this.onOpen,
    super.key,
  });

  final List<ConversationPreview> conversations;
  final ValueChanged<ConversationPreview> onOpen;

  @override
  Widget build(BuildContext context) {
    if (conversations.isEmpty) return const SizedBox.shrink();

    return EntranceFade(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          ClipRRect(
            borderRadius: BorderRadius.circular(22),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: .045),
                borderRadius: BorderRadius.circular(22),
                border: Border.all(color: Colors.white.withValues(alpha: .08)),
              ),
              child: Column(
                children: [
                  for (final c in conversations)
                    RepaintBoundary(
                      key: ValueKey('pinned-${c.id}'),
                      child: ConversationTile(
                        conversation: c,
                        onTap: () => onOpen(c),
                      ),
                    ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// The recent conversations section — a flat, airy list.
class RecentConversationsSection extends StatelessWidget {
  const RecentConversationsSection({
    required this.conversations,
    required this.onOpen,
    this.showLabel = true,
    super.key,
  });

  final List<ConversationPreview> conversations;
  final ValueChanged<ConversationPreview> onOpen;
  final bool showLabel;

  @override
  Widget build(BuildContext context) {
    if (conversations.isEmpty) return const SizedBox.shrink();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (showLabel) const _SectionLabel('Recent'),
        for (final c in conversations)
          RepaintBoundary(
            key: ValueKey('recent-${c.id}'),
            child: ConversationTile(
              conversation: c,
              onTap: () => onOpen(c),
            ),
          ),
      ],
    );
  }
}
