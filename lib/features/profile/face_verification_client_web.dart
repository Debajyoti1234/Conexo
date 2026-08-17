import 'dart:async';
import 'dart:convert';
import 'dart:html' as html;

import 'package:flutter/foundation.dart';

import '../../core/supabase/supabase_client.dart';
import '../../core/services/image_normalizer.dart';

class FaceVerificationException implements Exception {
  const FaceVerificationException(this.message);
  final String message;

  @override
  String toString() => message;
}

class VerificationResult {
  const VerificationResult({
    required this.match,
    required this.reason,
    this.similarity,
  });

  final bool match;
  final String reason;
  final double? similarity;

  factory VerificationResult.fromJson(Map<String, dynamic> json) {
    return VerificationResult(
      match: json['match'] as bool? ?? false,
      reason: json['reason'] as String? ?? 'internal_error',
      similarity: (json['similarity'] as num?)?.toDouble(),
    );
  }
}

class FaceVerificationClient {
  const FaceVerificationClient();

  Future<VerificationResult> verifyFace({
    required Uint8List selfieBytes,
    required String accessToken,
  }) async {
    final baseUrl = SupabaseClientConfig.faceVerificationApiUrl;
    print(
      '[FaceVerification] step=verify-start platform=web baseUrlEmpty=${baseUrl.isEmpty}',
    );
    if (baseUrl.isEmpty) {
      throw const FaceVerificationException(
        'Verification is temporarily unavailable. Please try again later.',
      );
    }

    final uri = Uri.parse('$baseUrl/api/v1/verify-face');
    print('[FaceVerification] step=api-url-resolved host=${uri.host} path=${uri.path}');

    final normalized = await ConexoImageNormalizer.normalize(selfieBytes);
    print(
      '[FaceVerification] step=normalized original=${selfieBytes.length} '
      'normalized=${normalized.bytes.length}',
    );

    final formData = html.FormData();
    final blob = html.Blob([normalized.bytes], 'image/jpeg');
    (formData as dynamic).append('selfie', blob, 'selfie.jpg');

    print(
      '[FaceVerification] step=formdata-prepared filename=selfie.jpg '
      'contentType=image/jpeg bytes=${normalized.bytes.length}',
    );

    final request = html.HttpRequest();
    request.open('POST', uri.toString());
    request.setRequestHeader('Authorization', 'Bearer $accessToken');

    final completer = Completer<VerificationResult>();

    final timer = Timer(const Duration(seconds: 30), () {
      if (!completer.isCompleted) {
        completer.completeError(const FaceVerificationException(
          'Verification is temporarily unavailable. Please try again later.',
        ));
      }
    });

    request.onReadyStateChange.listen((_) {
      if (request.readyState != html.HttpRequest.DONE) return;

      timer.cancel();

      final status = request.status ?? 0;
      print('[FaceVerification] step=send-complete status=$status');

      final body = request.responseText ?? '';
      print(
        '[FaceVerification] step=response-read-complete bytes=${body.length} status=$status',
      );

      if (status == 204) {
        completer.complete(const VerificationResult(
          match: false,
          reason: 'internal_error',
        ));
        return;
      }

      Map<String, dynamic> json;
      try {
        json = jsonDecode(body) as Map<String, dynamic>;
      } on FormatException {
        completer.complete(const VerificationResult(
          match: false,
          reason: 'internal_error',
        ));
        return;
      }

      if (status == 200) {
        completer.complete(VerificationResult.fromJson(json));
        return;
      }

      String reason;
      final detail = json['detail'];
      if (detail is Map<String, dynamic>) {
        reason = detail['reason'] as String? ?? 'internal_error';
      } else {
        reason = json['reason'] as String? ?? 'internal_error';
      }

      if (status == 400) {
        print('[FaceVerification] step=error-response status=400 reason=$reason');
      }

      completer.complete(VerificationResult(
        match: false,
        reason: _mapClientError(status, reason),
      ));
    });

    request.onError.listen((_) {
      timer.cancel();
      if (!completer.isCompleted) {
        completer.completeError(const FaceVerificationException(
          'Verification is temporarily unavailable. Please try again later.',
        ));
      }
    });

    request.send(formData);

    return completer.future;
  }

  String _mapClientError(int status, String reason) {
    switch (status) {
      case 400:
        return _mapClientReason(reason);
      case 401:
        return 'session_expired';
      case 404:
        return _mapClientReason(reason);
      case 422:
        return _mapClientReason(reason);
      case 429:
        return 'rate_limited';
      case 500:
      default:
        return 'internal_error';
    }
  }

  String _mapClientReason(String reason) {
    switch (reason) {
      case 'no_face':
      case 'multiple_faces':
      case 'invalid_image':
        return reason;
      case 'low_similarity':
        return 'low_similarity';
      case 'no_primary_photo':
        return 'no_primary_photo';
      case 'invalid_primary_photo':
        return 'invalid_primary_photo';
      case 'missing_selfie':
      case 'file_too_large':
      case 'invalid_file_type':
        return reason;
      case 'profile_not_found':
        return 'profile_not_found';
      case 'storage_failure':
        return 'storage_failure';
      case 'embedding_failed':
        return 'embedding_failed';
      case 'primary_photo_embedding_failed':
        return 'primary_photo_embedding_failed';
      case 'verification_update_failed':
        return 'verification_update_failed';
      default:
        return 'internal_error';
    }
  }
}
