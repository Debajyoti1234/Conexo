import 'package:flutter/material.dart';

import '../../data/app_state.dart';
import '../../data/mock_data.dart';
import '../../design/routes.dart';
import '../../design/tokens.dart';
import '../../design/widgets.dart';
import '../chat/chat_screen.dart';
import '../shell.dart';

String ago(DateTime t) {
  final d = DateTime.now().difference(t);
  if (d.inMinutes < 1) return 'now';
  if (d.inMinutes < 60) return '${d.inMinutes}m';
  if (d.inHours < 24) return '${d.inHours}h';
  if (d.inDays < 7) return '${d.inDays}d';
  return '${t.day}/${t.month}';
}

class MatchesScreen extends StatelessWidget {
  const MatchesScreen({super.key});

  void _open(BuildContext context, Match m) => Navigator.of(context).push(cxRoute(ChatScreen(match: m)));

  @override
  Widget build(BuildContext context) {
    final c = context.cx;
    final s = ConexoScope.of(context);
    final fresh = s.matches.where((m) => m.last == null).toList();
    final chats = s.matches.where((m) => m.last != null).toList()
      ..sort((a, b) => b.last!.at.compareTo(a.last!.at));
    final unread = s.unreadTotal;
    final emptyHeight = MediaQuery.sizeOf(context).height * .6;

    return SafeArea(
      bottom: false,
      child: RefreshIndicator(
        color: c.violet,
        backgroundColor: c.surface,
        onRefresh: s.refreshMatches,
        child: ListView(
          physics: const AlwaysScrollableScrollPhysics(),
          padding: const EdgeInsets.only(bottom: 130),
          children: [
            ScreenTitle(
              title: 'Matches',
              subtitle: s.matches.isEmpty
                  ? null
                  : unread > 0
                  ? '$unread unread. Don\'t leave them hanging.'
                  : 'Keep the good conversations going.',
            ),
            if (s.matches.isEmpty && s.loadingMatches)
              SizedBox(
                height: emptyHeight,
                child: Center(
                  child: SizedBox(width: 28, height: 28, child: CircularProgressIndicator(strokeWidth: 2.6, color: c.violet)),
                ),
              )
            else if (s.matches.isEmpty && s.matchesError != null)
              SizedBox(
                height: emptyHeight,
                child: EmptyState(
                  icon: Icons.wifi_off_rounded,
                  title: 'Matches didn\'t load',
                  body: s.matchesError!,
                  action: 'Try again',
                  onAction: s.refreshMatches,
                ),
              )
            else if (s.matches.isEmpty)
              SizedBox(
                height: emptyHeight,
                child: EmptyState(
                  icon: Icons.chat_bubble_rounded,
                  title: 'No matches yet',
                  body: 'Likes with a comment land better. Go find a prompt worth replying to.',
                  action: 'Start discovering',
                  onAction: () => HomeShell.of(context)?.go(0),
                ),
              ),
            if (fresh.isNotEmpty) ...[
              _Label('New matches', count: fresh.length),
              SizedBox(
                height: 128,
                child: ListView.separated(
                  scrollDirection: Axis.horizontal,
                  padding: const EdgeInsets.symmetric(horizontal: 20),
                  itemCount: fresh.length,
                  separatorBuilder: (_, _) => const SizedBox(width: 16),
                  itemBuilder: (context, i) {
                    final m = fresh[i];
                    return Reveal(
                      index: i,
                      child: Pressable(
                        onTap: () => _open(context, m),
                        child: SizedBox(
                          width: 80,
                          child: Column(
                            children: [
                              Avatar(photo: m.person.firstPhoto, size: 76, ring: true),
                              const SizedBox(height: 8),
                              Text(
                                m.person.name,
                                overflow: TextOverflow.ellipsis,
                                style: ConexoType.body(c.ink, size: 13.5, w: FontWeight.w700),
                              ),
                              Text('Your move', style: ConexoType.label(c.violet, size: 11)),
                            ],
                          ),
                        ),
                      ),
                    );
                  },
                ),
              ),
            ],
            if (chats.isNotEmpty) ...[
              const SizedBox(height: 8),
              const _Label('Conversations'),
              for (var i = 0; i < chats.length; i++)
                Reveal(
                  index: i + 1,
                  child: _ChatTile(
                    match: chats[i],
                    typing: s.typing.contains(chats[i].person.id),
                    onTap: () => _open(context, chats[i]),
                  ),
                ),
            ],
          ],
        ),
      ),
    );
  }
}

class _Label extends StatelessWidget {
  const _Label(this.text, {this.count});
  final String text;
  final int? count;

  @override
  Widget build(BuildContext context) {
    final c = context.cx;
    return Padding(
      padding: const EdgeInsets.fromLTRB(22, 18, 22, 12),
      child: Row(
        children: [
          Text(text, style: ConexoType.title(c.ink, size: 18)),
          if (count != null) ...[
            const SizedBox(width: 8),
            Text('$count', style: ConexoType.title(c.inkMute, size: 18)),
          ],
        ],
      ),
    );
  }
}

class _ChatTile extends StatelessWidget {
  const _ChatTile({required this.match, required this.typing, required this.onTap});
  final Match match;
  final bool typing;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final c = context.cx;
    final p = match.person;
    final last = match.last!;
    final unread = match.unread > 0;
    return Pressable(
      onTap: onTap,
      scale: .98,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
        child: Row(
          children: [
            Avatar(photo: p.firstPhoto, size: 60, online: p.activeNow),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Expanded(child: Text(p.name, style: ConexoType.title(c.ink, size: 18))),
                      Text(ago(last.at), style: ConexoType.label(unread ? c.violet : c.inkMute, size: 12)),
                    ],
                  ),
                  const SizedBox(height: 4),
                  Row(
                    children: [
                      Expanded(
                        child: AnimatedSwitcher(
                          duration: const Duration(milliseconds: 200),
                          child: Text(
                            typing ? 'typing…' : '${last.fromMe ? 'You: ' : ''}${last.text}',
                            key: ValueKey(typing),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: ConexoType.body(
                              typing ? c.violet : unread ? c.ink : c.inkSoft,
                              size: 14,
                              w: unread || typing ? FontWeight.w700 : FontWeight.w500,
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(width: 10),
                      if (unread)
                        Container(
                          constraints: const BoxConstraints(minWidth: 22),
                          height: 22,
                          padding: const EdgeInsets.symmetric(horizontal: 7),
                          alignment: Alignment.center,
                          decoration: BoxDecoration(gradient: c.warm, borderRadius: BorderRadius.circular(11)),
                          child: Text('${match.unread}', style: ConexoType.label(Colors.white, size: 11)),
                        )
                      else if (!last.fromMe)
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                          decoration: BoxDecoration(color: c.surfaceAlt, borderRadius: BorderRadius.circular(10)),
                          child: Text('Your turn', style: ConexoType.label(c.violet, size: 10.5)),
                        ),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
