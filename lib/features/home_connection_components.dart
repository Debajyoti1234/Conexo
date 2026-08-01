import 'package:flutter/material.dart';

import '../app/theme/app_widgets.dart';
import 'home_connection_data.dart';

class PersonDiscoveryCard extends StatelessWidget {
  const PersonDiscoveryCard({
    required this.person,
    required this.connected,
    required this.onConnect,
    super.key,
  });
  final ConnectionPreview person;
  final bool connected;
  final VoidCallback onConnect;

  @override
  Widget build(BuildContext context) => SizedBox(
    width: 218,
    child: GlassCard(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              UserAvatar(
                name: person.name,
                size: 50,
                online: true,
                color: person.color,
              ),
              const Spacer(),
              const Icon(
                Icons.verified_rounded,
                size: 19,
                color: Color(0xFF77DFF1),
              ),
            ],
          ),
          const SizedBox(height: 15),
          Text(
            person.name,
            style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 17),
          ),
          const SizedBox(height: 3),
          Text(
            person.about,
            style: const TextStyle(fontSize: 12, color: Color(0xFFB9C3DC)),
          ),
          const Spacer(),
          Text(
            person.sharedInterest,
            style: const TextStyle(fontSize: 12, color: Color(0xFFFFA2C2)),
          ),
          const SizedBox(height: 12),
          _ConnectionButton(
            connected: connected,
            onPressed: onConnect,
            compact: true,
          ),
        ],
      ),
    ),
  );
}

class ConnectionRecommendationCard extends StatelessWidget {
  const ConnectionRecommendationCard({
    required this.person,
    required this.connected,
    required this.onConnect,
    super.key,
  });
  final ConnectionPreview person;
  final bool connected;
  final VoidCallback onConnect;

  @override
  Widget build(BuildContext context) => GlassCard(
    child: Row(
      children: [
        UserAvatar(
          name: person.name,
          size: 58,
          online: true,
          color: person.color,
        ),
        const SizedBox(width: 14),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                person.name,
                style: const TextStyle(
                  fontWeight: FontWeight.w800,
                  fontSize: 16,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                person.about,
                style: const TextStyle(fontSize: 12, color: Color(0xFFB9C3DC)),
              ),
              const SizedBox(height: 8),
              Text(
                person.sharedInterest,
                style: const TextStyle(fontSize: 12, color: Color(0xFF9DE8D7)),
              ),
            ],
          ),
        ),
        const SizedBox(width: 10),
        _ConnectionButton(connected: connected, onPressed: onConnect),
      ],
    ),
  );
}

class ConversationTonightCard extends StatelessWidget {
  const ConversationTonightCard({
    required this.person,
    required this.connected,
    required this.onConnect,
    super.key,
  });
  final ConnectionPreview person;
  final bool connected;
  final VoidCallback onConnect;

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.all(20),
    decoration: BoxDecoration(
      gradient: LinearGradient(
        colors: [person.color.withValues(alpha: .28), const Color(0xFF1A2238)],
      ),
      borderRadius: BorderRadius.circular(24),
      border: Border.all(color: Colors.white.withValues(alpha: .11)),
    ),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'TONIGHT',
          style: TextStyle(
            letterSpacing: 1.4,
            fontSize: 11,
            color: Color(0xFFFFA2C2),
            fontWeight: FontWeight.w800,
          ),
        ),
        const SizedBox(height: 10),
        Text(
          person.conversation.title,
          style: const TextStyle(
            fontSize: 21,
            fontWeight: FontWeight.w800,
            letterSpacing: -.5,
          ),
        ),
        const SizedBox(height: 8),
        Text(
          person.prompt,
          style: const TextStyle(color: Color(0xFFD3DBEF), height: 1.4),
        ),
        const SizedBox(height: 18),
        Row(
          children: [
            const Icon(
              Icons.people_alt_outlined,
              size: 17,
              color: Color(0xFF77DFF1),
            ),
            const SizedBox(width: 7),
            Expanded(
              child: Text(
                person.sharedInterest,
                style: const TextStyle(fontSize: 13, color: Color(0xFFD3DBEF)),
              ),
            ),
            _ConnectionButton(connected: connected, onPressed: onConnect),
          ],
        ),
      ],
    ),
  );
}

class PeopleYouMayLikeRow extends StatelessWidget {
  const PeopleYouMayLikeRow({required this.people, super.key});
  final List<ConnectionPreview> people;

  @override
  Widget build(BuildContext context) => Row(
    children: people
        .map(
          (person) => Expanded(
            child: Padding(
              padding: EdgeInsets.only(right: person == people.last ? 0 : 10),
              child: Column(
                children: [
                  UserAvatar(
                    name: person.name,
                    size: 60,
                    online: true,
                    color: person.color,
                  ),
                  const SizedBox(height: 9),
                  Text(
                    person.name.split(' ').first,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const SizedBox(height: 3),
                  Text(
                    person.distance,
                    style: const TextStyle(
                      fontSize: 10,
                      color: Color(0xFF9DA9C8),
                    ),
                  ),
                ],
              ),
            ),
          ),
        )
        .toList(),
  );
}

class _ConnectionButton extends StatelessWidget {
  const _ConnectionButton({
    required this.connected,
    required this.onPressed,
    this.compact = false,
  });
  final bool connected;
  final VoidCallback onPressed;
  final bool compact;

  @override
  Widget build(BuildContext context) => AnimatedContainer(
    duration: const Duration(milliseconds: 260),
    height: compact ? 38 : 36,
    padding: EdgeInsets.symmetric(horizontal: compact ? 14 : 12),
    decoration: BoxDecoration(
      color: connected ? const Color(0xFF238F86) : const Color(0xFF7659DF),
      borderRadius: BorderRadius.circular(14),
    ),
    child: Material(
      color: Colors.transparent,
      child: InkWell(
        borderRadius: BorderRadius.circular(14),
        onTap: onPressed,
        child: Center(
          child: Text(
            connected ? 'Connected' : 'Say hello',
            style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w800),
          ),
        ),
      ),
    ),
  );
}
