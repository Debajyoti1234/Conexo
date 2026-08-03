import 'dart:async';

import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'home_connection_dashboard_cards.dart';
import 'home_connection_dashboard_data.dart';
import 'home_discovery_animations.dart';

/// The premium Connections dashboard — the user's relationship hub.
///
/// Owns all mutable state (network, requests, pending, hosted plans) so the
/// whole screen stays data-driven and animated. Section expansion state is
/// persisted locally via [SharedPreferences] and restored when the user
/// returns to the tab. No Firebase / backend involvement.
class ConnectionsDashboard extends StatefulWidget {
  const ConnectionsDashboard({super.key});

  @override
  State<ConnectionsDashboard> createState() => _ConnectionsDashboardState();
}

class _ConnectionsDashboardState extends State<ConnectionsDashboard> {
  static const _sectionIds = ['network', 'requests', 'pending', 'hosted'];

  late final List<NetworkConnection> _network = List.of(demoNetwork);
  late final List<IncomingRequest> _requests = List.of(demoRequests);
  late final List<PendingRequest> _pending = List.of(demoPending);
  late final List<HostedPlan> _plans = _copyPlans(demoHostedPlans);

  /// IDs currently animating out of the list (fade + collapse).
  final Set<String> _removing = <String>{};

  final Map<String, bool> _sectionExpanded = {
    'network': true,
    'requests': false,
    'pending': false,
    'hosted': true,
  };
  final Map<String, bool> _planExpanded = <String, bool>{};
  final Map<String, GlobalKey> _sectionKeys = {
    for (final id in _sectionIds) id: GlobalKey(),
  };
  final ScrollController _scrollController = ScrollController();
  SharedPreferences? _prefs;

  @override
  void initState() {
    super.initState();
    _restorePreferences();
  }

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

  // -------------------------------------------------------------------------
  // Local preference persistence (UI state only)
  // -------------------------------------------------------------------------

  Future<void> _restorePreferences() async {
    final prefs = await SharedPreferences.getInstance();
    if (!mounted) return;
    setState(() {
      _prefs = prefs;
      for (final id in _sectionIds) {
        final stored = prefs.getBool('cnx_section_$id');
        if (stored != null) _sectionExpanded[id] = stored;
      }
      for (final plan in _plans) {
        final stored = prefs.getBool('cnx_plan_${plan.id}');
        if (stored != null) _planExpanded[plan.id] = stored;
      }
    });
  }

  void _setSectionExpanded(String id, {required bool value}) {
    setState(() => _sectionExpanded[id] = value);
    _prefs?.setBool('cnx_section_$id', value);
  }

  void _setPlanExpanded(String id, {required bool value}) {
    setState(() => _planExpanded[id] = value);
    _prefs?.setBool('cnx_plan_$id', value);
  }

  // -------------------------------------------------------------------------
  // Scroll shortcuts from the summary cards
  // -------------------------------------------------------------------------

  void _scrollToSection(String id) {
    if (_sectionExpanded[id] != true) _setSectionExpanded(id, value: true);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final sectionContext = _sectionKeys[id]?.currentContext;
      if (sectionContext == null) return;
      Scrollable.ensureVisible(
        sectionContext,
        duration: const Duration(milliseconds: 550),
        curve: Curves.easeInOutCubic,
        alignment: 0.05,
      );
    });
  }

  // -------------------------------------------------------------------------
  // Mutations (all local, animated)
  // -------------------------------------------------------------------------

  void _animateRemoval(String id, VoidCallback complete) {
    setState(() => _removing.add(id));
    Timer(const Duration(milliseconds: 360), () {
      if (!mounted) return;
      setState(() {
        _removing.remove(id);
        complete();
      });
    });
  }

  void _acceptRequest(IncomingRequest request) {
    _animateRemoval(request.id, () {
      _requests.removeWhere((r) => r.id == request.id);
      _network.insert(
        0,
        NetworkConnection(
          id: 'network_${request.id}',
          name: request.name,
          age: request.age,
          occupation: request.occupation,
          city: request.city,
          connectedSince: 'Connected just now',
          mutualInterests: request.mutualInterests,
          color: request.color,
          portrait: request.portrait,
        ),
      );
    });
  }

  void _declineRequest(IncomingRequest request) {
    _animateRemoval(
      request.id,
      () => _requests.removeWhere((r) => r.id == request.id),
    );
  }

  void _cancelPending(PendingRequest request) {
    _animateRemoval(
      request.id,
      () => _pending.removeWhere((r) => r.id == request.id),
    );
  }

  void _approveJoin(HostedPlan plan, JoinRequest request) {
    _animateRemoval(request.id, () {
      plan.joinRequests.removeWhere((r) => r.id == request.id);
      plan.participants.add(
        Participant(
          id: 'participant_${request.id}',
          name: request.name,
          color: request.color,
          portrait: request.portrait,
        ),
      );
    });
  }

  void _declineJoin(HostedPlan plan, JoinRequest request) {
    _animateRemoval(
      request.id,
      () => plan.joinRequests.removeWhere((r) => r.id == request.id),
    );
  }

  // -------------------------------------------------------------------------
  // Build
  // -------------------------------------------------------------------------

  @override
  Widget build(BuildContext context) {
    return ListView(
      controller: _scrollController,
      physics: const BouncingScrollPhysics(
        parent: AlwaysScrollableScrollPhysics(),
      ),
      padding: const EdgeInsets.fromLTRB(2, 8, 2, 150),
      children: [
        const Text(
          'Connections',
          style: TextStyle(
            fontSize: 32,
            fontWeight: FontWeight.w800,
            letterSpacing: -0.6,
          ),
        ),
        const SizedBox(height: 8),
        const Text(
          'Your network, requests and hosted plans in one place.',
          style: TextStyle(
            fontSize: 14.5,
            color: Color(0xFFAFB8D4),
            height: 1.4,
          ),
        ),
        const SizedBox(height: 24),
        _buildSummaryGrid(),
        const SizedBox(height: 26),
        _buildNetworkSection(),
        _buildRequestsSection(),
        _buildPendingSection(),
        _buildHostedPlansSection(),
      ],
    );
  }

  // -- Summary cards --------------------------------------------------------

  Widget _buildSummaryGrid() {
    return GridView.count(
      crossAxisCount: 2,
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      childAspectRatio: 1.9,
      mainAxisSpacing: 10,
      crossAxisSpacing: 10,
      children: [
        _SummaryCard(
          index: 0,
          sectionId: 'network',
          icon: Icons.handshake_rounded,
          label: 'Network',
          count: _network.length,
          accent: const Color(0xFF47D7A5),
          onTap: _scrollToSection,
        ),
        _SummaryCard(
          index: 1,
          sectionId: 'requests',
          icon: Icons.favorite_rounded,
          label: 'Requests',
          count: _requests.length,
          accent: const Color(0xFFFF4D8D),
          onTap: _scrollToSection,
        ),
        _SummaryCard(
          index: 2,
          sectionId: 'pending',
          icon: Icons.hourglass_top_rounded,
          label: 'Pending',
          count: _pending.length,
          accent: const Color(0xFFFFC24D),
          onTap: _scrollToSection,
        ),
        _SummaryCard(
          index: 3,
          sectionId: 'hosted',
          icon: Icons.celebration_rounded,
          label: 'Hosted Plans',
          count: _plans.length,
          accent: const Color(0xFF7C3AED),
          onTap: _scrollToSection,
        ),
      ],
    );
  }

  // -- Sections -------------------------------------------------------------

  Widget _buildNetworkSection() {
    final content = _network.isEmpty
        ? const _EmptyState(
            icon: Icons.group_add_outlined,
            message:
                'Start building your circle by connecting with amazing people.',
          )
        : Column(
            children: [
              for (final connection in _network)
                CardDismiss(
                  key: ValueKey<String>('network-${connection.id}'),
                  visible: !_removing.contains(connection.id),
                  child: NetworkConnectionCard(connection: connection),
                ),
            ],
          );
    return _ExpandableSection(
      sectionKey: _sectionKeys['network']!,
      expanded: _sectionExpanded['network']!,
      onToggle: () => _setSectionExpanded(
        'network',
        value: !_sectionExpanded['network']!,
      ),
      icon: Icons.handshake_rounded,
      title: 'Your Network',
      count: _network.length,
      accent: const Color(0xFF47D7A5),
      child: content,
    );
  }

  Widget _buildRequestsSection() {
    final content = _requests.isEmpty
        ? const _EmptyState(
            icon: Icons.favorite_border_rounded,
            message: 'No connection requests yet.',
          )
        : Column(
            children: [
              for (final request in _requests)
                CardDismiss(
                  key: ValueKey<String>('request-${request.id}'),
                  visible: !_removing.contains(request.id),
                  child: IncomingRequestCard(
                    request: request,
                    onAccept: () => _acceptRequest(request),
                    onDecline: () => _declineRequest(request),
                  ),
                ),
            ],
          );
    return _ExpandableSection(
      sectionKey: _sectionKeys['requests']!,
      expanded: _sectionExpanded['requests']!,
      onToggle: () => _setSectionExpanded(
        'requests',
        value: !_sectionExpanded['requests']!,
      ),
      icon: Icons.favorite_rounded,
      title: 'Connection Requests',
      count: _requests.length,
      accent: const Color(0xFFFF4D8D),
      child: content,
    );
  }

  Widget _buildPendingSection() {
    final content = _pending.isEmpty
        ? const _EmptyState(
            icon: Icons.hourglass_empty_rounded,
            message: 'No pending requests.',
          )
        : Column(
            children: [
              for (final request in _pending)
                CardDismiss(
                  key: ValueKey<String>('pending-${request.id}'),
                  visible: !_removing.contains(request.id),
                  child: PendingRequestCard(
                    request: request,
                    onCancel: () => _cancelPending(request),
                  ),
                ),
            ],
          );
    return _ExpandableSection(
      sectionKey: _sectionKeys['pending']!,
      expanded: _sectionExpanded['pending']!,
      onToggle: () => _setSectionExpanded(
        'pending',
        value: !_sectionExpanded['pending']!,
      ),
      icon: Icons.hourglass_top_rounded,
      title: 'Pending Connections',
      count: _pending.length,
      accent: const Color(0xFFFFC24D),
      child: content,
    );
  }

  Widget _buildHostedPlansSection() {
    final content = _plans.isEmpty
        ? const _EmptyState(
            icon: Icons.event_available_outlined,
            message: "You haven't hosted any plans yet.",
          )
        : Column(
            children: [for (final plan in _plans) _buildHostedPlanCard(plan)],
          );
    return _ExpandableSection(
      sectionKey: _sectionKeys['hosted']!,
      expanded: _sectionExpanded['hosted']!,
      onToggle: () => _setSectionExpanded(
        'hosted',
        value: !_sectionExpanded['hosted']!,
      ),
      icon: Icons.celebration_rounded,
      title: 'Hosted Plans',
      count: _plans.length,
      accent: const Color(0xFF7C3AED),
      child: content,
    );
  }

  // -- Hosted plan card (data-driven, independently expandable) -------------

  Widget _buildHostedPlanCard(HostedPlan plan) {
    final expanded = _planExpanded[plan.id] ?? false;
    return Container(
      key: ValueKey<String>('plan-${plan.id}'),
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: const Color(0xFF141C31).withValues(alpha: .6),
        borderRadius: BorderRadius.circular(22),
        border: Border.all(color: Colors.white.withValues(alpha: .1)),
      ),
      clipBehavior: Clip.antiAlias,
      child: Column(
        children: [
          Material(
            color: Colors.transparent,
            child: InkWell(
              onTap: () => _setPlanExpanded(plan.id, value: !expanded),
              child: Padding(
                padding: const EdgeInsets.fromLTRB(16, 14, 16, 14),
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
                            Color.lerp(
                                  plan.color,
                                  const Color(0xFF7C3AED),
                                  0.5,
                                ) ??
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
                      child: const Icon(
                        Icons.event_rounded,
                        size: 22,
                        color: Colors.white,
                      ),
                    ),
                    const SizedBox(width: 14),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            plan.name,
                            style: const TextStyle(
                              fontSize: 16.5,
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
                    if (plan.joinRequests.isNotEmpty)
                      Padding(
                        padding: const EdgeInsets.only(right: 10),
                        child: _CountBadge(
                          count: plan.joinRequests.length,
                          accent: const Color(0xFFFFC24D),
                        ),
                      ),
                    AnimatedRotation(
                      turns: expanded ? 0.5 : 0,
                      duration: const Duration(milliseconds: 320),
                      curve: Curves.easeInOutCubic,
                      child: const Icon(
                        Icons.expand_more_rounded,
                        color: Color(0xFFB9C3DC),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
          AnimatedSize(
            duration: const Duration(milliseconds: 380),
            curve: Curves.easeInOutCubic,
            alignment: Alignment.topCenter,
            child: expanded
                ? Padding(
                    padding: const EdgeInsets.fromLTRB(16, 0, 16, 18),
                    child: EntranceFade(
                      offset: const Offset(0, 0.06),
                      scaleFrom: 0.985,
                      duration: const Duration(milliseconds: 420),
                      child: _buildPlanBody(plan),
                    ),
                  )
                : const SizedBox(width: double.infinity),
          ),
        ],
      ),
    );
  }

  Widget _buildPlanBody(HostedPlan plan) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            _PlanMetaChip(icon: Icons.calendar_today_rounded, label: plan.date),
            _PlanMetaChip(icon: Icons.schedule_rounded, label: plan.time),
            _PlanMetaChip(
              icon: Icons.location_on_outlined,
              label: plan.location,
            ),
          ],
        ),
        const SizedBox(height: 18),
        Row(
          children: [
            const Text(
              'Join Requests',
              style: TextStyle(fontSize: 14, fontWeight: FontWeight.w800),
            ),
            const SizedBox(width: 8),
            _CountBadge(
              count: plan.joinRequests.length,
              accent: const Color(0xFFFFC24D),
            ),
          ],
        ),
        const SizedBox(height: 10),
        if (plan.joinRequests.isEmpty)
          const _InlineEmpty(
            icon: Icons.person_add_alt_1_outlined,
            message: 'No join requests yet.',
          )
        else
          Column(
            children: [
              for (final request in plan.joinRequests)
                CardDismiss(
                  key: ValueKey<String>('join-${request.id}'),
                  visible: !_removing.contains(request.id),
                  spacing: 10,
                  child: JoinRequestRow(
                    request: request,
                    onApprove: () => _approveJoin(plan, request),
                    onDecline: () => _declineJoin(plan, request),
                  ),
                ),
            ],
          ),
        const SizedBox(height: 18),
        Row(
          children: [
            const Text(
              'Participants',
              style: TextStyle(fontSize: 14, fontWeight: FontWeight.w800),
            ),
            const SizedBox(width: 8),
            _CountBadge(
              count: plan.participants.length,
              accent: const Color(0xFF47D7A5),
            ),
          ],
        ),
        const SizedBox(height: 10),
        if (plan.participants.isEmpty)
          const _InlineEmpty(
            icon: Icons.people_outline_rounded,
            message: 'No participants yet.',
          )
        else
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              for (final participant in plan.participants)
                ParticipantChip(
                  key: ValueKey<String>('participant-${participant.id}'),
                  participant: participant,
                ),
            ],
          ),
      ],
    );
  }

  static List<HostedPlan> _copyPlans(List<HostedPlan> source) => [
    for (final plan in source)
      HostedPlan(
        id: plan.id,
        name: plan.name,
        date: plan.date,
        time: plan.time,
        location: plan.location,
        color: plan.color,
        joinRequests: List.of(plan.joinRequests),
        participants: List.of(plan.participants),
      ),
  ];
}

// ---------------------------------------------------------------------------
// Summary card
// ---------------------------------------------------------------------------

class _SummaryCard extends StatelessWidget {
  const _SummaryCard({
    required this.index,
    required this.sectionId,
    required this.icon,
    required this.label,
    required this.count,
    required this.accent,
    required this.onTap,
  });

  final int index;
  final String sectionId;
  final IconData icon;
  final String label;
  final int count;
  final Color accent;
  final ValueChanged<String> onTap;

  @override
  Widget build(BuildContext context) {
    return EntranceFade(
      delay: Duration(milliseconds: index * 80),
      offset: const Offset(0, 0.1),
      duration: const Duration(milliseconds: 460),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(22),
          onTap: () => onTap(sectionId),
          child: Ink(
            decoration: BoxDecoration(
              color: const Color(0xFF182039).withValues(alpha: .78),
              borderRadius: BorderRadius.circular(22),
              border: Border.all(color: Colors.white.withValues(alpha: .09)),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: .22),
                  blurRadius: 18,
                  offset: const Offset(0, 8),
                ),
              ],
            ),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 14),
              child: Row(
                children: [
                  Container(
                    height: 42,
                    width: 42,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: accent.withValues(alpha: .16),
                    ),
                    child: Icon(icon, size: 21, color: accent),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        AnimatedSwitcher(
                          duration: const Duration(milliseconds: 380),
                          switchInCurve: Curves.easeOutCubic,
                          switchOutCurve: Curves.easeInCubic,
                          transitionBuilder: (child, animation) =>
                              FadeTransition(
                                opacity: animation,
                                child: ScaleTransition(
                                  scale: Tween<double>(begin: 0.82, end: 1)
                                      .animate(animation),
                                  child: child,
                                ),
                              ),
                          child: Text(
                            '$count',
                            key: ValueKey<int>(count),
                            style: const TextStyle(
                              fontSize: 24,
                              fontWeight: FontWeight.w800,
                              letterSpacing: -0.4,
                              height: 1.1,
                            ),
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          label,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w700,
                            color: Color(0xFFB9C3DC),
                          ),
                        ),
                      ],
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

// ---------------------------------------------------------------------------
// Expandable section shell
// ---------------------------------------------------------------------------

class _ExpandableSection extends StatelessWidget {
  const _ExpandableSection({
    required this.sectionKey,
    required this.expanded,
    required this.onToggle,
    required this.icon,
    required this.title,
    required this.count,
    required this.accent,
    required this.child,
  });

  final GlobalKey sectionKey;
  final bool expanded;
  final VoidCallback onToggle;
  final IconData icon;
  final String title;
  final int count;
  final Color accent;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Container(
      key: sectionKey,
      margin: const EdgeInsets.only(bottom: 18),
      decoration: BoxDecoration(
        color: const Color(0xFF171F35).withValues(alpha: .55),
        borderRadius: BorderRadius.circular(26),
        border: Border.all(color: Colors.white.withValues(alpha: .09)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: .18),
            blurRadius: 20,
            offset: const Offset(0, 10),
          ),
        ],
      ),
      clipBehavior: Clip.antiAlias,
      child: Column(
        children: [
          Material(
            color: Colors.transparent,
            child: InkWell(
              onTap: onToggle,
              child: Padding(
                padding: const EdgeInsets.fromLTRB(18, 16, 16, 16),
                child: Row(
                  children: [
                    Container(
                      height: 40,
                      width: 40,
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(13),
                        color: accent.withValues(alpha: .15),
                      ),
                      child: Icon(icon, size: 20, color: accent),
                    ),
                    const SizedBox(width: 13),
                    Expanded(
                      child: Text(
                        title,
                        style: const TextStyle(
                          fontSize: 16.5,
                          fontWeight: FontWeight.w800,
                          letterSpacing: -0.2,
                        ),
                      ),
                    ),
                    Padding(
                      padding: const EdgeInsets.only(right: 6),
                      child: _CountBadge(count: count, accent: accent),
                    ),
                    AnimatedRotation(
                      turns: expanded ? 0.5 : 0,
                      duration: const Duration(milliseconds: 320),
                      curve: Curves.easeInOutCubic,
                      child: const Icon(
                        Icons.expand_more_rounded,
                        color: Color(0xFFB9C3DC),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
          AnimatedSize(
            duration: const Duration(milliseconds: 380),
            curve: Curves.easeInOutCubic,
            alignment: Alignment.topCenter,
            child: expanded
                ? Padding(
                    padding: const EdgeInsets.fromLTRB(14, 0, 14, 16),
                    child: EntranceFade(
                      offset: const Offset(0, 0.06),
                      scaleFrom: 0.985,
                      duration: const Duration(milliseconds: 420),
                      child: child,
                    ),
                  )
                : const SizedBox(width: double.infinity),
          ),
        ],
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Small building blocks
// ---------------------------------------------------------------------------

class _CountBadge extends StatelessWidget {
  const _CountBadge({required this.count, required this.accent});

  final int count;
  final Color accent;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 4),
      decoration: BoxDecoration(
        color: accent.withValues(alpha: .15),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: accent.withValues(alpha: .35)),
      ),
      child: AnimatedSwitcher(
        duration: const Duration(milliseconds: 320),
        switchInCurve: Curves.easeOutCubic,
        switchOutCurve: Curves.easeInCubic,
        transitionBuilder: (child, animation) => FadeTransition(
          opacity: animation,
          child: ScaleTransition(
            scale: Tween<double>(begin: 0.85, end: 1).animate(animation),
            child: child,
          ),
        ),
        child: Text(
          '$count',
          key: ValueKey<int>(count),
          style: TextStyle(
            fontSize: 12,
            fontWeight: FontWeight.w800,
            color: accent,
          ),
        ),
      ),
    );
  }
}

class _PlanMetaChip extends StatelessWidget {
  const _PlanMetaChip({required this.icon, required this.label});

  final IconData icon;
  final String label;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 11, vertical: 7),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: .06),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.white.withValues(alpha: .1)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 13, color: const Color(0xFFB9C3DC)),
          const SizedBox(width: 6),
          Text(
            label,
            style: const TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w600,
              color: Color(0xFFD3DBEF),
            ),
          ),
        ],
      ),
    );
  }
}

/// Premium empty state for a dashboard section.
class _EmptyState extends StatelessWidget {
  const _EmptyState({required this.icon, required this.message});

  final IconData icon;
  final String message;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 34),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: .04),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: Colors.white.withValues(alpha: .07)),
      ),
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
    );
  }
}

/// Compact inline empty note used inside a hosted plan card.
class _InlineEmpty extends StatelessWidget {
  const _InlineEmpty({required this.icon, required this.message});

  final IconData icon;
  final String message;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(vertical: 16),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: .04),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: Colors.white.withValues(alpha: .07)),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(icon, size: 16, color: const Color(0xFF9DB2E8)),
          const SizedBox(width: 8),
          Text(
            message,
            style: const TextStyle(
              fontSize: 12.5,
              fontWeight: FontWeight.w600,
              color: Color(0xFF9DB2E8),
            ),
          ),
        ],
      ),
    );
  }
}
