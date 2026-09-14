import 'dart:async';

import 'mock_data.dart';

enum SessionStage { signedOut, needsProfile, ready }

/// A failure with a message that is safe to show to people.
class ConexoFailure implements Exception {
  const ConexoFailure(this.message);
  final String message;

  @override
  String toString() => message;
}

class LocationFix {
  const LocationFix({required this.latitude, required this.longitude, this.areaName});
  final double latitude;
  final double longitude;
  final String? areaName;
}

class ProfileInput {
  const ProfileInput({
    required this.name,
    required this.birthday,
    required this.gender,
    required this.job,
    required this.city,
    required this.photos,
    required this.prompts,
    required this.vibes,
    this.location,
  });

  final String name;
  final DateTime birthday;
  final String gender;
  final String job;
  final String city;
  final List<String> photos;
  final List<Prompt> prompts;
  final List<String> vibes;
  final LocationFix? location;
}

/// Discovery preferences. Null means "no limit".
class Preferences {
  const Preferences({this.minAge, this.maxAge, this.distanceKm});
  final int? minAge;
  final int? maxAge;
  final int? distanceKm;
}

sealed class SourceEvent {
  const SourceEvent();
}

class MessageEvent extends SourceEvent {
  const MessageEvent(this.matchId, this.message);
  final String matchId;
  final Message message;
}

class TypingEvent extends SourceEvent {
  const TypingEvent(this.matchId, this.typing);
  final String matchId;
  final bool typing;
}

class HeartEvent extends SourceEvent {
  const HeartEvent(this.matchId, this.messageId, this.userId, this.added);
  final String matchId;
  final String messageId;
  final String userId;
  final bool added;
}

class ConnectionsChanged extends SourceEvent {
  const ConnectionsChanged();
}

/// Everything the redesigned UI needs from a backend.
abstract class ConexoDataSource {
  bool get isLive;
  String get myId;
  String? get myEmail;

  /// Name captured at sign-up, used to pre-fill profile setup.
  String get pendingName;

  /// True when discovery can't run until the person shares a location.
  bool get needsLocation;

  Stream<SourceEvent> get events;

  Future<void> init();
  Future<SessionStage> restoreSession();
  Future<SessionStage> signIn(String email, String password);

  /// Returns true when the account still needs email confirmation.
  Future<bool> signUp({required String name, required String email, required String password});

  /// Returns null when the browser is redirected to finish sign-in.
  Future<SessionStage?> signInWithGoogle();
  Future<void> resetPassword(String email);
  Future<void> signOut();

  Future<Person?> loadMyProfile();
  Future<Person> saveMyProfile(ProfileInput input);

  /// Returns null when the picker is cancelled.
  Future<String?> pickAndUploadPhoto(List<String> existing);
  Future<LocationFix?> detectLocation();
  Future<void> updateLocation(LocationFix fix);
  Future<Preferences> loadPreferences();
  Future<void> savePreferences(Preferences prefs);

  Future<List<Person>> loadDiscover();

  /// Returns the match when the like is mutual.
  Future<Match?> like(Person person, {String? comment});
  Future<void> pass(Person person);
  Future<void> resetPasses();

  Future<List<Like>> loadLikesYou();
  Future<Match> acceptLike(Like like);
  Future<void> dismissLike(Like like);

  Future<List<Match>> loadMatches();
  Future<List<Message>> openConversation(Match match);
  void closeConversation(Match match);
  Future<Message> sendMessage(Match match, String text);
  Future<void> toggleHeart(Match match, Message message);
  Future<void> markRead(Match match);
  Future<void> unmatch(Match match);

  void dispose();
}
