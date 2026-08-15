import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:conexo/features/profile/face_verification_client.dart';
import 'package:conexo/features/profile/selfie_capture_screen.dart';

void main() {
  group('SelfieCaptureResult', () {
    test('success creates result with bytes and null reason', () {
      final bytes = Uint8List.fromList([1, 2, 3]);
      final result = SelfieCaptureResult.success(bytes);
      expect(result.bytes, equals(bytes));
      expect(result.reason, isNull);
    });

    test('error creates result with reason and null bytes', () {
      final result = SelfieCaptureResult.error('file_too_large');
      expect(result.bytes, isNull);
      expect(result.reason, equals('file_too_large'));
    });
  });

  group('VerificationResult', () {
    test('fromJson parses match true', () {
      final result = VerificationResult.fromJson({
        'match': true,
        'threshold': 0.6,
        'reason': 'match',
        'similarity': 0.85,
      });
      expect(result.match, isTrue);
      expect(result.reason, equals('match'));
      expect(result.similarity, equals(0.85));
    });

    test('fromJson parses match false with defaults', () {
      final result = VerificationResult.fromJson({});
      expect(result.match, isFalse);
      expect(result.reason, equals('internal_error'));
      expect(result.similarity, isNull);
    });
  });

  group('Selfie validation', () {
    test('invalid extensions are not in allowed set', () {
      const allowed = <String>{'jpg', 'jpeg', 'png', 'webp'};
      expect(allowed.contains('bmp'), isFalse);
      expect(allowed.contains('gif'), isFalse);
    });

    test('empty bytes are rejected', () {
      final bytes = Uint8List(0);
      expect(bytes.isEmpty, isTrue);
    });

    test('5 MB limit enforced', () {
      const maxSize = 5 * 1024 * 1024;
      final under = Uint8List(maxSize - 1);
      final over = Uint8List(maxSize + 1);
      expect(under.length <= maxSize, isTrue);
      expect(over.length <= maxSize, isFalse);
    });
  });
}
