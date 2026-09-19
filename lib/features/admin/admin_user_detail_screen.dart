import 'package:flutter/material.dart';

import 'admin_data_service.dart';
import 'models/admin_user_detail.dart';
import 'models/admin_overview_data.dart';
import 'widgets/admin_location_map.dart';
import '../profile/profile_photo_resolver.dart';
import '../../app/theme/app_theme.dart';

class AdminUserDetailScreen extends StatefulWidget {
  const AdminUserDetailScreen({
    required this.userId,
    super.key,
  });

  final String userId;

  @override
  State<AdminUserDetailScreen> createState() => _AdminUserDetailScreenState();
}

class _AdminUserDetailScreenState extends State<AdminUserDetailScreen> {
  final AdminDataService _dataService = const AdminDataService();

  Future<AdminUserDetail?>? _detailFuture;

  @override
  void initState() {
    super.initState();
    _load();
  }

  void _load() {
    setState(() {
      _detailFuture = _fetch();
    });
  }

  Future<AdminUserDetail?> _fetch() async {
    try {
      return await _dataService.getUserDetail(widget.userId);
    } on AdminDataException {
      rethrow;
    } catch (_) {
      throw const AdminDataException(
        'Unable to load user details. Please try again.',
      );
    }
  }

  void _retry() => _load();

  void _back() {
    if (Navigator.of(context).canPop()) {
      Navigator.of(context).pop();
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.darkTheme.scaffoldBackgroundColor,
      body: Column(
        children: [
          _DetailTopBar(
            onBack: _back,
            onRefresh: _retry,
          ),
          const Divider(height: 1, color: Color(0xFF1E2438)),
          Expanded(
            child: FutureBuilder<AdminUserDetail?>(
              future: _detailFuture,
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const _DetailLoadingState();
                }
                if (snapshot.hasError) {
                  return _ErrorState(
                    onRetry: _retry,
                    onBack: _back,
                  );
                }
                final detail = snapshot.data;
                if (detail == null) {
                  return const _NotFoundState();
                }
                return _DetailBody(user: detail);
              },
            ),
          ),
        ],
      ),
    );
  }
}

class _DetailTopBar extends StatelessWidget {
  const _DetailTopBar({
    required this.onBack,
    required this.onRefresh,
  });

  final VoidCallback onBack;
  final VoidCallback onRefresh;

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 64,
      padding: const EdgeInsets.symmetric(horizontal: 20),
      decoration: const BoxDecoration(
        color: Color(0xFF0D1120),
        border: Border(
          bottom: BorderSide(color: Color(0xFF1E2438)),
        ),
      ),
      child: Row(
        children: [
          TextButton.icon(
            onPressed: onBack,
            icon: const Icon(
              Icons.arrow_back_rounded,
              size: 18,
              color: Color(0xFF9AA3C2),
            ),
            label: const Text(
              'Users',
              style: TextStyle(
                color: Color(0xFFB7A5FF),
                fontWeight: FontWeight.w600,
              ),
            ),
            style: TextButton.styleFrom(
              padding: const EdgeInsets.symmetric(horizontal: 8),
            ),
          ),
          const Spacer(),
          IconButton(
            onPressed: onRefresh,
            icon: const Icon(
              Icons.refresh_rounded,
              size: 20,
              color: Color(0xFF9AA3C2),
            ),
            tooltip: 'Refresh',
          ),
        ],
      ),
    );
  }
}

class _DetailBody extends StatelessWidget {
  const _DetailBody({required this.user});

  final AdminUserDetail user;

  @override
  Widget build(BuildContext context) {
    final bool narrow = MediaQuery.of(context).size.width < 900;
    return ListView(
      padding: const EdgeInsets.all(24),
      children: [
        _IdentityHeader(user: user),
        const SizedBox(height: 24),
        narrow
            ? Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  ..._leftColumnChildren(),
                  ..._rightColumnChildren(),
                ],
              )
            : Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: _leftColumnChildren(),
                    ),
                  ),
                  const SizedBox(width: 32),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: _rightColumnChildren(),
                    ),
                  ),
                ],
              ),
        const SizedBox(height: 8),
      ],
    );
  }

  List<Widget> _leftColumnChildren() => [
        _ProfileCard(user: user),
        const SizedBox(height: 16),
        _PhotosCard(user: user),
        const SizedBox(height: 16),
        _VerificationCard(user: user),
      ];

  List<Widget> _rightColumnChildren() => [
        _AccountCard(user: user),
        const SizedBox(height: 16),
        _LiveLocationCard(user: user),
        const SizedBox(height: 16),
        _DeviceActivityCard(user: user),
        const SizedBox(height: 16),
        _NetworkSummaryCard(user: user),
      ];
}

class _IdentityHeader extends StatelessWidget {
  const _IdentityHeader({required this.user});

  final AdminUserDetail user;

  @override
  Widget build(BuildContext context) {
    final name = user.displayName;
    final display = (name == null || name.isEmpty) ? 'Unnamed user' : name;

    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                display,
                style: const TextStyle(
                  fontSize: 22,
                  fontWeight: FontWeight.w800,
                  color: Colors.white,
                  letterSpacing: -0.3,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                user.userId,
                style: const TextStyle(
                  fontSize: 12,
                  color: Color(0xFF8E98B8),
                ),
              ),
            ],
          ),
        ),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            _StatusChip(
              label: _verificationLabel(user),
              dotColor: _verificationDot(user),
            ),
            _StatusChip(
              label: _visibilityLabel(user),
              dotColor: _visibilityDot(user),
            ),
            _StatusChip(
              label: user.profileCompleted == true
                  ? 'Completed'
                  : 'Incomplete',
              dotColor: user.profileCompleted == true
                  ? const Color(0xFF22C58E)
                  : const Color(0xFF4B5563),
            ),
            _StatusChip(label: user.availabilityStatus ?? '—'),
          ],
        ),
      ],
    );
  }
}

class _ProfileCard extends StatelessWidget {
  const _ProfileCard({required this.user});

  final AdminUserDetail user;

  @override
  Widget build(BuildContext context) {
    final rows = <Widget>[];
    void add(String label, String? value) {
      rows.add(_InfoRow(label: label, value: value ?? '—'));
    }

    add('Bio', user.bio);
    add('About me', user.aboutMe);
    add('Gender', user.gender);
    add('Location', user.location);
    add('Occupation', user.occupation);
    add('Education', user.education);
    add('Company', user.company);
    add('College', user.college);
    add('Hometown', user.hometown);
    add('Website', user.website);

    final dob = user.dateOfBirth;
    if (dob != null) {
      add('Date of birth', _formatDate(dob));
    }
    add('Availability', user.availabilityStatus);

    return _DetailCard(
      title: 'Profile',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          if (user.interests != null && user.interests!.isNotEmpty) ...[
            _sectionLabel('Interests'),
            const SizedBox(height: 6),
            _chips(user.interests),
            const SizedBox(height: 12),
          ],
          if (user.favoriteActivities != null &&
              user.favoriteActivities!.isNotEmpty) ...[
            _sectionLabel('Favorite activities'),
            const SizedBox(height: 6),
            _chips(user.favoriteActivities),
            const SizedBox(height: 12),
          ],
          if (user.languages != null && user.languages!.isNotEmpty) ...[
            _sectionLabel('Languages'),
            const SizedBox(height: 6),
            _chips(user.languages),
            const SizedBox(height: 12),
          ],
          ...rows,
        ],
      ),
    );
  }
}

class _PhotosCard extends StatefulWidget {
  const _PhotosCard({required this.user});

  final AdminUserDetail user;

  @override
  State<_PhotosCard> createState() => _PhotosCardState();
}

class _PhotosCardState extends State<_PhotosCard> {
  final List<String?> _resolved = [];
  var _loading = true;

  @override
  void initState() {
    super.initState();
    _resolvePhotos();
  }

  Future<void> _resolvePhotos() async {
    final photos = widget.user.photos;
    final results = <String?>[];

    if (photos is List) {
      for (final p in photos) {
        if (p is! Map) {
          results.add(null);
          continue;
        }
        final remoteUrl = p['remoteUrl'] as String?;
        if (remoteUrl == null || remoteUrl.isEmpty) {
          results.add(null);
        } else if (remoteUrl.startsWith('http://') ||
            remoteUrl.startsWith('https://')) {
          results.add(remoteUrl);
        } else if (remoteUrl.startsWith('profiles/')) {
          try {
            final resolved =
                await ProfilePhotoResolver.instance.resolvePhoto(remoteUrl);
            results.add(resolved.signedUrl);
          } catch (_) {
            results.add(null);
          }
        } else {
          results.add(null);
        }
      }
    }

    if (mounted) {
      setState(() {
        _resolved
          ..clear()
          ..addAll(results);
        _loading = false;
      });
    }
  }

  static Widget _brokenPlaceholder() => Container(
        color: const Color(0xFF0B1020),
        child: const Icon(
          Icons.broken_image_outlined,
          color: Color(0xFF4B5563),
        ),
      );

  @override
  Widget build(BuildContext context) {
    final hasUsablePhoto = _resolved.any((url) => url != null);

    return _DetailCard(
      title: 'Photos',
      child: _loading
          ? Center(
              child: SizedBox(
                width: 24,
                height: 24,
                child: CircularProgressIndicator(
                  strokeWidth: 2,
                  color: const Color(0xFF8B5CF6),
                ),
              ),
            )
          : hasUsablePhoto
              ? Wrap(
                  spacing: 12,
                  runSpacing: 12,
                  children: [
                    for (final url in _resolved)
                      SizedBox(
                        width: 120,
                        height: 120,
                        child: ClipRRect(
                          borderRadius: BorderRadius.circular(12),
                          child: url == null
                              ? _brokenPlaceholder()
                              : Image.network(
                                  url,
                                  fit: BoxFit.contain,
                                  width: 120,
                                  height: 120,
                                  errorBuilder: (_, _, _) =>
                                      _brokenPlaceholder(),
                                ),
                        ),
                      ),
                  ],
                )
              : Center(
                  child: Text(
                    'No profile photos',
                    style: const TextStyle(color: Color(0xFF7E88A8)),
                  ),
                ),
    );
  }
}

class _VerificationCard extends StatelessWidget {
  const _VerificationCard({required this.user});

  final AdminUserDetail user;

  @override
  Widget build(BuildContext context) {
    final status = _verificationLabel(user);
    final dotColor = _verificationDot(user);

    return _DetailCard(
      title: 'Verification',
      child: Row(
        children: [
          if (dotColor != null) ...[
            Container(
              width: 10,
              height: 10,
              decoration: BoxDecoration(
                color: dotColor,
                shape: BoxShape.circle,
              ),
            ),
            const SizedBox(width: 10),
          ],
          Text(
            status,
            style: const TextStyle(
              color: Color(0xFFD0D7F4),
              fontSize: 14,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }
}

class _AccountCard extends StatelessWidget {
  const _AccountCard({required this.user});

  final AdminUserDetail user;

  @override
  Widget build(BuildContext context) {
    final now = DateTime.now();
    String accountType;
    if (user.isAnonymous == true) {
      accountType = 'Anonymous';
    } else if (user.isSsoUser == true) {
      accountType = 'SSO';
    } else {
      accountType = 'Normal';
    }

    String status;
    if (user.deletedAt != null) {
      status = 'Deleted';
    } else if (user.bannedUntil != null) {
      status = user.bannedUntil!.isAfter(now)
          ? 'Banned until ${_formatDate(user.bannedUntil)}'
          : 'Active';
    } else {
      status = 'Active';
    }

    return _DetailCard(
      title: 'Account',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _InfoRow(label: 'Email', value: user.email ?? '—'),
          _InfoRow(label: 'Phone', value: user.phone ?? '—'),
          _InfoRow(
            label: 'Registration',
            value: _formatDate(user.registrationDate),
          ),
          _InfoRow(
            label: 'Last sign-in',
            value: _formatDateTime(user.lastSignInAt),
          ),
          _InfoRow(
            label: 'Email confirmed',
            value: user.emailConfirmedAt == null
                ? 'Not confirmed'
                : _formatDate(user.emailConfirmedAt),
          ),
          _InfoRow(
            label: 'Phone confirmed',
            value: user.phoneConfirmedAt == null
                ? 'Not confirmed'
                : _formatDate(user.phoneConfirmedAt),
          ),
          _InfoRow(label: 'Account type', value: accountType),
          _InfoRow(label: 'Status', value: status),
        ],
      ),
    );
  }
}

class _LiveLocationCard extends StatelessWidget {
  const _LiveLocationCard({required this.user});

  final AdminUserDetail user;

  @override
  Widget build(BuildContext context) {
    final status = user.locationStatus;
    final updatedAt = user.locationUpdatedAt;
    final lat = user.latitude;
    final lng = user.longitude;
    final hasLocation =
        status == 'live' || status == 'stale';
    final dotColor = status == 'live'
        ? const Color(0xFF22C58E)
        : status == 'stale'
            ? const Color(0xFFF59E0B)
            : const Color(0xFF4B5563);
    final statusLabel = status == 'live'
        ? 'Live'
        : status == 'stale'
            ? 'Stale'
            : 'No live location';

    return _DetailCard(
      title: 'Live Location',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 10,
                height: 10,
                decoration: BoxDecoration(
                  color: dotColor,
                  shape: BoxShape.circle,
                ),
              ),
              const SizedBox(width: 10),
              Text(
                statusLabel,
                style: TextStyle(
                  color: hasLocation
                      ? Colors.white
                      : const Color(0xFF7E88A8),
                  fontSize: 14,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          if (hasLocation && lat != null && lng != null) ...[
            AdminLocationMap(latitude: lat, longitude: lng),
            const SizedBox(height: 12),
            Text(
              'Latitude: ${lat.toStringAsFixed(6)}',
              style: const TextStyle(
                color: Color(0xFFD0D7F4),
                fontSize: 13,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              'Longitude: ${lng.toStringAsFixed(6)}',
              style: const TextStyle(
                color: Color(0xFFD0D7F4),
                fontSize: 13,
              ),
            ),
            const SizedBox(height: 12),
          ],
          Text(
            'Last location update: ${updatedAt == null ? '—' : 'Updated ${_timeAgo(updatedAt)}'}',
            style: const TextStyle(
              color: Color(0xFF8E98B8),
              fontSize: 12,
            ),
          ),
        ],
      ),
    );
  }
}

class _DeviceActivityCard extends StatelessWidget {
  const _DeviceActivityCard({required this.user});

  final AdminUserDetail user;

  @override
  Widget build(BuildContext context) {
    return _DetailCard(
      title: 'Device & Activity',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _InfoRow(
            label: 'Latest platform',
            value: user.latestPlatform ?? '—',
          ),
          _InfoRow(
            label: 'Latest app version',
            value: user.latestAppVersion ?? '—',
          ),
          _InfoRow(
            label: 'Last Active',
            value: user.lastActiveAt == null
                ? '—'
                : _timeAgo(user.lastActiveAt),
          ),
        ],
      ),
    );
  }
}

class _NetworkSummaryCard extends StatelessWidget {
  const _NetworkSummaryCard({required this.user});

  final AdminUserDetail user;

  @override
  Widget build(BuildContext context) {
    return _DetailCard(
      title: 'Network & Moderation',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _InfoRow(
            label: 'Connections',
            value: '${user.connectionCount}',
          ),
          _InfoRow(
            label: 'Conversations',
            value: '${user.conversationMembershipCount}',
          ),
          _InfoRow(
            label: 'Messages sent',
            value: '${user.messagesSentCount}',
          ),
          _InfoRow(
            label: 'Blocks',
            value: '${user.blockCount}',
          ),
          _InfoRow(
            label: 'Reports',
            value: '${user.safetyReportCount}',
          ),
        ],
      ),
    );
  }
}

class _DetailCard extends StatelessWidget {
  const _DetailCard({
    required this.title,
    required this.child,
  });

  final String title;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: const Color(0xFF151B2E),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFF29324A)),
      ),
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            title,
            style: const TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w700,
              color: Color(0xFF8E98B8),
            ),
          ),
          const SizedBox(height: 14),
          child,
        ],
      ),
    );
  }
}

class _InfoRow extends StatelessWidget {
  const _InfoRow({
    required this.label,
    required this.value,
  });

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 7),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 140,
            child: Text(
              label,
              style: const TextStyle(
                color: Color(0xFF7E88A8),
                fontSize: 13,
              ),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              value,
              style: const TextStyle(
                color: Color(0xFFD0D7F4),
                fontSize: 13,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _StatusChip extends StatelessWidget {
  const _StatusChip({
    required this.label,
    this.dotColor,
  });

  final String label;
  final Color? dotColor;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        color: const Color(0xFF8B5CF6).withValues(alpha: 0.10),
        borderRadius: BorderRadius.circular(100),
        border: Border.all(color: const Color(0xFF29324A)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (dotColor != null) ...[
            Container(
              width: 8,
              height: 8,
              decoration: BoxDecoration(
                color: dotColor,
                shape: BoxShape.circle,
              ),
            ),
            const SizedBox(width: 6),
          ],
          Text(
            label,
            style: const TextStyle(
              color: Color(0xFFD0D7F4),
              fontSize: 11,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }
}

class _DetailLoadingState extends StatelessWidget {
  const _DetailLoadingState();

  @override
  Widget build(BuildContext context) {
    final shimmer = Colors.white.withValues(alpha: 0.06);
    return ListView(
      padding: const EdgeInsets.all(24),
      children: [
        Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Container(
                    width: 240,
                    height: 24,
                    decoration: BoxDecoration(
                      color: shimmer,
                      borderRadius: BorderRadius.circular(6),
                    ),
                  ),
                  const SizedBox(height: 8),
                  Container(
                    width: 160,
                    height: 14,
                    decoration: BoxDecoration(
                      color: shimmer,
                      borderRadius: BorderRadius.circular(4),
                    ),
                  ),
                ],
              ),
            ),
            Wrap(
              spacing: 8,
              children: [
                for (int i = 0; i < 3; i++)
                  Container(
                    width: 80,
                    height: 24,
                    decoration: BoxDecoration(
                      color: shimmer,
                      borderRadius: BorderRadius.circular(100),
                    ),
                  ),
              ],
            ),
          ],
        ),
        const SizedBox(height: 24),
        LayoutBuilder(
          builder: (context, constraints) {
            if (constraints.maxWidth < 900) {
              return Column(
                children: [
                  for (int i = 0; i < 6; i++) ...[
                    _SkeletonCard(),
                    const SizedBox(height: 16),
                  ],
                ],
              );
            }
            return Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  child: Column(
                    children: [
                      for (int i = 0; i < 3; i++) ...[
                        _SkeletonCard(),
                        const SizedBox(height: 16),
                      ],
                    ],
                  ),
                ),
                const SizedBox(width: 32),
                Expanded(
                  child: Column(
                    children: [
                      for (int i = 0; i < 3; i++) ...[
                        _SkeletonCard(),
                        const SizedBox(height: 16),
                      ],
                    ],
                  ),
                ),
              ],
            );
          },
        ),
      ],
    );
  }
}

class _SkeletonCard extends StatelessWidget {
  const _SkeletonCard();

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 160,
      decoration: BoxDecoration(
        color: const Color(0xFF151B2E),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFF29324A)),
      ),
    );
  }
}

class _ErrorState extends StatelessWidget {
  const _ErrorState({
    required this.onRetry,
    required this.onBack,
  });

  final VoidCallback onRetry;
  final VoidCallback onBack;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 480),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 72,
              height: 72,
              decoration: BoxDecoration(
                color: const Color(0xFF8B5CF6).withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(20),
                border: Border.all(
                  color: const Color(0xFF9D82FF).withValues(alpha: 0.25),
                ),
              ),
              child: const Icon(
                Icons.error_outline,
                size: 32,
                color: Color(0xFFB7A5FF),
              ),
            ),
            const SizedBox(height: 24),
            const Text(
              'Unable to load user details',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.w700,
                color: Colors.white,
                letterSpacing: -0.3,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 10),
            const Text(
              'Please check your connection and try again.',
              style: TextStyle(
                fontSize: 14,
                color: Color(0xFF7E88A8),
                height: 1.5,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 28),
            ElevatedButton.icon(
              onPressed: onRetry,
              icon: const Icon(Icons.refresh_rounded, size: 18),
              label: const Text('Try Again'),
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF8B5CF6),
                foregroundColor: Colors.white,
                elevation: 0,
                padding: const EdgeInsets.symmetric(
                  horizontal: 20,
                  vertical: 14,
                ),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
            ),
            const SizedBox(height: 12),
            TextButton.icon(
              onPressed: onBack,
              icon: const Icon(
                Icons.arrow_back_rounded,
                size: 18,
                color: Color(0xFF9AA3C2),
              ),
              label: const Text(
                'Back to Users',
                style: TextStyle(color: Color(0xFFB7A5FF)),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _NotFoundState extends StatelessWidget {
  const _NotFoundState();

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(
            Icons.person_off_outlined,
            size: 48,
            color: Color(0xFF7E88A8),
          ),
          const SizedBox(height: 16),
          const Text(
            'User not found',
            style: TextStyle(
              fontSize: 16,
              color: Color(0xFF9AA3C2),
            ),
          ),
          const SizedBox(height: 20),
          TextButton.icon(
            onPressed: () {
              if (Navigator.of(context).canPop()) {
                Navigator.of(context).pop();
              }
            },
            icon: const Icon(
              Icons.arrow_back_rounded,
              size: 18,
              color: Color(0xFF9AA3C2),
            ),
            label: const Text(
              'Back to Users',
              style: TextStyle(color: Color(0xFFB7A5FF)),
            ),
          ),
        ],
      ),
    );
  }
}

Wrap _chips(List<String>? items) {
  if (items == null || items.isEmpty) {
    return const Wrap();
  }
  return Wrap(
    spacing: 8,
    runSpacing: 6,
    children: [
      for (final item in items)
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
          decoration: BoxDecoration(
            color: const Color(0xFF8B5CF6).withValues(alpha: 0.10),
            borderRadius: BorderRadius.circular(100),
            border: Border.all(color: const Color(0xFF29324A)),
          ),
          child: Text(
            item,
            style: const TextStyle(
              color: Color(0xFFD0D7F4),
              fontSize: 12,
            ),
          ),
        ),
    ],
  );
}

Widget _sectionLabel(String text) => Text(
      text,
      style: const TextStyle(
        fontSize: 12,
        fontWeight: FontWeight.w600,
        color: Color(0xFF8E98B8),
      ),
    );

String _formatDate(DateTime? date) {
  if (date == null) return '—';
  final y = date.year.toString();
  final m = date.month.toString().padLeft(2, '0');
  final d = date.day.toString().padLeft(2, '0');
  return '$y-$m-$d';
}

String _formatDateTime(DateTime? date) {
  if (date == null) return '—';
  return '${_formatDate(date)} ${date.hour.toString().padLeft(2, '0')}:${date.minute.toString().padLeft(2, '0')}';
}

String _timeAgo(DateTime? date) {
  if (date == null) return '—';
  final now = DateTime.now();
  final elapsed = now.difference(date);
  if (elapsed.isNegative) return 'now';
  if (elapsed.inSeconds < 5) return 'now';
  if (elapsed.inMinutes < 1) return '${elapsed.inSeconds}s ago';
  if (elapsed.inMinutes < 60) {
    final minutes = elapsed.inMinutes;
    return '$minutes min${minutes == 1 ? '' : 's'} ago';
  }
  if (elapsed.inHours < 24) return '${elapsed.inHours}h ago';
  if (elapsed.inDays == 1) return 'Yesterday';
  if (elapsed.inDays < 7) return '${elapsed.inDays}d ago';
  return _formatDate(date);
}

String _verificationLabel(AdminUserDetail user) {
  switch (user.verificationStatus) {
    case 'verified':
      return 'Verified';
    case 'pending':
      return 'Pending';
    case 'notVerified':
      return 'Not Verified';
    default:
      return '—';
  }
}

Color? _verificationDot(AdminUserDetail user) {
  switch (user.verificationStatus) {
    case 'verified':
      return const Color(0xFF22C58E);
    case 'pending':
      return const Color(0xFFF59E0B);
    default:
      return null;
  }
}

String _visibilityLabel(AdminUserDetail user) {
  switch (user.profileVisibility) {
    case 'public':
      return 'Public';
    case 'private':
      return 'Private';
    default:
      return '—';
  }
}

Color? _visibilityDot(AdminUserDetail user) {
  switch (user.profileVisibility) {
    case 'public':
      return const Color(0xFF3B82F6);
    case 'private':
      return const Color(0xFF6B7280);
    default:
      return null;
  }
}
