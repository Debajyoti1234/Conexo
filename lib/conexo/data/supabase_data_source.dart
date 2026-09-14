import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:image_picker/image_picker.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../core/services/live_location_tracker.dart';
import '../../core/services/location_service.dart';
import '../../core/supabase/auth_service.dart';
import '../../core/supabase/supabase_client.dart';
import '../../features/chat/chat_dtos.dart';
import '../../features/chat/chat_repository.dart';
import '../../features/chat/realtime_messages_service.dart';
import '../../features/profile/connection_repository.dart';
import '../../features/profile/discovery_data.dart';
import '../../features/profile/discovery_repository.dart';
import '../../features/profile/profile_data.dart' show kMinInterests, kMinProfilePhotos;
import '../../features/profile/profile_repository.dart';
import '../../features/profile/profile_validation.dart';
import '../../features/profile/realtime_connections_service.dart';
import '../../features/profile/supabase_profile_repository.dart';
import 'data_source.dart';
import 'mock_data.dart';

/// Live backend on the existing Supabase schema — no schema changes.
///
/// Mapping:
/// * like            → `connections` request (or accepting theirs = match)
/// * likes you       → incoming pending requests
/// * match           → accepted connection
/// * chat            → connection conversation (`messages`, realtime)
/// * message heart   → `message_likes`
/// * prompts         → readable blocks in `profiles.about_me`
/// * vibes           → `profiles.interests`
/// * like comment    → kept on this device, sent as the first message on match
class SupabaseDataSource implements ConexoDataSource {
  final _events = StreamController<SourceEvent>.broadcast();
  final _profiles = const SupabaseProfileRepository();
  final _connections = const ConnectionRepository();
  final _discovery = const DiscoveryRepository();
  final _chat = const ChatRepository();

  final Map<String, String> _conversationToMatch = {};
  final Map<String, StreamSubscription<ChatMessageEvent>> _openChats = {};
  final Map<String, RealtimeChannel> _heartChannels = {};
  StreamSubscription<void>? _connectionsSub;
  StreamSubscription<ChatMessageEvent>? _globalSub;
  Map<String, dynamic>? _myRow;
  bool _servicesStarted = false;

  SupabaseClient get _db => Supabase.instance.client;

  static const _columns =
      'id, display_name, date_of_birth, photos, bio, about_me, interests, languages, gender, location, '
      'occupation, college, education, verification_status, availability_status, latitude, longitude, '
      'profile_visibility, discovery_distance_km, discovery_min_age, discovery_max_age';

  @override
  bool get isLive => true;

  @override
  String get myId => AuthService.currentUser?.id ?? '';

  @override
  String? get myEmail => AuthService.currentUser?.email;

  @override
  String get pendingName {
    final meta = AuthService.currentUser?.userMetadata ?? const {};
    final name = (meta['name'] ?? meta['full_name'] ?? '').toString().trim();
    return name.split(' ').first;
  }

  @override
  bool get needsLocation => _myRow != null && _myRow!['latitude'] == null;

  @override
  Stream<SourceEvent> get events => _events.stream;

  void _emit(SourceEvent e) {
    if (!_events.isClosed) _events.add(e);
  }

  // ── Session ───────────────────────────────────────────────────────────────

  @override
  Future<void> init() async {
    if (!SupabaseClientConfig.isInitialized) {
      await SupabaseClientConfig.initialize();
    }
    if (!kIsWeb) {
      try {
        await GoogleSignIn.instance.initialize(
          serverClientId: const String.fromEnvironment('GOOGLE_SERVER_CLIENT_ID'),
        );
      } catch (_) {
        // Google sign-in stays unavailable; email still works.
      }
    }
  }

  @override
  Future<SessionStage> restoreSession() async {
    if (AuthService.currentSession == null) return SessionStage.signedOut;
    final status = await _profiles.checkProfileStatus();
    switch (status) {
      case ProfileStatus.complete:
        _startServices();
        return SessionStage.ready;
      case ProfileStatus.missing:
      case ProfileStatus.incomplete:
        return SessionStage.needsProfile;
      case ProfileStatus.error:
        throw const ConexoFailure('We couldn\'t load your profile. Check your connection and try again.');
    }
  }

  @override
  Future<SessionStage> signIn(String email, String password) async {
    try {
      await AuthService.signIn(email: email, password: password);
    } on AuthFailure catch (e) {
      throw ConexoFailure(e.message);
    }
    return restoreSession();
  }

  @override
  Future<bool> signUp({required String name, required String email, required String password}) async {
    try {
      final res = await AuthService.signUp(email: email, password: password, name: name);
      return res.session == null;
    } on AuthFailure catch (e) {
      throw ConexoFailure(e.message);
    }
  }

  @override
  Future<SessionStage?> signInWithGoogle() async {
    try {
      if (kIsWeb) {
        await _db.auth.signInWithOAuth(OAuthProvider.google, redirectTo: '${Uri.base.origin}/');
        return null;
      }
      final res = await AuthService.signInWithGoogle();
      if (res == null) return SessionStage.signedOut;
      return await restoreSession();
    } on AuthFailure catch (e) {
      throw ConexoFailure(e.message);
    } on AuthException catch (e) {
      throw ConexoFailure(e.message);
    }
  }

  @override
  Future<void> resetPassword(String email) async {
    try {
      await AuthService.resetPassword(email);
    } on AuthFailure catch (e) {
      throw ConexoFailure(e.message);
    }
  }

  @override
  Future<void> signOut() async {
    _stopServices();
    _myRow = null;
    _conversationToMatch.clear();
    await AuthService.signOut();
  }

  void _startServices() {
    if (_servicesStarted) return;
    _servicesStarted = true;
    LiveLocationTracker.start();
    RealtimeConnectionsService.instance.start();
    _connectionsSub = RealtimeConnectionsService.instance.onConnectionsChanged
        .listen((_) => _emit(const ConnectionsChanged()));
    RealtimeMessagesService.instance.startGlobal();
    _globalSub = RealtimeMessagesService.instance.onGlobalMessageChanged.listen((e) {
      final cm = e.message;
      if (cm == null) return;
      final matchId = _conversationToMatch[cm.conversationId];
      if (matchId == null || _openChats.containsKey(matchId)) return;
      _emit(MessageEvent(matchId, _toMessage(cm)));
    });
  }

  void _stopServices() {
    if (!_servicesStarted) return;
    _servicesStarted = false;
    LiveLocationTracker.stop();
    RealtimeConnectionsService.instance.stop();
    RealtimeMessagesService.instance.stopGlobal();
    _connectionsSub?.cancel();
    _globalSub?.cancel();
    for (final sub in _openChats.values) {
      sub.cancel();
    }
    _openChats.clear();
    for (final ch in _heartChannels.values) {
      _db.removeChannel(ch);
    }
    _heartChannels.clear();
  }

  // ── Profile ───────────────────────────────────────────────────────────────

  @override
  Future<Person?> loadMyProfile() async {
    final uid = myId;
    if (uid.isEmpty) return null;
    final row = await _db.from('profiles').select(_columns).eq('id', uid).maybeSingle();
    _myRow = row;
    return row == null ? null : _personFromRow(row);
  }

  @override
  Future<Person> saveMyProfile(ProfileInput input) async {
    final uid = myId;
    if (uid.isEmpty) throw const ConexoFailure('Your session expired. Sign in again.');

    final existing = _myRow ?? await _db.from('profiles').select(_columns).eq('id', uid).maybeSingle();
    final now = DateTime.now().toUtc().toIso8601String();
    final completed = input.photos.length >= kMinProfilePhotos &&
        input.vibes.length >= kMinInterests &&
        input.prompts.isNotEmpty &&
        input.gender.isNotEmpty &&
        input.city.trim().isNotEmpty &&
        validateDateOfBirth(input.birthday);

    final payload = <String, dynamic>{
      'id': uid,
      'display_name': input.name,
      'date_of_birth': formatDateOnly(input.birthday),
      'gender': input.gender,
      'occupation': input.job,
      'location': input.city,
      'photos': [for (var i = 0; i < input.photos.length; i++) _photoJson(input.photos[i], i)],
      'bio': input.prompts.isEmpty ? '' : input.prompts.first.answer,
      'about_me': encodePrompts(input.prompts),
      'interests': input.vibes,
      'languages': existing?['languages'] ?? <String>[],
      'profile_visibility': existing?['profile_visibility'] ?? 'public',
      'profile_completed': completed,
      'updated_at': now,
      if (existing == null) 'created_at': now,
      if (existing == null) 'social_links': <Object>[],
      if (existing == null) 'verification_status': 'notVerified',
      if (input.location != null) 'latitude': input.location!.latitude,
      if (input.location != null) 'longitude': input.location!.longitude,
    };

    try {
      await _db.from('profiles').upsert(payload);
    } on PostgrestException catch (e) {
      debugPrint('saveMyProfile failed: ${e.code} ${e.message}');
      throw const ConexoFailure('We couldn\'t save your profile. Check your connection and try again.');
    }

    _myRow = {...?existing, ...payload};
    if (completed) _startServices();
    return _personFromRow(_myRow!);
  }

  @override
  Future<String?> pickAndUploadPhoto(List<String> existing) async {
    final file = await ImagePicker().pickImage(source: ImageSource.gallery, maxWidth: 1600, imageQuality: 88);
    if (file == null) return null;
    try {
      return await _profiles.uploadProfilePhoto('photo_${DateTime.now().millisecondsSinceEpoch}', file);
    } catch (e) {
      debugPrint('uploadProfilePhoto failed: $e');
      throw const ConexoFailure('That photo didn\'t upload. Try a different one.');
    }
  }

  @override
  Future<LocationFix?> detectLocation() async {
    final r = await LocationService.detectCurrentLocation();
    final lat = r.latitude;
    final lng = r.longitude;
    if (lat == null || lng == null) {
      throw ConexoFailure(switch (r.outcome) {
        LocationOutcome.serviceDisabled => 'Location is off on this device. Turn it on and try again.',
        LocationOutcome.permissionDenied ||
        LocationOutcome.permissionPermanentlyDenied =>
          'Location access is blocked. Allow it in your browser or device settings, then try again.',
        _ => 'We couldn\'t get your location. Try again in a moment.',
      });
    }
    return LocationFix(latitude: lat, longitude: lng, areaName: r.areaName);
  }

  @override
  Future<void> updateLocation(LocationFix fix) async {
    final update = <String, dynamic>{
      'latitude': fix.latitude,
      'longitude': fix.longitude,
      if ((_myRow?['location'] as String? ?? '').isEmpty && fix.areaName != null) 'location': fix.areaName,
    };
    await _db.from('profiles').update(update).eq('id', myId);
    _myRow = {...?_myRow, ...update};
  }

  @override
  Future<Preferences> loadPreferences() async {
    final row = _myRow;
    return Preferences(
      minAge: (row?['discovery_min_age'] as num?)?.toInt(),
      maxAge: (row?['discovery_max_age'] as num?)?.toInt(),
      distanceKm: (row?['discovery_distance_km'] as num?)?.toInt(),
    );
  }

  @override
  Future<void> savePreferences(Preferences prefs) async {
    final update = {
      'discovery_min_age': prefs.minAge,
      'discovery_max_age': prefs.maxAge,
      'discovery_distance_km': prefs.distanceKm,
    };
    try {
      await _db.from('profiles').update(update).eq('id', myId);
    } on PostgrestException {
      throw const ConexoFailure('Your preferences didn\'t save. Try again.');
    }
    _myRow = {...?_myRow, ...update};
  }

  // ── Discovery & likes ─────────────────────────────────────────────────────

  @override
  Future<List<Person>> loadDiscover() async {
    final found = await _discovery.fetchNearby();
    final passed = await _passedIds();
    final visible = found.where((p) => !passed.contains(p.id)).toList();
    if (visible.isEmpty) return const [];

    final extra = await _db
        .from('profiles')
        .select('id, about_me, college, education')
        .inFilter('id', [for (final p in visible) p.id]);
    final byId = {for (final r in extra) r['id'] as String: r};
    return [for (final p in visible) _personFromDiscovery(p, byId[p.id])];
  }

  @override
  Future<Match?> like(Person person, {String? comment}) async {
    final uid = myId;
    final between = await _connections.getConnectionBetween(uid, person.id);
    if (between.isFailure) throw ConexoFailure(between.error!);
    final existing = between.value;
    final note = comment?.trim() ?? '';

    // They liked you first: accepting is the match.
    if (existing != null && existing.isPending && existing.recipientId == uid) {
      final r = await _connections.acceptRequest(existing.id);
      if (r.isFailure) throw ConexoFailure(r.error!);
      if (note.isNotEmpty) await _savePendingComment(existing.id, note);
      return Match(id: existing.id, person: person, matchedAt: DateTime.now(), openingLine: 'It\'s mutual');
    }
    if (existing != null) {
      if (existing.isAccepted) {
        return Match(id: existing.id, person: person, matchedAt: existing.updatedAt);
      }
      throw ConexoFailure('You already liked ${person.name}. Fingers crossed.');
    }

    final r = await _connections.sendRequest(person.id);
    if (r.isFailure) throw ConexoFailure(r.error!);
    if (note.isNotEmpty) await _savePendingComment(r.value!.id, note);
    return null;
  }

  @override
  Future<void> pass(Person person) async {
    final prefs = await SharedPreferences.getInstance();
    final ids = {...await _passedIds(), person.id};
    await prefs.setStringList(_passedKey, ids.toList());
  }

  @override
  Future<void> resetPasses() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_passedKey);
  }

  String get _passedKey => 'conexo_passed_$myId';

  Future<Set<String>> _passedIds() async {
    final prefs = await SharedPreferences.getInstance();
    return (prefs.getStringList(_passedKey) ?? const []).toSet();
  }

  @override
  Future<List<Like>> loadLikesYou() async {
    final r = await _connections.getIncomingRequests();
    if (r.isFailure) throw ConexoFailure(r.error!);
    final conns = r.value!;
    if (conns.isEmpty) return const [];
    final people = await _peopleByIds(conns.map((c) => c.requesterId));
    return [
      for (final c in conns)
        if (people[c.requesterId] != null)
          Like(id: c.id, from: people[c.requesterId]!, target: LikeTarget.profile, targetLabel: 'your profile'),
    ];
  }

  @override
  Future<Match> acceptLike(Like like) async {
    final r = await _connections.acceptRequest(like.id);
    if (r.isFailure) throw ConexoFailure(r.error!);
    return Match(id: like.id, person: like.from, matchedAt: DateTime.now(), openingLine: 'Liked your profile');
  }

  @override
  Future<void> dismissLike(Like like) async {
    final r = await _connections.rejectRequest(like.id);
    if (r.isFailure) throw ConexoFailure(r.error!);
  }

  // ── Matches & chat ────────────────────────────────────────────────────────

  @override
  Future<List<Match>> loadMatches() async {
    final uid = myId;
    final r = await _connections.getMyConnections();
    if (r.isFailure) throw ConexoFailure(r.error!);
    final accepted = r.value!.where((c) => c.isAccepted).toList();
    if (accepted.isEmpty) return const [];
    final people = await _peopleByIds(accepted.map((c) => c.otherUserId(uid)));

    final matches = await Future.wait([
      for (final c in accepted)
        if (people[c.otherUserId(uid)] != null)
          () async {
            final m = Match(id: c.id, person: people[c.otherUserId(uid)]!, matchedAt: c.updatedAt.toLocal());
            final conv = await _chat.getOrCreateConnectionConversation(c.id);
            final convId = conv.value;
            if (convId != null) {
              m.conversationId = convId;
              _conversationToMatch[convId] = c.id;
              final preview = (await _chat.getLatestMessagePreview(convId)).value;
              if (preview != null) {
                final content = (preview['content'] as String? ?? '').trim();
                m.lastMessage = Message(
                  id: 'preview-$convId',
                  text: content.isEmpty ? 'Sent an attachment' : content,
                  fromMe: preview['sender_id'] == uid,
                  at: DateTime.parse(preview['created_at'] as String).toLocal(),
                );
              }
              m.unread = (await _chat.loadUnreadCount(convId)).value ?? 0;
            }
            return m;
          }(),
    ]);
    return matches;
  }

  @override
  Future<List<Message>> openConversation(Match match) async {
    var convId = match.conversationId;
    if (convId == null) {
      final r = await _chat.getOrCreateConnectionConversation(match.id);
      if (r.isFailure) throw ConexoFailure(r.error!);
      convId = r.value!;
      match.conversationId = convId;
      _conversationToMatch[convId] = match.id;
    }

    final loaded = await _chat.loadMessages(convId);
    if (loaded.isFailure) throw ConexoFailure(loaded.error!);
    final hearts = (await _chat.loadLikesForConversation(convId)).value ?? const <String, List<String>>{};
    final messages = [for (final cm in loaded.value!) _toMessage(cm, hearts[cm.id])];

    final id = convId;
    RealtimeMessagesService.instance.start(id);
    await _openChats[match.id]?.cancel();
    _openChats[match.id] = RealtimeMessagesService.instance.onMessageChanged.listen((e) {
      final cm = e.message;
      if (cm == null || cm.conversationId != id) return;
      _emit(MessageEvent(match.id, _toMessage(cm)));
    });

    final existingChannel = _heartChannels.remove(match.id);
    if (existingChannel != null) await _db.removeChannel(existingChannel);
    _heartChannels[match.id] = _db
        .channel('conexo-hearts-$id')
        .onPostgresChanges(
          event: PostgresChangeEvent.all,
          schema: 'public',
          table: 'message_likes',
          callback: (payload) {
            final removed = payload.eventType == PostgresChangeEvent.delete;
            final rec = removed ? payload.oldRecord : payload.newRecord;
            final messageId = rec['message_id'] as String?;
            final userId = rec['user_id'] as String?;
            if (messageId == null || userId == null) return;
            _emit(HeartEvent(match.id, messageId, userId, !removed));
          },
        )
        .subscribe();

    // A comment left with the like goes out as the opener.
    final pending = await _takePendingComment(match.id);
    if (pending != null) {
      try {
        messages.add(await sendMessage(match, pending));
      } catch (_) {
        await _savePendingComment(match.id, pending);
      }
    }
    return messages;
  }

  @override
  void closeConversation(Match match) {
    final sub = _openChats.remove(match.id);
    if (sub != null) {
      sub.cancel();
      RealtimeMessagesService.instance.stop();
    }
    final ch = _heartChannels.remove(match.id);
    if (ch != null) _db.removeChannel(ch);
  }

  @override
  Future<Message> sendMessage(Match match, String text) async {
    final convId = match.conversationId;
    if (convId == null) throw const ConexoFailure('This chat isn\'t ready yet. Try again.');
    final r = await _chat.sendMessage(conversationId: convId, content: text);
    if (r.isFailure) throw const ConexoFailure('Message didn\'t send. Try again.');
    return _toMessage(r.value!);
  }

  @override
  Future<void> toggleHeart(Match match, Message message) async {
    if (message.id.startsWith('local-')) return;
    final r = await _chat.toggleLike(message.id);
    if (r.isFailure) throw const ConexoFailure('That reaction didn\'t save. Try again.');
  }

  @override
  Future<void> markRead(Match match) async {
    final convId = match.conversationId;
    if (convId != null) await _chat.updateLastReadAt(convId);
  }

  @override
  Future<void> unmatch(Match match) async {
    final r = await _connections.removeConnection(match.id);
    if (r.isFailure) throw ConexoFailure(r.error!);
    closeConversation(match);
  }

  @override
  void dispose() {
    _stopServices();
    _events.close();
  }

  // ── Mapping helpers ───────────────────────────────────────────────────────

  Future<Map<String, Person>> _peopleByIds(Iterable<String> ids) async {
    final list = ids.toSet().toList();
    if (list.isEmpty) return const {};
    final rows = await _db.from('profiles').select(_columns).inFilter('id', list);
    return {for (final row in rows) row['id'] as String: _personFromRow(row)};
  }

  Message _toMessage(ChatMessage cm, [List<String>? hearts]) {
    final String text;
    if (cm.deletedAt != null) {
      text = 'This message was deleted';
    } else {
      text = switch (cm.type) {
        'image' => cm.content.isEmpty ? '📷 Photo' : cm.content,
        'voice' => '🎙️ Voice note',
        'gif' => 'GIF',
        _ => cm.content,
      };
    }
    return Message(
      id: cm.id,
      text: text,
      fromMe: cm.senderId == myId,
      at: cm.createdAt.toLocal(),
      likedBy: {...?hearts},
    );
  }

  Person _personFromDiscovery(DiscoveryProfile p, Map<String, dynamic>? extra) {
    final km = ((p.distanceMeters ?? 0) / 1000).round();
    return _personFromRow({
      'id': p.id,
      'display_name': p.displayName.isNotEmpty ? p.displayName : p.name,
      'date_of_birth': formatDateOnly(p.dateOfBirth),
      'photos': [for (final ph in p.photos) ph.toJson()],
      'bio': p.bio,
      'about_me': extra?['about_me'],
      'interests': p.interests,
      'location': p.location,
      'occupation': p.occupation,
      'college': extra?['college'],
      'education': extra?['education'],
      'verification_status': p.verificationStatus.name,
      'availability_status': p.availabilityStatus,
    }, distanceKm: p.distanceMeters == null ? 0 : (km < 1 ? 1 : km));
  }

  Person _personFromRow(Map<String, dynamic> row, {int distanceKm = 0}) {
    final dob = DateTime.tryParse(row['date_of_birth'] as String? ?? '');
    final prompts = decodePrompts(row['about_me'] as String?);
    final bio = (row['bio'] as String? ?? '').trim();
    String? text(Object? v) {
      final s = (v as String? ?? '').trim();
      return s.isEmpty ? null : s;
    }

    return Person(
      id: row['id'] as String,
      name: text(row['display_name']) ?? 'Someone',
      age: dob == null ? 0 : ageFromDate(dob),
      birthday: dob,
      gender: text(row['gender']),
      city: text(row['location']) ?? '',
      job: text(row['occupation']) ?? '',
      school: text(row['college']) ?? text(row['education']),
      photos: photoPathsFromJson(row['photos']),
      prompts: prompts.isNotEmpty ? prompts : [if (bio.isNotEmpty) Prompt('About me', bio)],
      vibes: [for (final v in (row['interests'] as List? ?? const [])) v.toString()],
      distanceKm: distanceKm,
      verified: row['verification_status'] == 'verified',
      activeNow: row['availability_status'] == 'available_now',
    );
  }

  Map<String, dynamic> _photoJson(String path, int i) {
    final id = path.split('/').last.split('.').first;
    if (path.startsWith('assets/')) {
      return {'id': id, 'assetPath': path, 'isPrimary': i == 0, 'remoteUrl': null, 'uploadStatus': 'local'};
    }
    return {'id': id, 'isPrimary': i == 0, 'remoteUrl': path, 'uploadStatus': 'uploaded'};
  }

  Future<void> _savePendingComment(String connectionId, String comment) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('conexo_like_comment_$connectionId', comment);
  }

  Future<String?> _takePendingComment(String connectionId) async {
    final prefs = await SharedPreferences.getInstance();
    final key = 'conexo_like_comment_$connectionId';
    final value = prefs.getString(key);
    if (value != null) await prefs.remove(key);
    return value;
  }
}

/// Storage path for uploaded photos, asset path for legacy bundled ones.
List<String> photoPathsFromJson(Object? json) {
  if (json is! List) return const [];
  final paths = <String>[];
  for (final p in json) {
    if (p is! Map) continue;
    final remote = (p['remoteUrl'] as String? ?? '').trim();
    final asset = (p['assetPath'] as String? ?? '').trim();
    if (p['uploadStatus'] == 'uploaded' && remote.isNotEmpty) {
      paths.add(remote);
    } else if (asset.isNotEmpty) {
      paths.add(asset);
    } else if (remote.isNotEmpty) {
      paths.add(remote);
    }
  }
  return paths;
}

const _promptMarker = '✦ ';

/// Prompts are stored as readable blocks so older app versions still show
/// sensible "About me" text:
///
///     ✦ My simple pleasures
///     A window seat, a good playlist, and nowhere to be.
String encodePrompts(List<Prompt> prompts) => prompts
    .map((p) => '$_promptMarker${p.question.trim()}\n${p.answer.replaceAll('\n', ' ').trim()}')
    .join('\n\n');

List<Prompt> decodePrompts(String? text) {
  if (text == null || !text.contains(_promptMarker)) return const [];
  final prompts = <Prompt>[];
  for (final block in text.split(_promptMarker).skip(1)) {
    final nl = block.indexOf('\n');
    if (nl <= 0) continue;
    final q = block.substring(0, nl).trim();
    final a = block.substring(nl + 1).trim();
    if (q.isNotEmpty && a.isNotEmpty) prompts.add(Prompt(q, a));
  }
  return prompts;
}
