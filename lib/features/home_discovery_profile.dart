import 'dart:ui';

import 'package:flutter/material.dart';

import 'home_discovery_animations.dart';
import 'home_discovery_connect.dart';
import 'home_discovery_data.dart';

/// Immersive, full-screen discovery experience for a single person.
///
/// The whole page is one continuous vertical scroll: an immersive hero
/// portrait flows straight into a glass details section. Floating controls
/// are rendered by the parent and stay fixed above this scroll view.
class ImmersiveProfileView extends StatefulWidget {
  const ImmersiveProfileView({
    required super.key,
    required this.person,
    required this.counterLabel,
    required this.connectPhase,
  });

  final DiscoveryPerson person;
  final String counterLabel;
  final ConnectPhase connectPhase;

  @override
  State<ImmersiveProfileView> createState() => _ImmersiveProfileViewState();
}

class _ImmersiveProfileViewState extends State<ImmersiveProfileView> {
  // Each profile owns its scroll controller so the AnimatedSwitcher can mount
  // two views during a transition without attaching one controller twice.
  final ScrollController _scrollController = ScrollController();

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return CustomScrollView(
      controller: _scrollController,
      physics: const BouncingScrollPhysics(
        parent: AlwaysScrollableScrollPhysics(),
      ),
      slivers: [
        SliverToBoxAdapter(
          child: _HeroSection(
            person: widget.person,
            counterLabel: widget.counterLabel,
            connectPhase: widget.connectPhase,
          ),
        ),
        SliverToBoxAdapter(
          child: _DetailsSection(person: widget.person),
        ),
      ],
    );
  }
}


/// Full-bleed hero: portrait photo, layered scrims, badges, and the minimal
/// identity block (name, age, distance). Height tracks the viewport so the
/// image feels immersive without a hard-coded percentage.
class _HeroSection extends StatelessWidget {
  const _HeroSection({
    required this.person,
    required this.counterLabel,
    required this.connectPhase,
  });

  final DiscoveryPerson person;
  final String counterLabel;
  final ConnectPhase connectPhase;

  @override
  Widget build(BuildContext context) {
    final media = MediaQuery.of(context);
    final heroHeight = media.size.height - media.padding.top - 150;
    return SizedBox(
      height: heroHeight.clamp(420.0, 900.0),
      child: ClipRRect(
        borderRadius: const BorderRadius.vertical(bottom: Radius.circular(34)),
        child: Stack(
          fit: StackFit.expand,
          children: [
            _Portrait(person: person),
            // Layered premium depth: a soft accent glow, the darkening scrim
            // for legible overlay text, then a gentle vignette to focus.
            _HeroGlow(accent: person.color),
            const _HeroScrim(),
            const _HeroVignette(),
            Positioned(
              top: 18,
              left: 18,
              child: _BadgeColumn(person: person),
            ),
            Positioned(
              top: 18,
              right: 18,
              child: AnimatedSwitcher(
                duration: const Duration(milliseconds: 340),
                switchInCurve: Curves.easeOutCubic,
                switchOutCurve: Curves.easeInCubic,
                transitionBuilder: (child, animation) => FadeTransition(
                  opacity: animation,
                  child: ScaleTransition(scale: animation, child: child),
                ),
                child: HeroBadge(
                  key: ValueKey<String>(counterLabel),
                  icon: Icons.location_on_rounded,
                  label: counterLabel,
                  color: const Color(0xFFFF4D8D),
                ),
              ),
            ),
            Positioned(
              left: 22,
              right: 22,
              bottom: 26,
              child: _IdentityBlock(
                person: person,
                connectPhase: connectPhase,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// The portrait image with a graceful gradient fallback if the asset is
/// missing. Kept clean during transitions — no glow or flare in front.
class _Portrait extends StatelessWidget {
  const _Portrait({required this.person});

  final DiscoveryPerson person;

  @override
  Widget build(BuildContext context) {
    if (person.portrait.isEmpty) {
      return _FallbackPortrait(person: person);
    }
    return Image.asset(
      person.portrait,
      fit: BoxFit.cover,
      errorBuilder: (context, error, stackTrace) =>
          _FallbackPortrait(person: person),
    );
  }
}

/// A soft, multi-stop gradient avatar used when no portrait asset is
/// available. A radial highlight adds subtle lighting so the placeholder
/// still feels premium rather than flat.
class _FallbackPortrait extends StatelessWidget {
  const _FallbackPortrait({required this.person});

  final DiscoveryPerson person;

  @override
  Widget build(BuildContext context) {
    final base = person.color;
    return Stack(
      fit: StackFit.expand,
      children: [
        DecoratedBox(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [
                Color.lerp(base, Colors.white, 0.38) ?? base,
                base,
                Color.lerp(base, const Color(0xFF0A0F1F), 0.55) ?? base,
              ],
              stops: const [0.0, 0.5, 1.0],
            ),
          ),
        ),
        // Soft top-left lighting for a gentle sense of volume.
        DecoratedBox(
          decoration: BoxDecoration(
            gradient: RadialGradient(
              center: const Alignment(-0.4, -0.55),
              radius: 1.1,
              colors: [
                Colors.white.withValues(alpha: .28),
                Colors.transparent,
              ],
              stops: const [0.0, 0.7],
            ),
          ),
        ),
        Center(
          child: Text(
            person.name.isEmpty ? '?' : person.name.characters.first,
            style: TextStyle(
              fontSize: 128,
              fontWeight: FontWeight.w800,
              color: Colors.white.withValues(alpha: .34),
              letterSpacing: -2,
            ),
          ),
        ),
      ],
    );
  }
}

/// A soft radial accent glow behind the scrim, tinted by the person's color.
/// Adds depth and a premium sense of lighting without heavy effects.
class _HeroGlow extends StatelessWidget {
  const _HeroGlow({required this.accent});

  final Color accent;

  @override
  Widget build(BuildContext context) {
    return IgnorePointer(
      child: DecoratedBox(
        decoration: BoxDecoration(
          gradient: RadialGradient(
            center: const Alignment(0, -0.45),
            radius: 1.15,
            colors: [
              accent.withValues(alpha: .26),
              Colors.transparent,
            ],
            stops: const [0.0, 0.75],
          ),
        ),
      ),
    );
  }
}

/// Layered darkening scrims for readable overlay text and gentle depth.
class _HeroScrim extends StatelessWidget {
  const _HeroScrim();

  @override
  Widget build(BuildContext context) {
    return const DecoratedBox(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [
            Color(0x66000000),
            Color(0x00000000),
            Color(0x33000000),
            Color(0xE60A0F1F),
          ],
          stops: [0.0, 0.32, 0.62, 1.0],
        ),
      ),
    );
  }
}

/// A faint edge vignette that darkens the corners to draw the eye inward.
class _HeroVignette extends StatelessWidget {
  const _HeroVignette();

  @override
  Widget build(BuildContext context) {
    return IgnorePointer(
      child: DecoratedBox(
        decoration: BoxDecoration(
          gradient: RadialGradient(
            center: const Alignment(0, -0.15),
            radius: 1.2,
            colors: [
              Colors.transparent,
              Colors.black.withValues(alpha: .32),
            ],
            stops: const [0.62, 1.0],
          ),
        ),
      ),
    );
  }
}

/// The minimal identity block shown before scrolling: name, age, distance,
/// and the live connect-status line.
class _IdentityBlock extends StatelessWidget {
  const _IdentityBlock({required this.person, required this.connectPhase});

  final DiscoveryPerson person;
  final ConnectPhase connectPhase;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          '${person.name}, ${person.age}',
          style: const TextStyle(
            fontSize: 40,
            fontWeight: FontWeight.w800,
            letterSpacing: -0.8,
            height: 1.0,
            color: Colors.white,
            shadows: [
              Shadow(color: Color(0x99000000), blurRadius: 18),
            ],
          ),
        ),
        const SizedBox(height: 10),
        Row(
          children: [
            const Icon(
              Icons.near_me_rounded,
              size: 17,
              color: Color(0xFFEAEEF9),
            ),
            const SizedBox(width: 6),
            Text(
              person.distance,
              style: const TextStyle(
                color: Color(0xFFEAEEF9),
                fontSize: 15,
                fontWeight: FontWeight.w600,
                letterSpacing: .1,
                shadows: [Shadow(color: Color(0x99000000), blurRadius: 12)],
              ),
            ),
          ],
        ),
        _ConnectStatus(connectPhase: connectPhase),
      ],
    );
  }
}

/// Shows the current stage of the connect flow, if any.
class _ConnectStatus extends StatelessWidget {
  const _ConnectStatus({required this.connectPhase});

  final ConnectPhase connectPhase;

  @override
  Widget build(BuildContext context) {
    final (String, Color)? status = switch (connectPhase) {

      ConnectPhase.none => null,
      ConnectPhase.sending => ('Sending request…', const Color(0xFFFFC24D)),
      ConnectPhase.pending => ('Request sent • Pending', const Color(0xFF22D3EE)),
      ConnectPhase.connected => ('✨ You\u2019re connected', const Color(0xFF47D7A5)),
    };
    return AnimatedSwitcher(
      duration: const Duration(milliseconds: 300),
      child: status == null
          ? const SizedBox(height: 0, width: double.infinity)
          : Padding(
              key: ValueKey<String>(status.$1),
              padding: const EdgeInsets.only(top: 12),
              child: Text(
                status.$1,
                style: TextStyle(
                  color: status.$2,
                  fontWeight: FontWeight.w800,
                  fontSize: 14,
                  shadows: const [
                    Shadow(color: Color(0x99000000), blurRadius: 12),
                  ],
                ),
              ),
            ),
    );
  }
}

class _BadgeColumn extends StatelessWidget {
  const _BadgeColumn({required this.person});

  final DiscoveryPerson person;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (person.verified) ...[
          const _PulsingBadge(
            icon: Icons.verified_rounded,
            label: 'Verified',
            color: Color(0xFF22D3EE),
          ),
          const SizedBox(height: 10),
        ],
        if (person.availability.isNotEmpty)
          _ShimmerBadge(
            icon: Icons.bolt_rounded,
            label: person.availability,
            color: const Color(0xFF47D7A5),
          ),
      ],
    );
  }
}

/// Small glass pill used for hero badges.
class HeroBadge extends StatelessWidget {
  const HeroBadge({
    required this.icon,
    required this.label,
    required this.color,
    super.key,
  });

  final IconData icon;
  final String label;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: Colors.black.withValues(alpha: .42),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.white.withValues(alpha: .16)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 15, color: color),
          const SizedBox(width: 6),
          Text(
            label,
            style: const TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w700,
              color: Colors.white,
            ),
          ),
        ],
      ),
    );
  }
}

/// Verified badge with a soft breathing pulse every few seconds.
class _PulsingBadge extends StatefulWidget {
  const _PulsingBadge({
    required this.icon,
    required this.label,
    required this.color,
  });

  final IconData icon;
  final String label;
  final Color color;

  @override
  State<_PulsingBadge> createState() => _PulsingBadgeState();
}

class _PulsingBadgeState extends State<_PulsingBadge>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;
  late final Animation<double> _scale;
  late final Animation<double> _glow;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 2400),
    )..repeat(reverse: true);
    final curve = CurvedAnimation(parent: _controller, curve: Curves.easeInOut);
    _scale = Tween<double>(begin: 1.0, end: 1.06).animate(curve);
    _glow = Tween<double>(begin: 0.0, end: 0.45).animate(curve);
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _controller,
      builder: (context, child) {
        return Transform.scale(
          scale: _scale.value,
          child: DecoratedBox(
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(16),
              boxShadow: [
                BoxShadow(
                  color: widget.color.withValues(alpha: _glow.value),
                  blurRadius: 18,
                  spreadRadius: 1,
                ),
              ],
            ),
            child: child,
          ),
        );
      },
      child: HeroBadge(
        icon: widget.icon,
        label: widget.label,
        color: widget.color,
      ),
    );
  }
}

/// Available-now badge with a gentle fade shimmer loop.
class _ShimmerBadge extends StatefulWidget {
  const _ShimmerBadge({
    required this.icon,
    required this.label,
    required this.color,
  });

  final IconData icon;
  final String label;
  final Color color;

  @override
  State<_ShimmerBadge> createState() => _ShimmerBadgeState();
}

class _ShimmerBadgeState extends State<_ShimmerBadge>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;
  late final Animation<double> _opacity;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1900),
    )..repeat(reverse: true);
    _opacity = Tween<double>(begin: 0.55, end: 1.0).animate(
      CurvedAnimation(parent: _controller, curve: Curves.easeInOut),
    );
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return FadeTransition(
      opacity: _opacity,
      child: HeroBadge(
        icon: widget.icon,
        label: widget.label,
        color: widget.color,
      ),
    );
  }
}

/// The glass details section that flows below the hero in the same scroll.
class _DetailsSection extends StatelessWidget {
  const _DetailsSection({required this.person});

  final DiscoveryPerson person;

  @override
  Widget build(BuildContext context) {
    return Transform.translate(
      offset: const Offset(0, -26),
      child: ClipRRect(
        borderRadius: const BorderRadius.vertical(top: Radius.circular(30)),
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 22, sigmaY: 22),
          child: Container(
            decoration: BoxDecoration(
              color: const Color(0xFF141C31).withValues(alpha: .82),
              borderRadius:
                  const BorderRadius.vertical(top: Radius.circular(30)),
              border: Border(
                top: BorderSide(color: Colors.white.withValues(alpha: .1)),
              ),
            ),
            padding: const EdgeInsets.fromLTRB(24, 18, 24, 150),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: _buildSections(),
            ),
          ),
        ),
      ),
    );
  }

  List<Widget> _buildSections() {
    final sections = <Widget>[
      Center(
        child: Container(
          width: 44,
          height: 4,
          decoration: BoxDecoration(
            color: Colors.white.withValues(alpha: .22),
            borderRadius: BorderRadius.circular(4),
          ),
        ),
      ),
      const SizedBox(height: 22),
      Text(
        person.introduction,
        style: const TextStyle(
          fontSize: 18,
          height: 1.4,
          fontWeight: FontWeight.w600,
          letterSpacing: .1,
          color: Color(0xFFEAEEF9),
        ),
      ),
    ];

    void addChipSection(String title, IconData icon, List<String> values) {
      if (values.isEmpty) return;
      sections.add(
        _RevealSection(
          child: _ChipSection(title: title, icon: icon, values: values),
        ),
      );
    }

    void addTextSection(String title, IconData icon, String value) {
      if (value.isEmpty) return;
      sections.add(
        _RevealSection(
          child: _TextSection(title: title, icon: icon, value: value),
        ),
      );
    }

    addChipSection('Interests', Icons.interests_rounded, person.tags);
    addTextSection('Bio', Icons.auto_stories_rounded, person.bio);
    addTextSection('City', Icons.location_city_rounded, person.city);
    addTextSection('Occupation', Icons.work_outline_rounded, person.occupation);
    addTextSection(
      'Looking for',
      Icons.favorite_border_rounded,
      person.lookingFor,
    );
    addChipSection('Lifestyle', Icons.spa_outlined, person.lifestyle);
    addChipSection('Languages', Icons.translate_rounded, person.languages);
    addChipSection(
      'Mutual interests',
      Icons.people_alt_outlined,
      person.mutualInterests,
    );
    if (person.instagram.isNotEmpty) {
      sections.add(
        _RevealSection(
          child: _TextSection(
            title: 'Instagram',
            icon: Icons.camera_alt_outlined,
            value: person.instagram,
          ),
        ),
      );
    }

    return sections;
  }
}

class _SectionLabel extends StatelessWidget {
  const _SectionLabel({required this.title, required this.icon});

  final String title;
  final IconData icon;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Icon(icon, size: 19, color: const Color(0xFFB7A5FF)),
        const SizedBox(width: 9),
        Text(
          title,
          style: const TextStyle(
            fontSize: 17,
            fontWeight: FontWeight.w800,
            letterSpacing: .2,
            color: Color(0xFFEAEEF9),
          ),
        ),
      ],
    );
  }
}

class _TextSection extends StatelessWidget {
  const _TextSection({
    required this.title,
    required this.icon,
    required this.value,
  });

  final String title;
  final IconData icon;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _SectionLabel(title: title, icon: icon),
        const SizedBox(height: 10),
        Text(
          value,
          style: const TextStyle(
            color: Color(0xFFC7D0E6),
            height: 1.55,
            fontSize: 14.5,
          ),
        ),
      ],
    );
  }
}

class _ChipSection extends StatelessWidget {
  const _ChipSection({
    required this.title,
    required this.icon,
    required this.values,
  });

  final String title;
  final IconData icon;
  final List<String> values;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _SectionLabel(title: title, icon: icon),
        const SizedBox(height: 12),
        StaggeredChips(
          children: [
            for (final value in values) _DetailChip(label: value),
          ],
        ),
      ],
    );
  }
}

class _DetailChip extends StatelessWidget {
  const _DetailChip({required this.label});

  final String label;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 9),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: .07),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: Colors.white.withValues(alpha: .12)),
      ),
      child: Text(
        label,
        style: const TextStyle(
          fontSize: 12.5,
          fontWeight: FontWeight.w600,
          color: Color(0xFFDDE3F4),
        ),
      ),
    );
  }
}

/// Wraps a section with a gentle fade + slide + scale entrance (no bounce).
class _RevealSection extends StatelessWidget {
  const _RevealSection({required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(top: 26),
      child: EntranceFade(
        offset: const Offset(0, 0.12),
        scaleFrom: 0.97,
        duration: const Duration(milliseconds: 460),
        child: child,
      ),
    );
  }
}

/// Premium floating controls: Previous • Connect • Next.
class DiscoveryControls extends StatelessWidget {
  const DiscoveryControls({
    required this.onPrevious,
    required this.onNext,
    required this.onConnect,
    required this.connectPhase,
    super.key,
  });

  final VoidCallback onPrevious;
  final VoidCallback onNext;
  final VoidCallback onConnect;
  final ConnectPhase connectPhase;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        _CircleControl(
          icon: Icons.arrow_back_rounded,
          onTap: onPrevious,
          tooltip: 'Previous',
        ),
        const SizedBox(width: 34),
        _ConnectControl(connectPhase: connectPhase, onTap: onConnect),
        const SizedBox(width: 34),
        _CircleControl(
          icon: Icons.arrow_forward_rounded,
          onTap: onNext,
          tooltip: 'Next',
        ),
      ],
    );
  }
}

/// Glass Previous / Next button with a soft border, small shadow, and
/// animated press feedback.
class _CircleControl extends StatefulWidget {
  const _CircleControl({
    required this.icon,
    required this.onTap,
    required this.tooltip,
  });

  final IconData icon;
  final VoidCallback onTap;
  final String tooltip;

  @override
  State<_CircleControl> createState() => _CircleControlState();
}

class _CircleControlState extends State<_CircleControl> {
  bool _pressed = false;

  @override
  Widget build(BuildContext context) {
    return Tooltip(
      message: widget.tooltip,
      child: GestureDetector(
        onTapDown: (_) => setState(() => _pressed = true),
        onTapUp: (_) => setState(() => _pressed = false),
        onTapCancel: () => setState(() => _pressed = false),
        child: AnimatedScale(
          scale: _pressed ? 0.92 : 1.0,
          duration: const Duration(milliseconds: 160),
          curve: Curves.easeOutCubic,
          child: Container(
            height: 58,
            width: 58,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [
                  Colors.white.withValues(alpha: .14),
                  Colors.white.withValues(alpha: .05),
                ],
              ),
              border: Border.all(color: Colors.white.withValues(alpha: .18)),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: .32),
                  blurRadius: 18,
                  offset: const Offset(0, 8),
                ),
              ],
            ),
            child: Material(
              color: Colors.transparent,
              shape: const CircleBorder(),
              clipBehavior: Clip.antiAlias,
              child: InkWell(
                onTap: widget.onTap,
                child: Icon(widget.icon, color: Colors.white, size: 24),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// Gradient Connect circle with a strong glow and animated press feedback.
/// Reflects the current [ConnectPhase] with icon + gradient changes.
class _ConnectControl extends StatefulWidget {
  const _ConnectControl({required this.connectPhase, required this.onTap});

  final ConnectPhase connectPhase;
  final VoidCallback onTap;

  @override
  State<_ConnectControl> createState() => _ConnectControlState();
}

class _ConnectControlState extends State<_ConnectControl> {
  bool _pressed = false;

  bool get _busy => widget.connectPhase != ConnectPhase.none;

  void _setPressed(bool value) {
    if (_busy) return;
    setState(() => _pressed = value);
  }

  @override
  Widget build(BuildContext context) {
    final connected = widget.connectPhase == ConnectPhase.connected;
    final pending = widget.connectPhase == ConnectPhase.pending ||
        widget.connectPhase == ConnectPhase.sending;
    final IconData icon = connected
        ? Icons.check_rounded
        : pending
            ? Icons.hourglass_top_rounded
            : Icons.favorite_rounded;
    final gradient = connected
        ? const LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [Color(0xFF34D399), Color(0xFF22D3EE)],
          )
        : const LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [Color(0xFF7C3AED), Color(0xFF2563EB), Color(0xFF22D3EE)],
          );

    return Tooltip(
      message: switch (widget.connectPhase) {
        ConnectPhase.none => 'Connect',
        ConnectPhase.sending => 'Sending…',
        ConnectPhase.pending => 'Pending',
        ConnectPhase.connected => 'Connected',
      },
      child: GestureDetector(
        onTapDown: (_) => _setPressed(true),
        onTapUp: (_) => _setPressed(false),
        onTapCancel: () => _setPressed(false),
        child: AnimatedScale(
          scale: _pressed ? 0.92 : 1.0,
          duration: const Duration(milliseconds: 160),
          curve: Curves.easeOutCubic,
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 320),
            curve: Curves.easeOutCubic,
            height: 82,
            width: 82,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              gradient: gradient,
              boxShadow: [
                BoxShadow(
                  color: (connected
                          ? const Color(0xFF34D399)
                          : const Color(0xFF7C3AED))
                      .withValues(alpha: .55),
                  blurRadius: 34,
                  spreadRadius: 2,
                  offset: const Offset(0, 12),
                ),
                BoxShadow(
                  color: const Color(0xFF22D3EE).withValues(alpha: .35),
                  blurRadius: 22,
                  offset: const Offset(0, 4),
                ),
              ],
            ),
            child: Material(
              color: Colors.transparent,
              shape: const CircleBorder(),
              clipBehavior: Clip.antiAlias,
              child: InkWell(
                onTap: _busy ? null : widget.onTap,
                child: Icon(icon, color: Colors.white, size: 32),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
