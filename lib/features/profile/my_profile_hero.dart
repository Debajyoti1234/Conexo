import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

import 'profile_data.dart';
import 'profile_strength_data.dart';
import 'profile_strength_widgets.dart' show StrengthBadge;
import 'supabase_profile_repository.dart';

/// A premium, Tinder/Bumble-style hero photo carousel for the *own* profile
/// (My Profile). One large photo is shown at a time with:
///
///  • Swipe left/right between photos (via [PageView]).
///  • Tap left/right thirds to step between photos.
///  • Animated segmented progress bars pinned to the top.
///  • Smooth fade/slide transitions on the identity block.
///
/// This is presentation only — it never mutates the profile. Photo management
/// remains inside Edit Profile. When there are no photos, a graceful gradient
/// placeholder is shown so the hero still reads as premium.
class MyProfileHero extends StatefulWidget {
  const MyProfileHero({
    required this.profile,
    required this.strength,
    required this.displayName,
    this.age,
    this.onTapPhoto,
    super.key,
  });

  final UserProfile profile;
  final ProfileStrengthResult strength;
  final String displayName;
  final int? age;

  /// Optional fullscreen hook (placeholder). When null, tapping the center
  /// simply does nothing beyond the left/right navigation zones.
  final VoidCallback? onTapPhoto;

  @override
  State<MyProfileHero> createState() => _MyProfileHeroState();
}

class _MyProfileHeroState extends State<MyProfileHero> {
  late final PageController _controller;
  int _index = 0;

  static const _accent = Color(0xFF8B5CF6);
  static const _accent2 = Color(0xFF587BE2);
  static const _softText = Color(0xFFB9C3DC);

  List<ProfilePhoto> get _photos => widget.profile.photos;

  @override
  void initState() {
    super.initState();
    _controller = PageController();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _goTo(int target) {
    final count = _photos.length;
    if (count <= 1) return;
    final clamped = target.clamp(0, count - 1);
    if (clamped == _index) return;
    _controller.animateToPage(
      clamped,
      duration: const Duration(milliseconds: 420),
      curve: Curves.easeOutCubic,
    );
  }

  @override
  Widget build(BuildContext context) {
    final count = _photos.length;
    final verified =
        widget.profile.verificationStatus == VerificationStatus.verified;
    final titleLine = widget.age != null
        ? '${widget.displayName}, ${widget.age}'
        : widget.displayName;

    // Taller, more cinematic proportions that scale with the viewport while
    // staying within comfortable bounds on both phones and tablets.
    final screenHeight = MediaQuery.of(context).size.height;
    final heroHeight = (screenHeight * 0.68).clamp(460.0, 620.0);

    return RepaintBoundary(
      child: SizedBox(
        height: heroHeight,
        child: Stack(
          fit: StackFit.expand,
          children: [
            // ── Photo pager (or placeholder) ──────────────────────────────
            if (count == 0)
              const _HeroPlaceholder()
            else
              PageView.builder(
                controller: _controller,
                itemCount: count,
                onPageChanged: (i) => setState(() => _index = i),
                itemBuilder: (context, i) => _HeroPhoto(
                  key: ValueKey('hero_photo_${_photos[i].id}_$i'),
                  controller: _controller,
                  page: i,
                  assetPath: _photos[i].assetPath,
                  remoteUrl: _photos[i].remoteUrl,
                ),
              ),

            // ── Tap zones (left / center / right) ─────────────────────────
            if (count > 1)
              Positioned.fill(
                child: Row(
                  children: [
                    Expanded(
                      child: GestureDetector(
                        behavior: HitTestBehavior.translucent,
                        onTap: () => _goTo(_index - 1),
                      ),
                    ),
                    Expanded(
                      child: GestureDetector(
                        behavior: HitTestBehavior.translucent,
                        onTap: widget.onTapPhoto,
                      ),
                    ),
                    Expanded(
                      child: GestureDetector(
                        behavior: HitTestBehavior.translucent,
                        onTap: () => _goTo(_index + 1),
                      ),
                    ),
                  ],
                ),
              )
            else if (widget.onTapPhoto != null)
              Positioned.fill(
                child: GestureDetector(
                  behavior: HitTestBehavior.translucent,
                  onTap: widget.onTapPhoto,
                ),
              ),

            // ── Legibility scrim ──────────────────────────────────────────
            // A richer three-part gradient: a soft top wash keeps the progress
            // bars readable, a clear middle preserves the photo, and a deep,
            // gradually-ramped base anchors the identity block.
            const IgnorePointer(
              child: DecoratedBox(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    colors: [
                      Color(0x40000000),
                      Color(0x00000000),
                      Color(0x33000814),
                      Color(0xF205070E),
                    ],
                    stops: [0.0, 0.42, 0.72, 1.0],
                  ),
                ),
              ),
            ),

            // ── Vignette edge treatment ───────────────────────────────────
            // A soft radial darkening at the corners focuses the eye on the
            // subject and gives the hero a richer, editorial depth.
            const IgnorePointer(
              child: DecoratedBox(
                decoration: BoxDecoration(
                  gradient: RadialGradient(
                    center: Alignment.center,
                    radius: 1.15,
                    colors: [
                      Color(0x00000000),
                      Color(0x00000000),
                      Color(0x4D000000),
                    ],
                    stops: [0.0, 0.62, 1.0],
                  ),
                ),
              ),
            ),

            // ── Segmented progress bars ───────────────────────────────────
            if (count > 1)
              Positioned(
                top: MediaQuery.of(context).padding.top + 14,
                left: 18,
                right: 18,
                child: _ProgressBars(count: count, activeIndex: _index),
              ),

            // ── Identity block ────────────────────────────────────────────
            Positioned(
              left: 22,
              right: 22,
              bottom: 28,
              child: AnimatedSwitcher(
                duration: const Duration(milliseconds: 420),
                switchInCurve: Curves.easeOutCubic,
                switchOutCurve: Curves.easeInCubic,
                layoutBuilder: (currentChild, previousChildren) => Stack(
                  alignment: Alignment.bottomLeft,
                  children: [
                    ...previousChildren,
                    ?currentChild,
                  ],
                ),
                transitionBuilder: (child, animation) {
                  final curved = CurvedAnimation(
                    parent: animation,
                    curve: Curves.easeOutCubic,
                  );
                  return FadeTransition(
                    opacity: curved,
                    child: SlideTransition(
                      position: Tween<Offset>(
                        begin: const Offset(0, 0.10),
                        end: Offset.zero,
                      ).animate(curved),
                      child: Transform.scale(
                        alignment: Alignment.bottomLeft,
                        scale: Tween<double>(begin: 0.98, end: 1.0)
                            .animate(curved)
                            .value,
                        child: child,
                      ),
                    ),
                  );
                },
                child: Column(
                  key: ValueKey('identity_$_index'),
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      crossAxisAlignment: WrapCrossAlignment.center,
                      children: [
                        StrengthBadge(tier: widget.strength.tier, compact: true),
                        _CompletionPill(
                          percent: widget.strength.completionPercent,
                        ),
                        if (verified) const _VerifiedPill(),
                      ],
                    ),
                    const SizedBox(height: 16),
                    Text(
                      titleLine,
                      style: const TextStyle(
                        fontSize: 34,
                        height: 1.05,
                        fontWeight: FontWeight.w800,
                        letterSpacing: -0.8,
                        color: Colors.white,
                        shadows: [
                          Shadow(
                            color: Color(0x99000000),
                            blurRadius: 18,
                            offset: Offset(0, 3),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 12),
                    _MetaRow(
                      location: widget.profile.location,
                      occupation: widget.profile.occupation,
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// A single hero photo with a subtle parallax + scale as it scrolls past,
/// giving photo transitions a smoother, more premium feel than a flat slide.
class _HeroPhoto extends StatefulWidget {
  const _HeroPhoto({
    required this.controller,
    required this.page,
    required this.assetPath,
    this.remoteUrl,
    super.key,
  });

  final PageController controller;
  final int page;
  final String assetPath;
  final String? remoteUrl;

  @override
  State<_HeroPhoto> createState() => _HeroPhotoState();
}

class _HeroPhotoState extends State<_HeroPhoto> {
  String? _signedUrl;
  bool _loadingSignedUrl = true;

  @override
  void initState() {
    super.initState();
    if (widget.remoteUrl != null && widget.remoteUrl!.startsWith('profiles/')) {
      _fetchSignedUrl();
    } else {
      _loadingSignedUrl = false;
    }
  }

  Future<void> _fetchSignedUrl() async {
    final url = await const SupabaseProfileRepository()
        .getSignedPhotoUrl(widget.remoteUrl!);
    if (!mounted) return;
    setState(() {
      _signedUrl = url;
      _loadingSignedUrl = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    Widget child;
    if (_signedUrl != null) {
      child = Image.network(
        _signedUrl!,
        fit: BoxFit.cover,
        gaplessPlayback: true,
        frameBuilder: (context, image, frame, wasSyncLoaded) {
          if (wasSyncLoaded) return image;
          return Stack(
            fit: StackFit.expand,
            children: [
              const _HeroPlaceholder(),
              AnimatedOpacity(
                opacity: frame == null ? 0 : 1,
                duration: const Duration(milliseconds: 520),
                curve: Curves.easeOut,
                child: image,
              ),
            ],
          );
        },
        errorBuilder: (context, error, stackTrace) =>
            const _HeroPlaceholder(),
      );
    } else if (_loadingSignedUrl) {
      child = const _HeroPlaceholder();
    } else if (widget.remoteUrl != null && widget.remoteUrl!.startsWith('profiles/')) {
      child = const _HeroPlaceholder();
    } else if (widget.assetPath.trim().isEmpty) {
      child = const _HeroPlaceholder();
    } else if (widget.assetPath.startsWith('assets/')) {
      child = Image.asset(
        widget.assetPath,
        fit: BoxFit.cover,
        gaplessPlayback: true,
        frameBuilder: (context, image, frame, wasSyncLoaded) {
          if (wasSyncLoaded) return image;
          return Stack(
            fit: StackFit.expand,
            children: [
              const _HeroPlaceholder(),
              AnimatedOpacity(
                opacity: frame == null ? 0 : 1,
                duration: const Duration(milliseconds: 520),
                curve: Curves.easeOut,
                child: image,
              ),
            ],
          );
        },
        errorBuilder: (context, error, stackTrace) =>
            const _HeroPlaceholder(),
      );
    } else if (kIsWeb && widget.assetPath.startsWith('blob:')) {
      child = Image.network(
        widget.assetPath,
        fit: BoxFit.cover,
        gaplessPlayback: true,
        frameBuilder: (context, image, frame, wasSyncLoaded) {
          if (wasSyncLoaded) return image;
          return Stack(
            fit: StackFit.expand,
            children: [
              const _HeroPlaceholder(),
              AnimatedOpacity(
                opacity: frame == null ? 0 : 1,
                duration: const Duration(milliseconds: 520),
                curve: Curves.easeOut,
                child: image,
              ),
            ],
          );
        },
        errorBuilder: (context, error, stackTrace) =>
            const _HeroPlaceholder(),
      );
    } else if (kIsWeb) {
      child = const _HeroPlaceholder();
    } else {
      child = Image.file(
        File(widget.assetPath),
        fit: BoxFit.cover,
        gaplessPlayback: true,
        frameBuilder: (context, image, frame, wasSyncLoaded) {
          if (wasSyncLoaded) return image;
          return Stack(
            fit: StackFit.expand,
            children: [
              const _HeroPlaceholder(),
              AnimatedOpacity(
                opacity: frame == null ? 0 : 1,
                duration: const Duration(milliseconds: 520),
                curve: Curves.easeOut,
                child: image,
              ),
            ],
          );
        },
        errorBuilder: (context, error, stackTrace) =>
            const _HeroPlaceholder(),
      );
    }
    return AnimatedBuilder(
      animation: widget.controller,
      child: child,
      builder: (context, inner) {
        var offset = 0.0;
        if (widget.controller.position.haveDimensions) {
          offset = (widget.controller.page ??
              widget.controller.initialPage.toDouble()) - widget.page;
        }
        final t = offset.clamp(-1.0, 1.0);
        final scale = 1.0 + (1 - t.abs()) * 0.03;
        return Transform.translate(
          offset: Offset(-t * 36, 0),
          child: Transform.scale(scale: scale, child: inner),
        );
      },
    );
  }
}

class _HeroPlaceholder extends StatelessWidget {
  const _HeroPlaceholder();

  @override
  Widget build(BuildContext context) {
    return const DecoratedBox(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [_MyProfileHeroState._accent, _MyProfileHeroState._accent2],
        ),
      ),
      child: Center(
        child: Icon(
          Icons.person_rounded,
          size: 96,
          color: Colors.white24,
        ),
      ),
    );
  }
}

/// Animated segmented progress bars (Tinder/Instagram-style).
class _ProgressBars extends StatelessWidget {
  const _ProgressBars({required this.count, required this.activeIndex});

  final int count;
  final int activeIndex;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        for (var i = 0; i < count; i++)
          Expanded(
            child: Padding(
              key: ValueKey('progress_$i'),
              padding: EdgeInsets.only(right: i == count - 1 ? 0 : 5),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(4),
                child: Stack(
                  children: [
                    // Track — faint, with a hairline of inner depth.
                    Container(
                      height: 3.5,
                      decoration: BoxDecoration(
                        color: Colors.black.withValues(alpha: .28),
                        borderRadius: BorderRadius.circular(4),
                      ),
                    ),
                    Container(
                      height: 3.5,
                      color: Colors.white.withValues(alpha: .20),
                    ),
                    // Fill — animates its width for the active segment so the
                    // progression reads as a smooth sweep rather than a snap.
                    // The active bar carries a subtle gradient + brighter glow
                    // to signal focus; completed bars settle to solid white.
                    AnimatedFractionallySizedBox(
                      duration: const Duration(milliseconds: 460),
                      curve: Curves.easeOutCubic,
                      widthFactor: i < activeIndex
                          ? 1.0
                          : (i == activeIndex ? 1.0 : 0.0),
                      child: DecoratedBox(
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(4),
                          gradient: LinearGradient(
                            colors: i == activeIndex
                                ? const [Colors.white, Color(0xFFEDE7FF)]
                                : const [Colors.white, Colors.white],
                          ),
                          boxShadow: [
                            BoxShadow(
                              color: Colors.white
                                  .withValues(alpha: i == activeIndex ? .5 : .3),
                              blurRadius: i == activeIndex ? 8 : 5,
                            ),
                          ],
                        ),
                        child: const SizedBox(height: 3.5),
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

class _MetaRow extends StatelessWidget {
  const _MetaRow({required this.location, required this.occupation});

  final String location;
  final String occupation;

  @override
  Widget build(BuildContext context) {
    final chips = <Widget>[
      if (location.trim().isNotEmpty)
        _MetaChip(icon: Icons.place_outlined, label: location.trim()),
      if (occupation.trim().isNotEmpty)
        _MetaChip(icon: Icons.work_outline_rounded, label: occupation.trim()),
    ];
    if (chips.isEmpty) return const SizedBox.shrink();
    return Wrap(spacing: 8, runSpacing: 8, children: chips);
  }
}

class _MetaChip extends StatelessWidget {
  const _MetaChip({required this.icon, required this.label});

  final IconData icon;
  final String label;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 11, vertical: 7),
      decoration: BoxDecoration(
        color: Colors.black.withValues(alpha: .34),
        borderRadius: BorderRadius.circular(30),
        border: Border.all(color: Colors.white.withValues(alpha: .16)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: .28),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 14, color: _MyProfileHeroState._softText),
          const SizedBox(width: 6),
          Text(
            label,
            style: const TextStyle(
              fontSize: 12.5,
              fontWeight: FontWeight.w600,
              letterSpacing: 0.1,
              color: Color(0xFFEAEEF9),
            ),
          ),
        ],
      ),
    );
  }
}

class _CompletionPill extends StatelessWidget {
  const _CompletionPill({required this.percent});

  final int percent;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 11, vertical: 6),
      decoration: BoxDecoration(
        color: Colors.black.withValues(alpha: .34),
        borderRadius: BorderRadius.circular(30),
        border: Border.all(color: Colors.white.withValues(alpha: .18)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: .28),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Text(
        '$percent% complete',
        style: const TextStyle(
          fontSize: 11.5,
          fontWeight: FontWeight.w700,
          letterSpacing: 0.2,
          color: Color(0xFFEAEEF9),
        ),
      ),
    );
  }
}

class _VerifiedPill extends StatelessWidget {
  const _VerifiedPill();

  static const _verified = Color(0xFF47D7A5);

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: _verified.withValues(alpha: .16),
        borderRadius: BorderRadius.circular(30),
        border: Border.all(color: _verified.withValues(alpha: .55)),
      ),
      child: const Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.verified_rounded, size: 13, color: _verified),
          SizedBox(width: 4),
          Text(
            'Verified',
            style: TextStyle(
              fontSize: 11.5,
              fontWeight: FontWeight.w700,
              color: _verified,
            ),
          ),
        ],
      ),
    );
  }
}
