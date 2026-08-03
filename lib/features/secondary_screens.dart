import 'package:flutter/material.dart';

import '../app/theme/app_widgets.dart';
import 'home_connection_dashboard.dart';
import 'social_components.dart';


class DiscoverScreen extends StatelessWidget {
  const DiscoverScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return _ScreenFrame(
      child: ListView(
        padding: const EdgeInsets.all(20),
        children: [
          Text(
            'Discover people',
            style: Theme.of(
              context,
            ).textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.w800),
          ),
          const SizedBox(height: 8),
          const Text(
            'Find small plans with people who share your rhythm.',
            style: TextStyle(color: Color(0xFFB9C3DC)),
          ),
          const SizedBox(height: 24),
          const PlanSearchBar(),
          const SizedBox(height: 18),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: const [
              InterestChip(
                label: 'Tonight',
                icon: Icons.nightlight_round,
                selected: true,
              ),
              InterestChip(label: 'Close by', icon: Icons.near_me_outlined),
              InterestChip(
                label: 'This week',
                icon: Icons.calendar_today_rounded,
              ),
            ],
          ),
          const SizedBox(height: 30),
          const SectionHeader('Plans made for you'),
          const SizedBox(height: 14),
          for (final plan in nearbyPlans) ...[
            HostCard(plan: plan, onJoin: () {}),
            const SizedBox(height: 14),
          ],
        ],
      ),
    );
  }
}

class ConnectionsScreen extends StatelessWidget {
  const ConnectionsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return const _ScreenFrame(
      child: Padding(
        padding: EdgeInsets.symmetric(horizontal: 18),
        child: ConnectionsDashboard(),
      ),
    );
  }
}


class PlansScreen extends StatelessWidget {

  const PlansScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return _ScreenFrame(
      child: Scaffold(
        backgroundColor: Colors.transparent,
        floatingActionButton: FloatingActionButton.extended(
          onPressed: () {
            Navigator.of(context).push(
              MaterialPageRoute<void>(builder: (_) => const HostPlanScreen()),
            );
          },
          icon: const Icon(Icons.add_rounded),
          label: const Text('Host a Plan'),
        ),
        body: ListView(
          padding: const EdgeInsets.fromLTRB(20, 20, 20, 104),
          children: [
            Text(
              'Your plans',
              style: Theme.of(
                context,
              ).textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.w800),
            ),
            const SizedBox(height: 20),
            const SectionHeader('Plans Around You'),
            const SizedBox(height: 14),
            for (final plan in nearbyPlans.take(2)) ...[
              HostCard(plan: plan, onJoin: () {}),
              const SizedBox(height: 14),
            ],
            const SizedBox(height: 16),
            const SectionHeader('Hosted by you'),
            const SizedBox(height: 14),
            const GlassCard(
              child: ListTile(
                contentPadding: EdgeInsets.zero,
                leading: UserAvatar(name: 'Avery', color: Color(0xFF8B5CF6)),
                title: Text(
                  'Sunday sketch & coffee',
                  style: TextStyle(fontWeight: FontWeight.w800),
                ),
                subtitle: Text('Tomorrow - 4 people joined'),
                trailing: Icon(Icons.chevron_right_rounded),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class ChatsScreen extends StatelessWidget {
  const ChatsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return _ScreenFrame(
      child: ListView(
        padding: const EdgeInsets.all(20),
        children: [
          Text(
            'Chats',
            style: Theme.of(
              context,
            ).textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.w800),
          ),
          const SizedBox(height: 8),
          const Text(
            'Small plans are where better conversations begin.',
            style: TextStyle(color: Color(0xFFB9C3DC)),
          ),
          const SizedBox(height: 24),
          const _ChatRow(
            name: 'Coffee & Camera Walk',
            message: 'Maya is typing...',
            time: 'Now',
            color: Color(0xFFE36D9D),
            online: true,
          ),
          const _ChatRow(
            name: 'Arjun Mehta',
            message: 'I found the perfect place for this.',
            time: '14m',
            color: Color(0xFF22BFE0),
            online: true,
            unread: 2,
          ),
          const _ChatRow(
            name: 'Friday Vinyl Club',
            message: 'Nora: I can bring some records.',
            time: '1h',
            color: Color(0xFF8B5CF6),
            unread: 4,
          ),
        ],
      ),
    );
  }
}

class ProfileScreen extends StatelessWidget {
  const ProfileScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return _ScreenFrame(
      child: ListView(
        padding: const EdgeInsets.all(20),
        children: [
          const Center(
            child: UserAvatar(
              name: 'Avery',
              size: 104,
              online: true,
              color: Color(0xFF8B5CF6),
            ),
          ),
          const SizedBox(height: 16),
          Text(
            'Avery Sharma',
            textAlign: TextAlign.center,
            style: Theme.of(
              context,
            ).textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.w800),
          ),
          const SizedBox(height: 6),
          const Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(Icons.verified_rounded, size: 17, color: Color(0xFF69D9F0)),
              SizedBox(width: 5),
              Text(
                'Verified member',
                style: TextStyle(color: Color(0xFFB9C3DC)),
              ),
            ],
          ),
          const SizedBox(height: 26),
          Row(
            children: const [
              Expanded(
                child: ProfileStatCard(value: '8', label: 'Plans Hosted'),
              ),
              SizedBox(width: 10),
              Expanded(
                child: ProfileStatCard(value: '16', label: 'Plans Joined'),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Row(
            children: const [
              Expanded(
                child: ProfileStatCard(value: '27', label: 'Friends Made'),
              ),
              SizedBox(width: 10),
              Expanded(
                child: ProfileStatCard(value: '4.9', label: 'Host Rating'),
              ),
            ],
          ),
          const SizedBox(height: 28),
          const SectionHeader('Interests'),
          const SizedBox(height: 12),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: const [
              InterestChip(label: 'Coffee', icon: Icons.coffee_rounded),
              InterestChip(label: 'Live music', icon: Icons.music_note_rounded),
              InterestChip(label: 'Travel', icon: Icons.flight_takeoff_rounded),
              InterestChip(label: 'Design', icon: Icons.palette_outlined),
            ],
          ),
        ],
      ),
    );
  }
}

class HostPlanScreen extends StatelessWidget {
  const HostPlanScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Host a Plan')),
      body: ListView(
        padding: const EdgeInsets.all(20),
        children: [
          Text(
            'Make a little room for new people.',
            style: Theme.of(
              context,
            ).textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.w800),
          ),
          const SizedBox(height: 24),
          const TextField(
            decoration: InputDecoration(
              labelText: 'Plan title',
              hintText: 'Coffee and a good conversation',
            ),
          ),
          const SizedBox(height: 18),
          const GlassCard(
            child: Column(
              children: [
                ListTile(
                  contentPadding: EdgeInsets.zero,
                  leading: Icon(Icons.schedule_rounded),
                  title: Text('Time'),
                  subtitle: Text('Today - 7:00 PM'),
                ),
                Divider(height: 1),
                ListTile(
                  contentPadding: EdgeInsets.zero,
                  leading: Icon(Icons.location_on_outlined),
                  title: Text('Location'),
                  subtitle: Text('Choose a public place'),
                ),
              ],
            ),
          ),
          const SizedBox(height: 24),
          SizedBox(
            height: 56,
            child: FilledButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text('Publish Plan'),
            ),
          ),
        ],
      ),
    );
  }
}

class _ScreenFrame extends StatelessWidget {
  const _ScreenFrame({required this.child});
  final Widget child;
  @override
  Widget build(BuildContext context) => SafeArea(
    child: Center(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 860),
        child: child,
      ),
    ),
  );
}

class _ChatRow extends StatelessWidget {
  const _ChatRow({
    required this.name,
    required this.message,
    required this.time,
    required this.color,
    this.unread = 0,
    this.online = false,
  });
  final String name;
  final String message;
  final String time;
  final Color color;
  final int unread;
  final bool online;
  @override
  Widget build(BuildContext context) => ListTile(
    contentPadding: const EdgeInsets.symmetric(vertical: 7),
    leading: UserAvatar(name: name, size: 50, color: color, online: online),
    title: Text(name, style: const TextStyle(fontWeight: FontWeight.w800)),
    subtitle: Text(message, maxLines: 1, overflow: TextOverflow.ellipsis),
    trailing: Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Text(
          time,
          style: const TextStyle(fontSize: 11, color: Color(0xFFB9C3DC)),
        ),
        if (unread > 0) const SizedBox(height: 6),
        if (unread > 0) CircleAvatar(radius: 10, child: Text('$unread')),
      ],
    ),
  );
}
