import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../core/supabase/auth_service.dart';
import 'home_discovery_animations.dart';
import 'profile/connection_data.dart';
import 'profile/discovery_data.dart';

class ImmersiveProfileView extends StatefulWidget {
  const ImmersiveProfileView({
    required super.key,
    required this.profile,
    required this.counterLabel,
    required this.connection,
    required this.connecting,
    required this.connectionError,
    required this.onConnect,
    required this.onProfileTap,
    required this.onPrevious,
    required this.onNext,
  });

  final DiscoveryProfile profile;
  final String counterLabel;
  final Connection? connection;
  final bool connecting;
  final String? connectionError;
  final VoidCallback onConnect;
  final VoidCallback onProfileTap;
  final VoidCallback onPrevious;
  final VoidCallback onNext;

  @override
  State<ImmersiveProfileView> createState() => _ImmersiveProfileViewState();
}

class _ImmersiveProfileViewState extends State<ImmersiveProfileView> {
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
            profile: widget.profile,
            counterLabel: widget.counterLabel,
            connection: widget.connection,
            connecting: widget.connecting,
            connectionError: widget.connectionError,
            onConnect: widget.onConnect,
            onTap: widget.onProfileTap,
            onPrevious: widget.onPrevious,
            onNext: widget.onNext,
          ),
        ),
        SliverToBoxAdapter(
          child: _DetailsSection(profile: widget.profile),
        ),
        const SliverToBoxAdapter(
          child: SizedBox(height: 120),
        ),
      ],
    );
  }
}

class _HeroSection extends StatelessWidget {
  const _HeroSection({
    required this.profile,
    required this.counterLabel,
    required this.connection,
    required this.connecting,
    required this.connectionError,
    required this.onConnect,
    required this.onTap,
    required this.onPrevious,
    required this.onNext,
  });

  final DiscoveryProfile profile;
  final String counterLabel;
  final Connection? connection;
  final bool connecting;
  final String? connectionError;
  final VoidCallback onConnect;
  final VoidCallback onTap;
  final VoidCallback onPrevious;
  final VoidCallback onNext;

  @override
  Widget build(BuildContext context) {
    final media = MediaQuery.of(context);
    final heroHeight = media.size.height - media.padding.top - 140;
    return SizedBox(
      height: heroHeight.clamp(460.0, 900.0),
      child: ClipRRect(
        borderRadius: const BorderRadius.vertical(bottom: Radius.circular(34)),
        child: Stack(
          fit: StackFit.expand,
          children: [
            GestureDetector(
              onTap: onTap,
              child: _PhotoGallery(
                key: ValueKey<String>('gallery_${profile.name}'),
                profile: profile,
              ),
            ),
            const IgnorePointer(child: _HeroScrim()),
            Positioned(
              top: 18,
              left: 18,
              child: IgnorePointer(child: _BadgeColumn(profile: profile)),
            ),
            Positioned(
              top: 18,
              right: 18,
              child: IgnorePointer(
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
            ),
            Positioned(
              left: 22,
              right: 22,
              bottom: 100,
              child: IgnorePointer(
                child: _IdentityBlock(
                  profile: profile,
                  connection: connection,
                  connecting: connecting,
                  onConnect: onConnect,
                ),
              ),
            ),
            Positioned(
              left: 0,
              right: 0,
              bottom: 14,
              child: DiscoveryControls(
                connection: connection,
                connecting: connecting,
                onPrevious: onPrevious,
                onNext: onNext,
                onConnect: onConnect,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _PhotoGallery extends StatefulWidget {
  const _PhotoGallery({
    required this.profile,
    super.key,
  });

  final DiscoveryProfile profile;

  @override
  State<_PhotoGallery> createState() => _PhotoGalleryState();
}

class _PhotoGalleryState extends State<_PhotoGallery> {
  late final PageController _controller;
  int _photoIndex = 0;

  List<String> get _photos {
    final assets = [for (final p in widget.profile.photos) p.assetPath];
    if (assets.isEmpty) return [];
    if (assets.length > 1) return assets;
    return [assets.first, assets.first, assets.first];
  }

  @override
  void initState() {
    super.initState();
    _controller = PageController();
  }

  @override
  void didUpdateWidget(_PhotoGallery oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.profile.name != widget.profile.name && _photoIndex != 0) {
      _photoIndex = 0;
      if (_controller.hasClients) {
        _controller.jumpToPage(0);
      }
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _goToPhoto(int target) {
    final count = _photos.length;
    if (count <= 1) return;
    final clamped = target.clamp(0, count - 1);
    if (clamped == _photoIndex) return;
    HapticFeedback.lightImpact();
    _controller.animateToPage(
      clamped,
      duration: const Duration(milliseconds: 300),
      curve: Curves.easeOutCubic,
    );
  }

  @override
  Widget build(BuildContext context) {
    final photos = _photos;
    final count = photos.length;

    if (count == 0) {
      return _FallbackPortrait(profile: widget.profile);
    }

    return Stack(
      fit: StackFit.expand,
      children: [
        PageView.builder(
          controller: _controller,
          itemCount: count,
          onPageChanged: (i) => setState(() => _photoIndex = i),
          itemBuilder: (context, i) => _HeroPhoto(
            key: ValueKey('photo_${widget.profile.name}_$i'),
            assetPath: photos[i],
            profile: widget.profile,
          ),
        ),
        if (count > 1)
          Positioned.fill(
            child: Row(
              children: [
                Expanded(
                  flex: 40,
                  child: GestureDetector(
                    behavior: HitTestBehavior.translucent,
                    onTap: () => _goToPhoto(_photoIndex - 1),
                    child: Container(color: Colors.transparent),
                  ),
                ),
                const Spacer(flex: 20),
                Expanded(
                  flex: 40,
                  child: GestureDetector(
                    behavior: HitTestBehavior.translucent,
                    onTap: () => _goToPhoto(_photoIndex + 1),
                    child: Container(color: Colors.transparent),
                  ),
                ),
              ],
            ),
          ),
        if (count > 1)
          Positioned(
            top: 12,
            left: 18,
            right: 18,
            child: _FloatingProgressBars(count: count, activeIndex: _photoIndex),
          ),
      ],
    );
  }
}

class _HeroPhoto extends StatelessWidget {
  const _HeroPhoto({
    required this.assetPath,
    required this.profile,
    super.key,
  });

  final String assetPath;
  final DiscoveryProfile profile;

  @override
  Widget build(BuildContext context) {
    if (assetPath.trim().isEmpty) {
      return _FallbackPortrait(profile: profile);
    }
    return Image.asset(
      assetPath,
      fit: BoxFit.cover,
      gaplessPlayback: true,
      errorBuilder: (context, error, stackTrace) =>
          _FallbackPortrait(profile: profile),
    );
  }
}

class _FloatingProgressBars extends StatelessWidget {
  const _FloatingProgressBars({
    required this.count,
    required this.activeIndex,
  });

  final int count;
  final int activeIndex;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        for (var i = 0; i < count; i++)
          Expanded(
            child: Padding(
              key: ValueKey('progress_bar_$i'),
              padding: EdgeInsets.only(right: i == count - 1 ? 0 : 4),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(2),
                child: Stack(
                  children: [
                    Container(
                      height: 2,
                      decoration: BoxDecoration(
                        color: Colors.black.withValues(alpha: .35),
                        borderRadius: BorderRadius.circular(2),
                      ),
                    ),
                    AnimatedFractionallySizedBox(
                      duration: const Duration(milliseconds: 200),
                      curve: Curves.easeOutCubic,

                      widthFactor: i < activeIndex
                          ? 1.0
                          : (i == activeIndex ? 1.0 : 0.0),
                      child: Container(
                        height: 2,
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(2),
                          color: Colors.white.withValues(alpha: .85),
                          boxShadow: i == activeIndex
                              ? [
                                  BoxShadow(
                                    color:
                                        Colors.white.withValues(alpha: .3),
                                    blurRadius: 4,
                                  ),
                                ]
                              : null,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
      ],
    );
  }
}

class _FallbackPortrait extends StatelessWidget {
  const _FallbackPortrait({required this.profile});

  final DiscoveryProfile profile;

  Color get _baseColor {
    final colors = [
      Color(0xFFE36D9D),
      Color(0xFF22BFE0),
      Color(0xFFF09A65),
      Color(0xFF6C8EF5),
      Color(0xFFB78AF6),
      Color(0xFF47D7A5),
    ];
    return colors[profile.name.hashCode.abs() % colors.length];
  }

  @override
  Widget build(BuildContext context) {
    final base = _baseColor;
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
            profile.name.isEmpty ? '?' : profile.name.characters.first,
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

class _IdentityBlock extends StatelessWidget {
  const _IdentityBlock({
    required this.profile,
    required this.connection,
    required this.connecting,
    required this.onConnect,
  });

  final DiscoveryProfile profile;
  final Connection? connection;
  final bool connecting;
  final VoidCallback onConnect;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          '${profile.name}, ${profile.age}',
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
              profile.formattedDistance,
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
        _ConnectStatus(
          connection: connection,
          connecting: connecting,
          onConnect: onConnect,
        ),
      ],
    );
  }
}

class _ConnectStatus extends StatelessWidget {
  const _ConnectStatus({
    required this.connection,
    required this.connecting,
    required this.onConnect,
  });

  final Connection? connection;
  final bool connecting;
  final VoidCallback onConnect;

  @override
  Widget build(BuildContext context) {
    final status = switch (connection?.status) {
      ConnectionStatus.accepted => ('Connected', const Color(0xFF47D7A5)),
      ConnectionStatus.pending when connection != null =>
        (connection!.requesterId == AuthService.currentUser?.id
            ? 'Pending'
            : 'Incoming request', const Color(0xFF22D3EE)),
      null when connecting => ('Sending request...', const Color(0xFFFFC24D)),
      null => null,
      ConnectionStatus.pending => ('Pending', const Color(0xFF22D3EE)),
      ConnectionStatus.rejected => ('Declined', const Color(0xFFFF8BAE)),
      ConnectionStatus.cancelled => ('Cancelled', const Color(0xFF9DB2E8)),
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
  const _BadgeColumn({required this.profile});

  final DiscoveryProfile profile;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (profile.verified) ...[
          const _PulsingBadge(
            icon: Icons.verified_rounded,
            label: 'Verified',
            color: Color(0xFF22D3EE),
          ),
          const SizedBox(height: 10),
        ],
      ],
    );
  }
}

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

class _DetailsSection extends StatelessWidget {
  const _DetailsSection({required this.profile});

  final DiscoveryProfile profile;

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
            padding: const EdgeInsets.fromLTRB(24, 18, 24, 40),
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
        profile.bio,
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

    addChipSection('Interests', Icons.interests_rounded, profile.interests);
    addTextSection('Bio', Icons.auto_stories_rounded, profile.bio);
    addTextSection('City', Icons.location_city_rounded, profile.location);
    addTextSection(
      'Occupation',
      Icons.work_outline_rounded,
      profile.occupation ?? '',
    );
    addChipSection('Languages', Icons.translate_rounded, profile.languages);

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

class DiscoveryControls extends StatelessWidget {
  const DiscoveryControls({
    required this.onPrevious,
    required this.onNext,
    required this.onConnect,
    required this.connection,
    required this.connecting,
    super.key,
  });

  final VoidCallback onPrevious;
  final VoidCallback onNext;
  final VoidCallback onConnect;
  final Connection? connection;
  final bool connecting;

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
        _ConnectControl(
          connection: connection,
          connecting: connecting,
          onTap: onConnect,
        ),
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

class _ConnectControl extends StatefulWidget {
  const _ConnectControl({
    required this.connection,
    required this.connecting,
    required this.onTap,
  });

  final Connection? connection;
  final bool connecting;
  final VoidCallback onTap;

  @override
  State<_ConnectControl> createState() => _ConnectControlState();
}

class _ConnectControlState extends State<_ConnectControl> {
  bool _pressed = false;

  bool get _busy => widget.connecting;

  void _setPressed(bool value) {
    if (_busy) return;
    setState(() => _pressed = value);
  }

  @override
  Widget build(BuildContext context) {
    final connected = widget.connection?.isAccepted == true;
    final pending = widget.connection?.isPending == true || widget.connecting;
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
      message: switch (widget.connection?.status) {
        ConnectionStatus.accepted => 'Connected',
        ConnectionStatus.pending when widget.connection?.requesterId ==
                AuthService.currentUser?.id =>
          'Pending',
        ConnectionStatus.pending => 'Incoming request',
        ConnectionStatus.rejected => 'Declined',
        ConnectionStatus.cancelled => 'Cancelled',
        null when widget.connecting => 'Sending…',
        null => 'Connect',
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
