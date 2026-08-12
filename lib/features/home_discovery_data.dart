import 'package:flutter/material.dart';

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
  const NearbyMoment(this.title, this.subtitle, this.icon);
  final String title;
  final String subtitle;
  final IconData icon;
}

const conversations = <Conversation>[
  Conversation(
    'Coffee conversation',
    'Maya + 2 nearby',
    Icons.coffee_rounded,
    Color(0xFFE36D9D),
  ),
  Conversation(
    'Night walk',
    'Arjun + 3 nearby',
    Icons.nightlight_round,
    Color(0xFF6C8EF5),
  ),
  Conversation(
    'Photography talk',
    'Nora + 2 nearby',
    Icons.camera_alt_rounded,
    Color(0xFFF09A65),
  ),
  Conversation(
    'Study together',
    '4 people nearby',
    Icons.menu_book_rounded,
    Color(0xFF8B5CF6),
  ),
];
const circles = <InterestCircle>[
  InterestCircle('Coffee', Icons.coffee_rounded, Color(0xFFE36D9D)),
  InterestCircle('Music', Icons.music_note_rounded, Color(0xFF22D3EE)),
  InterestCircle('Travel', Icons.flight_takeoff_rounded, Color(0xFF8B5CF6)),
  InterestCircle('Photography', Icons.camera_alt_rounded, Color(0xFFF09A65)),
  InterestCircle('Gaming', Icons.sports_esports_rounded, Color(0xFF6C8EF5)),
  InterestCircle('Fitness', Icons.fitness_center_rounded, Color(0xFF47D7A5)),
  InterestCircle('Books', Icons.auto_stories_rounded, Color(0xFFFF4D8D)),
  InterestCircle('Creative', Icons.palette_outlined, Color(0xFFB78AF6)),
];
const nearbyMoments = <NearbyMoment>[
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
