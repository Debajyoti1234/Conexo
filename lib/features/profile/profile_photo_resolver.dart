import 'dart:async';

import 'package:flutter/widgets.dart';

import '../../core/supabase/auth_service.dart';
import 'supabase_profile_repository.dart';

class ResolvedProfilePhoto {
  const ResolvedProfilePhoto({
    required this.storagePath,
    required this.signedUrl,
    required this.imageProvider,
    required this.expiresAt,
  });

  final String storagePath;
  final String signedUrl;
  final ImageProvider imageProvider;
  final DateTime expiresAt;

  bool get isExpired => DateTime.now().isAfter(expiresAt);
}

class ProfilePhotoResolver {
  ProfilePhotoResolver._();

  static final ProfilePhotoResolver instance = ProfilePhotoResolver._();

  static const _cacheValiditySeconds = 3300;
  static const _maxCacheSize = 200;

  final SupabaseProfileRepository _repository = const SupabaseProfileRepository();

  final Map<String, ResolvedProfilePhoto> _cache = {};
  final Map<String, Future<ResolvedProfilePhoto>> _inFlight = {};

  ImageProvider? getProvider(String storagePath) {
    final entry = _cache[storagePath];
    if (entry == null || entry.isExpired) return null;
    return entry.imageProvider;
  }

  String? getSignedUrl(String storagePath) {
    final entry = _cache[storagePath];
    if (entry == null || entry.isExpired) return null;
    return entry.signedUrl;
  }

  Future<ResolvedProfilePhoto> resolvePhoto(String storagePath) async {
    if (storagePath.isEmpty) {
      throw StateError('Empty storage path');
    }

    final existing = _cache[storagePath];
    if (existing != null && !existing.isExpired) {
      return existing;
    }

    final inFlight = _inFlight[storagePath];
    if (inFlight != null) {
      return inFlight;
    }

    final request = _resolvePhotoInternal(storagePath);
    _inFlight[storagePath] = request;

    try {
      final result = await request;
      return result;
    } finally {
      _inFlight.remove(storagePath);
    }
  }

  Future<void> precachePhoto(
    String storagePath,
    BuildContext context, {
    VoidCallback? onReady,
  }) async {
    try {
      final resolved = await resolvePhoto(storagePath);
      if (!context.mounted) return;
      await precacheImage(resolved.imageProvider, context);
      onReady?.call();
    } catch (_) {
      // Individual photo failure must not block the screen.
    }
  }

  void invalidateProfile(String userId) {
    final prefix = 'profiles/$userId/';
    final keys = _cache.keys.where((k) => k.startsWith(prefix)).toList();
    for (final key in keys) {
      _cache.remove(key);
    }
  }

  void invalidatePath(String storagePath) {
    _cache.remove(storagePath);
  }

  void clear() {
    _cache.clear();
    _inFlight.clear();
  }

  Future<ResolvedProfilePhoto> _resolvePhotoInternal(String storagePath) async {
    final user = AuthService.currentUser;
    if (user == null) {
      throw StateError('No authenticated user');
    }

    final signedUrl = await _repository.getSignedPhotoUrl(storagePath);
    if (signedUrl == null || signedUrl.isEmpty) {
      throw StateError('Failed to sign photo: $storagePath');
    }

    final provider = NetworkImage(signedUrl);
    final expiresAt = DateTime.now().add(
      const Duration(seconds: _cacheValiditySeconds),
    );

    final result = ResolvedProfilePhoto(
      storagePath: storagePath,
      signedUrl: signedUrl,
      imageProvider: provider,
      expiresAt: expiresAt,
    );

    _cache[storagePath] = result;
    _enforceCacheLimit();

    return result;
  }

  void _enforceCacheLimit() {
    if (_cache.length <= _maxCacheSize) return;
    final entries = _cache.entries.toList()
      ..sort((a, b) => a.value.expiresAt.compareTo(b.value.expiresAt));
    for (var i = 0; i < entries.length - _maxCacheSize; i++) {
      _cache.remove(entries[i].key);
    }
  }
}
