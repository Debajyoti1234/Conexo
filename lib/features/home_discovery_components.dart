import 'package:flutter/material.dart' hide ConnectionState;

import 'home_discovery_data.dart';

class GlassContainer extends StatelessWidget {
  const GlassContainer({
    required this.child,
    super.key,
    this.padding = const EdgeInsets.all(18),
  });
  final Widget child;
  final EdgeInsets padding;
  @override
  Widget build(BuildContext context) => Container(
    padding: padding,
    decoration: BoxDecoration(
      color: const Color(0xFF1A2238).withValues(alpha: .82),
      borderRadius: BorderRadius.circular(24),
      border: Border.all(color: Colors.white.withValues(alpha: .1)),
    ),
    child: child,
  );
}

class PremiumSearchBar extends StatelessWidget {
  const PremiumSearchBar({super.key});
  @override
  Widget build(BuildContext context) => TextField(
    decoration: InputDecoration(
      hintText: 'Search people, interests, places',
      prefixIcon: const Icon(Icons.search_rounded),
    ),
  );
}

class DiscoverySectionHeader extends StatelessWidget {
  const DiscoverySectionHeader(this.title, {required this.subtitle, super.key});
  final String title;
  final String subtitle;
  @override
  Widget build(BuildContext context) => Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      Text(
        title,
        style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w800),
      ),
      Text(
        subtitle,
        style: const TextStyle(color: Color(0xFF9EABC9), fontSize: 13),
      ),
    ],
  );
}

class PersonDiscoveryCard extends StatelessWidget {
  const PersonDiscoveryCard({
    required this.person,
    required this.state,
    required this.onRequest,
    required this.onDecline,
    super.key,
  });
  final DiscoveryPerson person;
  final ConnectionState state;
  final VoidCallback onRequest;
  final VoidCallback onDecline;
  @override
  Widget build(BuildContext context) => GlassContainer(
    padding: EdgeInsets.zero,
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _Portrait(person: person),
        Padding(
          padding: const EdgeInsets.all(20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                '${person.name}, ${person.age}',
                style: const TextStyle(
                  fontSize: 25,
                  fontWeight: FontWeight.w800,
                ),
              ),
              Text(
                '📍 ${person.distance}',
                style: const TextStyle(color: Color(0xFFB9C3DC)),
              ),
              const SizedBox(height: 14),
              Wrap(
                spacing: 7,
                runSpacing: 7,
                children: person.tags
                    .map((tag) => InterestChip(label: tag))
                    .toList(),
              ),
              const SizedBox(height: 16),
              Text(
                person.introduction,
                style: const TextStyle(color: Color(0xFFDCE3F4)),
              ),
              const SizedBox(height: 20),
              ConnectionButton(
                state: state,
                onRequest: onRequest,
                onDecline: onDecline,
              ),
            ],
          ),
        ),
      ],
    ),
  );
}

class _Portrait extends StatelessWidget {
  const _Portrait({required this.person});
  final DiscoveryPerson person;
  @override
  Widget build(BuildContext context) => Container(
    height: 230,
    decoration: BoxDecoration(
      gradient: LinearGradient(colors: [person.color, const Color(0xFF11182C)]),
      borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
    ),
    child: Center(
      child: CircleAvatar(
        radius: 58,
        backgroundColor: Colors.white24,
        child: Text(
          person.name[0],
          style: const TextStyle(fontSize: 46, fontWeight: FontWeight.w800),
        ),
      ),
    ),
  );
}

class ConnectionButton extends StatelessWidget {
  const ConnectionButton({
    required this.state,
    required this.onRequest,
    required this.onDecline,
    super.key,
  });
  final ConnectionState state;
  final VoidCallback onRequest;
  final VoidCallback onDecline;
  @override
  Widget build(BuildContext context) {
    if (state == ConnectionState.pending) {
      return const Text('Connection request sent');
    }
    if (state == ConnectionState.declined) {
      return const Text('Not interested');
    }
    if (state == ConnectionState.accepted) {
      return const Text('Accepted — chat available');
    }
    return Row(
      children: [
        Expanded(
          child: OutlinedButton(
            onPressed: onDecline,
            child: const Text('Pass'),
          ),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: FilledButton(
            onPressed: onRequest,
            child: const Text('Send request'),
          ),
        ),
      ],
    );
  }
}

class InterestChip extends StatelessWidget {
  const InterestChip({required this.label, super.key});
  final String label;
  @override
  Widget build(BuildContext context) => Chip(label: Text(label));
}

class ConversationCard extends StatelessWidget {
  const ConversationCard({required this.conversation, super.key});
  final Conversation conversation;
  @override
  Widget build(BuildContext context) => SizedBox(
    width: 176,
    child: GlassContainer(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(conversation.icon, color: conversation.color),
          const Spacer(),
          Text(conversation.title),
          Text(conversation.people),
        ],
      ),
    ),
  );
}

class CircleCard extends StatelessWidget {
  const CircleCard({required this.circle, super.key});
  final InterestCircle circle;
  @override
  Widget build(BuildContext context) => SizedBox(
    width: 116,
    child: GlassContainer(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(circle.icon, color: circle.color),
          Text(circle.name),
        ],
      ),
    ),
  );
}

class NearbyMomentCard extends StatelessWidget {
  const NearbyMomentCard({required this.moment, super.key});
  final NearbyMoment moment;
  @override
  Widget build(BuildContext context) => GlassContainer(
    child: ListTile(
      contentPadding: EdgeInsets.zero,
      leading: Icon(moment.icon),
      title: Text(moment.title),
      subtitle: Text(moment.subtitle),
    ),
  );
}
