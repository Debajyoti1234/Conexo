import 'dart:async';
import 'dart:math' as math;

import 'data_source.dart';
import 'mock_data.dart';

/// Local demo backend. No network; replies and typing are simulated.
class MockDataSource implements ConexoDataSource {
  final _events = StreamController<SourceEvent>.broadcast();
  final _rng = math.Random();
  Person _me = me;
  final List<Person> _queue = [...discoverQueue];
  final Set<String> _passed = {};
  final List<Like> _likes = [...seedLikesYou];
  final List<Match> _matches = seedMatches();
  Preferences _prefs = const Preferences(minAge: 22, maxAge: 32, distanceKm: 15);
  int _n = 0;

  @override
  bool get isLive => false;

  @override
  String get myId => 'me';

  @override
  String? get myEmail => 'sam@conexo.app';

  @override
  String get pendingName => 'Sam';

  @override
  bool get needsLocation => false;

  @override
  Stream<SourceEvent> get events => _events.stream;

  Future<void> _beat([int ms = 700]) => Future<void>.delayed(Duration(milliseconds: ms));

  String _id() => 'mock-${++_n}-${DateTime.now().microsecondsSinceEpoch}';

  void _emit(SourceEvent e) {
    if (!_events.isClosed) _events.add(e);
  }

  @override
  Future<void> init() async {}

  @override
  Future<SessionStage> restoreSession() async => SessionStage.signedOut;

  @override
  Future<SessionStage> signIn(String email, String password) async {
    await _beat();
    return SessionStage.ready;
  }

  @override
  Future<bool> signUp({required String name, required String email, required String password}) async {
    await _beat();
    return false;
  }

  @override
  Future<SessionStage?> signInWithGoogle() async {
    await _beat();
    return SessionStage.ready;
  }

  @override
  Future<void> resetPassword(String email) => _beat(400);

  @override
  Future<void> signOut() async {}

  @override
  Future<Person?> loadMyProfile() async => _me;

  @override
  Future<Person> saveMyProfile(ProfileInput input) async {
    await _beat(500);
    final now = DateTime.now();
    var age = now.year - input.birthday.year;
    if (now.month < input.birthday.month ||
        (now.month == input.birthday.month && now.day < input.birthday.day)) {
      age--;
    }
    _me = Person(
      id: 'me',
      name: input.name,
      age: age,
      birthday: input.birthday,
      gender: input.gender,
      city: input.city,
      job: input.job,
      school: _me.school,
      height: _me.height,
      distanceKm: 0,
      verified: _me.verified,
      photos: [...input.photos],
      prompts: [...input.prompts],
      vibes: [...input.vibes],
    );
    return _me;
  }

  @override
  Future<String?> pickAndUploadPhoto(List<String> existing) async {
    await _beat(300);
    return samplePhotoPool.firstWhere((p) => !existing.contains(p), orElse: () => samplePhotoPool.first);
  }

  @override
  Future<LocationFix?> detectLocation() async {
    await _beat();
    return const LocationFix(latitude: 19.0596, longitude: 72.8295, areaName: 'Bandra, Mumbai');
  }

  @override
  Future<void> updateLocation(LocationFix fix) async {}

  @override
  Future<Preferences> loadPreferences() async => _prefs;

  @override
  Future<void> savePreferences(Preferences prefs) async {
    _prefs = prefs;
  }

  @override
  Future<List<Person>> loadDiscover() async {
    await _beat(450);
    return _queue.where((p) => !_passed.contains(p.id)).toList();
  }

  @override
  Future<Match?> like(Person person, {String? comment}) async {
    _queue.remove(person);
    if (!person.likesYou) return null;
    _likes.removeWhere((l) => l.from.id == person.id);
    final m = Match(
      id: 'match-${person.id}',
      person: person,
      matchedAt: DateTime.now(),
      openingLine: 'It\'s mutual',
      messages: [
        if (comment != null && comment.trim().isNotEmpty)
          Message(id: _id(), text: comment.trim(), fromMe: true, at: DateTime.now()),
      ],
    );
    _matches.insert(0, m);
    return m;
  }

  @override
  Future<void> pass(Person person) async {
    _queue.remove(person);
    _passed.add(person.id);
  }

  @override
  Future<void> resetPasses() async {
    _passed.clear();
    _queue
      ..clear()
      ..addAll(discoverQueue.where((p) => !_matches.any((m) => m.person.id == p.id)));
  }

  @override
  Future<List<Like>> loadLikesYou() async => [..._likes];

  @override
  Future<Match> acceptLike(Like like) async {
    _likes.remove(like);
    _queue.removeWhere((p) => p.id == like.from.id);
    final m = Match(
      id: 'match-${like.from.id}',
      person: like.from,
      matchedAt: DateTime.now(),
      openingLine: 'Liked your ${like.target == LikeTarget.prompt ? 'prompt' : 'photo'}',
      messages: [
        if (like.comment != null)
          Message(id: _id(), text: like.comment!, fromMe: false, at: DateTime.now()),
      ],
    );
    _matches.insert(0, m);
    return m;
  }

  @override
  Future<void> dismissLike(Like like) async {
    _likes.remove(like);
  }

  @override
  Future<List<Match>> loadMatches() async => [..._matches];

  @override
  Future<List<Message>> openConversation(Match match) async => [...match.messages];

  @override
  void closeConversation(Match match) {}

  @override
  Future<Message> sendMessage(Match match, String text) async {
    final msg = Message(id: _id(), text: text, fromMe: true, at: DateTime.now());
    Future<void>.delayed(const Duration(milliseconds: 900), () => _emit(TypingEvent(match.id, true)));
    Future<void>.delayed(const Duration(milliseconds: 2600), () {
      _emit(TypingEvent(match.id, false));
      _emit(
        MessageEvent(
          match.id,
          Message(
            id: _id(),
            text: cannedReplies[_rng.nextInt(cannedReplies.length)],
            fromMe: false,
            at: DateTime.now(),
          ),
        ),
      );
    });
    return msg;
  }

  @override
  Future<void> toggleHeart(Match match, Message message) async {}

  @override
  Future<void> markRead(Match match) async {}

  @override
  Future<void> unmatch(Match match) async {
    _matches.remove(match);
  }

  @override
  void dispose() => _events.close();
}
