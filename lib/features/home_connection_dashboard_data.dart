import 'package:flutter/material.dart';

/// Data models and demo content for the premium Connections dashboard.
///
/// All models carry a stable [String] `id` so the UI can key widgets and
/// perform local mutations without refactoring when a real backend (Firebase)
/// replaces this demo data later. No widgets live in this file.

// Local royalty-free demo portraits (shared with the People screen). Only
// AssetImage is used — never network images. The UI provides a graceful
// gradient fallback when a portrait fails to load.
const _p1 = 'assets/images/portraits/demo1.jpeg';
const _p2 = 'assets/images/portraits/demo2.jpeg';
const _p3 = 'assets/images/portraits/demo3.jpeg';
const _p4 = 'assets/images/portraits/demo4.jpeg';
const _p5 = 'assets/images/portraits/demo5.jpeg';
const _p6 = 'assets/images/portraits/demo6.jpeg';

/// A person already in the user's network (an established connection).
class NetworkConnection {
  const NetworkConnection({
    required this.id,
    required this.name,
    required this.age,
    required this.occupation,
    required this.city,
    required this.connectedSince,
    required this.mutualInterests,
    required this.color,
    this.portrait = '',
  });

  final String id;
  final String name;
  final int age;
  final String occupation;
  final String city;
  final String connectedSince;
  final List<String> mutualInterests;
  final Color color;
  final String portrait;
}

/// An incoming connection request from another person.
class IncomingRequest {
  const IncomingRequest({
    required this.id,
    required this.name,
    required this.bio,
    required this.mutualInterests,
    required this.color,
    this.age = 0,
    this.occupation = '',
    this.city = '',
    this.portrait = '',
  });

  final String id;
  final String name;
  final String bio;
  final List<String> mutualInterests;
  final Color color;
  final int age;
  final String occupation;
  final String city;
  final String portrait;
}

/// A request the user has sent that is awaiting a response.
class PendingRequest {
  const PendingRequest({
    required this.id,
    required this.name,
    required this.color,
    this.portrait = '',
  });

  final String id;
  final String name;
  final Color color;
  final String portrait;
}

/// Someone asking to join one of the user's hosted plans.
class JoinRequest {
  const JoinRequest({
    required this.id,
    required this.name,
    required this.color,
    this.portrait = '',
  });

  final String id;
  final String name;
  final Color color;
  final String portrait;
}

/// An approved participant of a hosted plan.
class Participant {
  const Participant({
    required this.id,
    required this.name,
    required this.color,
    this.portrait = '',
  });

  final String id;
  final String name;
  final Color color;
  final String portrait;
}

/// A plan hosted by the user, with its join requests and participants.
class HostedPlan {
  const HostedPlan({
    required this.id,
    required this.name,
    required this.date,
    required this.time,
    required this.location,
    required this.color,
    required this.joinRequests,
    required this.participants,
  });

  final String id;
  final String name;
  final String date;
  final String time;
  final String location;
  final Color color;
  final List<JoinRequest> joinRequests;
  final List<Participant> participants;
}

// ---------------------------------------------------------------------------
// Demo data
// ---------------------------------------------------------------------------

const demoNetwork = <NetworkConnection>[
  NetworkConnection(
    id: 'network_001',
    name: 'Maya Kapoor',
    age: 24,
    occupation: 'Product Designer',
    city: 'Bengaluru • Indiranagar',
    connectedSince: 'Connected since Jan 2026',
    mutualInterests: ['Photography', 'Coffee', 'Slow travel'],
    color: Color(0xFFE36D9D),
    portrait: _p1,
  ),
  NetworkConnection(
    id: 'network_002',
    name: 'Arjun Mehta',
    age: 27,
    occupation: 'Sound Engineer',
    city: 'Bengaluru • Koramangala',
    connectedSince: 'Connected since Dec 2025',
    mutualInterests: ['Music', 'Books', 'Long walks'],
    color: Color(0xFF22BFE0),
    portrait: _p2,
  ),
  NetworkConnection(
    id: 'network_003',
    name: 'Nora Ali',
    age: 26,
    occupation: 'Illustrator',
    city: 'Mumbai • Bandra',
    connectedSince: 'Connected since Nov 2025',
    mutualInterests: ['Photography', 'Art', 'Coffee'],
    color: Color(0xFFF09A65),
    portrait: _p3,
  ),
];

const demoRequests = <IncomingRequest>[
  IncomingRequest(
    id: 'request_001',
    name: 'Kabir Singh',
    bio:
        'Software engineer who unplugs on mountain trails and takes board-game '
        'nights a little too seriously.',
    mutualInterests: ['Running', 'Gaming', 'Cooking'],
    color: Color(0xFF6C8EF5),
    age: 29,
    occupation: 'Backend Engineer',
    city: 'Pune • Kalyani Nagar',
    portrait: _p4,
  ),
  IncomingRequest(
    id: 'request_002',
    name: 'Aisha Khan',
    bio:
        'Content writer with a shelf that keeps outgrowing my apartment. '
        'I bake when I think, and I think out loud over chai.',
    mutualInterests: ['Books', 'Poetry', 'Coffee'],
    color: Color(0xFFB78AF6),
    age: 25,
    occupation: 'Content Writer',
    city: 'Delhi • Hauz Khas',
    portrait: _p5,
  ),
];

const demoPending = <PendingRequest>[
  PendingRequest(
    id: 'pending_001',
    name: 'Dev Malhotra',
    color: Color(0xFF47D7A5),
    portrait: _p6,
  ),
  PendingRequest(
    id: 'pending_002',
    name: 'Sara Iyer',
    color: Color(0xFFFF4D8D),
    portrait: _p2,
  ),
];

const demoHostedPlans = <HostedPlan>[
  HostedPlan(
    id: 'plan_001',
    name: 'Coffee Meetup',
    date: 'Sat, 14 Feb 2026',
    time: '10:30 AM',
    location: 'Third Wave Coffee • Indiranagar',
    color: Color(0xFFE36D9D),
    joinRequests: [
      JoinRequest(
        id: 'join_001',
        name: 'Rehan Ahmed',
        color: Color(0xFF22D3EE),
        portrait: _p4,
      ),
      JoinRequest(
        id: 'join_002',
        name: 'Ananya Rao',
        color: Color(0xFFB78AF6),
        portrait: _p1,
      ),
    ],
    participants: [
      Participant(
        id: 'participant_001',
        name: 'Meera',
        color: Color(0xFFF09A65),
        portrait: _p2,
      ),
      Participant(
        id: 'participant_002',
        name: 'Karan',
        color: Color(0xFF22D3EE),
        portrait: _p6,
      ),
    ],
  ),
  HostedPlan(
    id: 'plan_002',
    name: 'Beach Walk',
    date: 'Sun, 22 Feb 2026',
    time: '6:00 AM',
    location: 'Vagator Beach • Goa',
    color: Color(0xFF6C8EF5),
    joinRequests: [
      JoinRequest(
        id: 'join_003',
        name: 'Aryan Nair',
        color: Color(0xFF22BFE0),
        portrait: _p4,
      ),
    ],
    participants: [
      Participant(
        id: 'participant_003',
        name: 'Tara',
        color: Color(0xFFB78AF6),
        portrait: _p1,
      ),
    ],
  ),
  HostedPlan(
    id: 'plan_003',
    name: 'Movie Night',
    date: 'Fri, 27 Feb 2026',
    time: '8:30 PM',
    location: 'PVR Forum • Koramangala',
    color: Color(0xFF22D3EE),
    joinRequests: [],
    participants: [
      Participant(
        id: 'participant_004',
        name: 'Zoya',
        color: Color(0xFFE36D9D),
        portrait: _p5,
      ),
      Participant(
        id: 'participant_005',
        name: 'Rohan',
        color: Color(0xFF6C8EF5),
        portrait: _p3,
      ),
      Participant(
        id: 'participant_006',
        name: 'Naina',
        color: Color(0xFFFF4D8D),
        portrait: _p5,
      ),
    ],
  ),
];
