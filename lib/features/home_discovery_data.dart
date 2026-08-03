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

// Local royalty-free demo portraits, distributed naturally across profiles.
const _p1 = 'assets/images/portraits/demo1.jpeg';
const _p2 = 'assets/images/portraits/demo2.jpeg';
const _p3 = 'assets/images/portraits/demo3.jpeg';
const _p4 = 'assets/images/portraits/demo4.jpeg';
const _p5 = 'assets/images/portraits/demo5.jpeg';
const _p6 = 'assets/images/portraits/demo6.jpeg';

const peopleAroundYou = <DiscoveryPerson>[
  DiscoveryPerson(
    'Maya',
    24,
    '800m away',
    'New here, looking for good conversations.',
    ['Coffee lover', 'Photography', 'Exploring the city'],
    Color(0xFFE36D9D),
    portrait: _p1,
    verified: true,
    availability: 'Available now',
    bio:
        'Recently moved for a new job and slowly turning this city into home. '
        'I love quiet cafes, golden-hour light, and long unhurried talks.',
    city: 'Bengaluru • Indiranagar',
    occupation: 'Product Designer',
    lookingFor: 'Genuine friends for coffee runs and weekend photo walks.',
    lifestyle: ['Early riser', 'Cafe hopper', 'Weekend explorer', 'Non-smoker'],
    languages: ['English', 'Hindi', 'Kannada'],
    mutualInterests: ['Photography', 'Coffee', 'Slow travel'],
    instagram: '@maya.captures',
  ),
  DiscoveryPerson(
    'Arjun',
    27,
    '1.4 km away',
    'A good playlist and an unhurried chat make my day.',
    ['Music', 'Walking', 'Books'],
    Color(0xFF22BFE0),
    portrait: _p2,
    verified: true,
    availability: 'Free this evening',
    bio:
        'Vinyl collector and part-time daydreamer. I believe the best evenings '
        'start with a good record and end with a real conversation.',
    city: 'Bengaluru • Koramangala',
    occupation: 'Sound Engineer',
    lookingFor: 'Someone to share playlists and slow evening walks with.',
    lifestyle: ['Night owl', 'Vinyl lover', 'Bookworm', 'Occasional runner'],
    languages: ['English', 'Hindi', 'Tamil'],
    mutualInterests: ['Music', 'Books', 'Long walks'],
    instagram: '@arjun.on.vinyl',
  ),
  DiscoveryPerson(
    'Nora',
    26,
    '650m away',
    'Chasing light and good espresso around the city.',
    ['Photography', 'Art', 'Cafes'],
    Color(0xFFF09A65),
    portrait: _p3,
    verified: true,
    availability: 'Available now',
    bio:
        'Street photographer by passion, illustrator by trade. I collect '
        'quiet mornings, film cameras, and honest conversations.',
    city: 'Mumbai • Bandra',
    occupation: 'Illustrator',
    lookingFor: 'Creative souls for gallery visits and photo wanders.',
    lifestyle: ['Creative', 'Film shooter', 'Tea person', 'Non-smoker'],
    languages: ['English', 'Hindi', 'Marathi'],
    mutualInterests: ['Photography', 'Art', 'Coffee'],
    instagram: '@nora.frames',
  ),
  DiscoveryPerson(
    'Kabir',
    29,
    '2.1 km away',
    'Trail runs at dawn, board games at night.',
    ['Running', 'Gaming', 'Cooking'],
    Color(0xFF6C8EF5),
    portrait: _p4,
    verified: false,
    availability: 'Free this weekend',
    bio:
        'Software engineer who unplugs on mountain trails. I cook a mean '
        'ramen and take my board-game nights a little too seriously.',
    city: 'Pune • Kalyani Nagar',
    occupation: 'Backend Engineer',
    lookingFor: 'Weekend hiking buddies and co-op gaming partners.',
    lifestyle: ['Early riser', 'Trail runner', 'Home chef', 'Non-smoker'],
    languages: ['English', 'Hindi', 'Punjabi'],
    mutualInterests: ['Running', 'Gaming', 'Cooking'],
    instagram: '@kabir.runs',
  ),
  DiscoveryPerson(
    'Aisha',
    25,
    '1.1 km away',
    'Books, chai, and slow Sundays are my love language.',
    ['Reading', 'Poetry', 'Baking'],
    Color(0xFFB78AF6),
    portrait: _p5,
    verified: true,
    availability: 'Available now',
    bio:
        'Content writer with a shelf that keeps outgrowing my apartment. '
        'I bake when I think, and I think out loud over chai.',
    city: 'Delhi • Hauz Khas',
    occupation: 'Content Writer',
    lookingFor: 'Bookish friends for reading circles and cafe afternoons.',
    lifestyle: ['Bookworm', 'Baker', 'Chai person', 'Homebody'],
    languages: ['English', 'Hindi', 'Urdu'],
    mutualInterests: ['Books', 'Poetry', 'Coffee'],
    instagram: '@aisha.reads',
  ),
  DiscoveryPerson(
    'Dev',
    28,
    '3.4 km away',
    'Weekend cyclist and unapologetic foodie.',
    ['Cycling', 'Food', 'Travel'],
    Color(0xFF47D7A5),
    portrait: _p6,
    verified: false,
    availability: 'Free this evening',
    bio:
        'Marketing lead who plans weekend rides around the best breakfast '
        'spots. Always up for a spontaneous road trip.',
    city: 'Hyderabad • Jubilee Hills',
    occupation: 'Marketing Lead',
    lookingFor: 'Ride-or-eat companions for weekend adventures.',
    lifestyle: ['Cyclist', 'Foodie', 'Traveler', 'Social'],
    languages: ['English', 'Hindi', 'Telugu'],
    mutualInterests: ['Cycling', 'Food', 'Travel'],
    instagram: '@dev.rides',
  ),
  DiscoveryPerson(
    'Sara',
    23,
    '400m away',
    'Dancer, plant mom, and forever curious.',
    ['Dance', 'Plants', 'Music'],
    Color(0xFFFF4D8D),
    portrait: _p2,
    verified: true,
    availability: 'Available now',
    bio:
        'Contemporary dancer teaching weekend classes. My apartment is '
        'basically a small jungle and I would not have it any other way.',
    city: 'Bengaluru • HSR Layout',
    occupation: 'Dance Instructor',
    lookingFor: 'Warm people for jam sessions and farmers-market runs.',
    lifestyle: ['Early riser', 'Plant parent', 'Dancer', 'Non-smoker'],
    languages: ['English', 'Hindi', 'Kannada'],
    mutualInterests: ['Dance', 'Music', 'Plants'],
    instagram: '@sara.moves',
  ),
  DiscoveryPerson(
    'Rehan',
    30,
    '2.8 km away',
    'Coffee first, philosophy second, everything else after.',
    ['Coffee', 'Chess', 'Podcasts'],
    Color(0xFF22D3EE),
    portrait: _p4,
    verified: true,
    availability: 'Free this weekend',
    bio:
        'Barista turned cafe owner. I brew single-origin pour-overs and love '
        'a good debate about almost anything.',
    city: 'Chennai • Nungambakkam',
    occupation: 'Cafe Owner',
    lookingFor: 'Curious minds for slow coffee and long chess games.',
    lifestyle: ['Coffee nerd', 'Chess player', 'Early riser', 'Non-smoker'],
    languages: ['English', 'Hindi', 'Tamil'],
    mutualInterests: ['Coffee', 'Chess', 'Podcasts'],
    instagram: '@rehan.brews',
  ),
  DiscoveryPerson(
    'Ananya',
    26,
    '900m away',
    'Yoga at sunrise, sketchbook at sunset.',
    ['Yoga', 'Art', 'Journaling'],
    Color(0xFFB78AF6),
    portrait: _p1,
    verified: false,
    availability: 'Available now',
    bio:
        'Wellness coach learning to slow down. I paint with watercolors and '
        'believe mornings should never be rushed.',
    city: 'Goa • Assagao',
    occupation: 'Wellness Coach',
    lookingFor: 'Grounded friends for beach walks and quiet mornings.',
    lifestyle: ['Yogi', 'Early riser', 'Minimalist', 'Non-smoker'],
    languages: ['English', 'Hindi', 'Konkani'],
    mutualInterests: ['Yoga', 'Art', 'Slow living'],
    instagram: '@ananya.calm',
  ),
  DiscoveryPerson(
    'Vikram',
    31,
    '4.0 km away',
    'Mountains over malls, always.',
    ['Hiking', 'Photography', 'Camping'],
    Color(0xFF6C8EF5),
    portrait: _p3,
    verified: true,
    availability: 'Free this weekend',
    bio:
        'Architect who escapes to the Himalayas every chance I get. My phone '
        'is 80 percent mountain photos and I am not sorry.',
    city: 'Dehradun • Rajpur Road',
    occupation: 'Architect',
    lookingFor: 'Trail companions for weekend treks and camp nights.',
    lifestyle: ['Explorer', 'Camper', 'Early riser', 'Non-smoker'],
    languages: ['English', 'Hindi', 'Garhwali'],
    mutualInterests: ['Hiking', 'Photography', 'Camping'],
    instagram: '@vikram.altitude',
  ),
  DiscoveryPerson(
    'Zoya',
    24,
    '1.7 km away',
    'Making music and collecting little joys.',
    ['Music', 'Singing', 'Thrifting'],
    Color(0xFFE36D9D),
    portrait: _p5,
    verified: true,
    availability: 'Available now',
    bio:
        'Indie singer-songwriter recording in my bedroom studio. I thrift '
        'vintage jackets and hum melodies on the metro.',
    city: 'Kolkata • Park Street',
    occupation: 'Musician',
    lookingFor: 'Music friends for open mics and thrift-store crawls.',
    lifestyle: ['Night owl', 'Thrifter', 'Songwriter', 'Non-smoker'],
    languages: ['English', 'Hindi', 'Bengali'],
    mutualInterests: ['Music', 'Singing', 'Vintage'],
    instagram: '@zoya.sings',
  ),
  DiscoveryPerson(
    'Ishan',
    29,
    '2.3 km away',
    'Startup by day, street food by night.',
    ['Food', 'Startups', 'Football'],
    Color(0xFF47D7A5),
    portrait: _p6,
    verified: false,
    availability: 'Free this evening',
    bio:
        'Building a small fintech and eating my way through every food '
        'street in town. Sunday football is non-negotiable.',
    city: 'Bengaluru • Whitefield',
    occupation: 'Founder',
    lookingFor: 'Hustlers and foodies for late dinners and pickup games.',
    lifestyle: ['Ambitious', 'Foodie', 'Footballer', 'Social'],
    languages: ['English', 'Hindi', 'Kannada'],
    mutualInterests: ['Food', 'Football', 'Startups'],
    instagram: '@ishan.builds',
  ),
  DiscoveryPerson(
    'Meera',
    27,
    '550m away',
    'Films, filter coffee, and finding hidden gems.',
    ['Cinema', 'Coffee', 'Writing'],
    Color(0xFFF09A65),
    portrait: _p2,
    verified: true,
    availability: 'Available now',
    bio:
        'Screenwriter chasing stories in everyday people. I could talk about '
        'films for hours and never run out of recommendations.',
    city: 'Mumbai • Andheri',
    occupation: 'Screenwriter',
    lookingFor: 'Cinephiles for film nights and long coffee talks.',
    lifestyle: ['Cinephile', 'Writer', 'Coffee lover', 'Night owl'],
    languages: ['English', 'Hindi', 'Marathi'],
    mutualInterests: ['Cinema', 'Writing', 'Coffee'],
    instagram: '@meera.writes',
  ),
  DiscoveryPerson(
    'Aryan',
    25,
    '3.1 km away',
    'Skater, sketcher, and weekend surfer.',
    ['Skating', 'Surfing', 'Design'],
    Color(0xFF22BFE0),
    portrait: _p4,
    verified: false,
    availability: 'Free this weekend',
    bio:
        'Graphic designer who lives for the ocean. I skate to work and chase '
        'waves whenever the coast calls.',
    city: 'Goa • Vagator',
    occupation: 'Graphic Designer',
    lookingFor: 'Easygoing friends for surf trips and skate sessions.',
    lifestyle: ['Surfer', 'Skater', 'Creative', 'Social'],
    languages: ['English', 'Hindi', 'Konkani'],
    mutualInterests: ['Surfing', 'Skating', 'Design'],
    instagram: '@aryan.waves',
  ),
  DiscoveryPerson(
    'Tara',
    28,
    '1.9 km away',
    'Gardens, galleries, and good company.',
    ['Gardening', 'Art', 'Cooking'],
    Color(0xFFB78AF6),
    portrait: _p1,
    verified: true,
    availability: 'Available now',
    bio:
        'Landscape designer turning balconies into little forests. I host '
        'slow dinners and believe plants make better neighbours.',
    city: 'Delhi • Saket',
    occupation: 'Landscape Designer',
    lookingFor: 'Kind people for garden brunches and gallery strolls.',
    lifestyle: ['Plant parent', 'Home chef', 'Early riser', 'Non-smoker'],
    languages: ['English', 'Hindi', 'Punjabi'],
    mutualInterests: ['Gardening', 'Art', 'Cooking'],
    instagram: '@tara.grows',
  ),
  DiscoveryPerson(
    'Rohan',
    32,
    '4.6 km away',
    'Runner, reader, and reluctant morning person.',
    ['Running', 'Books', 'Coffee'],
    Color(0xFF6C8EF5),
    portrait: _p3,
    verified: true,
    availability: 'Free this evening',
    bio:
        'Doctor who runs to think and reads to slow down. I am training for '
        'a marathon and always looking for a decent bookshop.',
    city: 'Bengaluru • Jayanagar',
    occupation: 'Physician',
    lookingFor: 'Running partners and friends who love a good bookstore.',
    lifestyle: ['Runner', 'Bookworm', 'Early riser', 'Non-smoker'],
    languages: ['English', 'Hindi', 'Kannada'],
    mutualInterests: ['Running', 'Books', 'Coffee'],
    instagram: '@rohan.miles',
  ),
  DiscoveryPerson(
    'Naina',
    23,
    '720m away',
    'Painting the city one mural at a time.',
    ['Art', 'Music', 'Travel'],
    Color(0xFFFF4D8D),
    portrait: _p5,
    verified: false,
    availability: 'Available now',
    bio:
        'Street artist and part-time barista. I chase blank walls and good '
        'light, and I never travel without my paints.',
    city: 'Jaipur • C-Scheme',
    occupation: 'Muralist',
    lookingFor: 'Playful souls for art walks and spontaneous trips.',
    lifestyle: ['Creative', 'Traveler', 'Night owl', 'Non-smoker'],
    languages: ['English', 'Hindi', 'Rajasthani'],
    mutualInterests: ['Art', 'Music', 'Travel'],
    instagram: '@naina.paints',
  ),
  DiscoveryPerson(
    'Karan',
    30,
    '2.6 km away',
    'Jazz records, home brews, and long drives.',
    ['Music', 'Driving', 'Cooking'],
    Color(0xFF22D3EE),
    portrait: _p6,
    verified: true,
    availability: 'Free this weekend',
    bio:
        'Chef who unwinds with jazz and a slow home brew. Give me an open '
        'road and a good playlist and I am the happiest person alive.',
    city: 'Chandigarh • Sector 9',
    occupation: 'Chef',
    lookingFor: 'Warm company for kitchen experiments and scenic drives.',
    lifestyle: ['Home chef', 'Music lover', 'Driver', 'Social'],
    languages: ['English', 'Hindi', 'Punjabi'],
    mutualInterests: ['Music', 'Cooking', 'Long drives'],
    instagram: '@karan.cooks',
  ),
];

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
