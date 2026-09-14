import 'dart:math' as math;

import 'package:flutter/material.dart';

import 'mock_data.dart';

/// Single source of truth for the mock front end.
///
/// No network, no Supabase. Replace the bodies of these methods with
/// repository calls when the database is reconnected.
class ConexoState extends ChangeNotifier {
  // ── Appearance ──────────────────────────────────────────────────────────
  bool night = false;
  void setNight(bool value) {
    night = value;
    notifyListeners();
  }

  // ── Session ─────────────────────────────────────────────────────────────
  bool signedIn = false;
  Person profile = me;

  Future<void> signIn() async {
    await Future<void>.delayed(const Duration(milliseconds: 900));
    signedIn = true;
    notifyListeners();
  }

  void signOut() {
    signedIn = false;
    notifyListeners();
  }

  void saveProfile(Person p) {
    profile = p;
    notifyListeners();
  }

  // ── Discovery ───────────────────────────────────────────────────────────
  final List<Person> queue = [...discoverQueue];
  final List<Like> likesYou = [...seedLikesYou];
  final List<Match> matches = seedMatches();

  Person? get current => queue.isEmpty ? null : queue.first;

  /// Likes a person. Returns the new [Match] when it's mutual.
  Match? like(Person p, {String? comment, String? what}) {
    queue.remove(p);
    Match? match;
    if (p.likesYou) {
      likesYou.removeWhere((l) => l.from.id == p.id);
      match = Match(
        person: p,
        matchedAt: DateTime.now(),
        openingLine: what == null ? 'It\'s mutual' : 'You liked: $what',
        messages: [
          if (comment != null && comment.trim().isNotEmpty)
            Message(text: comment.trim(), fromMe: true, at: DateTime.now()),
        ],
      );
      matches.insert(0, match);
    }
    notifyListeners();
    return match;
  }

  void pass(Person p) {
    queue.remove(p);
    notifyListeners();
  }

  void resetDeck() {
    queue
      ..clear()
      ..addAll(discoverQueue.where((p) => !matches.any((m) => m.person.id == p.id)));
    notifyListeners();
  }

  // ── Likes you ───────────────────────────────────────────────────────────
  Match acceptLike(Like l) {
    likesYou.remove(l);
    queue.removeWhere((p) => p.id == l.from.id);
    final m = Match(
      person: l.from,
      matchedAt: DateTime.now(),
      openingLine: 'Liked your ${l.target == LikeTarget.prompt ? 'prompt' : 'photo'}',
      messages: [
        if (l.comment != null)
          Message(text: l.comment!, fromMe: false, at: DateTime.now()),
      ],
    );
    matches.insert(0, m);
    notifyListeners();
    return m;
  }

  void dismissLike(Like l) {
    likesYou.remove(l);
    notifyListeners();
  }

  // ── Messaging ───────────────────────────────────────────────────────────
  final Set<String> typing = {};
  final _rng = math.Random();

  void send(Match m, String text) {
    if (text.trim().isEmpty) return;
    m.messages.add(Message(text: text.trim(), fromMe: true, at: DateTime.now()));
    notifyListeners();

    Future<void>.delayed(const Duration(milliseconds: 900), () {
      typing.add(m.person.id);
      notifyListeners();
    });
    Future<void>.delayed(const Duration(milliseconds: 2600), () {
      typing.remove(m.person.id);
      m.messages.add(
        Message(
          text: cannedReplies[_rng.nextInt(cannedReplies.length)],
          fromMe: false,
          at: DateTime.now(),
        ),
      );
      notifyListeners();
    });
  }

  void react(Message msg, String emoji) {
    msg.reaction = msg.reaction == emoji ? null : emoji;
    notifyListeners();
  }

  void markRead(Match m) {
    if (m.unread == 0) return;
    m.unread = 0;
    notifyListeners();
  }

  void unmatch(Match m) {
    matches.remove(m);
    notifyListeners();
  }

  int get unreadTotal => matches.fold(0, (s, m) => s + m.unread);

  // ── Preferences ─────────────────────────────────────────────────────────
  RangeValues ageRange = const RangeValues(22, 32);
  double maxDistance = 15;
  String interestedIn = 'Everyone';
  bool incognito = false;
  bool readReceipts = true;
  bool pushMatches = true;
  bool pushMessages = true;
  bool pushLikes = true;

  void update(VoidCallback change) {
    change();
    notifyListeners();
  }
}

/// Makes [ConexoState] available to the whole tree.
class ConexoScope extends InheritedNotifier<ConexoState> {
  const ConexoScope({required ConexoState state, required super.child, super.key})
      : super(notifier: state);

  static ConexoState of(BuildContext context) =>
      context.dependOnInheritedWidgetOfExactType<ConexoScope>()!.notifier!;

  static ConexoState read(BuildContext context) =>
      context.getInheritedWidgetOfExactType<ConexoScope>()!.notifier!;
}
