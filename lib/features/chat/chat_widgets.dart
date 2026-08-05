import 'package:flutter/material.dart';

import '../home_discovery_animations.dart';
import 'chat_models.dart';

/// Reusable premium primitives for the Connections inbox (Phase 6.1).
///
/// Local assets only. Every widget keeps the luxury dark-glass language and
/// stays const-constructible wherever possible for cheap rebuilds.

// ── Palette (kept local + minimal) ──────────────────────────────────────
const _kAccent = Color(0xFF8B5CF6);
const _kOnline = Color(0xFF47D7A5);
const _kSubtle = Color(0xFF9DB2E8);
const _kMuted = Color(0xFFB9C3DC);

/// A local portrait avatar with a graceful letter fallback and an optional
/// presence ring / dot. Never network.
class ConversationAvatar extends StatelessWidget {
  const ConversationAvatar({
    required this.asset,
    required this.name,
    required this.status,
    super.key,
    this.size = 56,
  });

  final String asset;
  final String name;
  final ConversationStatus status;
  final double size;

  @override
  Widget build(BuildContext context) {
    final isOnline = status == ConversationStatus.online;
    final isNew = status == ConversationStatus.recentlyConnected;

    return SizedBox(
      width: size,
      height: size,
      child: Stack(
        clipBehavior: Clip.none,
        children: [
          Container(
            width: size,
            height: size,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              border: Border.all(
                color: isNew
                    ? _kAccent.withValues(alpha: .8)
                    : Colors.white.withValues(alpha: .14),
                width: isNew ? 2 : 1.2,
              ),
            ),
            child: ClipOval(
              child: Image.asset(
                asset,
                fit: BoxFit.cover,
                errorBuilder: (context, error, stackTrace) => Container(
                  color: _kAccent,
                  alignment: Alignment.center,
                  child: Text(
                    name.isEmpty ? '?' : name.substring(0, 1).toUpperCase(),
                    style: TextStyle(
                      fontSize: size * .36,
                      fontWeight: FontWeight.w800,
                      color: Colors.white,
                    ),
                  ),
                ),
              ),
            ),
          ),
          if (isOnline)
            const Positioned(
              right: -1,
              bottom: -1,
              child: OnlineIndicator(ringColor: Color(0xFF0B1020)),
            ),
        ],
      ),
    );
  }
}

/// A small online presence dot with a dark ring so it reads on any avatar.
class OnlineIndicator extends StatelessWidget {
  const OnlineIndicator({required this.ringColor, super.key, this.size = 15});

  final Color ringColor;
  final double size;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        color: _kOnline,
        shape: BoxShape.circle,
        border: Border.all(color: ringColor, width: 2.4),
      ),
    );
  }
}

/// A pill-shaped unread count badge in the Conexo accent.
class UnreadBadge extends StatelessWidget {
  const UnreadBadge({required this.count, super.key});

  final int count;

  @override
  Widget build(BuildContext context) {
    final label = count > 99 ? '99+' : '$count';
    return Container(
      constraints: const BoxConstraints(minWidth: 22),
      height: 22,
      padding: const EdgeInsets.symmetric(horizontal: 7),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [Color(0xFF8B5CF6), Color(0xFF587BE2)],
        ),
        borderRadius: BorderRadius.circular(11),
        boxShadow: [
          BoxShadow(
            color: _kAccent.withValues(alpha: .45),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      alignment: Alignment.center,
      child: Text(
        label,
        style: const TextStyle(
          fontSize: 11.5,
          fontWeight: FontWeight.w800,
          color: Colors.white,
        ),
      ),
    );
  }
}

/// A subtle animated three-dot typing indicator used in the preview line.
class TypingIndicator extends StatefulWidget {
  const TypingIndicator({super.key, this.color = _kOnline});

  final Color color;

  @override
  State<TypingIndicator> createState() => _TypingIndicatorState();
}

class _TypingIndicatorState extends State<TypingIndicator>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1100),
    )..repeat();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 26,
      height: 10,
      child: AnimatedBuilder(
        animation: _controller,
        builder: (context, _) {
          return Row(
            mainAxisSize: MainAxisSize.min,
            children: List.generate(3, (i) {
              final phase = (_controller.value + i * 0.22) % 1.0;
              final t = (phase < 0.5 ? phase : 1 - phase) * 2; // 0→1→0
              return Padding(
                padding: const EdgeInsets.symmetric(horizontal: 1.6),
                child: Opacity(
                  opacity: 0.35 + t * 0.65,
                  child: Container(
                    width: 6,
                    height: 6,
                    decoration: BoxDecoration(
                      color: widget.color,
                      shape: BoxShape.circle,
                    ),
                  ),
                ),
              );
            }),
          );
        },
      ),
    );
  }
}

/// A small pinned glyph shown in the trailing column.
class PinnedIndicator extends StatelessWidget {
  const PinnedIndicator({super.key});

  @override
  Widget build(BuildContext context) => Transform.rotate(
        angle: 0.6,
        child: const Icon(
          Icons.push_pin_rounded,
          size: 14,
          color: _kSubtle,
        ),
      );
}

/// A compact verified badge that sits beside the name.
class VerifiedBadge extends StatelessWidget {
  const VerifiedBadge({super.key, this.size = 15});

  final double size;

  @override
  Widget build(BuildContext context) => Icon(
        Icons.verified_rounded,
        size: size,
        color: const Color(0xFF56B6FF),
      );
}

/// A premium glass search field with instant local filtering. UI only.
class PremiumSearchBar extends StatelessWidget {
  const PremiumSearchBar({
    required this.controller,
    super.key,
    this.hint = 'Search connections',
    this.onChanged,
    this.onClear,
  });

  final TextEditingController controller;
  final String hint;
  final ValueChanged<String>? onChanged;
  final VoidCallback? onClear;

  @override
  Widget build(BuildContext context) {
    return Container(
      constraints: const BoxConstraints(minHeight: 54),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: .06),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: Colors.white.withValues(alpha: .10)),
      ),
      child: Row(
        children: [
          const Icon(Icons.search_rounded, size: 20, color: _kSubtle),
          const SizedBox(width: 11),
          Expanded(
            child: TextField(
              controller: controller,
              onChanged: onChanged,
              textInputAction: TextInputAction.search,
              style: const TextStyle(
                fontSize: 14.5,
                color: Colors.white,
                fontWeight: FontWeight.w500,
              ),
              cursorColor: const Color(0xFFB7A5FF),
              decoration: const InputDecoration(
                isCollapsed: true,
                border: InputBorder.none,
                hintText: 'Search connections',
                hintStyle: TextStyle(
                  fontSize: 14.5,
                  color: _kSubtle,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ),
          ),
          ValueListenableBuilder<TextEditingValue>(
            valueListenable: controller,
            builder: (context, value, _) {
              if (value.text.isEmpty) return const SizedBox.shrink();
              return GestureDetector(
                onTap: onClear,
                child: const Padding(
                  padding: EdgeInsets.only(left: 6),
                  child: Icon(Icons.close_rounded, size: 18, color: _kSubtle),
                ),
              );
            },
          ),
        ],
      ),
    );
  }
}

/// The premium empty state shown when there are no matching conversations.
///
/// Tab-aware: [emptyIcon], [emptyTitle], and [emptyBody] let each tab supply
/// its own copy (Connections vs Plans). Search always wins over tab copy.
class EmptyInbox extends StatelessWidget {
  const EmptyInbox({
    super.key,
    this.isSearch = false,
    this.emptyIcon = Icons.forum_outlined,
    this.emptyTitle = 'No conversations yet',
    this.emptyBody = 'When you connect with people, your chats appear here.',
  });

  /// When true, the copy reflects an empty *search* rather than a fresh inbox.
  final bool isSearch;

  /// Tab-specific icon / title / body shown when not searching.
  final IconData emptyIcon;
  final String emptyTitle;
  final String emptyBody;

  @override
  Widget build(BuildContext context) {
    return EntranceFade(
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 72, horizontal: 28),
        child: Column(
          children: [
            Container(
              width: 84,
              height: 84,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: Colors.white.withValues(alpha: .05),
                border: Border.all(color: Colors.white.withValues(alpha: .10)),
              ),
              child: Icon(
                isSearch ? Icons.search_off_rounded : emptyIcon,
                size: 34,
                color: _kSubtle,
              ),
            ),
            const SizedBox(height: 20),
            Text(
              isSearch ? 'No matches' : emptyTitle,
              style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w800),
            ),
            const SizedBox(height: 8),
            Text(
              isSearch ? 'Try a different name.' : emptyBody,
              textAlign: TextAlign.center,
              style: const TextStyle(fontSize: 13.5, color: _kMuted),
            ),
          ],
        ),
      ),
    );
  }
}

/// A premium segmented control for the Chat home: **Connections | Plans**.
///
/// Dark-glass pill with a sliding highlight, optional per-segment count
/// badges, and haptic-free instant switching. UI only.
class ChatSegmentedTabs extends StatelessWidget {
  const ChatSegmentedTabs({
    required this.selectedIndex,
    required this.onChanged,
    super.key,
    this.connectionsCount,
    this.plansCount,
  });

  final int selectedIndex;
  final ValueChanged<int> onChanged;
  final int? connectionsCount;
  final int? plansCount;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final segmentWidth = (constraints.maxWidth - 8) / 2;
        return Container(
          height: 48,
          padding: const EdgeInsets.all(4),
          decoration: BoxDecoration(
            color: Colors.white.withValues(alpha: .05),
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: Colors.white.withValues(alpha: .08)),
          ),
          child: Stack(
            children: [
              AnimatedAlign(
                duration: const Duration(milliseconds: 260),
                curve: Curves.easeOutCubic,
                alignment: selectedIndex == 0
                    ? Alignment.centerLeft
                    : Alignment.centerRight,
                child: Container(
                  width: segmentWidth,
                  height: double.infinity,
                  decoration: BoxDecoration(
                    gradient: const LinearGradient(
                      colors: [Color(0xFF8B5CF6), Color(0xFF587BE2)],
                    ),
                    borderRadius: BorderRadius.circular(12),
                    boxShadow: [
                      BoxShadow(
                        color: _kAccent.withValues(alpha: .35),
                        blurRadius: 14,
                        offset: const Offset(0, 4),
                      ),
                    ],
                  ),
                ),
              ),
              Row(
                children: [
                  _Segment(
                    label: 'Connections',
                    count: connectionsCount,
                    selected: selectedIndex == 0,
                    onTap: () => onChanged(0),
                  ),
                  _Segment(
                    label: 'Plans',
                    count: plansCount,
                    selected: selectedIndex == 1,
                    onTap: () => onChanged(1),
                  ),
                ],
              ),
            ],
          ),
        );
      },
    );
  }
}

class _Segment extends StatelessWidget {
  const _Segment({
    required this.label,
    required this.selected,
    required this.onTap,
    this.count,
  });

  final String label;
  final bool selected;
  final VoidCallback onTap;
  final int? count;

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: onTap,
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text(
              label,
              style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w800,
                letterSpacing: -0.1,
                color: selected ? Colors.white : _kSubtle,
              ),
            ),
            if (count != null && count! > 0) ...[
              const SizedBox(width: 7),
              Container(
                constraints: const BoxConstraints(minWidth: 18),
                height: 18,
                padding: const EdgeInsets.symmetric(horizontal: 5),
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  color: selected
                      ? Colors.white.withValues(alpha: .22)
                      : Colors.white.withValues(alpha: .08),
                  borderRadius: BorderRadius.circular(9),
                ),
                child: Text(
                  '$count',
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w800,
                    color: selected ? Colors.white : _kSubtle,
                  ),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

/// A shimmering skeleton placeholder that mirrors the tile layout while the
/// inbox loads. Uses the shared [Shimmer] + skeleton primitives.
class LoadingSkeleton extends StatelessWidget {
  const LoadingSkeleton({super.key, this.rows = 7});

  final int rows;

  @override
  Widget build(BuildContext context) {
    return Shimmer(
      child: Column(
        children: [
          for (var i = 0; i < rows; i++)
            const Padding(
              padding: EdgeInsets.symmetric(vertical: 10),
              child: Row(
                children: [
                  SkeletonCircle(size: 56),
                  SizedBox(width: 14),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        SkeletonLine(width: 140, height: 13),
                        SizedBox(height: 10),
                        SkeletonLine(width: 220, height: 11),
                      ],
                    ),
                  ),
                  SizedBox(width: 14),
                  SkeletonLine(width: 28, height: 11),
                ],
              ),
            ),
        ],
      ),
    );
  }
}

/// A single premium conversation row.
///
/// Reusable + navigation-free: it only exposes an [onTap] intent so the inbox
/// screen owns routing.
class ConversationTile extends StatelessWidget {
  const ConversationTile({
    required this.conversation,
    required this.onTap,
    super.key,
  });

  final ConversationPreview conversation;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final c = conversation;
    final emphasizeName = c.hasUnread;

    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(20),
        splashColor: _kAccent.withValues(alpha: .10),
        highlightColor: Colors.white.withValues(alpha: .03),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 10),
          child: Row(
            children: [
              ConversationAvatar(
                asset: c.avatarAsset,
                name: c.name,
                status: c.status,
              ),
              const SizedBox(width: 14),
              Expanded(child: _NameAndPreview(c: c, emphasize: emphasizeName)),
              const SizedBox(width: 10),
              _Trailing(c: c),
            ],
          ),
        ),
      ),
    );
  }
}

/// The middle column: name row (with verified + muted) and the preview line.
class _NameAndPreview extends StatelessWidget {
  const _NameAndPreview({required this.c, required this.emphasize});

  final ConversationPreview c;
  final bool emphasize;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        Row(
          children: [
            Flexible(
              child: Text(
                c.name,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                  fontSize: 15.5,
                  fontWeight: FontWeight.w800,
                  letterSpacing: -0.2,
                  color: Colors.white,
                ),
              ),
            ),
            if (c.isVerified) ...[
              const SizedBox(width: 5),
              const VerifiedBadge(),
            ],
            if (c.isMuted) ...[
              const SizedBox(width: 5),
              const Icon(
                Icons.notifications_off_rounded,
                size: 13,
                color: _kSubtle,
              ),
            ],
          ],
        ),
        const SizedBox(height: 5),
        _PreviewLine(c: c, emphasize: emphasize),
      ],
    );
  }
}

/// The preview line switches to an animated typing indicator when active,
/// otherwise a glyph + message text.
class _PreviewLine extends StatelessWidget {
  const _PreviewLine({required this.c, required this.emphasize});

  final ConversationPreview c;
  final bool emphasize;

  @override
  Widget build(BuildContext context) {
    if (c.isTyping) {
      return Row(
        children: const [
          TypingIndicator(),
          SizedBox(width: 8),
          Text(
            'typing…',
            style: TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w600,
              color: _kOnline,
            ),
          ),
        ],
      );
    }

    final glyph = _previewGlyph(c.lastMessageType);
    return Row(
      children: [
        if (glyph != null) ...[
          Icon(glyph, size: 13.5, color: _kSubtle),
          const SizedBox(width: 5),
        ],
        Expanded(
          child: Text(
            c.lastMessage,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              fontSize: 13,
              fontWeight: emphasize ? FontWeight.w700 : FontWeight.w500,
              color: emphasize ? const Color(0xFFE7ECF9) : _kMuted,
            ),
          ),
        ),
      ],
    );
  }
}

/// The trailing column: timestamp on top, then unread badge / pinned glyph.
class _Trailing extends StatelessWidget {
  const _Trailing({required this.c});

  final ConversationPreview c;

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      mainAxisAlignment: MainAxisAlignment.center,
      crossAxisAlignment: CrossAxisAlignment.end,
      children: [
        Text(
          c.timestamp,
          style: TextStyle(
            fontSize: 11.5,
            fontWeight: FontWeight.w600,
            color: c.hasUnread ? const Color(0xFFB7A5FF) : _kSubtle,
          ),
        ),
        if (c.hasUnread) ...[
          const SizedBox(height: 6),
          UnreadBadge(count: c.unreadCount),
        ] else if (c.isPinned) ...[
          const SizedBox(height: 6),
          const PinnedIndicator(),
        ],
      ],
    );
  }
}

IconData? _previewGlyph(LastMessageType type) {
  switch (type) {
    case LastMessageType.plan:
      return Icons.event_rounded;
    case LastMessageType.connectionAccepted:
      return Icons.handshake_rounded;
    case LastMessageType.voiceNote:
      return Icons.mic_rounded;
    case LastMessageType.photo:
      return Icons.photo_outlined;
    case LastMessageType.text:
      return null;
  }
}
