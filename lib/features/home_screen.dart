import 'package:flutter/material.dart';

import '../app/theme/app_widgets.dart';
import 'home_connection_components.dart';
import 'home_connection_data.dart';
import 'social_components.dart';
import 'temporary_chat_screen.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  final Set<String> _connectedPeople = <String>{};
  String _selectedMood = 'Coffee';

  void _startConversation(ConnectionPreview person) {
    setState(() => _connectedPeople.add(person.name));
    Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => TemporaryPlanChatScreen(plan: person.conversation),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 860),
          child: ListView(
            padding: const EdgeInsets.fromLTRB(20, 24, 20, 36),
            children: [
              const _HomeGreeting(),
              const SizedBox(height: 28),
              const PlanSearchBar(hint: 'Who would you like to meet today?'),
              const SizedBox(height: 24),
              const Text(
                'Find your kind of people',
                style: TextStyle(
                  color: Color(0xFFB9C3DC),
                  fontSize: 13,
                  fontWeight: FontWeight.w700,
                ),
              ),
              const SizedBox(height: 12),
              _MoodSelector(
                selectedMood: _selectedMood,
                onSelected: (mood) => setState(() => _selectedMood = mood),
              ),
              const SizedBox(height: 36),
              const SectionHeader('People Nearby', action: 'See all'),
              const SizedBox(height: 14),
              SizedBox(
                height: 254,
                child: ListView.separated(
                  scrollDirection: Axis.horizontal,
                  itemCount: nearbyConnections.length,
                  separatorBuilder: (_, _) => const SizedBox(width: 14),
                  itemBuilder: (context, index) {
                    final person = nearbyConnections[index];
                    return PersonDiscoveryCard(
                      person: person,
                      connected: _connectedPeople.contains(person.name),
                      onConnect: () => _startConversation(person),
                    );
                  },
                ),
              ),
              const SizedBox(height: 34),
              const SectionHeader('Recommended Connections'),
              const SizedBox(height: 14),
              for (final person in recommendedConnections) ...[
                ConnectionRecommendationCard(
                  person: person,
                  connected: _connectedPeople.contains(person.name),
                  onConnect: () => _startConversation(person),
                ),
                const SizedBox(height: 14),
              ],
              const SizedBox(height: 20),
              const SectionHeader('Conversations Starting Tonight'),
              const SizedBox(height: 14),
              ConversationTonightCard(
                person: tonightConnection,
                connected: _connectedPeople.contains(tonightConnection.name),
                onConnect: () => _startConversation(tonightConnection),
              ),
              const SizedBox(height: 34),
              const SectionHeader('People You May Like'),
              const SizedBox(height: 14),
              PeopleYouMayLikeRow(people: peopleYouMayLike),
              const SizedBox(height: 34),
              const _FriendsOfFriendsPlaceholder(),
            ],
          ),
        ),
      ),
    );
  }
}

class _HomeGreeting extends StatelessWidget {
  const _HomeGreeting();

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Good Evening 👋',
                style: Theme.of(context).textTheme.titleMedium?.copyWith(
                  color: const Color(0xFFD6DCF0),
                  fontWeight: FontWeight.w700,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                "You don't have to spend\ntonight alone.",
                style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                  fontWeight: FontWeight.w800,
                  letterSpacing: -1,
                  height: 1.18,
                ),
              ),
            ],
          ),
        ),
        const UserAvatar(
          name: 'Avery',
          size: 52,
          online: true,
          color: Color(0xFF8B5CF6),
        ),
      ],
    );
  }
}

class _MoodSelector extends StatelessWidget {
  const _MoodSelector({required this.selectedMood, required this.onSelected});

  final String selectedMood;
  final ValueChanged<String> onSelected;

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: Row(
        children: moods.map((mood) {
          return Padding(
            padding: const EdgeInsets.only(right: 8),
            child: InterestChip(
              label: mood.label,
              icon: mood.icon,
              selected: selectedMood == mood.label,
              onTap: () => onSelected(mood.label),
            ),
          );
        }).toList(),
      ),
    );
  }
}

class _FriendsOfFriendsPlaceholder extends StatelessWidget {
  const _FriendsOfFriendsPlaceholder();

  @override
  Widget build(BuildContext context) {
    return GlassCard(
      child: Row(
        children: [
          Container(
            height: 48,
            width: 48,
            decoration: BoxDecoration(
              color: const Color(0xFF8B5CF6).withValues(alpha: .16),
              borderRadius: BorderRadius.circular(16),
            ),
            child: const Icon(Icons.group_outlined, color: Color(0xFFB7A5FF)),
          ),
          const SizedBox(width: 14),
          const Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Friends of Friends',
                  style: TextStyle(fontWeight: FontWeight.w800),
                ),
                SizedBox(height: 4),
                Text(
                  'A softer way to meet through people you trust.',
                  style: TextStyle(color: Color(0xFFB9C3DC), fontSize: 13),
                ),
              ],
            ),
          ),
          const Icon(Icons.lock_outline_rounded, color: Color(0xFF7884A5)),
        ],
      ),
    );
  }
}
