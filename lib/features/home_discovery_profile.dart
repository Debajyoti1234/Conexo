import 'dart:io';
import 'dart:ui';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../core/supabase/auth_service.dart';
import 'home_discovery_animations.dart';
import 'home_discovery_cache.dart';
import 'profile/connection_data.dart';
import 'profile/discovery_data.dart';
import 'profile/profile_data.dart';
import 'profile/supabase_profile_repository.dart';

const _kAccent = Color(0xFF8B5CF6);
const _kAccent2 = Color(0xFF587BE2);

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
      color: const Color(0xFFB7A5FF),
      backgroundColor: const Color(0xFF141C31),
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
    final heroHeight = media.size.height - media.padding.top;
    final screenHeight = media.size.height;
    final identityTop = screenHeight * 0.70;
    return SizedBox(
      height: heroHeight.clamp(480.0, 1000.0),
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
            Positioned(
              left: 22,
              right: 22,
              top: identityTop,
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
  late final PageController _controller;
  int _photoIndex = 0;

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

  List<ProfilePhoto> get _photos {
    final photos = widget.profile.photos;
    if (photos.isEmpty) return const [];
    if (photos.length > 1) return photos;
    return [photos.first, photos.first, photos.first];
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
      child: Stack(
        fit: StackFit.expand,
        children: [
          PageView.builder(
            controller: _controller,
            physics: const NeverScrollableScrollPhysics(),
            itemCount: count,
            onPageChanged: (i) => setState(() => _photoIndex = i),
            itemBuilder: (context, i) => _HeroPhoto(
              key: ValueKey('photo_${widget.profile.name}_$i'),
              photo: photos[i],
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
              top: MediaQuery.of(context).padding.top + 66,
              left: 20,
              right: 20,
              child: _FloatingProgressBars(
                count: count,
                activeIndex: _photoIndex,
              ),
            ),
        ],
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
      final cached = DiscoveryPhotoCache.getSignedUrl(url);
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
      final url = await const SupabaseProfileRepository().getSignedPhotoUrl(
        remoteUrl,
      );
      if (!mounted) return;

      if (url != null && url.isNotEmpty) {
        DiscoveryPhotoCache.setSignedUrl(remoteUrl, url);
      }

      setState(() {
        _signedUrl = url;
        _loadingSignedUrl = false;
      });
    } catch (e) {
      await Future.delayed(const Duration(milliseconds: 500));
      if (!mounted) return;
      try {
        final remoteUrl = widget.photo.remoteUrl!;
        final url = await const SupabaseProfileRepository().getSignedPhotoUrl(
          remoteUrl,
        );
        if (!mounted) return;

        if (url != null && url.isNotEmpty) {
          DiscoveryPhotoCache.setSignedUrl(remoteUrl, url);
        }

        setState(() {
          _signedUrl = url;
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
    return const DecoratedBox(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [_kAccent, _kAccent2],
        ),
      ),
      child: Center(
        child: Icon(Icons.person_rounded, size: 96, color: Colors.white24),
      ),
    );
  }
}

class _FloatingProgressBars extends StatelessWidget {
  const _FloatingProgressBars({required this.count, required this.activeIndex});

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
                                    color: Colors.white.withValues(alpha: .3),
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
              colors: [Colors.white.withValues(alpha: .28), Colors.transparent],
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
                  fontWeight: FontWeight.w800,
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
                color: Color(0xFFEAEEF9),
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
                  color: Color(0xFFEAEEF9).withValues(alpha: .7),
                  letterSpacing: .1,
                  shadows: [Shadow(color: Color(0x99000000), blurRadius: 12)],
                ),
              ),
              const SizedBox(width: 6),
              Text(
                distance,
                style: const TextStyle(
                  color: Color(0xFFEAEEF9),
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
              color: Color(0xFFEAEEF9),
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

    return ClipRRect(
      borderRadius: BorderRadius.circular(24),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 18, sigmaY: 18),
        child: Container(
          decoration: BoxDecoration(
            color: const Color(0xFF141C31).withValues(alpha: .78),
            borderRadius: BorderRadius.circular(24),
            border: Border.all(color: Colors.white.withValues(alpha: .12)),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: .30),
                blurRadius: 28,
                offset: const Offset(0, 10),
              ),
              BoxShadow(
                color: const Color(0xFF7C3AED).withValues(alpha: .12),
                blurRadius: 20,
                offset: const Offset(0, 4),
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
        color: Colors.black.withValues(alpha: .38),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: Colors.white.withValues(alpha: .14)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 8,
            height: 8,
            decoration: const BoxDecoration(
              shape: BoxShape.circle,
              color: Color(0xFF47D7A5),
              boxShadow: [BoxShadow(color: Color(0xFF47D7A5), blurRadius: 6)],
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
      ConnectionStatus.accepted => ('Connected', const Color(0xFF47D7A5)),
      ConnectionStatus.pending when connection != null => (
        connection!.requesterId == AuthService.currentUser?.id
            ? 'Pending'
            : 'Incoming request',
        const Color(0xFF22D3EE),
      ),
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
              color: const Color(0xFF141C31).withValues(alpha: .82),
              borderRadius: BorderRadius.circular(28),
              border: Border.all(color: Colors.white.withValues(alpha: .10)),
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
            color: Colors.white.withValues(alpha: .22),
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
        const Padding(
          padding: EdgeInsets.only(top: 22),
          child: Text(
            'No additional details shared yet.',
            style: TextStyle(
              color: Color(0xFFAEB9D6),
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
    required this.onConnect,
    required this.connection,
    required this.connecting,
    super.key,
  });

  final VoidCallback onConnect;
  final Connection? connection;
  final bool connecting;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(right: 28),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.end,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
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
              filter: ImageFilter.blur(sigmaX: 12, sigmaY: 12),
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 320),
                curve: Curves.easeOutCubic,
                height: 60,
                width: 60,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: Colors.white.withValues(alpha: .10),
                  border: Border.all(color: Colors.white.withValues(alpha: .18)),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: .25),
                      blurRadius: 24,
                      offset: const Offset(0, 10),
                    ),
                    BoxShadow(
                      color: const Color(0xFF7C3AED).withValues(alpha: .08),
                      blurRadius: 16,
                      offset: const Offset(0, 4),
                    ),
                    BoxShadow(
                      color: const Color(0xFF7C3AED).withValues(alpha: .04),
                      blurRadius: 28,
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
