import 'dart:io';
import 'dart:ui';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

import '../app/theme/app_theme.dart';

import '../../core/supabase/auth_service.dart';
import 'home_discovery_animations.dart';
import 'profile/connection_data.dart';
import 'profile/discovery_data.dart';
import 'profile/profile_data.dart';
import 'profile/profile_photo_resolver.dart';


class ImmersiveProfileView extends StatefulWidget {
  const ImmersiveProfileView({
    required super.key,
    required this.profile,
    required this.connection,
    required this.connecting,
    required this.onConnect,
    required this.onPrevious,
    required this.onNext,
    required this.onRefresh,
  });

  final DiscoveryProfile profile;
  final Connection? connection;
  final bool connecting;
  final VoidCallback onConnect;
  final VoidCallback onPrevious;
  final VoidCallback onNext;
  final Future<void> Function() onRefresh;

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
    return RefreshIndicator(
      onRefresh: widget.onRefresh,
      // Push the indicator below the floating greeting/filter pill.
      displacement: 96,
      color: context.cxInk,
      backgroundColor: context.cxSurface,
      child: CustomScrollView(
        controller: _scrollController,
        physics: const BouncingScrollPhysics(
          parent: AlwaysScrollableScrollPhysics(),
        ),
        slivers: [
          SliverToBoxAdapter(
            child: _HeroSection(
              profile: widget.profile,
              connection: widget.connection,
              connecting: widget.connecting,
              onConnect: widget.onConnect,
              onProfilePrevious: widget.onPrevious,
              onProfileNext: widget.onNext,
            ),
          ),
          // Elegant gap so the hero and information read as two distinct
          // premium glass surfaces rather than one continuous card.
          const SliverToBoxAdapter(child: SizedBox(height: 16)),
          SliverToBoxAdapter(child: _DetailsSection(profile: widget.profile)),
          // Hinge-style: the rest of the photos stack vertically below the
          // details so the whole profile reads top to bottom.
          for (final photo in widget.profile.photos.skip(1))
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(14, 16, 14, 0),
                child: _StackedPhotoCard(
                  key: ValueKey(
                    'stack_${widget.profile.name}_${photo.remoteUrl ?? photo.assetPath}',
                  ),
                  photo: photo,
                  profile: widget.profile,
                ),
              ),
            ),
          const SliverToBoxAdapter(child: SizedBox(height: 200)),
        ],
      ),
    );
  }
}

/// The hero photo section. Renders the centered, sharp photo with atmospheric
/// black scrim and the identity block below.
class _HeroSection extends StatelessWidget {
  const _HeroSection({
    required this.profile,
    required this.connection,
    required this.connecting,
    required this.onConnect,
    required this.onProfilePrevious,
    required this.onProfileNext,
  });

  final DiscoveryProfile profile;
  final Connection? connection;
  final bool connecting;
  final VoidCallback onConnect;
  final VoidCallback onProfilePrevious;
  final VoidCallback onProfileNext;

  @override
  Widget build(BuildContext context) {
    final media = MediaQuery.of(context);
    // A shorter, editorial first photo (roughly 62% of the screen) so the
    // details start above the fold and the page scrolls like Hinge.
    final heroHeight = (media.size.height * 0.62).clamp(420.0, 640.0);
    return SizedBox(
      height: heroHeight,
      child: ClipRRect(
        borderRadius: const BorderRadius.vertical(bottom: Radius.circular(34)),
        child: Stack(
          fit: StackFit.expand,
          children: [
            _PhotoGallery(
              key: ValueKey<String>('gallery_${profile.name}'),
              profile: profile,
              onProfilePrevious: onProfilePrevious,
              onProfileNext: onProfileNext,
            ),
            // Soft editorial scrim: keeps the lower third calm so the glass
            // identity card and the round controls read cleanly on any photo.
            const Positioned.fill(
              child: IgnorePointer(
                child: DecoratedBox(
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.topCenter,
                      end: Alignment.bottomCenter,
                      colors: [
                        Color(0x00000000),
                        Color(0x00000000),
                        Color(0x66000000),
                      ],
                      stops: [0.0, 0.55, 1.0],
                    ),
                  ),
                ),
              ),
            ),
            Positioned(
              left: 22,
              right: 22,
              bottom: 20,
              child: IgnorePointer(
                child: _IdentityBlock(
                  profile: profile,
                  connection: connection,
                  connecting: connecting,
                  onConnect: onConnect,
                ),
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
    required this.onProfilePrevious,
    required this.onProfileNext,
    super.key,
  });

  final DiscoveryProfile profile;
  final VoidCallback onProfilePrevious;
  final VoidCallback onProfileNext;

  @override
  State<_PhotoGallery> createState() => _PhotoGalleryState();
}

class _PhotoGalleryState extends State<_PhotoGallery> {
  double _dragStartX = 0;
  double _dragLastX = 0;

  static const double _kSwipeDistanceThreshold = 48;
  static const double _kSwipeVelocityThreshold = 350;

  void _handleProfileSwipe(DragEndDetails details) {
    final dx = _dragLastX - _dragStartX;
    if (dx.abs() >= _kSwipeDistanceThreshold) {
      if (dx < 0) {
        widget.onProfilePrevious();
      } else {
        widget.onProfileNext();
      }
      return;
    }
    final vx = details.velocity.pixelsPerSecond.dx;
    if (vx.abs() >= _kSwipeVelocityThreshold) {
      if (vx < 0) {
        widget.onProfilePrevious();
      } else {
        widget.onProfileNext();
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final photos = widget.profile.photos;
    if (photos.isEmpty) {
      return _FallbackPortrait(profile: widget.profile);
    }

    // Only the first photo lives in the hero. The remaining photos are laid
    // out vertically below the details (see ImmersiveProfileView), so the
    // profile reads as one top-to-bottom scroll instead of a slide gallery.
    // The horizontal swipe still moves between people.
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onHorizontalDragStart: (details) {
        _dragStartX = details.globalPosition.dx;
        _dragLastX = details.globalPosition.dx;
      },
      onHorizontalDragUpdate: (details) {
        _dragLastX = details.globalPosition.dx;
      },
      onHorizontalDragEnd: _handleProfileSwipe,
      child: _HeroPhoto(
        key: ValueKey('photo_${widget.profile.name}_0'),
        photo: photos.first,
        profile: widget.profile,
      ),
    );
  }
}

/// A rounded, fixed-height photo card used for the vertically stacked photos
/// below the hero. Reuses [_HeroPhoto] so loading and fallbacks are identical.
class _StackedPhotoCard extends StatelessWidget {
  const _StackedPhotoCard({
    required this.photo,
    required this.profile,
    super.key,
  });

  final ProfilePhoto photo;
  final DiscoveryProfile profile;

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(28),
      child: SizedBox(
        height: 440,
        width: double.infinity,
        child: _HeroPhoto(photo: photo, profile: profile),
      ),
    );
  }
}

class _HeroPhoto extends StatefulWidget {
  const _HeroPhoto({required this.photo, required this.profile, super.key});

  final ProfilePhoto photo;
  final DiscoveryProfile profile;

  @override
  State<_HeroPhoto> createState() => _HeroPhotoState();
}

class _HeroPhotoState extends State<_HeroPhoto> {
  String? _signedUrl;
  bool _loadingSignedUrl = true;

  @override
  void initState() {
    super.initState();
    final url = widget.photo.remoteUrl;
    if (kDebugMode) {
      debugPrint(
        '[DiscoveryPhoto] name=${widget.profile.name} '
        'remoteUrl=${url ?? "null"} assetPath=${widget.photo.assetPath.isEmpty ? "empty" : widget.photo.assetPath}',
      );
    }
    if (url != null && url.startsWith('profiles/')) {
      final cached = ProfilePhotoResolver.instance.getSignedUrl(url);
      if (cached != null) {
        _signedUrl = cached;
        _loadingSignedUrl = false;
      } else {
        _fetchSignedUrl();
      }
    } else if (url != null &&
        (url.startsWith('http://') || url.startsWith('https://'))) {
      _signedUrl = url;
      _loadingSignedUrl = false;
    } else {
      _loadingSignedUrl = false;
    }
  }

  Future<void> _fetchSignedUrl() async {
    try {
      final remoteUrl = widget.photo.remoteUrl!;
      final resolved = await ProfilePhotoResolver.instance.resolvePhoto(remoteUrl);
      if (!mounted) return;
      setState(() {
        _signedUrl = resolved.signedUrl;
        _loadingSignedUrl = false;
      });
    } catch (e) {
      await Future.delayed(const Duration(milliseconds: 500));
      if (!mounted) return;
      try {
        final remoteUrl = widget.photo.remoteUrl!;
        final resolved = await ProfilePhotoResolver.instance.resolvePhoto(remoteUrl);
        if (!mounted) return;
        setState(() {
          _signedUrl = resolved.signedUrl;
          _loadingSignedUrl = false;
        });
      } catch (e2) {
        if (!mounted) return;
        setState(() => _loadingSignedUrl = false);
      }
    }
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
        errorBuilder: (context, error, stackTrace) {
          if (kDebugMode) {
            debugPrint(
              '[DiscoveryPhoto] network image FAILED for ${widget.profile.name} error=$error',
            );
          }
          return const _HeroPlaceholder();
        },
      );
    } else if (_loadingSignedUrl) {
      child = const _HeroPlaceholder();
    } else if (widget.photo.remoteUrl != null &&
        widget.photo.remoteUrl!.startsWith('profiles/')) {
      child = const _HeroPlaceholder();
    } else if (widget.photo.assetPath.trim().isEmpty) {
      child = const _HeroPlaceholder();
    } else if (widget.photo.assetPath.startsWith('assets/')) {
      child = Image.asset(
        widget.photo.assetPath,
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
        errorBuilder: (context, error, stackTrace) => const _HeroPlaceholder(),
      );
    } else if (kIsWeb && widget.photo.assetPath.startsWith('blob:')) {
      child = Image.network(
        widget.photo.assetPath,
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
        errorBuilder: (context, error, stackTrace) => const _HeroPlaceholder(),
      );
    } else if (kIsWeb) {
      child = const _HeroPlaceholder();
    } else {
      child = Image.file(
        File(widget.photo.assetPath),
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
        errorBuilder: (context, error, stackTrace) => const _HeroPlaceholder(),
      );
    }

    return child;
  }
}

class _HeroPlaceholder extends StatelessWidget {
  const _HeroPlaceholder();

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [context.cxAccent, context.cxAccent],
        ),
      ),
      child: Center(
        child: Icon(Icons.person_rounded, size: 96, color: Colors.white24),
      ),
    );
  }
}


class _FallbackPortrait extends StatelessWidget {
  const _FallbackPortrait({required this.profile});

  final DiscoveryProfile profile;

  Color get _baseColor {
    final colors = [
      Color(0xFFD9485F),
      Color(0xFF0E8FA8),
      Color(0xFFD07A3A),
      Color(0xFF2F5FD0),
      Color(0xFF1B1B1F),
      Color(0xFF1F9D6B),
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
                Color.lerp(base, const Color(0xFFFFFFFF), 0.55) ?? base,
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
              colors: [context.cxInk.withValues(alpha: .28), Colors.transparent],
              stops: const [0.0, 0.7],
            ),
          ),
        ),
        Center(
          child: Text(
            profile.name.isEmpty ? '?' : profile.name.characters.first,
            style: TextStyle(
              fontSize: 128,
              fontFamily: 'Fraunces',
              fontWeight: FontWeight.w600,
              color: context.cxInk.withValues(alpha: .34),
              letterSpacing: -2,
            ),
          ),
        ),
      ],
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

  bool get _isActiveNow => profile.availabilityStatus == 'available_now';

  @override
  Widget build(BuildContext context) {
    final distance = profile.distanceMeters != null
        ? profile.formattedDistance
        : null;
    final occupation = profile.occupation?.trim() ?? '';

    final content = Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (_isActiveNow) ...[
          const _ActiveNowBadge(),
          const SizedBox(height: 12),
        ],
        Row(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            Flexible(
              child: Text(
                profile.name,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                  fontSize: 34,
                  fontFamily: 'Fraunces',
                  fontWeight: FontWeight.w600,
                  letterSpacing: -0.8,
                  color: Colors.white,
                  shadows: [Shadow(color: Color(0x99000000), blurRadius: 18)],
                ),
              ),
            ),
            if (profile.verified) ...[
              const SizedBox(width: 8),
              Icon(
                Icons.verified_rounded,
                size: 24,
                color: const Color(0xFF3B9EFF),
                shadows: [Shadow(color: Color(0x99000000), blurRadius: 10)],
              ),
            ],
          ],
        ),
        const SizedBox(height: 6),
        Row(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            Text(
              '${profile.age}',
              style: const TextStyle(
                fontSize: 15,
                fontWeight: FontWeight.w600,
                letterSpacing: .1,
                color: Colors.white,
                shadows: [Shadow(color: Color(0x99000000), blurRadius: 12)],
              ),
            ),
            if (distance != null) ...[
              const SizedBox(width: 6),
              Text(
                '·',
                style: TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.w600,
                  color: Colors.white.withValues(alpha: .7),
                  letterSpacing: .1,
                  shadows: [Shadow(color: Color(0x99000000), blurRadius: 12)],
                ),
              ),
              const SizedBox(width: 6),
              Text(
                distance,
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 15,
                  fontWeight: FontWeight.w600,
                  letterSpacing: .1,
                  shadows: [Shadow(color: Color(0x99000000), blurRadius: 12)],
                ),
              ),
            ],
          ],
        ),
        if (occupation.isNotEmpty) ...[
          const SizedBox(height: 6),
          Text(
            occupation,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 13,
              fontWeight: FontWeight.w500,
              letterSpacing: .2,
              shadows: [Shadow(color: Color(0x99000000), blurRadius: 10)],
            ),
          ),
        ],
        _ConnectStatus(
          connection: connection,
          connecting: connecting,
          onConnect: onConnect,
        ),
      ],
    );

    // Same frosted glass as the connect button: faint white gradient over the
    // blurred photo with a thin luminous rim, so card and button read as one.
    return ClipRRect(
      borderRadius: BorderRadius.circular(24),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 16, sigmaY: 16),
        child: Container(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [
                Colors.white.withValues(alpha: .34),
                Colors.white.withValues(alpha: .10),
              ],
            ),
            borderRadius: BorderRadius.circular(24),
            border: Border.all(
              color: Colors.white.withValues(alpha: .45),
              width: 1.2,
            ),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: .18),
                blurRadius: 20,
                offset: const Offset(0, 8),
              ),
            ],
          ),
          padding: const EdgeInsets.fromLTRB(20, 16, 20, 16),
          child: content,
        ),
      ),
    );
  }
}

/// A compact "Active now" presence pill shown above the name on the hero.
class _ActiveNowBadge extends StatelessWidget {
  const _ActiveNowBadge();

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: Colors.black.withValues(alpha: .28),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: Colors.white.withValues(alpha: .30)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 8,
            height: 8,
            decoration: const BoxDecoration(
              shape: BoxShape.circle,
              color: Color(0xFF1F9D6B),
              boxShadow: [BoxShadow(color: Color(0xFF1F9D6B), blurRadius: 6)],
            ),
          ),
          const SizedBox(width: 7),
          const Text(
            'Active now',
            style: TextStyle(
              fontSize: 12.5,
              fontWeight: FontWeight.w700,
              color: Colors.white,
            ),
          ),
        ],
      ),
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
      ConnectionStatus.accepted => ('Connected', const Color(0xFF1F9D6B)),
      ConnectionStatus.pending when connection != null => (
        connection!.requesterId == AuthService.currentUser?.id
            ? 'Pending'
            : 'Incoming request',
        const Color(0xFF0E8FA8),
      ),
      null when connecting => ('Sending request...', const Color(0xFFC98A1E)),
      ConnectionStatus.removed => null,
      null => null,
      ConnectionStatus.pending => ('Pending', const Color(0xFF0E8FA8)),
      ConnectionStatus.rejected => ('Declined', const Color(0xFFD9485F)),
      ConnectionStatus.cancelled => ('Cancelled', context.cxMuted),
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

class _DetailsSection extends StatelessWidget {
  const _DetailsSection({required this.profile});

  final DiscoveryProfile profile;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 14),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(28),
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 22, sigmaY: 22),
          child: Container(
            decoration: BoxDecoration(
              color: context.cxSurface.withValues(alpha: .82),
              borderRadius: BorderRadius.circular(28),
              border: Border.all(color: context.cxInk.withValues(alpha: .10)),
            ),
            padding: const EdgeInsets.fromLTRB(22, 14, 22, 30),
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
            color: Color(0xFF1B1B1F).withValues(alpha: .22),
            borderRadius: BorderRadius.circular(4),
          ),
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
      if (value.trim().isEmpty) return;
      sections.add(
        _RevealSection(
          child: _TextSection(title: title, icon: icon, value: value),
        ),
      );
    }

    addTextSection('About me', Icons.person_outline_rounded, profile.bio);
    addChipSection('Interests', Icons.auto_awesome_rounded, profile.interests);
    addChipSection('Languages', Icons.translate_rounded, profile.languages);
    addTextSection('Location', Icons.location_city_rounded, profile.location);
    addTextSection(
      'Occupation',
      Icons.work_outline_rounded,
      profile.occupation ?? '',
    );

    // Never leave the information card empty — keep it premium and intentional.
    if (sections.length == 1) {
      sections.add(
        Padding(
          padding: EdgeInsets.only(top: 22),
          child: Text(
            'No additional details shared yet.',
            style: TextStyle(
              color: Color(0xFF5C5C66),
              fontSize: 14,
              height: 1.5,
            ),
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
        Icon(icon, size: 19, color: context.cxInk),
        const SizedBox(width: 9),
        Text(
          title,
          style: TextStyle(
            fontSize: 17,
            fontWeight: FontWeight.w800,
            letterSpacing: .2,
            color: context.cxInk,
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
          style: TextStyle(
            color: context.cxSoft,
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
          children: [for (final value in values) _DetailChip(label: value)],
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
        color: context.cxInk.withValues(alpha: .07),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: context.cxInk.withValues(alpha: .12)),
      ),
      child: Text(
        label,
        style: TextStyle(
          fontSize: 12.5,
          fontWeight: FontWeight.w600,
          color: context.cxInk,
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
    required this.onConnect,
    required this.connection,
    required this.connecting,
    super.key,
    this.onSkip,
  });

  final VoidCallback onConnect;
  final Connection? connection;
  final bool connecting;

  /// Skips to the next person. Same action as swiping the photo; exposed as a
  /// button so users don't have to discover the gesture.
  final VoidCallback? onSkip;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 28),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.only(top: 7),
            child: onSkip == null
                ? const SizedBox(width: 60)
                : _SkipControl(onTap: onSkip!),
          ),
          Padding(
            padding: const EdgeInsets.only(top: 7),
            child: _ConnectControl(
              connection: connection,
              connecting: connecting,
              onTap: onConnect,
            ),
          ),
        ],
      ),
    );
  }
}

/// Round frosted-glass "skip" button (cross). Presentation mirrors
/// [_ConnectControl]; tapping it forwards to [onTap] only.
class _SkipControl extends StatefulWidget {
  const _SkipControl({required this.onTap});

  final VoidCallback onTap;

  @override
  State<_SkipControl> createState() => _SkipControlState();
}

class _SkipControlState extends State<_SkipControl> {
  bool _pressed = false;

  @override
  Widget build(BuildContext context) {
    return Tooltip(
      message: 'Skip',
      child: GestureDetector(
        onTapDown: (_) => setState(() => _pressed = true),
        onTapUp: (_) => setState(() => _pressed = false),
        onTapCancel: () => setState(() => _pressed = false),
        child: AnimatedScale(
          scale: _pressed ? 0.92 : 1.0,
          duration: const Duration(milliseconds: 160),
          curve: Curves.easeOutCubic,
          child: ClipOval(
            child: BackdropFilter(
              filter: ImageFilter.blur(sigmaX: 16, sigmaY: 16),
              child: Container(
                height: 60,
                width: 60,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  gradient: LinearGradient(
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                    colors: [
                      Colors.white.withValues(alpha: .34),
                      Colors.white.withValues(alpha: .10),
                    ],
                  ),
                  border: Border.all(
                    color: Colors.white.withValues(alpha: .45),
                    width: 1.2,
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: .18),
                      blurRadius: 20,
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
                    child: const Icon(Icons.close_rounded, color: Colors.white, size: 26),
                  ),
                ),
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
        : Icons.connect_without_contact_rounded;

    return Tooltip(
      message: switch (widget.connection?.status) {
        ConnectionStatus.accepted => 'Connected',
        ConnectionStatus.pending
            when widget.connection?.requesterId ==
                AuthService.currentUser?.id =>
          'Pending',
        ConnectionStatus.pending => 'Incoming request',
        ConnectionStatus.rejected => 'Declined',
        ConnectionStatus.cancelled => 'Cancelled',
        ConnectionStatus.removed => 'Removed',
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
          child: ClipOval(
            child: BackdropFilter(
              filter: ImageFilter.blur(sigmaX: 16, sigmaY: 16),
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 320),
                curve: Curves.easeOutCubic,
                height: 60,
                width: 60,
                // Frosted glass: a faint white-to-clear gradient over the
                // blurred photo with a thin luminous rim.
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  gradient: LinearGradient(
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                    colors: [
                      Colors.white.withValues(alpha: .34),
                      Colors.white.withValues(alpha: .10),
                    ],
                  ),
                  border: Border.all(
                    color: Colors.white.withValues(alpha: .45),
                    width: 1.2,
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: .18),
                      blurRadius: 20,
                      offset: const Offset(0, 8),
                    ),
                  ],
                ),
                child: Material(
                  color: Colors.transparent,
                  shape: const CircleBorder(),
                  clipBehavior: Clip.antiAlias,
                  child: InkWell(
                    onTap: _busy ? null : widget.onTap,
                    child: Icon(icon, color: Colors.white, size: 26),
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
