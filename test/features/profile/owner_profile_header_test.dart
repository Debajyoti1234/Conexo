import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:conexo/features/profile/profile_data.dart';
import 'package:conexo/features/profile/public_profile_data.dart';
import 'package:conexo/features/profile/public_profile_sections.dart';

/// Widget tests for the owner Profile header cluster (Name/Age → Privacy →
/// Verification). Non-owner (public) rendering must remain unchanged.
UserProfile _profile({
  required VerificationStatus status,
  required ProfileVisibility visibility,
}) {
  return UserProfile(
    id: 'u1',
    photos: const [],
    bio: '',
    interests: const [],
    languages: const [],
    gender: '',
    location: '',
    socialLinks: const [],
    verificationStatus: status,
    profileVisibility: visibility,
    displayName: 'Alex',
  );
}

PublicProfileViewData _data({
  required VerificationStatus status,
  required ProfileVisibility visibility,
}) {
  return PublicProfileViewData(
    profile: _profile(status: status, visibility: visibility),
    displayName: 'Alex',
    age: 25,
  );
}

Future<void> _pumpOwner(
  WidgetTester tester, {
  required VerificationStatus status,
  required ProfileVisibility visibility,
  VoidCallback? onOpen,
}) async {
  await tester.pumpWidget(
    MaterialApp(
      home: Scaffold(
        body: HeroSection(
          data: _data(status: status, visibility: visibility),
          owner: true,
          onOpenPrivacyVerification: onOpen ?? () {},
        ),
      ),
    ),
  );
  await tester.pumpAndSettle();
}

void main() {
  group('Owner header — verification states', () {
    testWidgets('Verified renders "Verified"', (tester) async {
      await _pumpOwner(tester,
          status: VerificationStatus.verified,
          visibility: ProfileVisibility.public);
      expect(find.text('Verified'), findsOneWidget);
    });

    testWidgets('Pending renders "Pending"', (tester) async {
      await _pumpOwner(tester,
          status: VerificationStatus.pending,
          visibility: ProfileVisibility.public);
      expect(find.text('Pending'), findsOneWidget);
    });

    testWidgets('Not verified renders "Verify"', (tester) async {
      await _pumpOwner(tester,
          status: VerificationStatus.notVerified,
          visibility: ProfileVisibility.private);
      expect(find.text('Verify'), findsOneWidget);
    });
  });

  group('Owner header — privacy indicator', () {
    testWidgets('Public shows globe (tooltip "Public")', (tester) async {
      await _pumpOwner(tester,
          status: VerificationStatus.verified,
          visibility: ProfileVisibility.public);
      expect(find.byTooltip('Public'), findsOneWidget);
      expect(find.byIcon(Icons.public_rounded), findsOneWidget);
    });

    testWidgets('Private shows lock (tooltip "Private")', (tester) async {
      await _pumpOwner(tester,
          status: VerificationStatus.notVerified,
          visibility: ProfileVisibility.private);
      expect(find.byTooltip('Private'), findsOneWidget);
      expect(find.byIcon(Icons.lock_rounded), findsOneWidget);
    });
  });

  group('Owner header — combined states', () {
    testWidgets('Public + Verified', (tester) async {
      await _pumpOwner(tester,
          status: VerificationStatus.verified,
          visibility: ProfileVisibility.public);
      expect(find.byTooltip('Public'), findsOneWidget);
      expect(find.text('Verified'), findsOneWidget);
    });

    testWidgets('Private + Verified', (tester) async {
      await _pumpOwner(tester,
          status: VerificationStatus.verified,
          visibility: ProfileVisibility.private);
      expect(find.byTooltip('Private'), findsOneWidget);
      expect(find.text('Verified'), findsOneWidget);
    });

    testWidgets('Public + Pending', (tester) async {
      await _pumpOwner(tester,
          status: VerificationStatus.pending,
          visibility: ProfileVisibility.public);
      expect(find.byTooltip('Public'), findsOneWidget);
      expect(find.text('Pending'), findsOneWidget);
    });

    testWidgets('Private + Pending', (tester) async {
      await _pumpOwner(tester,
          status: VerificationStatus.pending,
          visibility: ProfileVisibility.private);
      expect(find.byTooltip('Private'), findsOneWidget);
      expect(find.text('Pending'), findsOneWidget);
    });

    testWidgets('Public + Verify', (tester) async {
      await _pumpOwner(tester,
          status: VerificationStatus.notVerified,
          visibility: ProfileVisibility.public);
      expect(find.byTooltip('Public'), findsOneWidget);
      expect(find.text('Verify'), findsOneWidget);
    });

    testWidgets('Private + Verify', (tester) async {
      await _pumpOwner(tester,
          status: VerificationStatus.notVerified,
          visibility: ProfileVisibility.private);
      expect(find.byTooltip('Private'), findsOneWidget);
      expect(find.text('Verify'), findsOneWidget);
    });
  });

  group('Owner header — order & interaction', () {
    testWidgets('order is Name, Age → Privacy → Verification', (tester) async {
      await _pumpOwner(tester,
          status: VerificationStatus.verified,
          visibility: ProfileVisibility.public);

      final nameX = tester.getCenter(find.text('Alex, 25')).dx;
      final privacyX = tester.getCenter(find.byTooltip('Public')).dx;
      final verifyX = tester.getCenter(find.text('Verified')).dx;

      expect(nameX < privacyX, isTrue,
          reason: 'Name/Age must come before the privacy icon');
      expect(privacyX < verifyX, isTrue,
          reason: 'Privacy icon must come before the verification badge');
    });

    testWidgets('tapping privacy and verification both open the shortcut',
        (tester) async {
      var taps = 0;
      await _pumpOwner(tester,
          status: VerificationStatus.verified,
          visibility: ProfileVisibility.public,
          onOpen: () => taps++);

      await tester.tap(find.byTooltip('Public'));
      await tester.pump();
      expect(taps, 1);

      await tester.tap(find.text('Verified'));
      await tester.pump();
      expect(taps, 2);
    });
  });

  group('Non-owner header — unchanged', () {
    testWidgets('no privacy icon and no Verify affordance', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: HeroSection(
              data: _data(
                status: VerificationStatus.notVerified,
                visibility: ProfileVisibility.public,
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.byTooltip('Public'), findsNothing);
      expect(find.byTooltip('Private'), findsNothing);
      expect(find.text('Verify'), findsNothing);
      // The plain name is still rendered.
      expect(find.text('Alex, 25'), findsOneWidget);
    });
  });
}
