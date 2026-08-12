import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../core/supabase/auth_service.dart';
import 'connection_data.dart';
import 'connection_repository.dart';

class ConnectionUiModel {
  const ConnectionUiModel({
    required this.connectionId,
    required this.otherUserId,
    required this.otherUserName,
    this.otherUserAge,
    this.otherUserOccupation,
    this.otherUserCity,
    this.otherUserPortrait,
    this.otherUserColor,
    this.otherUserBio,
    this.otherUserLanguages = const [],
    this.otherUserAvailabilityStatus,
    this.mutualInterests = const [],
    this.isVerified = false,
    required this.status,
    required this.direction,
    required this.createdAt,
    required this.updatedAt,
  });

  final String connectionId;
  final String otherUserId;
  final String otherUserName;
  final int? otherUserAge;
  final String? otherUserOccupation;
  final String? otherUserCity;
  final String? otherUserPortrait;
  final Color? otherUserColor;
  final String? otherUserBio;
  final List<String> otherUserLanguages;
  final String? otherUserAvailabilityStatus;
  final List<String> mutualInterests;
  final bool isVerified;
  final ConnectionStatus status;
  final ConnectionDirection direction;
  final DateTime createdAt;
  final DateTime updatedAt;

  bool get isPending => status == ConnectionStatus.pending;
  bool get isAccepted => status == ConnectionStatus.accepted;
  bool get isRejected => status == ConnectionStatus.rejected;
  bool get isCancelled => status == ConnectionStatus.cancelled;
}

class ConnectionsViewModel {
  const ConnectionsViewModel();

  Future<List<ConnectionUiModel>> loadAcceptedConnections() async {
    final user = AuthService.currentUser;
    if (user == null) return const [];

    final connectionResult = await const ConnectionRepository().getMyConnections();
    if (connectionResult.isFailure) return const [];

    final accepted = connectionResult.value!
        .where((c) => c.status == ConnectionStatus.accepted)
        .toList();

    if (accepted.isEmpty) return const [];

    final otherIds = accepted
        .map((c) => c.otherUserId(user.id))
        .toList(growable: false);

    final profiles = await _fetchProfiles(otherIds);

    return accepted
        .map((c) {
          final otherId = c.otherUserId(user.id);
          final profile = profiles[otherId];
          final name = _profileString(profile, ['display_name', 'name']) ?? 'Unknown';
          final age = _profileAge(profile);
          final occupation = _profileString(profile, ['occupation']);
          final location = _profileString(profile, ['location']);
          final portrait = _profilePortrait(profile);
          final interests = _profileStringList(profile, ['interests']);
          final isVerified = _profileVerification(profile);
          final bio = _profileBio(profile);
          final languages = _profileLanguages(profile);
          final availabilityStatus = _profileAvailabilityStatus(profile);

          return ConnectionUiModel(
            connectionId: c.id,
            otherUserId: otherId,
            otherUserName: name,
            otherUserAge: age,
            otherUserOccupation: occupation,
            otherUserCity: location,
            otherUserPortrait: portrait,
            otherUserColor: _colorForName(name),
            otherUserBio: bio,
            otherUserLanguages: languages,
            otherUserAvailabilityStatus: availabilityStatus,
            mutualInterests: interests,
            isVerified: isVerified,
            status: c.status,
            direction: c.directionFor(user.id),
            createdAt: c.createdAt,
            updatedAt: c.updatedAt,
          );
        })
        .toList(growable: false);
  }

  Future<List<ConnectionUiModel>> loadIncomingRequests() async {
    final user = AuthService.currentUser;
    if (user == null) return const [];

    final connectionResult =
        await const ConnectionRepository().getIncomingRequests();
    if (connectionResult.isFailure) return const [];

    final incoming = connectionResult.value!;
    if (incoming.isEmpty) return const [];

    final requesterIds = incoming
        .map((c) => c.requesterId)
        .toList(growable: false);

    final profiles = await _fetchProfiles(requesterIds);

    return incoming
        .map((c) {
          final profile = profiles[c.requesterId];
          final name = _profileString(profile, ['display_name', 'name']) ?? 'Unknown';
          final age = _profileAge(profile);
          final occupation = _profileString(profile, ['occupation']);
          final location = _profileString(profile, ['location']);
          final portrait = _profilePortrait(profile);
          final interests = _profileStringList(profile, ['interests']);
          final isVerified = _profileVerification(profile);
          final bio = _profileBio(profile);
          final languages = _profileLanguages(profile);
          final availabilityStatus = _profileAvailabilityStatus(profile);

          return ConnectionUiModel(
            connectionId: c.id,
            otherUserId: c.requesterId,
            otherUserName: name,
            otherUserAge: age,
            otherUserOccupation: occupation,
            otherUserCity: location,
            otherUserPortrait: portrait,
            otherUserColor: _colorForName(name),
            otherUserBio: bio,
            otherUserLanguages: languages,
            otherUserAvailabilityStatus: availabilityStatus,
            mutualInterests: interests,
            isVerified: isVerified,
            status: c.status,
            direction: ConnectionDirection.received,
            createdAt: c.createdAt,
            updatedAt: c.updatedAt,
          );
        })
        .toList(growable: false);
  }

  Future<List<ConnectionUiModel>> loadOutgoingRequests() async {
    final user = AuthService.currentUser;
    if (user == null) return const [];

    final connectionResult =
        await const ConnectionRepository().getOutgoingRequests();
    if (connectionResult.isFailure) return const [];

    final outgoing = connectionResult.value!;
    if (outgoing.isEmpty) return const [];

    final recipientIds = outgoing
        .map((c) => c.recipientId)
        .toList(growable: false);

    final profiles = await _fetchProfiles(recipientIds);

    return outgoing
        .map((c) {
          final profile = profiles[c.recipientId];
          final name = _profileString(profile, ['display_name', 'name']) ?? 'Unknown';
          final age = _profileAge(profile);
          final occupation = _profileString(profile, ['occupation']);
          final location = _profileString(profile, ['location']);
          final portrait = _profilePortrait(profile);
          final interests = _profileStringList(profile, ['interests']);
          final isVerified = _profileVerification(profile);
          final bio = _profileBio(profile);
          final languages = _profileLanguages(profile);
          final availabilityStatus = _profileAvailabilityStatus(profile);

          return ConnectionUiModel(
            connectionId: c.id,
            otherUserId: c.recipientId,
            otherUserName: name,
            otherUserAge: age,
            otherUserOccupation: occupation,
            otherUserCity: location,
            otherUserPortrait: portrait,
            otherUserColor: _colorForName(name),
            otherUserBio: bio,
            otherUserLanguages: languages,
            otherUserAvailabilityStatus: availabilityStatus,
            mutualInterests: interests,
            isVerified: isVerified,
            status: c.status,
            direction: ConnectionDirection.sent,
            createdAt: c.createdAt,
            updatedAt: c.updatedAt,
          );
        })
        .toList(growable: false);
  }

  Future<ConnectionResult<void>> acceptRequest(String connectionId) async {
    return await const ConnectionRepository().acceptRequest(connectionId);
  }

  Future<ConnectionResult<void>> rejectRequest(String connectionId) async {
    return await const ConnectionRepository().rejectRequest(connectionId);
  }

  Future<ConnectionResult<void>> cancelRequest(String connectionId) async {
    return await const ConnectionRepository().cancelRequest(connectionId);
  }

  Future<Map<String, Map<String, dynamic>>> _fetchProfiles(
      List<String> userIds) async {
    if (userIds.isEmpty) return const {};

    final result = await Supabase.instance.client
        .from('profiles')
        .select()
        .inFilter('id', userIds);

    final map = <String, Map<String, dynamic>>{};
    for (final row in result) {
      final id = row['id'] as String;
      map[id] = Map<String, dynamic>.from(row as Map);
    }
    return map;
  }

  String? _profileString(
      Map<String, dynamic>? profile, List<String> keys) {
    if (profile == null) return null;
    for (final key in keys) {
      final value = profile[key];
      if (value is String && value.isNotEmpty) return value;
    }
    return null;
  }

  int? _profileAge(Map<String, dynamic>? profile) {
    final raw = profile?['date_of_birth'];
    if (raw is! String || raw.isEmpty) return null;
    return _ageFromDate(raw);
  }

  String? _profilePortrait(Map<String, dynamic>? profile) {
    final photos = profile?['photos'];
    if (photos is! List || photos.isEmpty) return null;
    final first = photos.first;
    if (first is! Map) return null;
    final assetPath = first['assetPath'];
    if (assetPath is String && assetPath.isNotEmpty) return assetPath;
    return null;
  }

  List<String> _profileStringList(
      Map<String, dynamic>? profile, List<String> keys) {
    if (profile == null) return const [];
    for (final key in keys) {
      final value = profile[key];
      if (value is List) {
        return [for (final e in value) '$e'];
      }
    }
    return const [];
  }

  bool _profileVerification(Map<String, dynamic>? profile) {
    final raw = profile?['verification_status'];
    if (raw is! String) return false;
    return raw == 'verified';
  }

  String? _profileBio(Map<String, dynamic>? profile) {
    final raw = profile?['bio'];
    if (raw is! String || raw.isEmpty) return null;
    return raw;
  }

  List<String> _profileLanguages(Map<String, dynamic>? profile) {
    final raw = profile?['languages'];
    if (raw is! List) return const [];
    return [for (final e in raw) '$e'];
  }

  String? _profileAvailabilityStatus(Map<String, dynamic>? profile) {
    final raw = profile?['availability_status'];
    if (raw is! String || raw.isEmpty) return null;
    return raw;
  }

  int? _ageFromDate(String dateOfBirth) {
    try {
      final dob = DateTime.parse(dateOfBirth);
      final now = DateTime.now();
      var age = now.year - dob.year;
      if (now.month < dob.month ||
          (now.month == dob.month && now.day < dob.day)) {
        age--;
      }
      return age;
    } catch (_) {
      return null;
    }
  }

  Color _colorForName(String name) {
    if (name.isEmpty) return const Color(0xFF8B5CF6);
    var hash = 0;
    for (var i = 0; i < name.length; i++) {
      hash = name.codeUnitAt(i) + ((hash << 5) - hash);
    }
    final hue = ((hash % 360) + 360) % 360;
    return HSLColor.fromAHSL(1.0, hue.toDouble(), 0.55, 0.55).toColor();
  }
}
