import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'home_discovery_data.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});
  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  int _index = 0;
  bool _requestSent = false;
  bool _connected = false;
  int _direction = 1;
  String _selectedFilter = 'All';

  void _move(int direction) {
    setState(() {
      _direction = direction;
      _index =
          (_index + direction + peopleAroundYou.length) %
          peopleAroundYou.length;
      _requestSent = false;
      _connected = false;
    });
  }

  void _sendRequest() {
    showModalBottomSheet<void>(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (sheetContext) => Container(
        padding: const EdgeInsets.all(24),
        decoration: BoxDecoration(
          color: const Color(0xFF172039).withValues(alpha: .96),
          borderRadius: const BorderRadius.vertical(top: Radius.circular(30)),
          border: Border.all(color: Colors.white12),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Connect with ${peopleAroundYou[_index].name}?', style: const TextStyle(fontSize: 22, fontWeight: FontWeight.w800)),
            const SizedBox(height: 10),
            const Text('Your request will be sent. They can choose whether to accept it. No one can message you until they approve.', style: TextStyle(color: Color(0xFFB9C3DC), height: 1.45)),
            const SizedBox(height: 24),
            Row(children: [
              Expanded(child: OutlinedButton(onPressed: () => Navigator.of(sheetContext).pop(), child: const Text('Cancel'))),
              const SizedBox(width: 12),
              Expanded(child: FilledButton(onPressed: () { HapticFeedback.lightImpact(); Navigator.of(sheetContext).pop(); setState(() => _requestSent = true); Future<void>.delayed(const Duration(seconds: 5), () { if (mounted) setState(() { _requestSent = false; _connected = true; }); }); }, child: const Text('Send Request'))),
            ]),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final person = peopleAroundYou[_index];
    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          children: [
            AnimatedSwitcher(
              duration: const Duration(milliseconds: 300),
              child: Align(
                key: ValueKey<int>(DateTime.now().hour),
                alignment: Alignment.centerLeft,
                child: Text(
                  _greeting(),
                  style: const TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ),
            ),
            const SizedBox(height: 12),
            SizedBox(
              height: 42,
              child: GestureDetector(
                onLongPress: () => _showFilters(context),
                child: ListView.separated(
                  scrollDirection: Axis.horizontal,
                  itemCount: _discoveryFilters.length,
                  separatorBuilder: (_, _) => const SizedBox(width: 8),
                  itemBuilder: (context, index) {
                    final filter = _discoveryFilters[index];
                    return _DiscoveryFilterChip(
                      label: filter,
                      selected: _selectedFilter == filter,
                      onTap: () => setState(() => _selectedFilter = filter),
                    );
                  },
                ),
              ),
            ),
            const SizedBox(height: 16),
            Expanded(
              child: AnimatedSwitcher(
                duration: const Duration(milliseconds: 300),
                switchInCurve: Curves.easeInOutCubic,
                switchOutCurve: Curves.easeInOutCubic,
                transitionBuilder: (child, animation) => SlideTransition(
                  position: Tween<Offset>(
                    begin: Offset(_direction.toDouble(), 0),
                    end: Offset.zero,
                  ).animate(animation),
                  child: FadeTransition(
                    opacity: animation,
                    child: ScaleTransition(
                      scale: Tween<double>(
                        begin: .96,
                        end: 1,
                      ).animate(animation),
                      child: child,
                    ),
                  ),
                ),
                child: _FullProfile(
                  key: ValueKey(person.name),
                  person: person,
                  counter: 'Nearby • ${_index + 1} / 27',
                  requestSent: _requestSent,
                  connected: _connected,
                ),
              ),
            ),
            const SizedBox(height: 16),
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                _Arrow(icon: Icons.arrow_back_rounded, onTap: () => _move(-1)),
                const SizedBox(width: 28),
                _ConnectButton(sent: _requestSent, onTap: _sendRequest),
                const SizedBox(width: 28),
                _Arrow(
                  icon: Icons.arrow_forward_rounded,
                  onTap: () => _move(1),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  String _greeting() {
    final hour = DateTime.now().hour;
    if (hour < 5 || hour >= 22) return 'Still Awake? 🌌';
    if (hour < 12) return 'Good Morning ☀️';
    if (hour < 17) return 'Good Afternoon 🌤';
    return 'Good Evening 🌙';
  }

  void _showFilters(BuildContext context) {
    showModalBottomSheet<void>(
      context: context,
      backgroundColor: Colors.transparent,
      sheetAnimationStyle: const AnimationStyle(
        duration: Duration(milliseconds: 300),
        curve: Curves.easeInOutCubic,
      ),
      builder: (_) => const _FilterPreferencesSheet(),
    );
  }
}

class _FilterPreferencesSheet extends StatelessWidget {
  const _FilterPreferencesSheet();

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.fromLTRB(24, 14, 24, 34),
    decoration: BoxDecoration(
      color: const Color(0xFF172039).withValues(alpha: .97),
      borderRadius: const BorderRadius.vertical(top: Radius.circular(32)),
      border: Border.all(color: Colors.white.withValues(alpha: .12)),
    ),
    child: SafeArea(
      top: false,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: const [
          Center(child: SizedBox(width: 38, child: Divider(thickness: 3))),
          SizedBox(height: 20),
          Text(
            'Discovery preferences',
            style: TextStyle(fontSize: 20, fontWeight: FontWeight.w800),
          ),
          SizedBox(height: 20),
          _PreferenceGroup(
            title: 'Distance',
            values: ['1 km', '3 km', '5 km', '10 km'],
          ),
          _PreferenceGroup(
            title: 'Availability',
            values: ['Available Now', 'Today', 'This Week'],
          ),
          _PreferenceGroup(
            title: 'Verification',
            values: ['Verified Only', 'Everyone'],
          ),
          _PreferenceGroup(
            title: 'Sort',
            values: ['Closest', 'Best Match', 'Recently Joined', 'Most Active'],
          ),
        ],
      ),
    ),
  );
}

class _PreferenceGroup extends StatelessWidget {
  const _PreferenceGroup({required this.title, required this.values});
  final String title;
  final List<String> values;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.only(bottom: 18),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(title, style: const TextStyle(fontWeight: FontWeight.w800)),
        const SizedBox(height: 9),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: values.map((value) => Chip(label: Text(value))).toList(),
        ),
      ],
    ),
  );
}

const _discoveryFilters = <String>[
  'All',
  'Nearby',
  'Coffee',
  'Walk',
  'Music',
  'Study',
  'Verified',
  'Available Now',
  'New',
  'Shared Interests',
];

class _DiscoveryFilterChip extends StatelessWidget {
  const _DiscoveryFilterChip({
    required this.label,
    required this.selected,
    required this.onTap,
  });
  final String label;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) => AnimatedContainer(
    duration: const Duration(milliseconds: 240),
    decoration: BoxDecoration(
      color: selected
          ? const Color(0xFF7C3AED)
          : Colors.white.withValues(alpha: .08),
      borderRadius: BorderRadius.circular(16),
      border: Border.all(
        color: Colors.white.withValues(alpha: selected ? .0 : .12),
      ),
    ),
    child: Material(
      color: Colors.transparent,
      child: InkWell(
        borderRadius: BorderRadius.circular(16),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
          child: Text(
            label,
            style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w700),
          ),
        ),
      ),
    ),
  );
}

class _FullProfile extends StatelessWidget {
  const _FullProfile({
    required super.key,
    required this.person,
    required this.counter,
    required this.requestSent,
    required this.connected,
  });
  final DiscoveryPerson person;
  final String counter;
  final bool requestSent;
  final bool connected;
  @override
  Widget build(BuildContext context) => Stack(
    fit: StackFit.expand,
    children: [
      Container(
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(30),
          gradient: LinearGradient(
            colors: [person.color, const Color(0xFF0A0F1F)],
          ),
        ),
        child: Center(
          child: CircleAvatar(
            radius: 105,
            backgroundColor: Colors.white24,
            child: Text(
              person.name[0],
              style: const TextStyle(fontSize: 80, fontWeight: FontWeight.w800),
            ),
          ),
        ),
      ),
      Positioned(top: 18, left: 18, child: _Badge(label: 'Verified')),
      Positioned(
        top: 18,
        right: 18,
        child: AnimatedSwitcher(
          duration: const Duration(milliseconds: 300),
          child: _Badge(key: ValueKey(counter), label: counter),
        ),
      ),
      const Positioned(
        top: 58,
        left: 18,
        child: _Badge(label: '● Available now'),
      ),
      Positioned(
        left: 12,
        right: 12,
        bottom: 12,
        child: _ProfileInfo(person: person, requestSent: requestSent, connected: connected),
      ),
    ],
  );
}

class _ProfileInfo extends StatelessWidget {
  const _ProfileInfo({required this.person, required this.requestSent, required this.connected});
  final DiscoveryPerson person;
  final bool requestSent;
  final bool connected;
  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.all(20),
    decoration: BoxDecoration(
      color: const Color(0xFF172039).withValues(alpha: .9),
      borderRadius: BorderRadius.circular(26),
    ),
    child: Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          '${person.name}, ${person.age}',
          style: const TextStyle(fontSize: 26, fontWeight: FontWeight.w800),
        ),
        Text(person.distance),
        const SizedBox(height: 10),
        Wrap(
          spacing: 6,
          children: person.tags.map((tag) => Chip(label: Text(tag))).toList(),
        ),
        const SizedBox(height: 8),
        Text(person.introduction),
        const SizedBox(height: 16),
        const _OpenToday(),
        if (requestSent)
          const Padding(
            padding: EdgeInsets.only(top: 10),
            child: Text(
              '✓ Request Sent',
              style: TextStyle(
                color: Color(0xFF22D3EE),
                fontWeight: FontWeight.w800,
              ),
            ),
          ),
        if (connected) const Padding(padding: EdgeInsets.only(top: 10), child: Text('✨ You’re Connected', style: TextStyle(color: Color(0xFF22D3EE), fontWeight: FontWeight.w800))),
      ],
    ),
  );
}

class _OpenToday extends StatelessWidget {
  const _OpenToday();

  static const _items = <String>[
    '☕ Coffee',
    '🚶 Walk',
    'House Parties',
    'Clubbing',
    'Cafe Hunting',
    '🎵 Music',
    '📚 Study',
    '🍽 Dinner',
    '🎮 Gaming',
    '📷 Photography',
    '💬 Conversation',
  ];

  @override
  Widget build(BuildContext context) {
    return AnimatedOpacity(
      duration: const Duration(milliseconds: 300),
      opacity: 1,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Open Today',
            style: TextStyle(fontWeight: FontWeight.w800),
          ),
          const SizedBox(height: 8),
          Wrap(
            spacing: 7,
            runSpacing: 7,
            children: _items
                .map((item) => _OpenTodayChip(label: item))
                .toList(),
          ),
        ],
      ),
    );
  }
}

class _OpenTodayChip extends StatelessWidget {
  const _OpenTodayChip({required this.label});
  final String label;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: .08),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: Colors.white.withValues(alpha: .1)),
      ),
      child: Text(
        label,
        style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600),
      ),
    );
  }
}

class _ConnectButton extends StatelessWidget {
  const _ConnectButton({required this.sent, required this.onTap});
  final bool sent;
  final VoidCallback onTap;
  @override
  Widget build(BuildContext context) => GestureDetector(
    onTap: sent ? null : onTap,
    child: AnimatedContainer(
      duration: const Duration(milliseconds: 300),
      height: 70,
      width: 70,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        gradient: const LinearGradient(
          colors: [Color(0xFF7C3AED), Color(0xFF22D3EE)],
        ),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF7C3AED).withValues(alpha: .45),
            blurRadius: 24,
          ),
        ],
      ),
      child: Icon(sent ? Icons.check_rounded : Icons.auto_awesome_rounded),
    ),
  );
}

class _Badge extends StatelessWidget {
  const _Badge({required this.label, super.key});
  final String label;
  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.all(8),
    decoration: BoxDecoration(
      color: Colors.black38,
      borderRadius: BorderRadius.circular(14),
    ),
    child: Text(label),
  );
}

class _Arrow extends StatelessWidget {
  const _Arrow({required this.icon, required this.onTap});
  final IconData icon;
  final VoidCallback onTap;
  @override
  Widget build(BuildContext context) => CircleAvatar(
    radius: 28,
    backgroundColor: const Color(0xFF1A2238),
    child: IconButton(onPressed: onTap, icon: Icon(icon)),
  );
}
