import 'package:flutter/material.dart';

import '../home_discovery_animations.dart';
import 'my_plans_data.dart';

/// Reusable premium primitives for the My Plans management experience.
///
/// Everything reuses the established Conexo dark-glass language (glass fills,
/// soft borders, layered shadows, EntranceFade). Motion stays limited to
/// AnimatedSwitcher / AnimatedScale / Fade with easeOutCubic / easeInOutCubic
/// — no bounce, elastic, or overshoot. Local assets and resolved remote URLs.

const _kAccent = Color(0xFF8B5CF6);
const _kSecondary = Color(0xFF587BE2);
const _kSoftText = Color(0xFFB9C3DC);
const _kGlassPanel = Color(0xFF141B31);

// ── Tabs ────────────────────────────────────────────────────────────────

/// The five management sections. Hosting + Joined + Requested use the reusable
/// [ExperienceCard]; Archived + Drafts get their own light-weight rows.
enum MyPlansTab { hosting, joined, requested, archived, drafts }

extension MyPlansTabLabel on MyPlansTab {
  String get label => switch (this) {
        MyPlansTab.hosting => 'Hosting',
        MyPlansTab.joined => 'Joined',
        MyPlansTab.requested => 'Requested',
        MyPlansTab.archived => 'Archived',
        MyPlansTab.drafts => 'Drafts',
      };

  IconData get icon => switch (this) {
        MyPlansTab.hosting => Icons.campaign_rounded,
        MyPlansTab.joined => Icons.event_available_rounded,
        MyPlansTab.requested => Icons.hourglass_top_rounded,
        MyPlansTab.archived => Icons.inventory_2_rounded,
        MyPlansTab.drafts => Icons.drafts_rounded,
      };
}

/// A premium segmented glass tab bar. Fully controlled — selection state is
/// owned by the parent (single source of truth), mirroring [CategoryStrip].
class MyPlansTabBar extends StatelessWidget {
  const MyPlansTabBar({
    required this.selected,
    required this.onSelected,
    super.key,
  });

  final MyPlansTab selected;
  final ValueChanged<MyPlansTab> onSelected;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 46,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        physics: const BouncingScrollPhysics(),
        padding: const EdgeInsets.symmetric(horizontal: 20),
        itemCount: MyPlansTab.values.length,
        separatorBuilder: (_, _) => const SizedBox(width: 10),

        itemBuilder: (context, i) {
          final tab = MyPlansTab.values[i];
          return _TabChip(
            tab: tab,
            selected: tab == selected,
            onTap: () => onSelected(tab),
          );
        },
      ),
    );
  }
}

class _TabChip extends StatefulWidget {
  const _TabChip({
    required this.tab,
    required this.selected,
    required this.onTap,
  });

  final MyPlansTab tab;
  final bool selected;
  final VoidCallback onTap;

  @override
  State<_TabChip> createState() => _TabChipState();
}

class _TabChipState extends State<_TabChip> {
  bool _pressed = false;

  @override
  Widget build(BuildContext context) {
    final selected = widget.selected;
    return GestureDetector(
      onTapDown: (_) => setState(() => _pressed = true),
      onTapUp: (_) => setState(() => _pressed = false),
      onTapCancel: () => setState(() => _pressed = false),
      onTap: widget.onTap,
      child: AnimatedScale(
        scale: _pressed ? 0.95 : 1.0,
        duration: const Duration(milliseconds: 160),
        curve: Curves.easeOutCubic,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 260),
          curve: Curves.easeOutCubic,
          padding: const EdgeInsets.symmetric(horizontal: 16),
          alignment: Alignment.center,
          decoration: BoxDecoration(
            gradient: selected
                ? const LinearGradient(colors: [_kAccent, _kSecondary])
                : null,
            color: selected ? null : Colors.white.withValues(alpha: .06),
            borderRadius: BorderRadius.circular(15),
            border: selected
                ? null
                : Border.all(color: Colors.white.withValues(alpha: .12)),
            boxShadow: selected
                ? [
                    BoxShadow(
                      color: _kAccent.withValues(alpha: .45),
                      blurRadius: 20,
                      offset: const Offset(0, 8),
                    ),
                  ]
                : null,
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                widget.tab.icon,
                size: 16,
                color: selected ? Colors.white : const Color(0xFF9DB2E8),
              ),
              const SizedBox(width: 7),
              Text(
                widget.tab.label,
                style: TextStyle(
                  fontSize: 13.5,
                  fontWeight: FontWeight.w800,
                  color: selected ? Colors.white : const Color(0xFFCBD4EC),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ── Insight card ────────────────────────────────────────────────────────

/// A single premium glass insight tile (value + label + icon).
class InsightCard extends StatelessWidget {
  const InsightCard({
    required this.value,
    required this.label,
    required this.icon,
    required this.accent,
    super.key,
  });

  final String value;
  final String label;
  final IconData icon;
  final Color accent;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 150,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: _kGlassPanel.withValues(alpha: .9),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: Colors.white.withValues(alpha: .1)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: .3),
            blurRadius: 22,
            offset: const Offset(0, 12),
          ),
          BoxShadow(
            color: accent.withValues(alpha: .16),
            blurRadius: 26,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 38,
            height: 38,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: accent.withValues(alpha: .22),
            ),
            alignment: Alignment.center,
            child: Icon(icon, size: 19, color: Colors.white),
          ),
          const SizedBox(height: 14),
          Text(
            value,
            style: const TextStyle(
              fontSize: 24,
              fontWeight: FontWeight.w800,
              letterSpacing: -0.4,
              color: Colors.white,
            ),
          ),
          const SizedBox(height: 2),
          Text(
            label,
            style: const TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w600,
              color: _kSoftText,
            ),
          ),
        ],
      ),
    );
  }
}

// ── Status badge ────────────────────────────────────────────────────────

/// A small glass status pill (Active / Upcoming / Past / Draft).
class StatusBadge extends StatelessWidget {
  const StatusBadge({required this.label, required this.color, super.key});

  final String label;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        color: color.withValues(alpha: .2),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: color.withValues(alpha: .45)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 6,
            height: 6,
            decoration: BoxDecoration(shape: BoxShape.circle, color: color),
          ),
          const SizedBox(width: 6),
          Text(
            label,
            style: const TextStyle(
              fontSize: 10.5,
              fontWeight: FontWeight.w800,
              letterSpacing: .2,
              color: Colors.white,
            ),
          ),
        ],
      ),
    );
  }
}

// ── Action bar ──────────────────────────────────────────────────────────

/// A row of small glass management actions shown under a hosted plan card
/// (Edit / Share / Archive or Delete). UI only — callbacks are wired by the
/// screen so behaviour stays local and testable.
class PlanActionBar extends StatelessWidget {
  const PlanActionBar({
    this.onEdit,
    this.onShare,
    required this.trailingLabel,
    required this.trailingIcon,
    required this.onTrailing,
    super.key,
  });

  final VoidCallback? onEdit;
  final VoidCallback? onShare;
  final String trailingLabel;
  final IconData trailingIcon;
  final VoidCallback onTrailing;

   @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        if (onEdit != null)
          Expanded(
            child: _ActionButton(
              label: 'Edit',
              icon: Icons.edit_rounded,
              onTap: onEdit!,
            ),
          ),
        if (onEdit != null && onShare != null)
          const SizedBox(width: 10),
        if (onShare != null)
          Expanded(
            child: _ActionButton(
              label: 'Share',
              icon: Icons.ios_share_rounded,
              onTap: onShare!,
            ),
          ),
        if (onShare != null)
          const SizedBox(width: 10),
        Expanded(
          child: _ActionButton(
            label: trailingLabel,
            icon: trailingIcon,
            onTap: onTrailing,
            danger: trailingLabel == 'Delete',
          ),
        ),
      ],
    );
  }
}

class _ActionButton extends StatefulWidget {
  const _ActionButton({
    required this.label,
    required this.icon,
    required this.onTap,
    this.danger = false,
  });

  final String label;
  final IconData icon;
  final VoidCallback onTap;
  final bool danger;

  @override
  State<_ActionButton> createState() => _ActionButtonState();
}

class _ActionButtonState extends State<_ActionButton> {
  bool _pressed = false;

  @override
  Widget build(BuildContext context) {
    final color =
        widget.danger ? const Color(0xFFE36D9D) : const Color(0xFFB7A5FF);
    return GestureDetector(
      onTapDown: (_) => setState(() => _pressed = true),
      onTapUp: (_) => setState(() => _pressed = false),
      onTapCancel: () => setState(() => _pressed = false),
      onTap: widget.onTap,
      child: AnimatedScale(
        scale: _pressed ? 0.95 : 1.0,
        duration: const Duration(milliseconds: 150),
        curve: Curves.easeOutCubic,
        child: Container(
          height: 42,
          alignment: Alignment.center,
          decoration: BoxDecoration(
            color: Colors.white.withValues(alpha: .06),
            borderRadius: BorderRadius.circular(13),
            border: Border.all(
              color: widget.danger
                  ? color.withValues(alpha: .35)
                  : Colors.white.withValues(alpha: .12),
            ),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(widget.icon, size: 15, color: color),
              const SizedBox(width: 6),
              Text(
                widget.label,
                style: TextStyle(
                  fontSize: 12.5,
                  fontWeight: FontWeight.w800,
                  color: color,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ── Draft card ──────────────────────────────────────────────────────────

/// A light-weight glass row summarising a saved draft (cover + title +
/// resume / delete). Renders even when the draft is only partially filled.
class DraftCard extends StatelessWidget {
  const DraftCard({
    required this.title,
    required this.coverAsset,
    this.coverPreviewUrl,
    required this.subtitle,
    required this.onResume,
    required this.onDelete,
    super.key,
  });

  final String title;
  final String? coverAsset;
  final String? coverPreviewUrl;
  final String subtitle;
  final VoidCallback onResume;
  final VoidCallback onDelete;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: _kGlassPanel.withValues(alpha: .9),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: Colors.white.withValues(alpha: .1)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: .3),
            blurRadius: 20,
            offset: const Offset(0, 10),
          ),
        ],
      ),
      child: Row(
        children: [
          ClipRRect(
            borderRadius: BorderRadius.circular(14),
            child: SizedBox(
              width: 64,
              height: 64,
              child: _buildCoverImage(),
            ),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    const StatusBadge(label: 'Draft', color: Color(0xFFF09A65)),
                    const Spacer(),
                    GestureDetector(
                      onTap: onDelete,
                      child: Icon(
                        Icons.delete_outline_rounded,
                        size: 19,
                        color: Colors.white.withValues(alpha: .55),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                Text(
                  title,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    fontSize: 15.5,
                    fontWeight: FontWeight.w800,
                    color: Colors.white,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  subtitle,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(fontSize: 12, color: _kSoftText),
                ),
              ],
            ),
          ),
          const SizedBox(width: 10),
          _ResumeButton(onTap: onResume),
        ],
      ),
    );
  }

  Widget _buildCoverImage() {
    final asset = coverAsset;
    if (asset == null || asset.isEmpty) return _coverFallback();

    final previewUrl = coverPreviewUrl;
    if (previewUrl != null && previewUrl.isNotEmpty) {
      return Image.network(
        previewUrl,
        fit: BoxFit.cover,
        loadingBuilder: (context, child, progress) {
          if (progress == null) return child;
          return Container(
            color: _kGlassPanel,
            child: Center(
              child: SizedBox(
                width: 20,
                height: 20,
                child: CircularProgressIndicator(
                  strokeWidth: 2,
                  color: Colors.white.withValues(alpha: .7),
                  value: progress.expectedTotalBytes != null
                      ? progress.cumulativeBytesLoaded /
                          progress.expectedTotalBytes!
                      : null,
                ),
              ),
            ),
          );
        },
        errorBuilder: (_, _, _) => _coverFallback(),
      );
    }

    if (asset.startsWith('http://') || asset.startsWith('https://')) {
      return Image.network(
        asset,
        fit: BoxFit.cover,
        errorBuilder: (_, _, _) => _coverFallback(),
      );
    }

    if (asset.startsWith('assets/')) {
      return Image.asset(
        asset,
        fit: BoxFit.cover,
        errorBuilder: (_, _, _) => _coverFallback(),
      );
    }

    return _coverFallback();
  }

  Widget _coverFallback() => const DecoratedBox(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [_kAccent, _kSecondary],
          ),
        ),
        child: Center(
          child: Icon(Icons.drafts_rounded, size: 22, color: Colors.white),
        ),
      );
}

class _ResumeButton extends StatefulWidget {
  const _ResumeButton({required this.onTap});
  final VoidCallback onTap;

  @override
  State<_ResumeButton> createState() => _ResumeButtonState();
}

class _ResumeButtonState extends State<_ResumeButton> {
  bool _pressed = false;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTapDown: (_) => setState(() => _pressed = true),
      onTapUp: (_) => setState(() => _pressed = false),
      onTapCancel: () => setState(() => _pressed = false),
      onTap: widget.onTap,
      child: AnimatedScale(
        scale: _pressed ? 0.95 : 1.0,
        duration: const Duration(milliseconds: 150),
        curve: Curves.easeOutCubic,
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 11),
          decoration: BoxDecoration(
            gradient: const LinearGradient(colors: [_kAccent, _kSecondary]),
            borderRadius: BorderRadius.circular(13),
            boxShadow: [
              BoxShadow(
                color: _kAccent.withValues(alpha: .45),
                blurRadius: 18,
                offset: const Offset(0, 8),
              ),
            ],
          ),
          child: const Text(
            'Resume',
            style: TextStyle(
              fontSize: 12.5,
              fontWeight: FontWeight.w800,
              color: Colors.white,
            ),
          ),
        ),
      ),
    );
  }
}

// ── Empty states ────────────────────────────────────────────────────────

/// Premium per-tab empty state. Local iconography only.
class MyPlansEmptyState extends StatelessWidget {
  const MyPlansEmptyState({
    required this.icon,
    required this.title,
    required this.message,
    super.key,
  });

  final IconData icon;
  final String title;
  final String message;

  @override
  Widget build(BuildContext context) {
    return EntranceFade(
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 60, horizontal: 24),
        child: Column(
          children: [
            Container(
              width: 84,
              height: 84,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: Colors.white.withValues(alpha: .06),
                border: Border.all(color: Colors.white.withValues(alpha: .12)),
              ),
              child: Icon(icon, size: 36, color: const Color(0xFF9DB2E8)),
            ),
            const SizedBox(height: 20),
            Text(
              title,
              style: const TextStyle(fontSize: 19, fontWeight: FontWeight.w800),
            ),
            const SizedBox(height: 8),
            Text(
              message,
              textAlign: TextAlign.center,
              style: const TextStyle(fontSize: 13.5, color: _kSoftText),
            ),
          ],
        ),
      ),
    );
  }
}

// ── Glass dialogs (edit / share / confirm) ──────────────────────────────

/// A shared premium glass dialog shell used by edit / share / confirm.
class _GlassDialog extends StatelessWidget {
  const _GlassDialog({required this.child});
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Dialog(
      backgroundColor: Colors.transparent,
      insetPadding: const EdgeInsets.symmetric(horizontal: 28),
      child: Container(
        padding: const EdgeInsets.all(22),
        decoration: BoxDecoration(
          color: const Color(0xFF161E36).withValues(alpha: .98),
          borderRadius: BorderRadius.circular(24),
          border: Border.all(color: Colors.white.withValues(alpha: .12)),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: .5),
              blurRadius: 34,
              offset: const Offset(0, 18),
            ),
          ],
        ),
        child: child,
      ),
    );
  }
}

class _DialogGhost extends StatelessWidget {
  const _DialogGhost({required this.label, required this.onTap});
  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        height: 46,
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: Colors.white.withValues(alpha: .06),
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: Colors.white.withValues(alpha: .14)),
        ),
        child: Text(
          label,
          style: const TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.w800,
            color: Colors.white,
          ),
        ),
      ),
    );
  }
}

/// Shows the premium glass "Share Plan" sheet with local share options.
Future<void> showSharePlanDialog(BuildContext context, String title) {
  return showDialog<void>(
    context: context,
    builder: (context) => _GlassDialog(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Row(
            children: [
              Icon(Icons.ios_share_rounded, size: 20, color: Color(0xFFB7A5FF)),
              SizedBox(width: 10),
              Text(
                'Share Plan',
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.w800),
              ),
            ],
          ),
          const SizedBox(height: 16),
          Text(
            'Invite people to "$title".',
            style: const TextStyle(fontSize: 13.5, color: _kSoftText),
          ),
          const SizedBox(height: 16),
          const _ShareOptionRow(),
          const SizedBox(height: 22),
          _DialogGhost(
            label: 'Close',
            onTap: () => Navigator.of(context).pop(),
          ),
        ],
      ),
    ),
  );
}

class _ShareOptionRow extends StatelessWidget {
  const _ShareOptionRow();

  @override
  Widget build(BuildContext context) {
    const options = [
      (Icons.link_rounded, 'Copy link'),
      (Icons.chat_bubble_rounded, 'Message'),
      (Icons.qr_code_rounded, 'QR code'),
    ];
    return Row(
      children: [
        for (final o in options)
          Expanded(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 4),
              child: Column(
                children: [
                  Container(
                    height: 54,
                    decoration: BoxDecoration(
                      color: Colors.white.withValues(alpha: .06),
                      borderRadius: BorderRadius.circular(15),
                      border: Border.all(
                        color: Colors.white.withValues(alpha: .12),
                      ),
                    ),
                    child: Icon(o.$1, color: const Color(0xFFB7A5FF)),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    o.$2,
                    style: const TextStyle(fontSize: 11.5, color: _kSoftText),
                  ),
                ],
              ),
            ),
          ),
      ],
    );
  }
}

/// Shows a premium glass confirmation dialog. Returns `true` when confirmed.
Future<bool> showConfirmDialog(
  BuildContext context, {
  required String title,
  required String message,
  required String confirmLabel,
  bool danger = false,
}) async {
  final result = await showDialog<bool>(
    context: context,
    builder: (context) => _GlassDialog(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w800),
          ),
          const SizedBox(height: 12),
          Text(
            message,
            style: const TextStyle(
              fontSize: 13.5,
              height: 1.5,
              color: _kSoftText,
            ),
          ),
          const SizedBox(height: 22),
          Row(
            children: [
              Expanded(
                child: _DialogGhost(
                  label: 'Cancel',
                  onTap: () => Navigator.of(context).pop(false),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: GestureDetector(
                  onTap: () => Navigator.of(context).pop(true),
                  child: Container(
                    height: 46,
                    alignment: Alignment.center,
                    decoration: BoxDecoration(
                      gradient: danger
                          ? const LinearGradient(
                              colors: [Color(0xFFE36D9D), Color(0xFFC2477A)],
                            )
                          : const LinearGradient(
                              colors: [_kAccent, _kSecondary],
                            ),
                      borderRadius: BorderRadius.circular(14),
                    ),
                    child: Text(
                      confirmLabel,
                      style: const TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w800,
                        color: Colors.white,
                      ),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    ),
  );
  return result ?? false;
}

// ── Filter bar ──────────────────────────────────────────────────────────

/// A horizontal strip of glass filter chips (Today / Upcoming / This Week /
/// Past). Fully controlled — a `null` selection means "All".
class MyPlansFilterBar extends StatelessWidget {
  const MyPlansFilterBar({
    required this.selected,
    required this.onSelected,
    super.key,
  });

  final MyPlansFilter? selected;
  final ValueChanged<MyPlansFilter?> onSelected;

  static const _labels = {
    MyPlansFilter.today: 'Today',
    MyPlansFilter.upcoming: 'Upcoming',
    MyPlansFilter.thisWeek: 'This Week',
    MyPlansFilter.past: 'Past',
  };

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 38,
      child: ListView(
        scrollDirection: Axis.horizontal,
        physics: const BouncingScrollPhysics(),
        padding: const EdgeInsets.symmetric(horizontal: 20),
        children: [
          _FilterChip(
            label: 'All',
            selected: selected == null,
            onTap: () => onSelected(null),
          ),
          for (final f in MyPlansFilter.values) ...[
            const SizedBox(width: 9),
            _FilterChip(
              label: _labels[f]!,
              selected: selected == f,
              onTap: () => onSelected(f),
            ),
          ],
        ],
      ),
    );
  }
}

class _FilterChip extends StatelessWidget {
  const _FilterChip({
    required this.label,
    required this.selected,
    required this.onTap,
  });

  final String label;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 240),
        curve: Curves.easeOutCubic,
        padding: const EdgeInsets.symmetric(horizontal: 15),
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: selected
              ? _kAccent.withValues(alpha: .22)
              : Colors.white.withValues(alpha: .05),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: selected
                ? _kAccent.withValues(alpha: .5)
                : Colors.white.withValues(alpha: .1),
          ),
        ),
        child: Text(
          label,
          style: TextStyle(
            fontSize: 12.5,
            fontWeight: FontWeight.w700,
            color: selected ? Colors.white : const Color(0xFFCBD4EC),
          ),
        ),
      ),
    );
  }
}
