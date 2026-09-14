import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../../features/profile/profile_data.dart' show kMinInterests, kMinProfilePhotos;
import '../../data/app_state.dart';
import '../../data/data_source.dart';
import '../../data/mock_data.dart';
import '../../design/routes.dart';
import '../../design/tokens.dart';
import '../../design/widgets.dart';
import '../../widgets/cx_image.dart';
import '../auth/auth_scaffold.dart' show showCxSnack;
import '../shell.dart';

/// Profile creation in five light steps. When [initial] is given it acts as
/// the profile editor instead and pops on save.
class ProfileSetupScreen extends StatefulWidget {
  const ProfileSetupScreen({required this.firstName, this.initial, super.key});
  final String firstName;
  final Person? initial;

  @override
  State<ProfileSetupScreen> createState() => _ProfileSetupScreenState();
}

class _ProfileSetupScreenState extends State<ProfileSetupScreen> {
  static const _steps = 5;

  bool get _editing => widget.initial != null;
  int _step = 0;

  // Basics
  late final _name = TextEditingController(text: widget.initial?.name ?? widget.firstName);
  late DateTime? _birthday = widget.initial?.birthday;
  late String? _gender = widget.initial?.gender;
  late final _job = TextEditingController(text: widget.initial?.job ?? '');
  late final _city = TextEditingController(text: widget.initial?.city ?? '');

  // Content
  late final List<String> _photos = [...?widget.initial?.photos];
  bool _uploading = false;
  late final List<String> _questions =
      widget.initial?.prompts.map((p) => p.question).toList() ?? [promptLibrary[0], promptLibrary[1]];
  late final List<TextEditingController> _answers = [
    for (final p in widget.initial?.prompts ?? const <Prompt>[]) TextEditingController(text: p.answer),
    if (widget.initial == null || widget.initial!.prompts.isEmpty) ...[
      TextEditingController(),
      TextEditingController(),
    ],
  ];
  late final Set<String> _vibes = {...?widget.initial?.vibes};

  // Finish
  LocationFix? _fix;
  bool _locating = false;
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    while (_questions.length < _answers.length) {
      _questions.add(promptLibrary.firstWhere((q) => !_questions.contains(q)));
    }
    for (final ctrl in [_name, _job, _city, ..._answers]) {
      ctrl.addListener(() => setState(() {}));
    }
  }

  @override
  void dispose() {
    _name.dispose();
    _job.dispose();
    _city.dispose();
    for (final a in _answers) {
      a.dispose();
    }
    super.dispose();
  }

  bool get _live => ConexoScope.read(context).source.isLive;
  int get _minPhotos => _live ? kMinProfilePhotos : 2;
  int get _minVibes => _live ? kMinInterests : 3;

  List<Prompt> get _answered => [
    for (var i = 0; i < _answers.length; i++)
      if (_answers[i].text.trim().length >= 3) Prompt(_questions[i], _answers[i].text.trim()),
  ];

  bool get _valid => switch (_step) {
    0 => _name.text.trim().length >= 2 &&
        _birthday != null &&
        _gender != null &&
        _job.text.trim().isNotEmpty &&
        _city.text.trim().isNotEmpty,
    1 => _photos.length >= _minPhotos && !_uploading,
    2 => _answered.length >= 2,
    3 => _vibes.length >= _minVibes,
    _ => !_saving,
  };

  void _next() {
    if (!_valid) return;
    FocusScope.of(context).unfocus();
    if (_step < _steps - 1) {
      setState(() => _step++);
      return;
    }
    _finish();
  }

  void _back() {
    if (_step == 0) {
      Navigator.of(context).maybePop();
      return;
    }
    setState(() => _step--);
  }

  Future<void> _addPhoto() async {
    if (_uploading) return;
    setState(() => _uploading = true);
    try {
      final path = await ConexoScope.read(context).addPhoto(_photos);
      if (path != null && mounted) setState(() => _photos.add(path));
    } on ConexoFailure catch (e) {
      if (mounted) showCxSnack(context, e.message);
    } catch (_) {
      if (mounted) showCxSnack(context, 'That photo didn\'t upload. Try a different one.');
    } finally {
      if (mounted) setState(() => _uploading = false);
    }
  }

  Future<void> _locate() async {
    setState(() => _locating = true);
    try {
      final fix = await ConexoScope.read(context).detectLocation();
      if (fix != null && mounted) {
        setState(() {
          _fix = fix;
          if (_city.text.trim().isEmpty && fix.areaName != null) _city.text = fix.areaName!;
        });
      }
    } on ConexoFailure catch (e) {
      if (mounted) showCxSnack(context, e.message);
    } catch (_) {
      if (mounted) showCxSnack(context, 'We couldn\'t get your location. Try again in a moment.');
    } finally {
      if (mounted) setState(() => _locating = false);
    }
  }

  Future<void> _finish() async {
    setState(() => _saving = true);
    final input = ProfileInput(
      name: _name.text.trim(),
      birthday: _birthday!,
      gender: _gender!,
      job: _job.text.trim(),
      city: _city.text.trim(),
      photos: [..._photos],
      prompts: _answered,
      vibes: [..._vibes],
      location: _fix,
    );
    try {
      await ConexoScope.read(context).saveProfile(input);
    } on ConexoFailure catch (e) {
      if (mounted) {
        showCxSnack(context, e.message);
        setState(() => _saving = false);
      }
      return;
    } catch (_) {
      if (mounted) {
        showCxSnack(context, 'We couldn\'t save your profile. Check your connection and try again.');
        setState(() => _saving = false);
      }
      return;
    }
    if (!mounted) return;
    HapticFeedback.mediumImpact();
    if (_editing) {
      Navigator.of(context).pop();
      showCxSnack(context, 'Saved. Looking sharp.');
    } else {
      Navigator.of(context).pushAndRemoveUntil(cxRoute(const HomeShell()), (_) => false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final c = context.cx;
    final name = _name.text.trim().isEmpty ? 'you' : _name.text.trim();
    final headings = [
      ('Nice to meet you,', '$name.', 'The basics first. You can change these any time.'),
      ('Show off', 'a little.', 'Add at least $_minPhotos. Candid beats posed, every single time.'),
      ('Give them something', 'to reply to.', 'Answer two prompts. Specific is magnetic; "I love travel" is not.'),
      ('What\'s your', 'vibe?', 'Pick at least $_minVibes. We\'ll use them to find your people.'),
      (_editing ? 'Looking' : 'You\'re', _editing ? 'good.' : 'all set.', 'Here\'s a peek at what people will see first.'),
    ];
    final h = headings[_step];

    return Scaffold(
      backgroundColor: c.bg,
      body: SafeArea(
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 520),
            child: Column(
              children: [
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 8, 20, 0),
                  child: Row(
                    children: [
                      CxIconButton(
                        icon: _step == 0 && _editing ? Icons.close_rounded : Icons.arrow_back_rounded,
                        tooltip: 'Back',
                        filled: false,
                        onTap: _step == 0 && !_editing ? null : _back,
                      ),
                      const SizedBox(width: 8),
                      Expanded(child: StepBar(count: _steps, index: _step)),
                      const SizedBox(width: 14),
                      Text('${_step + 1}/$_steps', style: ConexoType.label(c.inkMute)),
                    ],
                  ),
                ),
                Expanded(
                  child: AnimatedSwitcher(
                    duration: const Duration(milliseconds: 380),
                    switchInCurve: Curves.easeOutCubic,
                    switchOutCurve: Curves.easeInCubic,
                    transitionBuilder: (child, a) => FadeTransition(
                      opacity: a,
                      child: SlideTransition(
                        position: Tween(begin: const Offset(.05, 0), end: Offset.zero).animate(a),
                        child: child,
                      ),
                    ),
                    child: ListView(
                      key: ValueKey(_step),
                      padding: const EdgeInsets.fromLTRB(24, 28, 24, 24),
                      children: [
                        Text(h.$1, style: ConexoType.display(c.ink, size: 38)),
                        GradientText(h.$2, style: ConexoType.display(c.ink, size: 38)),
                        const SizedBox(height: 10),
                        Text(h.$3, style: ConexoType.body(c.inkSoft, size: 15)),
                        const SizedBox(height: 28),
                        switch (_step) {
                          0 => _basics(c),
                          1 => _photoGrid(c),
                          2 => _promptEditor(c),
                          3 => _vibePicker(c),
                          _ => _preview(c),
                        },
                      ],
                    ),
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.fromLTRB(24, 8, 24, 16),
                  child: CxButton(
                    label: _step == _steps - 1 ? (_editing ? 'Save changes' : 'Start meeting people') : 'Continue',
                    icon: _step == _steps - 1 ? Icons.auto_awesome_rounded : null,
                    loading: _saving,
                    onTap: _valid ? _next : null,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  // ── Step 0 ────────────────────────────────────────────────────────────────
  Widget _basics(ConexoColors c) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        CxField(controller: _name, label: 'First name', hint: 'What your friends call you'),
        const SizedBox(height: 22),
        const _FieldLabel('Birthday'),
        Pressable(
          scale: .98,
          onTap: () async {
            final now = DateTime.now();
            final picked = await showDatePicker(
              context: context,
              initialDate: _birthday ?? DateTime(now.year - 24, now.month, now.day),
              firstDate: DateTime(now.year - 80),
              lastDate: DateTime(now.year - 18, now.month, now.day),
              helpText: 'When\'s your birthday?',
            );
            if (picked != null) setState(() => _birthday = picked);
          },
          child: Container(
            height: 56,
            padding: const EdgeInsets.symmetric(horizontal: 18),
            decoration: BoxDecoration(
              color: c.surfaceAlt.withValues(alpha: c.isNight ? 1 : .6),
              borderRadius: BorderRadius.circular(18),
            ),
            child: Row(
              children: [
                Icon(Icons.cake_outlined, size: 20, color: c.inkMute),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    _birthday == null ? 'Pick a date' : '${_birthday!.day} / ${_birthday!.month} / ${_birthday!.year}',
                    style: ConexoType.body(_birthday == null ? c.inkMute : c.ink, size: 16, w: FontWeight.w600),
                  ),
                ),
                if (_birthday != null)
                  Text(
                    '${DateTime.now().difference(_birthday!).inDays ~/ 365} years young',
                    style: ConexoType.label(c.violet, size: 12),
                  ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 22),
        const _FieldLabel('I am'),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            for (final g in genderOptions)
              VibeChip(label: g, selected: _gender == g, onTap: () => setState(() => _gender = g)),
          ],
        ),
        const SizedBox(height: 22),
        CxField(controller: _job, label: 'What do you do?', hint: 'e.g. Designer, student, chef', icon: Icons.work_outline_rounded),
        const SizedBox(height: 18),
        CxField(controller: _city, label: 'Where are you based?', hint: 'e.g. Bandra, Mumbai', icon: Icons.location_on_outlined),
      ],
    );
  }

  // ── Step 1 ────────────────────────────────────────────────────────────────
  Widget _photoGrid(ConexoColors c) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        GridView.builder(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          itemCount: 6,
          gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: 3,
            mainAxisSpacing: 10,
            crossAxisSpacing: 10,
            childAspectRatio: .78,
          ),
          itemBuilder: (context, i) {
            final has = i < _photos.length;
            final isNext = i == _photos.length;
            return AnimatedSwitcher(
              duration: const Duration(milliseconds: 320),
              transitionBuilder: (child, a) => ScaleTransition(
                scale: CurvedAnimation(parent: a, curve: Curves.easeOutBack),
                child: FadeTransition(opacity: a, child: child),
              ),
              child: has
                  ? Stack(
                      key: ValueKey(_photos[i]),
                      fit: StackFit.expand,
                      children: [
                        ClipRRect(borderRadius: BorderRadius.circular(20), child: CxImage(_photos[i])),
                        if (i == 0)
                          Positioned(
                            left: 8,
                            bottom: 8,
                            child: Container(
                              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                              decoration: BoxDecoration(color: c.ink, borderRadius: BorderRadius.circular(10)),
                              child: Text('Main', style: ConexoType.label(c.isNight ? c.bg : Colors.white, size: 10.5)),
                            ),
                          ),
                        Positioned(
                          top: 6,
                          right: 6,
                          child: Pressable(
                            onTap: () => setState(() => _photos.removeAt(i)),
                            child: Container(
                              width: 28,
                              height: 28,
                              decoration: BoxDecoration(color: c.surface, shape: BoxShape.circle, boxShadow: c.softShadow),
                              child: Icon(Icons.close_rounded, size: 16, color: c.ink),
                            ),
                          ),
                        ),
                      ],
                    )
                  : Pressable(
                      key: ValueKey('empty$i'),
                      onTap: isNext && !_uploading ? _addPhoto : null,
                      child: CustomPaint(
                        painter: _DashedRRect(color: isNext ? c.violet : c.line),
                        child: Center(
                          child: isNext && _uploading
                              ? SizedBox(
                                  width: 26,
                                  height: 26,
                                  child: CircularProgressIndicator(strokeWidth: 2.4, color: c.violet),
                                )
                              : Container(
                                  width: 34,
                                  height: 34,
                                  decoration: BoxDecoration(
                                    gradient: isNext ? c.warm : null,
                                    color: isNext ? null : c.surfaceAlt,
                                    shape: BoxShape.circle,
                                  ),
                                  child: Icon(Icons.add_rounded, size: 20, color: isNext ? Colors.white : c.inkMute),
                                ),
                        ),
                      ),
                    ),
            );
          },
        ),
        const SizedBox(height: 16),
        Row(
          children: [
            Icon(Icons.info_outline_rounded, size: 16, color: c.inkMute),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                _live
                    ? 'Clear, recent photos of just you work best. The first one is your main photo.'
                    : 'Demo mode: tapping + adds a sample photo.',
                style: ConexoType.body(c.inkMute, size: 12.5),
              ),
            ),
          ],
        ),
      ],
    );
  }

  // ── Step 2 ────────────────────────────────────────────────────────────────
  Widget _promptEditor(ConexoColors c) {
    Future<void> pickQuestion(int i) async {
      final q = await showModalBottomSheet<String>(
        context: context,
        backgroundColor: c.bg,
        showDragHandle: true,
        shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(32))),
        builder: (context) => ListView(
          shrinkWrap: true,
          padding: const EdgeInsets.fromLTRB(20, 0, 20, 24),
          children: [
            Text('Pick a prompt', style: ConexoType.title(c.ink, size: 22)),
            const SizedBox(height: 12),
            for (final q in promptLibrary.where((q) => !_questions.contains(q) || q == _questions[i]))
              Pressable(
                scale: .98,
                onTap: () => Navigator.pop(context, q),
                child: Container(
                  margin: const EdgeInsets.only(bottom: 8),
                  padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 16),
                  decoration: BoxDecoration(
                    color: q == _questions[i] ? c.surfaceAlt : c.surface,
                    borderRadius: BorderRadius.circular(18),
                    border: Border.all(color: q == _questions[i] ? c.violet : c.line),
                  ),
                  child: Text(q, style: ConexoType.body(c.ink, size: 15, w: FontWeight.w600)),
                ),
              ),
          ],
        ),
      );
      if (q != null) setState(() => _questions[i] = q);
    }

    return Column(
      children: [
        for (var i = 0; i < _answers.length; i++) ...[
          CxCard(
            padding: const EdgeInsets.fromLTRB(18, 14, 18, 8),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Pressable(
                  scale: .98,
                  onTap: () => pickQuestion(i),
                  child: Row(
                    children: [
                      Expanded(child: Text(_questions[i], style: ConexoType.title(c.ink, size: 18))),
                      Icon(Icons.swap_horiz_rounded, size: 20, color: c.violet),
                    ],
                  ),
                ),
                TextField(
                  controller: _answers[i],
                  maxLength: 150,
                  maxLines: 3,
                  minLines: 1,
                  cursorColor: c.violet,
                  style: ConexoType.body(c.ink, size: 16),
                  decoration: InputDecoration(
                    hintText: 'Your answer…',
                    hintStyle: ConexoType.body(c.inkMute, size: 16),
                    border: InputBorder.none,
                    counterStyle: ConexoType.label(c.inkMute, size: 11),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 12),
        ],
        if (_answers.length < 3)
          Pressable(
            onTap: () => setState(() {
              _questions.add(promptLibrary.firstWhere((q) => !_questions.contains(q)));
              _answers.add(TextEditingController()..addListener(() => setState(() {})));
            }),
            child: Container(
              height: 56,
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(18),
                border: Border.all(color: c.line, width: 1.2),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.add_rounded, color: c.violet),
                  const SizedBox(width: 8),
                  Text('Add a third prompt', style: ConexoType.body(c.violet, size: 15, w: FontWeight.w700)),
                ],
              ),
            ),
          ),
      ],
    );
  }

  // ── Step 3 ────────────────────────────────────────────────────────────────
  Widget _vibePicker(ConexoColors c) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Wrap(
          spacing: 8,
          runSpacing: 10,
          children: [
            for (final v in {...vibeLibrary, ..._vibes})
              VibeChip(
                label: v,
                selected: _vibes.contains(v),
                onTap: () => setState(() {
                  if (!_vibes.remove(v) && _vibes.length < 8) _vibes.add(v);
                }),
              ),
          ],
        ),
        const SizedBox(height: 18),
        AnimatedSwitcher(
          duration: const Duration(milliseconds: 200),
          child: Text(
            _vibes.length < _minVibes
                ? '${_minVibes - _vibes.length} more to go'
                : '${_vibes.length} of 8 picked. Nice taste.',
            key: ValueKey(_vibes.length),
            style: ConexoType.label(_vibes.length < _minVibes ? c.inkMute : c.violet, size: 13),
          ),
        ),
      ],
    );
  }

  // ── Step 4 ────────────────────────────────────────────────────────────────
  Widget _preview(ConexoColors c) {
    final answered = _answered;
    return Column(
      children: [
        CxCard(
          padding: const EdgeInsets.all(10),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              AspectRatio(
                aspectRatio: 4 / 4.2,
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(20),
                  child: CxImage(_photos.isEmpty ? '' : _photos.first),
                ),
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(12, 16, 12, 10),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(_name.text.trim(), style: ConexoType.display(c.ink, size: 30)),
                    const SizedBox(height: 2),
                    Text(
                      [_job.text.trim(), _city.text.trim()].where((x) => x.isNotEmpty).join('  ·  '),
                      style: ConexoType.body(c.inkSoft, size: 14),
                    ),
                    if (answered.isNotEmpty) ...[
                      const SizedBox(height: 16),
                      Text(answered.first.question, style: ConexoType.label(c.inkSoft, size: 12.5)),
                      const SizedBox(height: 6),
                      Text(answered.first.answer, style: ConexoType.title(c.ink, size: 20)),
                    ],
                  ],
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 16),
        CxCard(
          padding: const EdgeInsets.fromLTRB(18, 14, 14, 14),
          child: Row(
            children: [
              Icon(Icons.near_me_outlined, color: c.violet),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      _fix == null ? 'Show people nearby' : 'Location on',
                      style: ConexoType.body(c.ink, size: 15, w: FontWeight.w700),
                    ),
                    Text(
                      _fix == null
                          ? 'Conexo uses your location to find people around you.'
                          : (_fix!.areaName ?? 'We\'ll show people near you.'),
                      style: ConexoType.body(c.inkMute, size: 12.5),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 10),
              if (_fix == null)
                SizedBox(
                  width: 96,
                  child: CxButton(
                    label: 'Share',
                    height: 42,
                    variant: CxButtonVariant.ink,
                    loading: _locating,
                    onTap: _locate,
                  ),
                )
              else
                Icon(Icons.check_circle_rounded, color: c.success),
            ],
          ),
        ),
      ],
    );
  }
}

class _FieldLabel extends StatelessWidget {
  const _FieldLabel(this.text);
  final String text;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.only(left: 4, bottom: 10),
    child: Text(text, style: ConexoType.label(context.cx.inkSoft)),
  );
}

class _DashedRRect extends CustomPainter {
  _DashedRRect({required this.color});
  final Color color;

  @override
  void paint(Canvas canvas, Size size) {
    final path = Path()..addRRect(RRect.fromRectAndRadius((Offset.zero & size).deflate(1), const Radius.circular(20)));
    final paint = Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.6;
    for (final metric in path.computeMetrics()) {
      var d = 0.0;
      while (d < metric.length) {
        canvas.drawPath(metric.extractPath(d, d + 7), paint);
        d += 12;
      }
    }
  }

  @override
  bool shouldRepaint(_DashedRRect old) => old.color != color;
}
