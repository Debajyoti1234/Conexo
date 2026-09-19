import 'package:flutter/material.dart';

import 'admin_data_service.dart';
import 'models/admin_overview_data.dart';

class AdminOverviewScreen extends StatefulWidget {
  const AdminOverviewScreen({super.key});

  @override
  State<AdminOverviewScreen> createState() => _AdminOverviewScreenState();
}

class _AdminOverviewScreenState extends State<AdminOverviewScreen> {
  final AdminDataService _dataService = const AdminDataService();

  Future<AdminOverviewMetrics>? _metricsFuture;

  @override
  void initState() {
    super.initState();
    _metricsFuture = _loadMetrics();
  }

  Future<AdminOverviewMetrics> _loadMetrics() async {
    try {
      return await _dataService.fetchOverviewMetrics();
    } on AdminDataException {
      rethrow;
    } catch (_) {
      throw const AdminDataException(
        'Unable to load dashboard metrics. Please try again.',
      );
    }
  }

  void _retry() {
    setState(() {
      _metricsFuture = _loadMetrics();
    });
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<AdminOverviewMetrics>(
      future: _metricsFuture,
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const _LoadingState();
        }

        if (snapshot.hasError) {
          return _ErrorState(onRetry: _retry);
        }

        if (!snapshot.hasData) {
          return const _EmptyState();
        }

        return _OverviewBody(metrics: snapshot.data!);
      },
    );
  }
}

class _LoadingState extends StatelessWidget {
  const _LoadingState();

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.all(24),
      children: [
        const Text(
          'Overview',
          style: TextStyle(
            fontSize: 20,
            fontWeight: FontWeight.w800,
            color: Colors.white,
            letterSpacing: -0.3,
          ),
        ),
        const SizedBox(height: 16),
        LayoutBuilder(
          builder: (context, constraints) {
            final crossAxisCount = constraints.maxWidth > 1100
                ? 4
                : constraints.maxWidth > 700
                    ? 2
                    : 1;

            return Wrap(
              spacing: 16,
              runSpacing: 16,
              children: List.generate(
                6,
                (index) => SizedBox(
                  width: (constraints.maxWidth -
                          (crossAxisCount - 1) * 16) /
                      crossAxisCount,
                  child: const _SkeletonCard(),
                ),
              ),
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
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: const Color(0xFF151B2E),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(
          color: const Color(0xFF29324A),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 44,
            height: 44,
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.06),
              borderRadius: BorderRadius.circular(12),
            ),
          ),
          const SizedBox(height: 16),
          Container(
            width: 80,
            height: 28,
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.06),
              borderRadius: BorderRadius.circular(6),
            ),
          ),
          const SizedBox(height: 6),
          Container(
            width: 120,
            height: 16,
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.04),
              borderRadius: BorderRadius.circular(4),
            ),
          ),
        ],
      ),
    );
  }
}

class _EmptyState extends StatelessWidget {
  const _EmptyState();

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(
            Icons.inbox_outlined,
            size: 48,
            color: Color(0xFF7E88A8),
          ),
          const SizedBox(height: 16),
          const Text(
            'No metrics available',
            style: TextStyle(
              fontSize: 16,
              color: Color(0xFF9AA3C2),
            ),
          ),
        ],
      ),
    );
  }
}

class _ErrorState extends StatelessWidget {
  const _ErrorState({
    required this.onRetry,
  });

  final VoidCallback onRetry;

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
              'Unable to load dashboard metrics',
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
            _RetryButton(onPressed: onRetry),
          ],
        ),
      ),
    );
  }
}

class _RetryButton extends StatelessWidget {
  const _RetryButton({
    required this.onPressed,
  });

  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    return ElevatedButton.icon(
      onPressed: onPressed,
      icon: const Icon(
        Icons.refresh_rounded,
        size: 18,
      ),
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
    );
  }
}

class _OverviewBody extends StatelessWidget {
  const _OverviewBody({
    required this.metrics,
  });

  final AdminOverviewMetrics metrics;

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.all(24),
      children: [
        const Text(
          'Overview',
          style: TextStyle(
            fontSize: 20,
            fontWeight: FontWeight.w800,
            color: Colors.white,
            letterSpacing: -0.3,
          ),
        ),
        const SizedBox(height: 6),
        const Text(
          'Live platform metrics',
          style: TextStyle(
            fontSize: 13,
            color: Color(0xFF7E88A8),
          ),
        ),
        const SizedBox(height: 20),
        LayoutBuilder(
          builder: (context, constraints) {
            final crossAxisCount = constraints.maxWidth > 1100
                ? 4
                : constraints.maxWidth > 700
                    ? 2
                    : 1;

            return Wrap(
              spacing: 16,
              runSpacing: 16,
              children: [
                _statCard(
                  constraints,
                  crossAxisCount,
                  icon: Icons.people_alt_outlined,
                  label: 'Total Users',
                  value: '${metrics.totalUsers}',
                ),
                _statCard(
                  constraints,
                  crossAxisCount,
                  icon: Icons.person_add_alt_1_outlined,
                  label: 'New Users Today',
                  value: '${metrics.newUsersToday}',
                ),
                _statCard(
                  constraints,
                  crossAxisCount,
                  icon: Icons.date_range_outlined,
                  label: 'New Users · 7 Days',
                  value: '${metrics.newUsers7d}',
                ),
                _statCard(
                  constraints,
                  crossAxisCount,
                  icon: Icons.calendar_month_outlined,
                  label: 'New Users · 30 Days',
                  value: '${metrics.newUsers30d}',
                ),
                _statCard(
                  constraints,
                  crossAxisCount,
                  icon: Icons.verified_outlined,
                  label: 'Verified Users',
                  value: '${metrics.verifiedUsers}',
                ),
                _statCard(
                  constraints,
                  crossAxisCount,
                  icon: Icons.pending_actions_outlined,
                  label: 'Pending Verification',
                  value: '${metrics.pendingVerification}',
                ),
                _statCard(
                  constraints,
                  crossAxisCount,
                  icon: Icons.public_outlined,
                  label: 'Public Profiles',
                  value: '${metrics.publicProfiles}',
                ),
                _statCard(
                  constraints,
                  crossAxisCount,
                  icon: Icons.lock_outline_rounded,
                  label: 'Private Profiles',
                  value: '${metrics.privateProfiles}',
                ),
                _statCard(
                  constraints,
                  crossAxisCount,
                  icon: Icons.event_available_outlined,
                  label: 'Active Plans',
                  value: '${metrics.activePlans}',
                ),
                _statCard(
                  constraints,
                  crossAxisCount,
                  icon: Icons.hub_outlined,
                  label: 'Active Connections',
                  value: '${metrics.activeConnections}',
                ),
                _statCard(
                  constraints,
                  crossAxisCount,
                  icon: Icons.forum_outlined,
                  label: 'Total Rooms',
                  value: '${metrics.totalRooms}',
                ),
                _statCard(
                  constraints,
                  crossAxisCount,
                  icon: Icons.report_problem_outlined,
                  label: 'Open Reports',
                  value: '${metrics.openReports}',
                ),
                _statCard(
                  constraints,
                  crossAxisCount,
                  icon: Icons.access_time_outlined,
                  label: 'Active Users',
                  value: metrics.activeUsers == null
                      ? '—'
                      : '${metrics.activeUsers}',
                ),
                _statCard(
                  constraints,
                  crossAxisCount,
                  icon: Icons.block_outlined,
                  label: 'Suspended / Banned',
                  value: metrics.suspendedBannedUsers == null
                      ? '—'
                      : '${metrics.suspendedBannedUsers}',
                ),
              ],
            );
          },
        ),
      ],
    );
  }

  Widget _statCard(
    BoxConstraints constraints,
    int crossAxisCount, {
    required IconData icon,
    required String label,
    required String value,
  }) {
    final width = (constraints.maxWidth -
            (crossAxisCount - 1) * 16) /
        crossAxisCount;

    return SizedBox(
      width: width,
      child: _StatCard(
        icon: icon,
        label: label,
        value: value,
      ),
    );
  }
}

class _StatCard extends StatelessWidget {
  const _StatCard({
    required this.icon,
    required this.label,
    required this.value,
  });

  final IconData icon;
  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Container(
      constraints: const BoxConstraints(
        minHeight: 148,
      ),
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: const Color(0xFF151B2E),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(
          color: const Color(0xFF29324A),
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.16),
            blurRadius: 20,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 44,
            height: 44,
            decoration: BoxDecoration(
              color: const Color(0xFF8B5CF6).withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(
                color: const Color(0xFF9D82FF).withValues(alpha: 0.14),
              ),
            ),
            child: Icon(
              icon,
              size: 21,
              color: const Color(0xFFB7A5FF),
            ),
          ),
          const Spacer(),
          Text(
            value,
            style: const TextStyle(
              fontSize: 28,
              fontWeight: FontWeight.w800,
              color: Colors.white,
              letterSpacing: -0.7,
            ),
          ),
          const SizedBox(height: 5),
          Text(
            label,
            style: const TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w500,
              color: Color(0xFF8E98B8),
            ),
          ),
        ],
      ),
    );
  }
}
