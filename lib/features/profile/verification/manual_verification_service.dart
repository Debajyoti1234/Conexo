import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../core/supabase/auth_service.dart';
import '../../../core/services/image_normalizer.dart';

enum ManualVerificationStage { idle, checking, uploading, submitting, done }

class ManualVerificationRequest {
  const ManualVerificationRequest({
    required this.id,
    required this.userId,
    required this.status,
    required this.selfiePath,
    required this.idFrontPath,
    required this.idBackPath,
    required this.createdAt,
  });

  factory ManualVerificationRequest.fromMap(Map<String, dynamic> map) {
    return ManualVerificationRequest(
      id: map['id'] as String,
      userId: map['user_id'] as String,
      status: map['status'] as String,
      selfiePath: map['selfie_path'] as String,
      idFrontPath: map['id_front_path'] as String,
      idBackPath: map['id_back_path'] as String?,
      createdAt: map['created_at'] != null
          ? DateTime.tryParse(map['created_at'] as String)
          : null,
    );
  }

  final String id;
  final String userId;
  final String status;
  final String selfiePath;
  final String idFrontPath;
  final String? idBackPath;
  final DateTime? createdAt;
}

class ManualVerificationException implements Exception {
  const ManualVerificationException(this.message);
  final String message;

  @override
  String toString() => message;
}

class ManualVerificationService {
  const ManualVerificationService();

  static const String _bucket = 'verification-documents';

  Future<ManualVerificationRequest?> checkExistingPending() async {
    final userId = _currentUserId;
    if (userId.isEmpty) return null;

    try {
      final response = await Supabase.instance.client
          .from('manual_verification_requests')
          .select()
          .eq('user_id', userId)
          .eq('status', 'pending_review')
          .limit(1);

      if (response.isNotEmpty) {
        final row = response.first;
        return ManualVerificationRequest.fromMap(row);
      }
    } catch (_) {
      // If the query fails, proceed as if no pending request exists.
    }
    return null;
  }

  Future<ManualVerificationRequest?> submit({
    required Uint8List selfieBytes,
    required Uint8List idFrontBytes,
    Uint8List? idBackBytes,
  }) async {
    final userId = _currentUserId;
    if (userId.isEmpty) {
      throw const ManualVerificationException('Not authenticated. Please sign in again.');
    }

    final requestId = _generateRequestId();
    final selfiePath = '$userId/$requestId/selfie.jpg';
    final idFrontPath = '$userId/$requestId/id_front.jpg';
    final idBackPath = idBackBytes != null
        ? '$userId/$requestId/id_back.jpg'
        : null;

    final uploadedPaths = <String>[];

    try {
      final selfieNormalized =
          await ConexoImageNormalizer.normalize(selfieBytes);
      final idFrontNormalized =
          await ConexoImageNormalizer.normalize(idFrontBytes);
      Uint8List? idBackBytesCompressed;
      if (idBackBytes != null) {
        idBackBytesCompressed =
            (await ConexoImageNormalizer.normalize(idBackBytes)).bytes;
      }

      await Supabase.instance.client.storage.from(_bucket).uploadBinary(
            selfiePath,
            selfieNormalized.bytes,
            fileOptions: const FileOptions(contentType: 'image/jpeg'),
          );
      uploadedPaths.add(selfiePath);

      await Supabase.instance.client.storage.from(_bucket).uploadBinary(
            idFrontPath,
            idFrontNormalized.bytes,
            fileOptions: const FileOptions(contentType: 'image/jpeg'),
          );
      uploadedPaths.add(idFrontPath);

      if (idBackPath != null && idBackBytesCompressed != null) {
        await Supabase.instance.client.storage.from(_bucket).uploadBinary(
              idBackPath,
              idBackBytesCompressed,
              fileOptions: const FileOptions(contentType: 'image/jpeg'),
            );
        uploadedPaths.add(idBackPath);
      }

      final insertPayload = <String, dynamic>{
        'user_id': userId,
        'status': 'pending_review',
        'selfie_path': selfiePath,
        'id_front_path': idFrontPath,
      };
      if (idBackPath != null) {
        insertPayload['id_back_path'] = idBackPath;
      }

      final response = await Supabase.instance.client
          .from('manual_verification_requests')
          .insert(insertPayload)
          .select()
          .single();

      final request = ManualVerificationRequest.fromMap(response);

      await Supabase.instance.client
          .from('profiles')
          .update({'verification_status': 'pending'})
          .eq('id', userId);

      return request;
    } catch (e) {
      debugPrint('ManualVerificationService submit error: $e');
      await _cleanupUploadedFiles(uploadedPaths);
      rethrow;
    }
  }

  Future<void> _cleanupUploadedFiles(List<String> paths) async {
    if (paths.isEmpty) return;
    try {
      for (final path in paths) {
        await Supabase.instance.client.storage.from(_bucket).remove([path]);
      }
      debugPrint('ManualVerificationService cleanup: removed $paths');
    } catch (e) {
      debugPrint('ManualVerificationService cleanup failed: $e');
    }
  }

  String get _currentUserId {
    return AuthService.currentUser?.id ?? '';
  }

  String _generateRequestId() {
    return 'mv_${DateTime.now().millisecondsSinceEpoch}_${_currentUserId.substring(0, 8)}';
  }
}