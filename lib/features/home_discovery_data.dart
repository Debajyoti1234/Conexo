import 'package:flutter/material.dart';

import '../app/theme/app_theme.dart';

enum ConnectionState { none, pending, accepted, declined }

class DiscoveryPerson {
  const DiscoveryPerson(
    this.name,
    this.age,
    this.distance,
    this.introduction,
    this.tags,
    this.color, {
    this.portrait = '',
    this.verified = false,
    this.availability = '',
    this.bio = '',
    this.city = '',
    this.occupation = '',
    this.lookingFor = '',
    this.lifestyle = const <String>[],
    this.languages = const <String>[],
    this.mutualInterests = const <String>[],
    this.instagram = '',
  });
  final String name;
  final int age;
  final String distance;
  final String introduction;
  final List<String> tags;
  final Color color;
  final String portrait;
  final bool verified;
  final String availability;
  final String bio;
  final String city;
  final String occupation;
  final String lookingFor;
  final List<String> lifestyle;
  final List<String> languages;
  final List<String> mutualInterests;
  final String instagram;
}

class Conversation {
  const Conversation(this.title, this.people, this.icon, this.color);
  final String title;
  final String people;

  final IconData icon;
  final Color color;
}

class InterestCircle {
  const InterestCircle(this.name, this.icon, this.color);
  final String name;
  final IconData icon;
  final Color color;
}

class NearbyMoment {
  NearbyMoment(this.title, this.subtitle, this.icon);
  final String title;
  final String subtitle;
  final IconData icon;
}

final conversations = <Conversation>[
  Conversation(
    'Coffee conversation',
    'Maya + 2 nearby',
    Icons.coffee_rounded,
    Color(0xFFD9485F),
  ),
  Conversation(
    'Night walk',
    'Arjun + 3 nearby',
    Icons.nightlight_round,
    Color(0xFF2F5FD0),
  ),
  Conversation(
    'Photography talk',
    'Nora + 2 nearby',
    Icons.camera_alt_rounded,
    Color(0xFFD07A3A),
  ),
  Conversation(
    'Study together',
    '4 people nearby',
    Icons.menu_book_rounded,
    Color(0xFF1B1B1F),
  ),
];
final circles = <InterestCircle>[
  InterestCircle('Coffee', Icons.coffee_rounded, Color(0xFFD9485F)),
  InterestCircle('Music', Icons.music_note_rounded, Color(0xFF0E8FA8)),
  InterestCircle('Travel', Icons.flight_takeoff_rounded, Color(0xFF1B1B1F)),
  InterestCircle('Photography', Icons.camera_alt_rounded, Color(0xFFD07A3A)),
  InterestCircle('Gaming', Icons.sports_esports_rounded, Color(0xFF2F5FD0)),
  InterestCircle('Fitness', Icons.fitness_center_rounded, Color(0xFF1F9D6B)),
  InterestCircle('Books', Icons.auto_stories_rounded, Color(0xFFD9485F)),
  InterestCircle('Creative', Icons.palette_outlined, Color(0xFF1B1B1F)),
];
final nearbyMoments = <NearbyMoment>[
  NearbyMoment(
    'Someone nearby wants company for coffee.',
    'A quiet hello could make their evening.',
    Icons.coffee_rounded,
  ),
  NearbyMoment(
    '3 people are exploring cafes nearby.',
    'Join the conversation when it feels right.',
    Icons.groups_rounded,
  ),
];
