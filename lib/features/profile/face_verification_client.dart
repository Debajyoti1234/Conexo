import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;

import '../../core/supabase/supabase_client.dart';

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
    print('[FaceVerification] step=verify-start platform=${kIsWeb ? "web" : "mobile"} baseUrlEmpty=${baseUrl.isEmpty}');
    if (baseUrl.isEmpty) {
      throw const FaceVerificationException(
        'Verification is temporarily unavailable. Please try again later.',
      );
    }

    final uri = Uri.parse('$baseUrl/api/v1/verify-face');
    print('[FaceVerification] step=api-url-resolved host=${uri.host} path=${uri.path}');
    final request = http.MultipartRequest('POST', uri);
    print('[FaceVerification] step=multipart-created');

    request.headers.addAll({
      'Authorization': 'Bearer $accessToken',
    });

    request.files.add(
      http.MultipartFile.fromBytes(
        'selfie',
        selfieBytes,
        filename: 'selfie.jpg',
      ),
    );
    print('[FaceVerification] step=file-attached bytes=${selfieBytes.length}');

    print('[FaceVerification] step=send-start');
    final streamed = await request.send().timeout(
      const Duration(seconds: 30),
      onTimeout: () => throw const FaceVerificationException(
        'Verification is temporarily unavailable. Please try again later.',
      ),
    );
    print('[FaceVerification] step=send-complete status=${streamed.statusCode}');

    final status = streamed.statusCode;
    final body = await streamed.stream.bytesToString().timeout(
      const Duration(seconds: 30),
      onTimeout: () => throw const FaceVerificationException(
        'Verification is temporarily unavailable. Please try again later.',
      ),
    );
    print('[FaceVerification] step=response-read-complete bytes=${body.length} status=$status');

    if (status == 204) {
      return const VerificationResult(
        match: false,
        reason: 'internal_error',
      );
    }

    Map<String, dynamic> json;
    try {
      json = jsonDecode(body) as Map<String, dynamic>;
    } on FormatException {
      return const VerificationResult(
        match: false,
        reason: 'internal_error',
      );
    }

    if (status == 200) {
      return VerificationResult.fromJson(json);
    }

    final reason = json['reason'] as String? ?? 'internal_error';
    return VerificationResult(
      match: false,
      reason: _mapClientError(status, reason),
    );
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
