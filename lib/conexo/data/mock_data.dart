/// Mock data for the redesigned front end.
///
/// The database is intentionally disconnected. Everything here is local so the
/// full journey (sign up → profile → discover → match → chat) can be tested
/// end to end. Shapes loosely mirror the Supabase-backed models so wiring the
/// real repositories back in later is a mapping job, not a rewrite.
library;

class Prompt {
  const Prompt(this.question, this.answer);
  final String question;
  final String answer;
}

class Person {
  const Person({
    required this.id,
    required this.name,
    required this.age,
    required this.city,
    required this.job,
    required this.photos,
    required this.prompts,
    required this.vibes,
    required this.distanceKm,
    this.pronouns,
    this.school,
    this.height,
    this.lookingFor = 'Something real',
    this.verified = false,
    this.activeNow = false,
    this.likesYou = false,
  });

  final String id;
  final String name;
  final int age;
  final String city;
  final String job;
  final String? pronouns;
  final String? school;
  final String? height;
  final List<String> photos;
  final List<Prompt> prompts;
  final List<String> vibes;
  final int distanceKm;
  final String lookingFor;
  final bool verified;
  final bool activeNow;

  /// When true, liking this person creates an instant match (mock behaviour).
  final bool likesYou;

  String get firstPhoto => photos.first;
}

enum LikeTarget { photo, prompt }

class Like {
  const Like({
    required this.from,
    required this.target,
    required this.targetLabel,
    this.comment,
  });
  final Person from;
  final LikeTarget target;

  /// The photo index or prompt question that was liked.
  final String targetLabel;
  final String? comment;
}

class Message {
  Message({
    required this.text,
    required this.fromMe,
    required this.at,
    this.reaction,
  });
  final String text;
  final bool fromMe;
  final DateTime at;
  String? reaction;
}

class Match {
  Match({
    required this.person,
    required this.matchedAt,
    List<Message>? messages,
    this.unread = 0,
    this.openingLine,
  }) : messages = messages ?? [];

  final Person person;
  final DateTime matchedAt;
  final List<Message> messages;
  int unread;

  /// What sparked the match, e.g. the prompt that was liked.
  final String? openingLine;

  Message? get last => messages.isEmpty ? null : messages.last;
  bool get yourMove => messages.isEmpty || !messages.last.fromMe;
}

const _p = 'assets/images/people';

final ananya = Person(
  id: 'ananya',
  name: 'Ananya',
  age: 24,
  pronouns: 'she/her',
  city: 'Bandra, Mumbai',
  job: 'Product designer',
  school: 'NID Ahmedabad',
  height: "5'5\"",
  distanceKm: 3,
  verified: true,
  activeNow: true,
  likesYou: true,
  photos: const ['$_p/ananya_1.jpg', '$_p/ananya_2.jpg'],
  vibes: const ['Film cameras', 'Filter coffee', 'Sunset chaser', 'Dog person'],
  lookingFor: 'A long-term thing',
  prompts: const [
    Prompt('My most irrational fear', 'Running out of film right before the good light hits.'),
    Prompt('We\'ll get along if', 'You have strong opinions about the best vada pav in the city.'),
    Prompt('A perfect Sunday', 'Flea market, a long lunch, and a nap I didn\'t plan.'),
  ],
);

final kabir = Person(
  id: 'kabir',
  name: 'Kabir',
  age: 27,
  pronouns: 'he/him',
  city: 'Indiranagar, Bengaluru',
  job: 'Chef at a tiny pasta place',
  height: "5'11\"",
  distanceKm: 5,
  verified: true,
  photos: const ['$_p/kabir_1.jpg', '$_p/kabir_2.jpg'],
  vibes: const ['Cycling', 'Home cook', 'Old Bollywood', 'Early riser'],
  prompts: const [
    Prompt('I\'m weirdly attracted to', 'People who order for the table and nail it.'),
    Prompt('Green flags I look for', 'You text back, you tip well, you\'re nice to the waiter.'),
    Prompt('Let\'s debate this topic', 'Pineapple on pizza is fine. Ketchup on pasta is a crime.'),
  ],
);

final meera = Person(
  id: 'meera',
  name: 'Meera',
  age: 25,
  pronouns: 'she/her',
  city: 'Koramangala, Bengaluru',
  job: 'Writes about climate for a living',
  school: 'St. Xavier\'s',
  height: "5'4\"",
  distanceKm: 2,
  likesYou: true,
  photos: const ['$_p/meera_1.jpg', '$_p/meera_2.jpg'],
  vibes: const ['Poetry', 'Beach walks', 'Bookstores', 'Chai over coffee'],
  lookingFor: 'Something real, no rush',
  prompts: const [
    Prompt('The way to win me over', 'Leave a sticky note in a book you think I\'d love.'),
    Prompt('I geek out on', 'Tide charts. Ask me when the best sunset walk is. I know.'),
  ],
);

final rohan = Person(
  id: 'rohan',
  name: 'Rohan',
  age: 26,
  pronouns: 'he/him',
  city: 'Hauz Khas, Delhi',
  job: 'Sound engineer',
  height: "6'0\"",
  distanceKm: 8,
  activeNow: true,
  photos: const ['$_p/rohan_1.jpg', '$_p/rohan_2.jpg'],
  vibes: const ['Open mics', 'Trekking', 'Vinyl', 'Night owl'],
  prompts: const [
    Prompt('Two truths and a lie', 'I\'ve played for 3,000 people. I can\'t whistle. I love karaoke.'),
    Prompt('Typical Sunday', 'Recovering from Saturday\'s gig with parathas and a hill trail.'),
  ],
);

final zoya = Person(
  id: 'zoya',
  name: 'Zoya',
  age: 23,
  pronouns: 'she/her',
  city: 'Park Street, Kolkata',
  job: 'Painter & illustrator',
  distanceKm: 4,
  verified: true,
  likesYou: true,
  photos: const ['$_p/zoya_1.jpg'],
  vibes: const ['Abstract art', 'Indie music', 'Street food', 'Thrifting'],
  prompts: const [
    Prompt('I\'m looking for', 'Someone who\'ll sit through a four-hour gallery crawl and still want dinner after.'),
    Prompt('Change my mind about', 'Puchka is a breakfast food.'),
  ],
);

final dev = Person(
  id: 'dev',
  name: 'Dev',
  age: 28,
  pronouns: 'he/him',
  city: 'Salt Lake, Kolkata',
  job: 'Architect',
  school: 'CEPT University',
  height: "5'10\"",
  distanceKm: 6,
  photos: const ['$_p/dev_1.jpg'],
  vibes: const ['Chai stalls', 'Old buildings', 'Crosswords', 'Football'],
  prompts: const [
    Prompt('Dating me is like', 'A long walk where I point at every cool balcony we pass.'),
    Prompt('Best travel story', 'Missed a train in Jaipur, found the best lassi of my life.'),
  ],
);

/// The signed-in user in mock mode.
final me = Person(
  id: 'me',
  name: 'Sam',
  age: 25,
  pronouns: 'they/them',
  city: 'Bandra, Mumbai',
  job: 'Growth @ a fintech startup',
  school: 'IIT Bombay',
  height: "5'8\"",
  distanceKm: 0,
  verified: true,
  photos: const ['$_p/me_1.jpg', '$_p/hero.jpg'],
  vibes: const ['Coffee walks', 'Stand-up comedy', 'Weekend treks', 'Board games'],
  prompts: const [
    Prompt('My simple pleasures', 'A window seat, a good playlist, and nowhere to be.'),
    Prompt('I\'ll pick the spot if', 'You promise to order dessert without asking first.'),
  ],
);

final discoverQueue = [ananya, kabir, rohan, meera, dev, zoya];

final seedLikesYou = [
  Like(
    from: meera,
    target: LikeTarget.prompt,
    targetLabel: 'My simple pleasures',
    comment: 'Window seat people are the best people. What\'s on the playlist?',
  ),
  Like(from: zoya, target: LikeTarget.photo, targetLabel: 'Photo 1'),
];

List<Match> seedMatches() {
  final now = DateTime.now();
  return [
    Match(
      person: dev,
      matchedAt: now.subtract(const Duration(days: 2)),
      unread: 2,
      openingLine: 'Liked your prompt: I\'ll pick the spot if…',
      messages: [
        Message(text: 'Okay but dessert without asking is a bold ask.', fromMe: false, at: now.subtract(const Duration(days: 1, hours: 3))),
        Message(text: 'Bold asks get bold desserts. I know a place.', fromMe: true, at: now.subtract(const Duration(days: 1, hours: 2))),
        Message(text: 'Say the word. Saturday?', fromMe: false, at: now.subtract(const Duration(minutes: 42))),
        Message(text: 'Also, the chai stall near Salt Lake. You in?', fromMe: false, at: now.subtract(const Duration(minutes: 40))),
      ],
    ),
    Match(
      person: kabir,
      matchedAt: now.subtract(const Duration(hours: 9)),
      openingLine: 'You liked his photo',
    ),
  ];
}

/// Prompt questions offered during profile creation.
const promptLibrary = [
  'My simple pleasures',
  'I\'ll pick the spot if',
  'The way to win me over',
  'Green flags I look for',
  'A perfect Sunday',
  'Let\'s debate this topic',
  'I geek out on',
  'Two truths and a lie',
  'Dating me is like',
  'Change my mind about',
];

const vibeLibrary = [
  'Coffee walks', 'Stand-up comedy', 'Weekend treks', 'Board games',
  'Film cameras', 'Home cook', 'Open mics', 'Bookstores', 'Street food',
  'Gym rat', 'Thrifting', 'Indie music', 'Cricket', 'Football', 'Yoga',
  'Night owl', 'Early riser', 'Dog person', 'Cat person', 'Travel',
];

const cannedReplies = [
  'Haha okay, you have my attention 👀',
  'Wait that\'s actually so good',
  'Deal. But I\'m picking the playlist.',
  'Tell me more, I\'m listening',
  'Okay this is the best message I\'ve gotten all week',
];
