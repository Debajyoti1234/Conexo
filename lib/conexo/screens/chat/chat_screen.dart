import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../data/app_state.dart';
import '../../data/mock_data.dart';
import '../../design/routes.dart';
import '../../design/tokens.dart';
import '../../design/widgets.dart';
import '../matches/matches_screen.dart' show ago;
import '../profile/person_screen.dart';

class ChatScreen extends StatefulWidget {
  const ChatScreen({required this.match, super.key});
  final Match match;

  @override
  State<ChatScreen> createState() => _ChatScreenState();
}

class _ChatScreenState extends State<ChatScreen> {
  final _input = TextEditingController();
  final _scroll = ScrollController();
  int _lastCount = 0;

  @override
  void initState() {
    super.initState();
    _input.addListener(() => setState(() {}));
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) ConexoScope.read(context).markRead(widget.match);
    });
  }

  @override
  void dispose() {
    _input.dispose();
    _scroll.dispose();
    super.dispose();
  }

  void _send([String? text]) {
    final t = text ?? _input.text;
    if (t.trim().isEmpty) return;
    HapticFeedback.lightImpact();
    ConexoScope.read(context).send(widget.match, t);
    _input.clear();
  }

  void _toBottom() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!_scroll.hasClients) return;
      _scroll.animateTo(0, duration: const Duration(milliseconds: 320), curve: Curves.easeOutCubic);
    });
  }

  List<String> _suggestions(Person p) => [
    'Hey ${p.name} 👋',
    if (p.prompts.isNotEmpty) 'Okay, your "${p.prompts.first.question}" answer is elite',
    'Chai this weekend?',
  ];

  Future<void> _menu(String action) async {
    final s = ConexoScope.read(context);
    final p = widget.match.person;
    switch (action) {
      case 'profile':
        Navigator.of(context).push(cxRoute(PersonScreen(person: p)));
      case 'unmatch':
        final ok = await showDialog<bool>(
          context: context,
          builder: (context) {
            final c = context.cx;
            return AlertDialog(
              backgroundColor: c.surface,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(28)),
              title: Text('Unmatch ${p.name}?', style: ConexoType.title(c.ink)),
              content: Text(
                'This removes the chat for both of you. No hard feelings, no take-backs.',
                style: ConexoType.body(c.inkSoft),
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(context, false),
                  child: Text('Keep chatting', style: ConexoType.label(c.inkSoft, size: 14)),
                ),
                TextButton(
                  onPressed: () => Navigator.pop(context, true),
                  child: Text('Unmatch', style: ConexoType.label(c.danger, size: 14)),
                ),
              ],
            );
          },
        );
        if (ok == true && mounted) {
          s.unmatch(widget.match);
          Navigator.of(context).pop();
        }
      case 'report':
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Thanks for flagging. Our safety team will take a look.')),
        );
    }
  }

  @override
  Widget build(BuildContext context) {
    final c = context.cx;
    final s = ConexoScope.of(context);
    final m = widget.match;
    final p = m.person;
    final typing = s.typing.contains(p.id);
    final msgs = m.messages.reversed.toList();

    if (m.messages.length != _lastCount) {
      _lastCount = m.messages.length;
      _toBottom();
    }

    return Scaffold(
      backgroundColor: c.bg,
      body: SafeArea(
        child: Column(
          children: [
            // Header
            Padding(
              padding: const EdgeInsets.fromLTRB(12, 6, 8, 8),
              child: Row(
                children: [
                  CxIconButton(
                    icon: Icons.arrow_back_rounded,
                    tooltip: 'Back',
                    filled: false,
                    onTap: () => Navigator.of(context).pop(),
                  ),
                  const SizedBox(width: 4),
                  Expanded(
                    child: Pressable(
                      scale: .98,
                      onTap: () => _menu('profile'),
                      child: Row(
                        children: [
                          Avatar(photo: p.firstPhoto, size: 44, online: p.activeNow),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(p.name, style: ConexoType.title(c.ink, size: 19)),
                                Text(
                                  typing
                                      ? 'typing…'
                                      : p.activeNow
                                      ? 'Active now'
                                      : 'Matched ${ago(m.matchedAt)} ago',
                                  style: ConexoType.body(
                                    typing || p.activeNow ? c.success : c.inkMute,
                                    size: 12.5,
                                    w: FontWeight.w600,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                  PopupMenuButton<String>(
                    tooltip: 'More',
                    color: c.surface,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
                    icon: Icon(Icons.more_horiz_rounded, color: c.ink),
                    onSelected: _menu,
                    itemBuilder: (_) => [
                      _item('profile', Icons.person_outline_rounded, 'View profile', c.ink),
                      _item('report', Icons.flag_outlined, 'Report', c.ink),
                      _item('unmatch', Icons.heart_broken_outlined, 'Unmatch', c.danger),
                    ],
                  ),
                ],
              ),
            ),
            Divider(height: 1, color: c.line),
            // Messages
            Expanded(
              child: ListView.builder(
                controller: _scroll,
                reverse: true,
                padding: const EdgeInsets.fromLTRB(14, 16, 14, 16),
                itemCount: msgs.length + 2,
                itemBuilder: (context, i) {
                  if (i == 0) {
                    return AnimatedSize(
                      duration: const Duration(milliseconds: 220),
                      child: typing ? const _TypingBubble() : const SizedBox(width: double.infinity),
                    );
                  }
                  if (i == msgs.length + 1) return _MatchIntro(match: m, me: s.profile);
                  final idx = i - 1;
                  final msg = msgs[idx];
                  final older = idx + 1 < msgs.length ? msgs[idx + 1] : null;
                  final newer = idx > 0 ? msgs[idx - 1] : null;
                  final firstInGroup = older == null || older.fromMe != msg.fromMe;
                  final lastInGroup = newer == null || newer.fromMe != msg.fromMe;
                  return _Bubble(
                    msg: msg,
                    first: firstInGroup,
                    last: lastInGroup,
                    onReact: () {
                      HapticFeedback.lightImpact();
                      s.react(msg, '❤️');
                    },
                  );
                },
              ),
            ),
            // Icebreakers
            AnimatedSize(
              duration: const Duration(milliseconds: 260),
              curve: Curves.easeOutCubic,
              child: m.messages.length < 2 && !typing
                  ? SizedBox(
                      height: 52,
                      child: ListView.separated(
                        scrollDirection: Axis.horizontal,
                        padding: const EdgeInsets.fromLTRB(14, 4, 14, 8),
                        itemCount: _suggestions(p).length,
                        separatorBuilder: (_, _) => const SizedBox(width: 8),
                        itemBuilder: (_, i) {
                          final text = _suggestions(p)[i];
                          return VibeChip(label: text, onTap: () => _send(text));
                        },
                      ),
                    )
                  : const SizedBox(width: double.infinity),
            ),
            // Composer
            Container(
              padding: const EdgeInsets.fromLTRB(14, 8, 10, 10),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Expanded(
                    child: Container(
                      decoration: BoxDecoration(
                        color: c.surface,
                        borderRadius: BorderRadius.circular(26),
                        border: Border.all(color: c.line),
                      ),
                      child: TextField(
                        controller: _input,
                        minLines: 1,
                        maxLines: 5,
                        textInputAction: TextInputAction.send,
                        onSubmitted: (_) => _send(),
                        cursorColor: c.violet,
                        style: ConexoType.body(c.ink, size: 15.5),
                        decoration: InputDecoration(
                          hintText: m.messages.isEmpty ? 'Break the ice with ${p.name}…' : 'Say something good…',
                          hintStyle: ConexoType.body(c.inkMute, size: 15.5),
                          border: InputBorder.none,
                          contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  AnimatedScale(
                    scale: _input.text.trim().isEmpty ? .86 : 1,
                    duration: const Duration(milliseconds: 220),
                    curve: Curves.easeOutBack,
                    child: Pressable(
                      onTap: _input.text.trim().isEmpty ? null : _send,
                      scale: .88,
                      child: Container(
                        width: 50,
                        height: 50,
                        decoration: BoxDecoration(gradient: c.warm, shape: BoxShape.circle),
                        child: const Icon(Icons.arrow_upward_rounded, color: Colors.white, size: 24),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  PopupMenuItem<String> _item(String v, IconData icon, String label, Color color) => PopupMenuItem(
    value: v,
    child: Row(
      children: [
        Icon(icon, size: 20, color: color),
        const SizedBox(width: 12),
        Text(label, style: ConexoType.body(color, size: 14.5, w: FontWeight.w600)),
      ],
    ),
  );
}

class _MatchIntro extends StatelessWidget {
  const _MatchIntro({required this.match, required this.me});
  final Match match;
  final Person me;

  @override
  Widget build(BuildContext context) {
    final c = context.cx;
    final d = match.matchedAt;
    const months = ['Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun', 'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'];
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 8, 20, 24),
      child: Column(
        children: [
          SizedBox(
            width: 104,
            height: 64,
            child: Stack(
              children: [
                Avatar(photo: me.firstPhoto, size: 64),
                Positioned(right: 0, child: Avatar(photo: match.person.firstPhoto, size: 64)),
              ],
            ),
          ),
          const SizedBox(height: 14),
          Text(
            'You matched with ${match.person.name}',
            style: ConexoType.title(c.ink, size: 18),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 4),
          Text(
            '${d.day} ${months[d.month - 1]}${match.openingLine == null ? '' : '  ·  ${match.openingLine}'}',
            textAlign: TextAlign.center,
            style: ConexoType.body(c.inkMute, size: 13),
          ),
        ],
      ),
    );
  }
}

class _Bubble extends StatelessWidget {
  const _Bubble({required this.msg, required this.first, required this.last, required this.onReact});
  final Message msg;
  final bool first;
  final bool last;
  final VoidCallback onReact;

  @override
  Widget build(BuildContext context) {
    final c = context.cx;
    final mine = msg.fromMe;
    const r = Radius.circular(22);
    const tight = Radius.circular(6);
    final radius = BorderRadius.only(
      topLeft: !mine && !first ? tight : r,
      bottomLeft: !mine && !last ? tight : r,
      topRight: mine && !first ? tight : r,
      bottomRight: mine && !last ? tight : r,
    );

    return Padding(
      padding: EdgeInsets.only(top: first ? 10 : 2, bottom: msg.reaction != null ? 12 : 0),
      child: Align(
        alignment: mine ? Alignment.centerRight : Alignment.centerLeft,
        child: ConstrainedBox(
          constraints: BoxConstraints(maxWidth: MediaQuery.sizeOf(context).width * .74),
          child: GestureDetector(
            onDoubleTap: onReact,
            child: TweenAnimationBuilder<double>(
              tween: Tween(begin: 0, end: 1),
              duration: const Duration(milliseconds: 320),
              curve: Curves.easeOutCubic,
              builder: (_, v, child) => Opacity(
                opacity: v,
                child: Transform.translate(offset: Offset(0, 10 * (1 - v)), child: child),
              ),
              child: Stack(
                clipBehavior: Clip.none,
                children: [
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 11),
                    decoration: BoxDecoration(
                      gradient: mine ? c.warm : null,
                      color: mine ? null : c.surface,
                      borderRadius: radius,
                      border: mine ? null : Border.all(color: c.line),
                    ),
                    child: Text(
                      msg.text,
                      style: ConexoType.body(mine ? Colors.white : c.ink, size: 15.5),
                    ),
                  ),
                  if (msg.reaction != null)
                    Positioned(
                      bottom: -13,
                      right: mine ? null : -4,
                      left: mine ? -4 : null,
                      child: TweenAnimationBuilder<double>(
                        tween: Tween(begin: 0, end: 1),
                        duration: const Duration(milliseconds: 500),
                        curve: Curves.elasticOut,
                        builder: (_, v, child) => Transform.scale(scale: v, child: child),
                        child: Container(
                          padding: const EdgeInsets.all(4),
                          decoration: BoxDecoration(
                            color: c.surface,
                            shape: BoxShape.circle,
                            border: Border.all(color: c.line),
                          ),
                          child: Text(msg.reaction!, style: const TextStyle(fontSize: 12)),
                        ),
                      ),
                    ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _TypingBubble extends StatefulWidget {
  const _TypingBubble();

  @override
  State<_TypingBubble> createState() => _TypingBubbleState();
}

class _TypingBubbleState extends State<_TypingBubble> with SingleTickerProviderStateMixin {
  late final AnimationController _c = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 1100),
  )..repeat();

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final c = context.cx;
    return Align(
      alignment: Alignment.centerLeft,
      child: Container(
        margin: const EdgeInsets.only(top: 10),
        padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 16),
        decoration: BoxDecoration(
          color: c.surface,
          borderRadius: BorderRadius.circular(22),
          border: Border.all(color: c.line),
        ),
        child: AnimatedBuilder(
          animation: _c,
          builder: (_, _) => Row(
            mainAxisSize: MainAxisSize.min,
            children: List.generate(3, (i) {
              final t = ((_c.value - i * .18) % 1.0);
              final lift = t < .4 ? Curves.easeInOut.transform(t / .4) : t < .8 ? 1 - Curves.easeInOut.transform((t - .4) / .4) : 0.0;
              return Container(
                margin: const EdgeInsets.symmetric(horizontal: 2.5),
                transform: Matrix4.translationValues(0, -4 * lift, 0),
                width: 7,
                height: 7,
                decoration: BoxDecoration(
                  color: Color.lerp(c.inkMute, c.violet, lift),
                  shape: BoxShape.circle,
                ),
              );
            }),
          ),
        ),
      ),
    );
  }
}
