import 'package:flutter/material.dart';
import 'social_components.dart';

class MoodOption {
  const MoodOption(this.label, this.icon);
  final String label;
  final IconData icon;
}

class ConnectionPreview {
  const ConnectionPreview({
    required this.name,
    required this.about,
    required this.distance,
    required this.sharedInterest,
    required this.prompt,
    required this.color,
    required this.conversation,
  });
  final String name;
  final String about;
  final String distance;
  final String sharedInterest;
  final String prompt;
  final Color color;
  final PlanPreview conversation;
}

const moods = <MoodOption>[
  MoodOption('Coffee', Icons.coffee_rounded),
  MoodOption('Music', Icons.music_note_rounded),
  MoodOption('Travel', Icons.flight_takeoff_rounded),
  MoodOption('Food', Icons.restaurant_rounded),
  MoodOption('Walking', Icons.directions_walk_rounded),
  MoodOption('Photography', Icons.camera_alt_rounded),
  MoodOption('Gaming', Icons.sports_esports_rounded),
  MoodOption('Study', Icons.menu_book_rounded),
  MoodOption('Creative', Icons.palette_outlined),
  MoodOption('Fitness', Icons.fitness_center_rounded),
];
const nearbyConnections = <ConnectionPreview>[
  ConnectionPreview(
    name: 'Maya Kapoor',
    about: 'Quietly curious - photographer',
    distance: '0.8 km away',
    sharedInterest: 'You both love photography',
    prompt: 'Ask Maya about the photo she keeps returning to.',
    color: Color(0xFFE36D9D),
    conversation: PlanPreview(
      host: 'Maya Kapoor',
      title: 'A slow coffee and a real conversation',
      description: 'Maya is looking for kind company around Cubbon Park.',
      distance: '0.8 km',
      members: 3,
      time: 'Tonight - 6:30 PM',
      color: Color(0xFFE36D9D),
    ),
  ),
  ConnectionPreview(
    name: 'Arjun Mehta',
    about: 'Good listener - vinyl collector',
    distance: '1.4 km away',
    sharedInterest: 'You both save music for rainy days',
    prompt: 'His easiest icebreaker: your first concert.',
    color: Color(0xFF22BFE0),
    conversation: PlanPreview(
      host: 'Arjun Mehta',
      title: 'Music, stories, and an unhurried evening',
      description: 'Arjun is making room for new company after work.',
      distance: '1.4 km',
      members: 5,
      time: 'Tonight - 8:00 PM',
      color: Color(0xFF22BFE0),
    ),
  ),
  ConnectionPreview(
    name: 'Nora Ali',
    about: 'Food explorer - new in town',
    distance: '2.1 km away',
    sharedInterest: 'You both want to try somewhere new',
    prompt: 'She knows a tiny place with excellent shared plates.',
    color: Color(0xFFF09A65),
    conversation: PlanPreview(
      host: 'Nora Ali',
      title: 'A table with room for one more',
      description: 'Nora would love a friendly face over supper.',
      distance: '2.1 km',
      members: 4,
      time: 'Tomorrow - 7:30 PM',
      color: Color(0xFFF09A65),
    ),
  ),
];
const recommendedConnections = <ConnectionPreview>[
  ConnectionPreview(
    name: 'Ishaan Roy',
    about: 'Designer - walks to think',
    distance: '1.1 km away',
    sharedInterest: '3 things in common',
    prompt: 'Start with the last place that made you feel inspired.',
    color: Color(0xFF8B5CF6),
    conversation: PlanPreview(
      host: 'Ishaan Roy',
      title: 'A walk with no need to rush',
      description: 'A thoughtful hello can be enough to start.',
      distance: '1.1 km',
      members: 2,
      time: 'Tonight - 7:15 PM',
      color: Color(0xFF8B5CF6),
    ),
  ),
  ConnectionPreview(
    name: 'Lina Fernandes',
    about: 'Book lover - sunny optimism',
    distance: '2.4 km away',
    sharedInterest: 'You both enjoy slow Sundays',
    prompt: 'Her coffee order is always a surprise.',
    color: Color(0xFF6CA9F4),
    conversation: PlanPreview(
      host: 'Lina Fernandes',
      title: 'A warm hello over coffee',
      description: 'Lina is hoping to meet someone genuine nearby.',
      distance: '2.4 km',
      members: 2,
      time: 'Tomorrow - 10:00 AM',
      color: Color(0xFF6CA9F4),
    ),
  ),
];
const tonightConnection = ConnectionPreview(
  name: 'Sana & 3 nearby people',
  about: 'A welcoming little circle',
  distance: '1.2 km away',
  sharedInterest: 'Coffee - music - good conversation',
  prompt: 'No agenda - just a table where nobody has to sit alone.',
  color: Color(0xFFFF4D8D),
  conversation: PlanPreview(
    host: 'Sana',
    title: 'A table for people who want company',
    description: 'A relaxed circle is getting together this evening.',
    distance: '1.2 km',
    members: 4,
    time: 'Tonight - 7:00 PM',
    color: Color(0xFFFF4D8D),
  ),
);
final peopleYouMayLike = <ConnectionPreview>[
  nearbyConnections[0],
  recommendedConnections[0],
  nearbyConnections[2],
];
