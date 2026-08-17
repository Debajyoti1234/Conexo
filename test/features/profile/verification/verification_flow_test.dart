import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:conexo/features/profile/face_verification_client.dart';
import 'package:conexo/features/profile/verification/verification_components.dart';
import 'package:conexo/features/profile/verification/verification_guidance_screen.dart';
import 'package:conexo/features/profile/verification/verification_status_view.dart';

void main() {
  group('VerifyAngle model', () {
    test('canonical order is front, left, right', () {
      expect(VerifyAngle.values,
          equals([VerifyAngle.front, VerifyAngle.left, VerifyAngle.right]));
    });

    test('labels and steps are correct', () {
      expect(VerifyAngle.front.label, 'FRONT');
      expect(VerifyAngle.left.label, 'LEFT');
      expect(VerifyAngle.right.label, 'RIGHT');
      expect(VerifyAngle.front.step, 1);
      expect(VerifyAngle.left.step, 2);
      expect(VerifyAngle.right.step, 3);
    });

    test('each angle maps to its own glyph asset', () {
      expect(VerifyAngle.front.glyph, contains('face_front'));
      expect(VerifyAngle.left.glyph, contains('face_left'));
      expect(VerifyAngle.right.glyph, contains('face_right'));
    });
  });

  group('VerificationResult (multi-angle contract)', () {
    test('fromJson parses a 200 match body and leaves angle null', () {
      final result = VerificationResult.fromJson({
        'match': true,
        'threshold': 0.4,
        'reason': 'match',
        'similarity': 0.83,
        'angle_similarities': {'front': 0.83, 'left': 0.71, 'right': 0.69},
      });
      expect(result.match, isTrue);
      expect(result.reason, 'match');
      expect(result.similarity, 0.83);
      expect(result.angle, isNull);
    });

    test('carries an angle for a per-angle failure', () {
      const result = VerificationResult(
        match: false,
        reason: 'no_face',
        angle: 'left',
      );
      expect(result.match, isFalse);
      expect(result.reason, 'no_face');
      expect(result.angle, 'left');
    });
  });

  group('Multi-angle multipart contract', () {
    test('sends exactly selfie_front/left/right as image/jpeg .jpg parts', () {
      final request = FaceVerificationClient.buildMultiAngleRequest(
        uri: Uri.parse('https://api.example.com/api/v1/verify-face-multi'),
        accessToken: 'test-token',
        frontJpeg: Uint8List.fromList([1, 2, 3]),
        leftJpeg: Uint8List.fromList([4, 5, 6]),
        rightJpeg: Uint8List.fromList([7, 8, 9]),
      );

      // Exactly three parts, in canonical order, with the exact field names.
      expect(
        request.files.map((f) => f.field).toList(),
        <String>['selfie_front', 'selfie_left', 'selfie_right'],
      );

      // Every part is a .jpg with an explicit image/jpeg content type.
      for (final part in request.files) {
        expect(part.filename, '${part.field}.jpg');
        expect(part.contentType.mimeType, 'image/jpeg');
      }

      expect(request.method, 'POST');
      expect(request.url.path, '/api/v1/verify-face-multi');
      expect(request.headers['Authorization'], 'Bearer test-token');
    });
  });

  group('Premium status UI', () {
    testWidgets('verified view shows reward copy + CTA', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(body: VerifySuccessView(onContinue: () {})),
        ),
      );
      await tester.pump(const Duration(milliseconds: 500));

      expect(find.text("You're Verified!"), findsOneWidget);
      expect(find.text('Continue to App'), findsOneWidget);
    });

    testWidgets('failed view offers retry + review tips', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: VerifyFailedView(onRetry: () {}, onReviewTips: () {}),
          ),
        ),
      );
      await tester.pump(const Duration(milliseconds: 500));

      expect(find.text('Try Again'), findsOneWidget);
      expect(find.text('Review photo tips'), findsOneWidget);
    });

    testWidgets('tips view lists guidance + Got it', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: VerifyTipsView(onGotIt: () {}, onBack: () {}),
          ),
        ),
      );
      await tester.pump(const Duration(milliseconds: 300));

      expect(find.text('Photo tips'), findsOneWidget);
      expect(find.text('Got it'), findsOneWidget);
      expect(find.text('Use better lighting'), findsOneWidget);
    });
  });

  group('Guidance screen', () {
    testWidgets('opens on the Get Verified intro', (tester) async {
      await tester.pumpWidget(
        const MaterialApp(home: VerificationGuidanceScreen()),
      );
      await tester.pump(const Duration(milliseconds: 300));

      expect(find.text('Get Verified'), findsOneWidget);
      expect(find.text('Get Started'), findsOneWidget);
    });
  });
}
