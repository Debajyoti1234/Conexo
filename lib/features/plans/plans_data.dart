import 'package:flutter/material.dart';

/// Data layer for the premium Plans discovery experience.
///
/// Everything here is local + demo only. Models are shaped so a future
/// backend (or cloud image source) can replace the data source without
/// touching any UI: [Experience.coverAsset] is a plain string today and can
/// become a remote URL later behind the same field.

/// Whether an experience is open to everyone or invite-only.
enum PlanVisibility { public, private }

/// The visual layout a card should use. The dataset assigns these so the
/// discovery feed feels curated rather than repetitive.
enum CardVariant {
  /// Large immersive image, glass overlay, info at the bottom. (Default)
  immersive,

  /// Image on top, content below, minimal glass.
  stacked,

  /// Edge-to-edge image with a floating information card.
  floating,

  /// Small compact premium card, used naturally inside horizontal rails.
  compact,
}

/// A browsing category shown in the horizontal category strip.
class PlanCategory {
  const PlanCategory(this.label, this.emoji, this.icon, this.color);
  final String label;
  final String emoji;
  final IconData icon;
  final Color color;
}

/// A single real-life experience someone can discover.
class Experience {
  const Experience({
    required this.id,
    required this.title,
    required this.host,
    required this.hostPortrait,
    required this.coverAsset,
    required this.category,
    required this.mood,
    required this.moodEmoji,
    required this.city,
    required this.date,
    required this.time,
    required this.distance,
    required this.goingCount,
    required this.spotsLeft,
    required this.accent,
    required this.highlight,
    required this.participants,
    this.visibility = PlanVisibility.public,
    this.cardVariant = CardVariant.immersive,
    this.isEditorsPick = false,
    this.sections = const <String>[],
  });

  final String id;
  final String title;
  final String host;
  final String hostPortrait;
  final String coverAsset;
  final String category;
  final String mood;
  final String moodEmoji;
  final String city;
  final String date;
  final String time;
  final String distance;
  final int goingCount;
  final int spotsLeft;
  final Color accent;
  final String highlight;
  final List<String> participants;
  final PlanVisibility visibility;
  final CardVariant cardVariant;
  final bool isEditorsPick;
  final List<String> sections;

  bool get isPublic => visibility == PlanVisibility.public;
}

// ── Local demo portraits (reused for hosts + participants) ──────────────
const _p1 = 'assets/images/portraits/demo1.jpeg';
const _p2 = 'assets/images/portraits/demo2.jpeg';
const _p3 = 'assets/images/portraits/demo3.jpeg';
const _p4 = 'assets/images/portraits/demo4.jpeg';
const _p5 = 'assets/images/portraits/demo5.jpeg';
const _p6 = 'assets/images/portraits/demo6.jpeg';

// ── Local cover images (18 available) ───────────────────────────────────
const _cBeach = 'assets/images/plans/beach_walk.jpeg';
const _cBoard = 'assets/images/plans/board_games.jpeg';
const _cCafe = 'assets/images/plans/cafe_hunting.jpeg';
const _cCamp = 'assets/images/plans/camping.jpeg';
const _cChai = 'assets/images/plans/chai_chusky.jpeg';
const _cCode = 'assets/images/plans/coding_session.jpeg';
const _cCycle = 'assets/images/plans/cycling.jpeg';
const _cFootball = 'assets/images/plans/football.jpeg';
const _cHouse = 'assets/images/plans/house_party.jpeg';
const _cKaraoke = 'assets/images/plans/karaoke.jpeg';
const _cDrive = 'assets/images/plans/long_drive.jpeg';
const _cMovie = 'assets/images/plans/movie_night.jpeg';
const _cMusic = 'assets/images/plans/music_jamming.jpeg';
const _cPaint = 'assets/images/plans/painting.jpeg';
const _cRooftop = 'assets/images/plans/rooftop_lounge.jpeg';
const _cStartup = 'assets/images/plans/startup_meetup.jpeg';
const _cStreet = 'assets/images/plans/street_food.jpeg';
const _cUno = 'assets/images/plans/uno_night.jpeg';

// Accent palette, reused across the dataset for consistent premium colour.
const _violet = Color(0xFF8B5CF6);
const _blue = Color(0xFF6C8EF5);
const _cyan = Color(0xFF22BFE0);
const _pink = Color(0xFFE36D9D);
const _orange = Color(0xFFF09A65);
const _green = Color(0xFF47D7A5);

/// The 11 browsing categories (last one is Custom for user-created plans).
const planCategories = <PlanCategory>[
  PlanCategory('Chill', '☕', Icons.coffee_rounded, _pink),
  PlanCategory('House', '🏠', Icons.home_rounded, _orange),
  PlanCategory('Music', '🎵', Icons.music_note_rounded, _cyan),
  PlanCategory('Nightlife', '🌃', Icons.nightlife_rounded, _violet),
  PlanCategory('Food', '🍜', Icons.ramen_dining_rounded, _orange),
  PlanCategory('Outdoors', '🌿', Icons.park_rounded, _green),
  PlanCategory('Creative', '🎨', Icons.palette_rounded, _pink),
  PlanCategory('Professional', '💼', Icons.work_rounded, _blue),
  PlanCategory('Sports', '💪', Icons.sports_basketball_rounded, _green),
  PlanCategory('Spontaneous', '🌈', Icons.bolt_rounded, _cyan),
  PlanCategory('Custom', '✨', Icons.auto_awesome_rounded, _violet),
];

/// The full demo dataset (~38 experiences) mapped onto the 18 local covers.
const experiences = <Experience>[
  Experience(
    id: 'e01', title: 'Sunset Ride', host: 'Kabir', hostPortrait: _p4,
    coverAsset: _cDrive, category: 'Spontaneous', mood: 'Chill',
    moodEmoji: '🌇', city: 'Bengaluru', date: 'Today', time: '6:30 PM',
    distance: '2.4 km', goingCount: 12, spotsLeft: 4, accent: _orange,
    highlight: 'Editor\'s Pick', participants: [_p1, _p2, _p3],
    cardVariant: CardVariant.floating, isEditorsPick: true,
    sections: ['featured', 'today', 'trending'],
  ),
  Experience(
    id: 'e02', title: 'Movie Night', host: 'Maya', hostPortrait: _p1,
    coverAsset: _cMovie, category: 'Chill', mood: 'Movie', moodEmoji: '🎬',
    city: 'Bengaluru', date: 'Today', time: '8:00 PM', distance: '1.1 km',
    goingCount: 8, spotsLeft: 2, accent: _violet,
    highlight: 'Popular this weekend', participants: [_p2, _p5, _p6],
    cardVariant: CardVariant.immersive, sections: ['featured', 'today'],
  ),
  Experience(
    id: 'e03', title: 'UNO Night', host: 'Sara', hostPortrait: _p5,
    coverAsset: _cUno, category: 'Chill', mood: 'Chill', moodEmoji: '🃏',
    city: 'Bengaluru', date: 'Today', time: '7:30 PM', distance: '0.8 km',
    goingCount: 6, spotsLeft: 3, accent: _pink,
    highlight: '3 friends interested', participants: [_p1, _p3],
    cardVariant: CardVariant.stacked, sections: ['today', 'friends', 'new'],
  ),
  Experience(
    id: 'e04', title: 'House Party', host: 'Ishan', hostPortrait: _p6,
    coverAsset: _cHouse, category: 'House', mood: 'House', moodEmoji: '🏠',
    city: 'Bengaluru', date: 'Sat', time: '9:00 PM', distance: '3.2 km',
    goingCount: 24, spotsLeft: 6, accent: _orange,
    highlight: 'Trending in Bengaluru', participants: [_p2, _p4, _p1, _p5],
    visibility: PlanVisibility.private, cardVariant: CardVariant.immersive,
    sections: ['trending', 'friends'],
  ),
  Experience(
    id: 'e05', title: 'Chai & Chuski', host: 'Aisha', hostPortrait: _p5,
    coverAsset: _cChai, category: 'Food', mood: 'Chill', moodEmoji: '☕',
    city: 'Delhi', date: 'Today', time: '5:00 PM', distance: '1.7 km',
    goingCount: 5, spotsLeft: 4, accent: _orange,
    highlight: 'Hosted by Aisha', participants: [_p1, _p2],
    cardVariant: CardVariant.compact, sections: ['today', 'near', 'new'],
  ),
  Experience(
    id: 'e06', title: 'Cafe Hunting', host: 'Nora', hostPortrait: _p3,
    coverAsset: _cCafe, category: 'Chill', mood: 'Chill', moodEmoji: '☕',
    city: 'Mumbai', date: 'Sun', time: '11:00 AM', distance: '2.1 km',
    goingCount: 9, spotsLeft: 5, accent: _pink,
    highlight: '12 mutual interests nearby', participants: [_p1, _p4, _p6],
    cardVariant: CardVariant.stacked, sections: ['near', 'trending'],
  ),
  Experience(
    id: 'e07', title: 'Music Jamming', host: 'Zoya', hostPortrait: _p5,
    coverAsset: _cMusic, category: 'Music', mood: 'Music', moodEmoji: '🎵',
    city: 'Kolkata', date: 'Fri', time: '7:00 PM', distance: '4.0 km',
    goingCount: 11, spotsLeft: 3, accent: _cyan,
    highlight: 'Editor\'s Pick', participants: [_p2, _p3, _p6],
    cardVariant: CardVariant.immersive, isEditorsPick: true,
    sections: ['featured', 'trending'],
  ),
  Experience(
    id: 'e08', title: 'Netflix & Chill', host: 'Meera', hostPortrait: _p2,
    coverAsset: _cMovie, category: 'Chill', mood: 'Movie', moodEmoji: '🎬',
    city: 'Mumbai', date: 'Today', time: '9:30 PM', distance: '0.6 km',
    goingCount: 4, spotsLeft: 2, accent: _violet,
    highlight: 'Hosted by Meera', participants: [_p1, _p5],
    visibility: PlanVisibility.private, cardVariant: CardVariant.compact,
    sections: ['today', 'near'],
  ),
  Experience(
    id: 'e09', title: 'Coding Session', host: 'Kabir', hostPortrait: _p4,
    coverAsset: _cCode, category: 'Professional', mood: 'Focus',
    moodEmoji: '💻', city: 'Pune', date: 'Sat', time: '10:00 AM',
    distance: '2.8 km', goingCount: 7, spotsLeft: 5, accent: _blue,
    highlight: 'Popular this weekend', participants: [_p6, _p3],
    cardVariant: CardVariant.stacked, sections: ['trending', 'new'],
  ),
  Experience(
    id: 'e10', title: 'Startup Meetup', host: 'Ishan', hostPortrait: _p6,
    coverAsset: _cStartup, category: 'Professional', mood: 'Network',
    moodEmoji: '💼', city: 'Bengaluru', date: 'Wed', time: '6:00 PM',
    distance: '5.1 km', goingCount: 32, spotsLeft: 8, accent: _blue,
    highlight: 'Trending in Bengaluru', participants: [_p1, _p2, _p4, _p5],
    cardVariant: CardVariant.immersive, sections: ['trending'],
  ),
  Experience(
    id: 'e11', title: 'Football Match', host: 'Dev', hostPortrait: _p6,
    coverAsset: _cFootball, category: 'Sports', mood: 'Sport',
    moodEmoji: '⚽', city: 'Hyderabad', date: 'Sun', time: '7:00 AM',
    distance: '3.4 km', goingCount: 18, spotsLeft: 4, accent: _green,
    highlight: '3 friends interested', participants: [_p3, _p4, _p2],
    cardVariant: CardVariant.floating, sections: ['friends', 'near'],
  ),
  Experience(
    id: 'e12', title: 'Board Games', host: 'Rehan', hostPortrait: _p4,
    coverAsset: _cBoard, category: 'Chill', mood: 'Chill', moodEmoji: '🎲',
    city: 'Chennai', date: 'Fri', time: '8:00 PM', distance: '1.9 km',
    goingCount: 6, spotsLeft: 2, accent: _pink,
    highlight: 'Hosted by Rehan', participants: [_p1, _p5],
    cardVariant: CardVariant.compact, sections: ['new', 'near'],
  ),
  Experience(
    id: 'e13', title: 'Pottery Workshop', host: 'Tara', hostPortrait: _p1,
    coverAsset: _cPaint, category: 'Creative', mood: 'Creative',
    moodEmoji: '🎨', city: 'Delhi', date: 'Sat', time: '2:00 PM',
    distance: '2.6 km', goingCount: 10, spotsLeft: 5, accent: _pink,
    highlight: 'Editor\'s Pick', participants: [_p2, _p6],
    cardVariant: CardVariant.stacked, isEditorsPick: true,
    sections: ['featured', 'new'],
  ),
  Experience(
    id: 'e14', title: 'Painting Together', host: 'Naina', hostPortrait: _p5,
    coverAsset: _cPaint, category: 'Creative', mood: 'Creative',
    moodEmoji: '🎨', city: 'Jaipur', date: 'Sun', time: '4:00 PM',
    distance: '0.7 km', goingCount: 8, spotsLeft: 6, accent: _violet,
    highlight: '12 mutual interests nearby', participants: [_p3, _p4],
    cardVariant: CardVariant.compact, sections: ['near', 'new'],
  ),
  Experience(
    id: 'e15', title: 'Long Drive', host: 'Karan', hostPortrait: _p6,
    coverAsset: _cDrive, category: 'Spontaneous', mood: 'Chill',
    moodEmoji: '🚗', city: 'Chandigarh', date: 'Today', time: '10:00 PM',
    distance: '4.6 km', goingCount: 5, spotsLeft: 3, accent: _cyan,
    highlight: 'Popular this weekend', participants: [_p1, _p2],
    cardVariant: CardVariant.immersive, sections: ['today', 'trending'],
  ),
  Experience(
    id: 'e16', title: 'Night Out', host: 'Zoya', hostPortrait: _p2,
    coverAsset: _cRooftop, category: 'Nightlife', mood: 'Nightlife',
    moodEmoji: '🌃', city: 'Kolkata', date: 'Sat', time: '10:30 PM',
    distance: '3.0 km', goingCount: 20, spotsLeft: 5, accent: _violet,
    highlight: 'Trending in Kolkata', participants: [_p3, _p5, _p6],
    cardVariant: CardVariant.floating, sections: ['trending'],
  ),
  Experience(
    id: 'e17', title: 'Camping', host: 'Vikram', hostPortrait: _p3,
    coverAsset: _cCamp, category: 'Outdoors', mood: 'Outdoor',
    moodEmoji: '🌿', city: 'Dehradun', date: 'Sat', time: '5:00 PM',
    distance: '12 km', goingCount: 14, spotsLeft: 6, accent: _green,
    highlight: 'Editor\'s Pick', participants: [_p1, _p4, _p6],
    cardVariant: CardVariant.immersive, isEditorsPick: true,
    sections: ['featured', 'near'],
  ),
  Experience(
    id: 'e18', title: 'Beach Walk', host: 'Ananya', hostPortrait: _p1,
    coverAsset: _cBeach, category: 'Outdoors', mood: 'Outdoor',
    moodEmoji: '🌊', city: 'Goa', date: 'Sun', time: '6:00 AM',
    distance: '1.3 km', goingCount: 7, spotsLeft: 5, accent: _cyan,
    highlight: 'Hosted by Ananya', participants: [_p2, _p5],
    cardVariant: CardVariant.stacked, sections: ['near', 'new'],
  ),
  Experience(
    id: 'e19', title: 'Morning Cycling', host: 'Dev', hostPortrait: _p6,
    coverAsset: _cCycle, category: 'Sports', mood: 'Sport', moodEmoji: '🚴',
    city: 'Hyderabad', date: 'Today', time: '6:00 AM', distance: '2.2 km',
    goingCount: 9, spotsLeft: 4, accent: _green,
    highlight: 'Popular this weekend', participants: [_p3, _p4],
    cardVariant: CardVariant.compact, sections: ['today', 'near'],
  ),
  Experience(
    id: 'e20', title: 'Street Food Hunt', host: 'Ishan', hostPortrait: _p6,
    coverAsset: _cStreet, category: 'Food', mood: 'Food', moodEmoji: '🍜',
    city: 'Bengaluru', date: 'Fri', time: '7:30 PM', distance: '1.5 km',
    goingCount: 13, spotsLeft: 5, accent: _orange,
    highlight: 'Trending in Bengaluru', participants: [_p1, _p2, _p5],
    cardVariant: CardVariant.immersive, sections: ['trending', 'friends'],
  ),
  Experience(
    id: 'e21', title: 'Photography Walk', host: 'Nora', hostPortrait: _p3,
    coverAsset: _cCafe, category: 'Creative', mood: 'Creative',
    moodEmoji: '📷', city: 'Mumbai', date: 'Sun', time: '5:30 PM',
    distance: '2.0 km', goingCount: 8, spotsLeft: 3, accent: _pink,
    highlight: 'Editor\'s Pick', participants: [_p4, _p6],
    cardVariant: CardVariant.stacked, isEditorsPick: true,
    sections: ['featured', 'near'],
  ),
  Experience(
    id: 'e22', title: 'Rooftop Lounge', host: 'Karan', hostPortrait: _p6,
    coverAsset: _cRooftop, category: 'Nightlife', mood: 'Nightlife',
    moodEmoji: '🌃', city: 'Chandigarh', date: 'Sat', time: '8:30 PM',
    distance: '3.7 km', goingCount: 16, spotsLeft: 4, accent: _violet,
    highlight: 'Popular this weekend', participants: [_p1, _p3, _p5],
    cardVariant: CardVariant.floating, sections: ['trending'],
  ),
  Experience(
    id: 'e23', title: 'Karaoke', host: 'Sara', hostPortrait: _p5,
    coverAsset: _cKaraoke, category: 'Music', mood: 'Music', moodEmoji: '🎤',
    city: 'Bengaluru', date: 'Fri', time: '9:00 PM', distance: '1.2 km',
    goingCount: 12, spotsLeft: 6, accent: _cyan,
    highlight: '3 friends interested', participants: [_p2, _p4, _p6],
    cardVariant: CardVariant.immersive, sections: ['friends', 'trending'],
  ),
  Experience(
    id: 'e24', title: 'Pizza Night', host: 'Meera', hostPortrait: _p2,
    coverAsset: _cStreet, category: 'Food', mood: 'Food', moodEmoji: '🍕',
    city: 'Mumbai', date: 'Today', time: '8:00 PM', distance: '0.9 km',
    goingCount: 6, spotsLeft: 2, accent: _orange,
    highlight: 'Hosted by Meera', participants: [_p1, _p3],
    cardVariant: CardVariant.compact, sections: ['today', 'near'],
  ),
  Experience(
    id: 'e25', title: 'Badminton', host: 'Rohan', hostPortrait: _p3,
    coverAsset: _cFootball, category: 'Sports', mood: 'Sport',
    moodEmoji: '🏸', city: 'Bengaluru', date: 'Sat', time: '7:00 AM',
    distance: '2.9 km', goingCount: 8, spotsLeft: 2, accent: _green,
    highlight: 'Popular this weekend', participants: [_p4, _p5],
    cardVariant: CardVariant.compact, sections: ['near', 'new'],
  ),
  Experience(
    id: 'e26', title: 'Book Club', host: 'Aisha', hostPortrait: _p5,
    coverAsset: _cCafe, category: 'Chill', mood: 'Chill', moodEmoji: '📚',
    city: 'Delhi', date: 'Sun', time: '4:00 PM', distance: '1.6 km',
    goingCount: 10, spotsLeft: 5, accent: _pink,
    highlight: '12 mutual interests nearby', participants: [_p1, _p2],
    cardVariant: CardVariant.stacked, sections: ['near', 'new'],
  ),
  Experience(
    id: 'e27', title: 'Open Mic', host: 'Zoya', hostPortrait: _p2,
    coverAsset: _cMusic, category: 'Music', mood: 'Music', moodEmoji: '🎙',
    city: 'Kolkata', date: 'Fri', time: '8:00 PM', distance: '2.3 km',
    goingCount: 15, spotsLeft: 7, accent: _cyan,
    highlight: 'Trending in Kolkata', participants: [_p3, _p6],
    cardVariant: CardVariant.immersive, sections: ['trending'],
  ),
  Experience(
    id: 'e28', title: 'Coffee & Conversations', host: 'Maya',
    hostPortrait: _p1, coverAsset: _cChai, category: 'Chill', mood: 'Chill',
    moodEmoji: '☕', city: 'Bengaluru', date: 'Today', time: '4:30 PM',
    distance: '0.5 km', goingCount: 4, spotsLeft: 3, accent: _pink,
    highlight: 'Hosted by Maya', participants: [_p2, _p5],
    cardVariant: CardVariant.compact, sections: ['today', 'near'],
  ),
  Experience(
    id: 'e29', title: 'Tea Talk', host: 'Ananya', hostPortrait: _p1,
    coverAsset: _cChai, category: 'Chill', mood: 'Chill', moodEmoji: '🍵',
    city: 'Goa', date: 'Sun', time: '5:00 PM', distance: '1.0 km',
    goingCount: 5, spotsLeft: 4, accent: _orange,
    highlight: '3 friends interested', participants: [_p3, _p4],
    cardVariant: CardVariant.compact, sections: ['friends', 'new'],
  ),
  Experience(
    id: 'e30', title: 'Study Together', host: 'Kabir', hostPortrait: _p4,
    coverAsset: _cCode, category: 'Professional', mood: 'Focus',
    moodEmoji: '📖', city: 'Pune', date: 'Today', time: '3:00 PM',
    distance: '1.8 km', goingCount: 7, spotsLeft: 5, accent: _blue,
    highlight: 'Popular this weekend', participants: [_p1, _p6],
    cardVariant: CardVariant.stacked, sections: ['today', 'near'],
  ),
  Experience(
    id: 'e31', title: 'Library Session', host: 'Rohan', hostPortrait: _p3,
    coverAsset: _cCode, category: 'Professional', mood: 'Focus',
    moodEmoji: '📚', city: 'Bengaluru', date: 'Sat', time: '11:00 AM',
    distance: '2.5 km', goingCount: 6, spotsLeft: 4, accent: _blue,
    highlight: 'Hosted by Rohan', participants: [_p2, _p4],
    cardVariant: CardVariant.compact, sections: ['new', 'near'],
  ),
  Experience(
    id: 'e32', title: 'Dog Walk', host: 'Sara', hostPortrait: _p5,
    coverAsset: _cBeach, category: 'Outdoors', mood: 'Outdoor',
    moodEmoji: '🐕', city: 'Bengaluru', date: 'Today', time: '6:30 AM',
    distance: '0.4 km', goingCount: 4, spotsLeft: 3, accent: _green,
    highlight: '3 friends interested', participants: [_p1, _p3],
    cardVariant: CardVariant.compact, sections: ['today', 'friends', 'near'],
  ),
  Experience(
    id: 'e33', title: 'Sunrise Run', host: 'Rohan', hostPortrait: _p3,
    coverAsset: _cCycle, category: 'Sports', mood: 'Sport', moodEmoji: '🏃',
    city: 'Bengaluru', date: 'Today', time: '5:45 AM', distance: '1.4 km',
    goingCount: 9, spotsLeft: 5, accent: _green,
    highlight: 'Popular this weekend', participants: [_p2, _p6],
    cardVariant: CardVariant.stacked, sections: ['today', 'near'],
  ),
  Experience(
    id: 'e34', title: 'Photography Ride', host: 'Vikram', hostPortrait: _p3,
    coverAsset: _cDrive, category: 'Creative', mood: 'Creative',
    moodEmoji: '📷', city: 'Dehradun', date: 'Sun', time: '6:00 AM',
    distance: '3.1 km', goingCount: 8, spotsLeft: 4, accent: _cyan,
    highlight: 'Editor\'s Pick', participants: [_p1, _p4],
    cardVariant: CardVariant.floating, isEditorsPick: true,
    sections: ['featured', 'near'],
  ),
  Experience(
    id: 'e35', title: 'Sunday Brunch', host: 'Tara', hostPortrait: _p1,
    coverAsset: _cCafe, category: 'Food', mood: 'Food', moodEmoji: '🥐',
    city: 'Delhi', date: 'Sun', time: '11:30 AM', distance: '2.0 km',
    goingCount: 11, spotsLeft: 5, accent: _orange,
    highlight: '12 mutual interests nearby', participants: [_p2, _p3, _p5],
    cardVariant: CardVariant.immersive, sections: ['trending', 'new'],
  ),
  Experience(
    id: 'e36', title: 'Cricket Match', host: 'Dev', hostPortrait: _p6,
    coverAsset: _cFootball, category: 'Sports', mood: 'Sport',
    moodEmoji: '🏏', city: 'Hyderabad', date: 'Sat', time: '8:00 AM',
    distance: '4.2 km', goingCount: 22, spotsLeft: 6, accent: _green,
    highlight: 'Trending in Hyderabad', participants: [_p1, _p2, _p4],
    cardVariant: CardVariant.stacked, sections: ['trending', 'friends'],
  ),
  Experience(
    id: 'e37', title: 'Chess Evening', host: 'Rehan', hostPortrait: _p4,
    coverAsset: _cBoard, category: 'Chill', mood: 'Focus', moodEmoji: '♟',
    city: 'Chennai', date: 'Fri', time: '6:30 PM', distance: '1.1 km',
    goingCount: 6, spotsLeft: 4, accent: _blue,
    highlight: 'Hosted by Rehan', participants: [_p3, _p5],
    cardVariant: CardVariant.compact, sections: ['new', 'near'],
  ),
  Experience(
    id: 'e38', title: 'Cooking Together', host: 'Karan', hostPortrait: _p6,
    coverAsset: _cHouse, category: 'Food', mood: 'Food', moodEmoji: '🍳',
    city: 'Chandigarh', date: 'Sun', time: '1:00 PM', distance: '2.7 km',
    goingCount: 8, spotsLeft: 5, accent: _orange,
    highlight: '3 friends interested', participants: [_p1, _p2],
    cardVariant: CardVariant.stacked, sections: ['friends', 'new'],
  ),
  Experience(
    id: 'e39', title: 'Tech Talk', host: 'Ishan', hostPortrait: _p6,
    coverAsset: _cStartup, category: 'Professional', mood: 'Network',
    moodEmoji: '🎤', city: 'Bengaluru', date: 'Wed', time: '7:00 PM',
    distance: '5.4 km', goingCount: 28, spotsLeft: 8, accent: _blue,
    highlight: 'Trending in Bengaluru', participants: [_p2, _p3, _p4, _p5],
    cardVariant: CardVariant.immersive, sections: ['trending'],
  ),
];

/// The single featured experience shown in the cinematic hero.
Experience get heroExperience => experiences.first;

// ── Pure parse helpers (used by the central distance-first comparator) ──

/// Parses a distance label like `"2.4 km"` / `"12 km"` into kilometres.
/// Unparseable values sort last.
double parseDistanceKm(String distance) {
  final match = RegExp(r'[\d.]+').firstMatch(distance);
  if (match == null) return double.maxFinite;
  return double.tryParse(match.group(0)!) ?? double.maxFinite;
}

/// Parses a start-time label like `"6:30 PM"` into minutes-since-midnight.
/// Unparseable values sort last.
int parseStartMinutes(String time) {
  final match = RegExp(r'(\d{1,2}):(\d{2})\s*([AaPp][Mm])').firstMatch(time);
  if (match == null) return 24 * 60;
  var hour = int.parse(match.group(1)!);
  final minute = int.parse(match.group(2)!);
  final isPm = match.group(3)!.toUpperCase() == 'PM';
  if (hour == 12) hour = 0;
  if (isPm) hour += 12;
  return hour * 60 + minute;
}

/// Whether a date label represents "today" in the demo dataset.
bool isToday(String date) => date.trim().toLowerCase() == 'today';

/// Reorders a rail so no two adjacent cards show the same highlight line.
/// Pure + stable: only nudges an item back by one slot when it would repeat.
List<Experience> avoidAdjacentDuplicateHighlights(List<Experience> items) {
  if (items.length < 2) return items;
  final result = <Experience>[];
  final pending = List<Experience>.from(items);
  while (pending.isNotEmpty) {
    var pickIndex = 0;
    if (result.isNotEmpty) {
      final last = result.last.highlight;
      final alt = pending.indexWhere((e) => e.highlight != last);
      if (alt != -1) pickIndex = alt;
    }
    result.add(pending.removeAt(pickIndex));
  }
  return result;
}

// ── Section builders (consume the SINGLE processed pipeline output) ─────

/// Builds every rail's slice from one already-filtered + sorted list, so no
/// rail ever filters or sorts independently. Empty rails are hidden by the
/// UI. Highlight de-duplication keeps each rail feeling curated.
Map<String, List<Experience>> sectionsFor(List<Experience> processed) {
  List<Experience> slice(String key) => avoidAdjacentDuplicateHighlights(
        processed.where((e) => e.sections.contains(key)).toList(),
      );
  return {
    'featured': slice('featured'),
    'today': slice('today'),
    'trending': slice('trending'),
    'near': slice('near'),
    'friends': slice('friends'),
    'new': slice('new'),
  };
}


