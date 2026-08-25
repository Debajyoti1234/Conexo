import 'package:flutter/material.dart';

import '../../features/home_connection_dashboard_cards.dart';
import '../../features/plans/plan_repository.dart';
import '../../features/plans/supabase_plan_repository.dart';

class HostedPlansPage extends StatefulWidget {
  const HostedPlansPage({super.key, this.repository = const SupabasePlanRepository()});

  final PlanRepository repository;

  @override
  State<HostedPlansPage> createState() => _HostedPlansPageState();
}

class _HostedPlansPageState extends State<HostedPlansPage> {
  List<_HostedPlanUi> _plans = const [];
  bool _loading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final experiences = await widget.repository.getPublishedExperiences();
      if (!mounted) return;
      final plans = <_HostedPlanUi>[];
      for (final exp in experiences) {
        final members = await widget.repository.getPlanMembers(exp.id);
        final joinedCount = members
            .where((m) => m.status == 'joined' && m.role != 'creator' && m.userId != exp.hostId)
            .length;
        plans.add(_HostedPlanUi(
          id: exp.id,
          name: exp.title,
          date: _formatDate(exp.date),
          time: exp.time,
          location: exp.city,
          color: exp.accent,
          memberCount: joinedCount,
        ));
      }
      if (!mounted) return;
      setState(() {
        _plans = plans;
        _loading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _error = e.toString();
        _loading = false;
      });
    }
  }

  String _formatDate(String shortDate) {
    final now = DateTime.now();
    const months = ['Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun', 'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'];
    const days = ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'];
    if (shortDate.contains(RegExp(r'^(Mon|Tue|Wed|Thu|Fri|Sat|Sun)'))) return shortDate;
    for (final month in months) {
      final regex = RegExp('$month (\\d+)');
      final match = regex.firstMatch(shortDate);
      if (match != null) {
        final day = int.parse(match.group(1)!);
        final date = DateTime(now.year, months.indexOf(month) + 1, day);
        return '${days[date.weekday - 1]}, $day $month ${date.year}';
      }
    }
    return shortDate;
  }

  void _openPlan(String planId) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('Opening plan $planId...'),
        backgroundColor: const Color(0xFF8B5CF6),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF0B1020),
      body: SafeArea(
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 18, 20, 6),
              child: Row(
                children: [
                  IconButton(
                    onPressed: () => Navigator.of(context).pop(),
                    icon: const Icon(Icons.arrow_back_rounded,
                        color: Colors.white),
                    tooltip: 'Back',
                  ),
                  const SizedBox(width: 8),
                  const Expanded(
                    child: Text(
                      'Hosted Plans',
                      style: TextStyle(
                        fontSize: 24,
                        fontWeight: FontWeight.w800,
                        color: Color(0xFFEAEEF9),
                        letterSpacing: -0.4,
                      ),
                    ),
                  ),
                ],
              ),
            ),
            Expanded(
              child: _loading
                  ? const Center(
                      child: CircularProgressIndicator(color: Color(0xFF8B5CF6)),
                    )
                  : _error != null
                      ? _ErrorState(message: _error!, onRetry: _load)
                      : _plans.isEmpty
                          ? _EmptyState(
                              icon: Icons.event_available_outlined,
                              message:
                                  'No hosted plans yet. Your plans will appear here.',
                            )
                          : ListView.builder(
                              padding:
                                  const EdgeInsets.fromLTRB(20, 10, 20, 100),
                              itemCount: _plans.length,
                              itemBuilder: (context, index) {
                                final plan = _plans[index];
                                return Padding(
                                  padding: const EdgeInsets.only(bottom: 12),
                                  child: _HostedPlanRow(
                                    plan: plan,
                                    onOpen: () => _openPlan(plan.id),
                                  ),
                                );
                              },
                            ),
            ),
          ],
        ),
      ),
    );
  }
}

class _HostedPlanRow extends StatelessWidget {
  const _HostedPlanRow({required this.plan, required this.onOpen});

  final _HostedPlanUi plan;
  final VoidCallback onOpen;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: const Color(0xFF141C31).withValues(alpha: .55),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: Colors.white.withValues(alpha: .08)),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Row(
          children: [
            Container(
              height: 46,
              width: 46,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                gradient: LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: [
                    plan.color,
                    Color.lerp(plan.color, const Color(0xFF7C3AED), 0.5) ??
                        plan.color,
                  ],
                ),
                boxShadow: [
                  BoxShadow(
                    color: plan.color.withValues(alpha: .45),
                    blurRadius: 16,
                    offset: const Offset(0, 6),
                  ),
                ],
              ),
              child: const Icon(Icons.event_rounded,
                  size: 22, color: Colors.white),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    plan.name,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w800,
                      letterSpacing: -0.2,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    '${plan.date} • ${plan.time}',
                    style: const TextStyle(
                      fontSize: 12.5,
                      color: Color(0xFF9DB2E8),
                    ),
                  ),
                ],
              ),
            ),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
              decoration: BoxDecoration(
                color: const Color(0xFF47D7A5).withValues(alpha: .12),
                borderRadius: BorderRadius.circular(10),
                border:
                    Border.all(color: const Color(0xFF47D7A5).withValues(alpha: .3)),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(Icons.people_rounded,
                      size: 12, color: Color(0xFF47D7A5)),
                  const SizedBox(width: 4),
                  Text(
                    '${plan.memberCount}',
                    style: const TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w800,
                      color: Color(0xFF47D7A5),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 12),
            ActionPill(
              label: 'Open Plan',
              icon: Icons.open_in_new_rounded,
              primary: true,
              onTap: onOpen,
            ),
          ],
        ),
      ),
    );
  }
}

class _ErrorState extends StatelessWidget {
  const _ErrorState({required this.message, required this.onRetry});

  final String message;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 72, horizontal: 28),
      child: Column(
        children: [
          Container(
            height: 58,
            width: 58,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: const Color(0xFFFF4D8D).withValues(alpha: .12),
            ),
            child: const Icon(Icons.wifi_off_rounded,
                size: 27, color: Color(0xFFFF4D8D)),
          ),
          const SizedBox(height: 14),
          Text(
            'Something went wrong',
            style: const TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.w800,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            message,
            textAlign: TextAlign.center,
            style: const TextStyle(
              fontSize: 13.5,
              color: Color(0xFFB9C3DC),
            ),
          ),
          const SizedBox(height: 18),
          FilledButton.icon(
            onPressed: onRetry,
            icon: const Icon(Icons.refresh_rounded, size: 18),
            label: const Text('Retry'),
          ),
        ],
      ),
    );
  }
}

class _EmptyState extends StatelessWidget {
  const _EmptyState({required this.icon, required this.message});

  final IconData icon;
  final String message;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 72, horizontal: 28),
        child: Column(
          children: [
            Container(
              height: 58,
              width: 58,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: const Color(0xFF7C3AED).withValues(alpha: .14),
              ),
              child: Icon(icon, size: 27, color: const Color(0xFFB7A5FF)),
            ),
            const SizedBox(height: 14),
            Text(
              message,
              textAlign: TextAlign.center,
              style: const TextStyle(
                fontSize: 13.5,
                height: 1.45,
                fontWeight: FontWeight.w600,
                color: Color(0xFFB9C3DC),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _HostedPlanUi {
  const _HostedPlanUi({
    required this.id,
    required this.name,
    required this.date,
    required this.time,
    required this.location,
    required this.color,
    required this.memberCount,
  });

  final String id;
  final String name;
  final String date;
  final String time;
  final String location;
  final Color color;
  final int memberCount;
}
