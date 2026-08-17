import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
// ignore: depend_on_referenced_packages
import 'package:http_parser/http_parser.dart';

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

/// Cross-platform face-verification transport.
///
/// This is the last known-good architecture: a single `package:http`
/// [http.MultipartRequest]. It works identically on mobile (via `dart:io`
/// `HttpClient`) and on Flutter web (via `package:http`'s `BrowserClient`,
/// which sends `request.finalize().toBytes()` — the fully serialized multipart
/// body — verbatim through `window.fetch`).
///
/// Because the whole multipart body (including the per-part `Content-Type`) is
/// serialized by `package:http` before it ever reaches the browser, whatever
/// [MediaType] we set on the [http.MultipartFile] is exactly what Railway
/// receives. If [http.MultipartFile.fromBytes] is called WITHOUT a
/// `contentType`, the part defaults to `application/octet-stream` (see
/// `MultipartFile`'s constructor), which is baked into the body and makes
/// Railway reject the upload with HTTP 400. Setting
/// `contentType: MediaType('image', 'jpeg')` is therefore the whole fix for the
/// iOS Safari `application/octet-stream` problem — the browser does not strip
/// or override it.
class FaceVerificationClient {
  const FaceVerificationClient();

  Future<VerificationResult> verifyFace({
    required Uint8List selfieBytes,
    required String accessToken,
  }) async {
    _trace('verification-start platform=${kIsWeb ? "web" : "mobile"}');

    final baseUrl = SupabaseClientConfig.faceVerificationApiUrl;
    if (baseUrl.isEmpty) {
      throw const FaceVerificationException(
        'Verification is temporarily unavailable. Please try again later.',
      );
    }

    final uri = Uri.parse('$baseUrl/api/v1/verify-face');
    _trace('source-byte-length value=${selfieBytes.length}');

    // Canonicalize to JPEG bytes so the transmitted image is always a real
    // JPEG regardless of what the browser/camera produced.
    final normalized = await ConexoImageNormalizer.normalize(selfieBytes);
    _trace(
      'normalized original=${selfieBytes.length} normalized=${normalized.bytes.length}',
    );
    _trace('normalized-filename value=selfie.jpg');
    _trace('normalized-mime value=${normalized.contentType}');

    final request = http.MultipartRequest('POST', uri);
    _trace('multipart-created');

    request.headers.addAll({
      'Authorization': 'Bearer $accessToken',
    });

    // The per-part Content-Type below is written into the multipart body by
    // package:http and sent verbatim on every platform (including iOS Safari
    // via window.fetch). This is what makes Railway see image/jpeg.
    final filePart = http.MultipartFile.fromBytes(
      'selfie',
      normalized.bytes,
      filename: 'selfie.jpg',
      contentType: MediaType('image', 'jpeg'),
    );
    request.files.add(filePart);
    _trace('multipart-file-created');
    _trace('multipart-file-content-type value=${filePart.contentType}');
    _trace('multipart-file-filename value=${filePart.filename}');
    _trace('request-created host=${uri.host} path=${uri.path}');

    final http.StreamedResponse streamed;
    try {
      _trace('send-start');
      streamed = await request.send().timeout(
        const Duration(seconds: 30),
        onTimeout: () => throw const FaceVerificationException(
          'Verification is temporarily unavailable. Please try again later.',
        ),
      );
    } on FaceVerificationException {
      rethrow;
    } catch (e) {
      // Client-side / CORS / network failure BEFORE a response is received.
      _trace('send-exception error=$e');
      throw const FaceVerificationException(
        'Verification is temporarily unavailable. Please try again later.',
      );
    }
    _trace('send-complete status=${streamed.statusCode}');

    final status = streamed.statusCode;
    final body = await streamed.stream.bytesToString().timeout(
      const Duration(seconds: 30),
      onTimeout: () => throw const FaceVerificationException(
        'Verification is temporarily unavailable. Please try again later.',
      ),
    );
    _trace('response-status value=$status');
    _trace('response-body value=$body');

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

    String reason;
    final detail = json['detail'];
    if (detail is Map<String, dynamic>) {
      reason = detail['reason'] as String? ?? 'internal_error';
    } else {
      reason = json['reason'] as String? ?? 'internal_error';
    }

    return VerificationResult(
      match: false,
      reason: _mapClientError(status, reason),
    );
  }

  /// Temporary diagnostic tracing for the selfie verification transport.
  /// Debug-only (stripped from release builds) — safe to remove once iOS
  /// Safari has been confirmed on a physical device.
  void _trace(String message) {
    if (kDebugMode) {
      // ignore: avoid_print
      print('[FaceVerificationWebTrace] step=$message');
    }
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
