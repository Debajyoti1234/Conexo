import 'dart:async';

import 'package:flutter/material.dart';

import 'data_source.dart';
import 'mock_data.dart';

/// Single source of truth for the UI. All backend work goes through [source].
class ConexoState extends ChangeNotifier {
  ConexoState(this.source) {
    _events = source.events.listen(_onEvent);
  }

  final ConexoDataSource source;
  late final StreamSubscription<SourceEvent> _events;
  bool _disposed = false;

  void _notify() {
    if (!_disposed) notifyListeners();
  }

  // ── Appearance ──────────────────────────────────────────────────────────
  bool night = false;
  void setNight(bool value) {
    night = value;
    _notify();
  }

  // ── Session & profile ───────────────────────────────────────────────────
  static const _nobody = Person(
    id: '',
    name: '',
    age: 0,
    city: '',
    job: '',
    photos: [],
    prompts: [],
    vibes: [],
    distanceKm: 0,
  );

  Person? _profile;
  Person get profile => _profile ?? _nobody;
  Preferences prefs = const Preferences();

  String get suggestedName {
    final n = _profile?.name ?? '';
    return n.isNotEmpty ? n : source.pendingName;
  }

  bool get needsLocation => source.needsLocation;

  Future<SessionStage> boot() async {
    await source.init();
    final stage = await source.restoreSession();
    await _afterAuth(stage);
    return stage;
  }

  Future<SessionStage> signIn(String email, String password) async {
    final stage = await source.signIn(email, password);
    await _afterAuth(stage);
    return stage;
  }

  Future<bool> signUp({required String name, required String email, required String password}) =>
      source.signUp(name: name, email: email, password: password);

  Future<SessionStage?> signInWithGoogle() async {
    final stage = await source.signInWithGoogle();
    if (stage != null) await _afterAuth(stage);
    return stage;
  }

  Future<void> resetPassword(String email) => source.resetPassword(email);

  Future<void> signOut() async {
    await source.signOut();
    _profile = null;
    queue.clear();
    likesYou.clear();
    matches.clear();
    typing.clear();
    _openChats.clear();
    _notify();
  }

  Future<void> _afterAuth(SessionStage stage) async {
    if (stage == SessionStage.signedOut) return;
    await _loadProfile();
    if (stage == SessionStage.ready) unawaited(refreshAll());
  }

  Future<void> _loadProfile() async {
    try {
      _profile = await source.loadMyProfile();
      prefs = await source.loadPreferences();
    } catch (e) {
      debugPrint('Conexo: profile load failed: $e');
    }
    _notify();
  }

  Future<void> saveProfile(ProfileInput input) async {
    _profile = await source.saveMyProfile(input);
    _notify();
    unawaited(refreshAll());
  }

  Future<String?> addPhoto(List<String> existing) => source.pickAndUploadPhoto(existing);

  Future<LocationFix?> detectLocation() => source.detectLocation();

  Future<void> shareLocation() async {
    final fix = await source.detectLocation();
    if (fix == null) return;
    await source.updateLocation(fix);
    await _loadProfile();
    await refreshDiscover();
  }

  Future<void> savePrefs(Preferences next) async {
    prefs = next;
    _notify();
    await source.savePreferences(next);
    unawaited(refreshDiscover());
  }

  // ── Discovery ───────────────────────────────────────────────────────────
  final List<Person> queue = [];
  bool loadingDiscover = false;
  String? discoverError;

  Person? get current => queue.isEmpty ? null : queue.first;

  Future<void> refreshAll() async {
    await Future.wait([refreshDiscover(), refreshLikes(), refreshMatches()]);
  }

  Future<void> refreshDiscover() async {
    loadingDiscover = true;
    discoverError = null;
    _notify();
    try {
      final people = await source.loadDiscover();
      queue
        ..clear()
        ..addAll(people.where((p) => !matches.any((m) => m.person.id == p.id)));
    } catch (e) {
      discoverError = _describe(e);
    } finally {
      loadingDiscover = false;
      _notify();
    }
  }

  /// Likes a person. Returns the match when it's mutual.
  Future<Match?> like(Person p, {String? comment, String? what}) async {
    queue.remove(p);
    _notify();
    try {
      final match = await source.like(p, comment: comment);
      if (match != null) {
        matches.removeWhere((m) => m.id == match.id);
        matches.insert(0, match);
        likesYou.removeWhere((l) => l.from.id == p.id);
        _notify();
      }
      return match;
    } catch (_) {
      queue.insert(0, p);
      _notify();
      rethrow;
    }
  }

  Future<void> pass(Person p) async {
    queue.remove(p);
    _notify();
    await source.pass(p);
  }

  Future<void> resetDeck() async {
    await source.resetPasses();
    await refreshDiscover();
  }

  // ── Likes you ───────────────────────────────────────────────────────────
  final List<Like> likesYou = [];
  bool loadingLikes = false;
  String? likesError;

  Future<void> refreshLikes() async {
    loadingLikes = true;
    likesError = null;
    _notify();
    try {
      final likes = await source.loadLikesYou();
      likesYou
        ..clear()
        ..addAll(likes);
    } catch (e) {
      likesError = _describe(e);
    } finally {
      loadingLikes = false;
      _notify();
    }
  }

  Future<Match> acceptLike(Like like) async {
    final match = await source.acceptLike(like);
    likesYou.remove(like);
    queue.removeWhere((p) => p.id == like.from.id);
    matches.removeWhere((m) => m.id == match.id);
    matches.insert(0, match);
    _notify();
    return match;
  }

  Future<void> dismissLike(Like like) async {
    final i = likesYou.indexOf(like);
    likesYou.remove(like);
    _notify();
    try {
      await source.dismissLike(like);
    } catch (_) {
      if (i >= 0) likesYou.insert(i.clamp(0, likesYou.length), like);
      _notify();
      rethrow;
    }
  }

  // ── Matches & messaging ─────────────────────────────────────────────────
  final List<Match> matches = [];
  bool loadingMatches = false;
  String? matchesError;
  final Set<String> typing = {};
  final Set<String> _openChats = {};

  int get unreadTotal => matches.fold(0, (s, m) => s + m.unread);

  Future<void> refreshMatches() async {
    loadingMatches = true;
    matchesError = null;
    _notify();
    try {
      final fresh = await source.loadMatches();
      final old = {for (final m in matches) m.id: m};
      final merged = <Match>[];
      for (final next in fresh) {
        final prev = old[next.id];
        if (prev != null && _openChats.contains(prev.id)) {
          merged.add(prev);
        } else {
          merged.add(next);
        }
      }
      matches
        ..clear()
        ..addAll(merged);
    } catch (e) {
      matchesError = _describe(e);
    } finally {
      loadingMatches = false;
      _notify();
    }
  }

  Future<void> openChat(Match m) async {
    _openChats.add(m.id);
    m.loading = true;
    _notify();
    try {
      final loaded = await source.openConversation(m);
      m.messages
        ..clear()
        ..addAll(loaded);
      m.unread = 0;
      unawaited(source.markRead(m).catchError((Object _) {}));
    } finally {
      m.loading = false;
      _notify();
    }
  }

  void closeChat(Match m) {
    _openChats.remove(m.id);
    typing.remove(m.person.id);
    source.closeConversation(m);
  }

  Future<void> send(Match m, String text) async {
    final t = text.trim();
    if (t.isEmpty) return;
    final draft = Message(
      id: 'local-${DateTime.now().microsecondsSinceEpoch}',
      text: t,
      fromMe: true,
      at: DateTime.now(),
    );
    m.messages.add(draft);
    _notify();
    try {
      final saved = await source.sendMessage(m, t);
      final i = m.messages.indexOf(draft);
      if (m.messages.any((x) => x.id == saved.id)) {
        m.messages.remove(draft);
      } else if (i >= 0) {
        m.messages[i] = saved;
      }
      m.lastMessage = saved;
      _notify();
    } catch (_) {
      m.messages.remove(draft);
      _notify();
      rethrow;
    }
  }

  Future<void> react(Match m, Message msg) async {
    final me = source.myId;
    final had = msg.likedBy.contains(me);
    had ? msg.likedBy.remove(me) : msg.likedBy.add(me);
    _notify();
    try {
      await source.toggleHeart(m, msg);
    } catch (_) {
      had ? msg.likedBy.add(me) : msg.likedBy.remove(me);
      _notify();
      rethrow;
    }
  }

  Future<void> unmatch(Match m) async {
    await source.unmatch(m);
    matches.remove(m);
    _openChats.remove(m.id);
    _notify();
  }

  // ── Events ──────────────────────────────────────────────────────────────
  Match? _match(String id) {
    for (final m in matches) {
      if (m.id == id) return m;
    }
    return null;
  }

  void _merge(Match m, Message msg) {
    final i = m.messages.indexWhere((x) => x.id == msg.id);
    if (i >= 0) {
      msg.likedBy.addAll(m.messages[i].likedBy);
      m.messages[i] = msg;
    } else {
      m.messages.add(msg);
      m.messages.sort((a, b) => a.at.compareTo(b.at));
    }
  }

  void _onEvent(SourceEvent event) {
    switch (event) {
      case MessageEvent(matchId: final id, message: final msg):
        final m = _match(id);
        if (m == null) {
          unawaited(refreshMatches());
          return;
        }
        final seen = m.messages.any((x) => x.id == msg.id);
        _merge(m, msg);
        m.lastMessage = msg;
        if (_openChats.contains(id)) {
          if (!msg.fromMe) unawaited(source.markRead(m).catchError((Object _) {}));
        } else if (!msg.fromMe && !seen) {
          m.unread++;
        }
        _notify();
      case TypingEvent(matchId: final id, typing: final on):
        final m = _match(id);
        if (m == null) return;
        on ? typing.add(m.person.id) : typing.remove(m.person.id);
        _notify();
      case HeartEvent(matchId: final id, messageId: final messageId, userId: final userId, added: final added):
        final m = _match(id);
        if (m == null) return;
        for (final msg in m.messages) {
          if (msg.id == messageId) {
            added ? msg.likedBy.add(userId) : msg.likedBy.remove(userId);
          }
        }
        _notify();
      case ConnectionsChanged():
        unawaited(refreshLikes());
        unawaited(refreshMatches());
    }
  }

  String _describe(Object e) =>
      e is ConexoFailure ? e.message : 'Couldn\'t reach Conexo. Check your connection and try again.';

  @override
  void dispose() {
    _disposed = true;
    _events.cancel();
    source.dispose();
    super.dispose();
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
