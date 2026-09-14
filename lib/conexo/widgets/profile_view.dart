import 'package:flutter/material.dart';

import '../data/mock_data.dart';
import '../design/tokens.dart';
import '../design/widgets.dart';

/// Called when the viewer likes a specific photo or prompt.
typedef LikeCallback = void Function(String what, Widget preview);

/// A Hinge-style vertical profile: photos and prompts interleaved, with the
/// vitals and vibes woven in so every scroll reveals something to talk about.
class ProfileView extends StatelessWidget {
  const ProfileView({
    required this.person,
    this.onLike,
    this.header,
    this.controller,
    this.bottomPadding = 150,
    super.key,
  });

  final Person person;
  final LikeCallback? onLike;
  final Widget? header;
  final ScrollController? controller;
  final double bottomPadding;

  @override
  Widget build(BuildContext context) {
    final p = person;
    final blocks = <Widget>[_NameHeader(p), ?header];
    final n = p.photos.length > p.prompts.length ? p.photos.length : p.prompts.length;
    var vibesAdded = false;
    for (var i = 0; i < n; i++) {
      if (i < p.photos.length) blocks.add(_PhotoBlock(p, i, onLike));
      if (i < p.prompts.length) blocks.add(_PromptBlock(p.prompts[i], onLike));
      if (i == 0) blocks.add(_Vitals(p));
      if (i == 1) {
        blocks.add(_Vibes(p));
        vibesAdded = true;
      }
    }
    if (!vibesAdded) blocks.add(_Vibes(p));

    return ListView.separated(
      controller: controller,
      padding: EdgeInsets.fromLTRB(16, 4, 16, bottomPadding),
      itemCount: blocks.length,
      separatorBuilder: (_, _) => const SizedBox(height: 14),
      itemBuilder: (_, i) => i < 4 ? Reveal(index: i, child: blocks[i]) : blocks[i],
    );
  }
}

class _NameHeader extends StatelessWidget {
  const _NameHeader(this.p);
  final Person p;

  @override
  Widget build(BuildContext context) {
    final c = context.cx;
    return Padding(
      padding: const EdgeInsets.fromLTRB(6, 8, 6, 2),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Row(
                  children: [
                    Flexible(
                      child: Text(
                        p.name,
                        style: ConexoType.display(c.ink, size: 40),
                        overflow: TextOverflow.ellipsis,
                        maxLines: 1,
                      ),
                    ),
                    if (p.verified) ...[
                      const SizedBox(width: 8),
                      Tooltip(
                        message: 'Photo verified',
                        child: Icon(Icons.verified_rounded, color: c.cyan, size: 24),
                      ),
                    ],
                  ],
                ),
              ),
              if (p.activeNow)
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                  decoration: BoxDecoration(
                    color: c.success.withValues(alpha: .12),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Row(
                    children: [
                      Container(
                        width: 7,
                        height: 7,
                        decoration: BoxDecoration(color: c.success, shape: BoxShape.circle),
                      ),
                      const SizedBox(width: 6),
                      Text('Active now', style: ConexoType.label(c.success, size: 11.5)),
                    ],
                  ),
                ),
            ],
          ),
          const SizedBox(height: 4),
          Text(
            [?p.pronouns, '${p.distanceKm} km away'].join('  ·  '),
            style: ConexoType.body(c.inkSoft, size: 14),
          ),
        ],
      ),
    );
  }
}

class _PhotoBlock extends StatelessWidget {
  const _PhotoBlock(this.p, this.i, this.onLike);
  final Person p;
  final int i;
  final LikeCallback? onLike;

  @override
  Widget build(BuildContext context) {
    final photo = p.photos[i];
    return AspectRatio(
      aspectRatio: 4 / 5,
      child: Stack(
        fit: StackFit.expand,
        children: [
          ClipRRect(
            borderRadius: BorderRadius.circular(28),
            child: Image.asset(photo, fit: BoxFit.cover),
          ),
          if (onLike != null)
            Positioned(
              right: 14,
              bottom: 14,
              child: SparkButton(
                onTap: () => onLike!(
                  'photo ${i + 1}',
                  ClipRRect(
                    borderRadius: BorderRadius.circular(20),
                    child: Image.asset(photo, height: 220, width: double.infinity, fit: BoxFit.cover),
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}

class _PromptBlock extends StatelessWidget {
  const _PromptBlock(this.prompt, this.onLike);
  final Prompt prompt;
  final LikeCallback? onLike;

  @override
  Widget build(BuildContext context) {
    final c = context.cx;
    return CxCard(
      padding: const EdgeInsets.fromLTRB(24, 24, 16, 18),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(prompt.question, style: ConexoType.label(c.inkSoft, size: 13)),
          const SizedBox(height: 12),
          Padding(
            padding: const EdgeInsets.only(right: 8),
            child: Text(prompt.answer, style: ConexoType.title(c.ink, size: 26)),
          ),
          if (onLike != null)
            Align(
              alignment: Alignment.centerRight,
              child: SparkButton(
                onTap: () => onLike!(
                  prompt.question,
                  PromptPreview(prompt),
                ),
              ),
            )
          else
            const SizedBox(height: 6),
        ],
      ),
    );
  }
}

class PromptPreview extends StatelessWidget {
  const PromptPreview(this.prompt, {super.key});
  final Prompt prompt;

  @override
  Widget build(BuildContext context) {
    final c = context.cx;
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(color: c.surfaceAlt, borderRadius: BorderRadius.circular(20)),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(prompt.question, style: ConexoType.label(c.inkSoft, size: 12.5)),
          const SizedBox(height: 8),
          Text(prompt.answer, style: ConexoType.title(c.ink, size: 20)),
        ],
      ),
    );
  }
}

class _Vitals extends StatelessWidget {
  const _Vitals(this.p);
  final Person p;

  @override
  Widget build(BuildContext context) {
    final c = context.cx;
    final quick = <(IconData, String)>[
      (Icons.cake_outlined, '${p.age}'),
      if (p.height != null) (Icons.straighten_rounded, p.height!),
      (Icons.location_on_outlined, p.city),
    ];
    final rows = <(IconData, String)>[
      (Icons.work_outline_rounded, p.job),
      if (p.school != null) (Icons.school_outlined, p.school!),
      (Icons.favorite_border_rounded, p.lookingFor),
    ];
    return CxCard(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Column(
        children: [
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
            child: Row(
              children: [
                for (var i = 0; i < quick.length; i++) ...[
                  Icon(quick[i].$1, size: 19, color: c.violet),
                  const SizedBox(width: 8),
                  Text(quick[i].$2, style: ConexoType.body(c.ink, size: 14.5, w: FontWeight.w600)),
                  if (i < quick.length - 1)
                    Container(
                      width: 1,
                      height: 20,
                      margin: const EdgeInsets.symmetric(horizontal: 16),
                      color: c.line,
                    ),
                ],
              ],
            ),
          ),
          for (final r in rows) ...[
            Divider(height: 1, indent: 20, endIndent: 20, color: c.line),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
              child: Row(
                children: [
                  Icon(r.$1, size: 19, color: c.violet),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(r.$2, style: ConexoType.body(c.ink, size: 14.5, w: FontWeight.w600)),
                  ),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }
}

class _Vibes extends StatelessWidget {
  const _Vibes(this.p);
  final Person p;

  @override
  Widget build(BuildContext context) {
    final c = context.cx;
    return CxCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Their vibe', style: ConexoType.label(c.inkSoft, size: 13)),
          const SizedBox(height: 14),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [for (final v in p.vibes) VibeChip(label: v)],
          ),
        ],
      ),
    );
  }
}

/// Bottom sheet for adding an optional comment to a like.
/// Returns null when dismissed, otherwise the (possibly empty) comment.
Future<String?> showLikeSheet(BuildContext context, {required Person person, required Widget preview}) {
  return showModalBottomSheet<String>(
    context: context,
    isScrollControlled: true,
    backgroundColor: Colors.transparent,
    barrierColor: Colors.black.withValues(alpha: .35),
    builder: (context) => _LikeSheet(person: person, preview: preview),
  );
}

class _LikeSheet extends StatefulWidget {
  const _LikeSheet({required this.person, required this.preview});
  final Person person;
  final Widget preview;

  @override
  State<_LikeSheet> createState() => _LikeSheetState();
}

class _LikeSheetState extends State<_LikeSheet> {
  final _comment = TextEditingController();

  @override
  void dispose() {
    _comment.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final c = context.cx;
    return Padding(
      padding: EdgeInsets.only(bottom: MediaQuery.viewInsetsOf(context).bottom),
      child: Container(
        decoration: BoxDecoration(
          color: c.bg,
          borderRadius: const BorderRadius.vertical(top: Radius.circular(32)),
        ),
        padding: const EdgeInsets.fromLTRB(20, 12, 20, 24),
        child: SafeArea(
          top: false,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Center(
                child: Container(
                  width: 40,
                  height: 4,
                  decoration: BoxDecoration(color: c.line, borderRadius: BorderRadius.circular(4)),
                ),
              ),
              const SizedBox(height: 18),
              Text('Send ${widget.person.name} a like', style: ConexoType.title(c.ink, size: 22)),
              const SizedBox(height: 14),
              widget.preview,
              const SizedBox(height: 18),
              CxField(
                controller: _comment,
                label: 'Add a comment',
                hint: 'Say what caught your eye',
                maxLength: 140,
                maxLines: 2,
              ),
              const SizedBox(height: 4),
              Text(
                'Likes with a comment are way more likely to start a chat.',
                style: ConexoType.body(c.inkMute, size: 12.5),
              ),
              const SizedBox(height: 18),
              CxButton(
                label: 'Send like',
                icon: Icons.favorite_rounded,
                onTap: () => Navigator.of(context).pop(_comment.text),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
