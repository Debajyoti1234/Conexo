import 'dart:async';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';
import 'package:http/http.dart' as http;
import 'package:image_picker/image_picker.dart';
import 'package:record/record.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../core/supabase/auth_service.dart';
import '../../core/services/image_normalizer.dart';

class ChatAttachmentResult<T> {
  const ChatAttachmentResult._(this._value, this._error);

  const ChatAttachmentResult.success(T value) : this._(value, null);
  const ChatAttachmentResult.failure(String error) : this._(null, error);

  final T? _value;
  final String? _error;

  T? get value => _value;
  String? get error => _error;
  bool get isSuccess => error == null;
  bool get isFailure => error != null;
}

class ResolvedChatAttachment {
  const ResolvedChatAttachment({
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

class ChatAttachmentService {
  ChatAttachmentService._();

  static final ChatAttachmentService instance = ChatAttachmentService._();

  static const _bucket = 'chat-attachments';
  static const _cacheValiditySeconds = 3300;
  static const _maxCacheSize = 200;

  final Map<String, ResolvedChatAttachment> _cache = {};
  final Map<String, Future<ResolvedChatAttachment>> _inFlight = {};

  AudioRecorder? _recorder;
  DateTime? _recordingStartedAt;

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

  Future<ResolvedChatAttachment> resolveAttachment(String storagePath) async {
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

    final request = _resolveAttachmentInternal(storagePath);
    _inFlight[storagePath] = request;

    try {
      final result = await request;
      return result;
    } finally {
      _inFlight.remove(storagePath);
    }
  }

  Future<void> precacheAttachment(
    String storagePath,
    BuildContext context, {
    VoidCallback? onReady,
  }) async {
    try {
      final resolved = await resolveAttachment(storagePath);
      if (!context.mounted) return;
      await precacheImage(resolved.imageProvider, context);
      onReady?.call();
    } catch (_) {
      // Individual attachment failure must not block the screen.
    }
  }

  void invalidateConversation(String conversationId) {
    final prefix = 'chat-attachments/$conversationId/';
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

  Future<ResolvedChatAttachment> _resolveAttachmentInternal(
    String storagePath,
  ) async {
    final user = AuthService.currentUser;
    if (user == null) {
      throw StateError('No authenticated user');
    }

    final signedUrl = await Supabase.instance.client.storage
        .from(_bucket)
        .createSignedUrl(storagePath, 3600);

    if (signedUrl.isEmpty) {
      throw StateError('Failed to sign attachment: $storagePath');
    }

    final provider = NetworkImage(signedUrl);
    final expiresAt = DateTime.now().add(
      const Duration(seconds: _cacheValiditySeconds),
    );

    final result = ResolvedChatAttachment(
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

  Future<ChatAttachmentResult<String>> pickAndUploadImage({
    String? conversationId,
  }) async {
    try {
      final picker = ImagePicker();
      final XFile? picked = await picker.pickImage(
        source: ImageSource.gallery,
        imageQuality: 100,
        maxWidth: 4096,
        maxHeight: 4096,
      );

      if (picked == null) {
        return const ChatAttachmentResult.failure('No image selected');
      }

      final user = AuthService.currentUser;
      if (user == null) {
        return const ChatAttachmentResult.failure('Not authenticated');
      }

      final rawBytes = await picked.readAsBytes();

      if (rawBytes.isEmpty) {
        return const ChatAttachmentResult.failure('Empty image file');
      }

      if (rawBytes.length > 50 * 1024 * 1024) {
        return const ChatAttachmentResult.failure('Image exceeds 50MB limit');
      }

      final normalized = await ConexoImageNormalizer.normalize(rawBytes);

      final messageId = _generateUniqueId();
      final safeConversationId = conversationId ?? 'unknown';
      final storagePath = '$_bucket/$safeConversationId/$messageId.jpg';

      await Supabase.instance.client.storage
          .from(_bucket)
          .uploadBinary(
            storagePath,
            normalized.bytes,
            fileOptions: const FileOptions(
              contentType: 'image/jpeg',
              upsert: false,
            ),
          );

      return ChatAttachmentResult.success(storagePath);
    } on AuthException catch (e) {
      return ChatAttachmentResult.failure(e.message);
    } catch (e) {
      if (kDebugMode) {
        debugPrint('pickAndUploadImage FAILED: $e');
      }
      return ChatAttachmentResult.failure('Failed to upload image');
    }
  }

  Future<ChatAttachmentResult<void>> deleteAttachment(String storagePath) async {
    try {
      await Supabase.instance.client.storage
          .from(_bucket)
          .remove([storagePath]);
      _cache.remove(storagePath);
      return const ChatAttachmentResult.success(null);
    } on AuthException catch (e) {
      return ChatAttachmentResult.failure(e.message);
    } catch (e) {
      if (kDebugMode) {
        debugPrint('deleteAttachment FAILED: $e');
      }
      return ChatAttachmentResult.failure('Failed to delete image');
    }
  }

  Future<ChatAttachmentResult<void>> startVoiceRecording() async {
    try {
      _recorder ??= AudioRecorder();

      if (await _recorder!.isRecording()) {
        return const ChatAttachmentResult.failure('Already recording');
      }

      final hasPermission = await _recorder!.hasPermission();
      if (!hasPermission) {
        return const ChatAttachmentResult.failure('Microphone permission denied');
      }

      final tempDir = Directory.systemTemp;
      final tempPath = '${tempDir.path}/conexo_voice_${_generateUniqueId()}.m4a';

      if (kDebugMode) {
        debugPrint('startVoiceRecording: permission granted, starting at $tempPath');
      }

      await _recorder!.start(
        RecordConfig(
          encoder: AudioEncoder.aacLc,
          sampleRate: 22050,
          bitRate: 32000,
          numChannels: 1,
        ),
        path: tempPath,
      );

      _recordingStartedAt = DateTime.now();

      return const ChatAttachmentResult.success(null);
    } on AuthException catch (e) {
      return ChatAttachmentResult.failure(e.message);
    } catch (e) {
      if (kDebugMode) {
        debugPrint('startVoiceRecording FAILED: $e');
      }
      return ChatAttachmentResult.failure('Failed to start recording');
    }
  }

  Future<ChatAttachmentResult<String?>> stopVoiceRecording({
    String? conversationId,
  }) async {
    try {
      if (_recorder == null || !await _recorder!.isRecording()) {
        return const ChatAttachmentResult.failure('Not recording');
      }

      final tempPath = await _recorder!.stop();
      _recordingStartedAt = null;

      if (tempPath == null || tempPath.isEmpty) {
        return const ChatAttachmentResult.failure('Recording empty');
      }

      final file = File(tempPath);
      if (!await file.exists()) {
        return const ChatAttachmentResult.failure('Recording file missing');
      }

      final rawBytes = await file.readAsBytes();
      if (rawBytes.isEmpty) {
        return const ChatAttachmentResult.failure('Recording is empty');
      }

      final user = AuthService.currentUser;
      if (user == null) {
        return const ChatAttachmentResult.failure('Not authenticated');
      }

      final messageId = _generateUniqueId();
      final safeConversationId = conversationId ?? 'unknown';
      final storagePath = '$_bucket/$safeConversationId/$messageId.m4a';

      if (kDebugMode) {
        debugPrint('stopVoiceRecording: uploading to $storagePath (bytes=${rawBytes.length})');
      }

      await Supabase.instance.client.storage
          .from(_bucket)
          .uploadBinary(
            storagePath,
            rawBytes,
            fileOptions: const FileOptions(
              contentType: 'audio/mp4',
              upsert: false,
            ),
          );

      if (kDebugMode) {
        debugPrint('stopVoiceRecording: upload complete: $storagePath');
      }

      return ChatAttachmentResult.success(storagePath);
    } on AuthException catch (e) {
      return ChatAttachmentResult.failure(e.message);
    } catch (e) {
      if (kDebugMode) {
        debugPrint('stopVoiceRecording FAILED: $e');
      }
      return ChatAttachmentResult.failure('Failed to upload voice');
    }
  }

  Future<void> cancelVoiceRecording() async {
    try {
      if (_recorder != null && await _recorder!.isRecording()) {
        await _recorder!.stop();
      }
    } catch (_) {
      // ignore cancel errors
    } finally {
      _recordingStartedAt = null;
    }
  }

  Duration? get voiceRecordingDuration {
    if (_recordingStartedAt == null) return null;
    return DateTime.now().difference(_recordingStartedAt!);
  }

  bool get isVoiceRecording =>
      _recorder != null && _recordingStartedAt != null;

  String _generateUniqueId() {
    final now = DateTime.now();
    final micro = now.microsecondsSinceEpoch;
    final seed = micro * 1000 + now.millisecond;
    final hex1 = (seed % 0xFFFFFFFF).toRadixString(16).padLeft(8, '0');
    final hex2 = ((seed >> 32) % 0xFFFFFFFF).toRadixString(16).padLeft(8, '0');
    final random = (seed * 2654435761) & 0xFFFFFFFF;
    final hex3 = random.toRadixString(16).padLeft(8, '0');
    return '$hex1$hex2$hex3';
  }

  /// Downloads a GIF from a remote [url] and uploads it to the existing
  /// `chat-attachments` Storage bucket, returning the storage path.
  /// Reuses the SAME bucket, path scheme, and RLS as images/voice — no new
  /// backend tables or policies are required.
  Future<ChatAttachmentResult<String>> pickAndUploadGif({
    required String url,
    String? conversationId,
  }) async {
    try {
      if (url.isEmpty) {
        return const ChatAttachmentResult.failure('Empty GIF URL');
      }

      final user = AuthService.currentUser;
      if (user == null) {
        return const ChatAttachmentResult.failure('Not authenticated');
      }

      final response = await http
          .get(Uri.parse(url))
          .timeout(const Duration(seconds: 15));

      if (response.statusCode != 200) {
        return ChatAttachmentResult.failure(
          'Failed to download GIF (HTTP ${response.statusCode})',
        );
      }

      final rawBytes = response.bodyBytes;
      if (rawBytes.isEmpty) {
        return const ChatAttachmentResult.failure('Empty GIF file');
      }

      if (rawBytes.length > 50 * 1024 * 1024) {
        return const ChatAttachmentResult.failure('GIF exceeds 50MB limit');
      }

      final messageId = _generateUniqueId();
      final safeConversationId = conversationId ?? 'unknown';
      final storagePath = '$_bucket/$safeConversationId/$messageId.gif';

      if (kDebugMode) {
        debugPrint('pickAndUploadGif: uploading to $storagePath (bytes=${rawBytes.length})');
      }

      await Supabase.instance.client.storage
          .from(_bucket)
          .uploadBinary(
            storagePath,
            rawBytes,
            fileOptions: const FileOptions(
              contentType: 'image/gif',
              upsert: false,
            ),
          );

      return ChatAttachmentResult.success(storagePath);
    } on AuthException catch (e) {
      return ChatAttachmentResult.failure(e.message);
    } catch (e) {
      if (kDebugMode) {
        debugPrint('pickAndUploadGif FAILED: $e');
      }
      return const ChatAttachmentResult.failure('Failed to upload GIF');
    }
  }
}