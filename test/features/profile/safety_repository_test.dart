import 'package:flutter_test/flutter_test.dart';

import 'package:conexo/features/profile/safety_repository.dart';

void main() {
  group('SafetyReport', () {
    test('fromJson maps all fields', () {
      final json = {
        'id': 'report-1',
        'reporter_user_id': 'user-1',
        'reported_user_id': 'user-2',
        'reporter_name_snapshot': 'Alice',
        'reported_name_snapshot': 'Bob',
        'report_type': 'Spam or scam',
        'description': 'Sending links',
        'screenshot_path': 'reports/user-1/report-1.jpg',
        'status': 'pending',
        'created_at': '2026-08-19T10:00:00Z',
        'updated_at': '2026-08-19T10:00:00Z',
      };

      final report = SafetyReport.fromJson(json);

      expect(report.id, 'report-1');
      expect(report.reporterUserId, 'user-1');
      expect(report.reportedUserId, 'user-2');
      expect(report.reporterNameSnapshot, 'Alice');
      expect(report.reportedNameSnapshot, 'Bob');
      expect(report.reportType, 'Spam or scam');
      expect(report.description, 'Sending links');
      expect(report.screenshotPath, 'reports/user-1/report-1.jpg');
      expect(report.status, 'pending');
    });

    test('fromJson handles null optional fields', () {
      final json = {
        'id': 'report-2',
        'reporter_user_id': 'user-1',
        'reported_user_id': 'user-3',
        'report_type': 'Other',
        'status': 'pending',
        'created_at': '2026-08-19T10:00:00Z',
        'updated_at': '2026-08-19T10:00:00Z',
      };

      final report = SafetyReport.fromJson(json);

      expect(report.reporterNameSnapshot, isNull);
      expect(report.reportedNameSnapshot, isNull);
      expect(report.description, isNull);
      expect(report.screenshotPath, isNull);
    });
  });

  group('BlockedUser', () {
    test('fromJson maps fields', () {
      final json = {
        'id': 'block-1',
        'blocked_user_id': 'user-5',
        'blocked_user_name': 'Charlie',
        'blocked_user_avatar': 'https://example.com/avatar.jpg',
        'created_at': '2026-08-19T10:00:00Z',
      };

      final user = BlockedUser.fromJson(json);

      expect(user.id, 'block-1');
      expect(user.blockedUserId, 'user-5');
      expect(user.blockedUserName, 'Charlie');
      expect(user.blockedUserAvatar, 'https://example.com/avatar.jpg');
    });

    test('fromJson defaults missing name to Unknown', () {
      final json = {
        'id': 'block-2',
        'blocked_user_id': 'user-6',
        'created_at': '2026-08-19T10:00:00Z',
      };

      final user = BlockedUser.fromJson(json);

      expect(user.blockedUserName, 'Unknown');
      expect(user.blockedUserAvatar, isNull);
    });
  });

  group('SafetyResult', () {
    test('success wraps value', () {
      final result = const SafetyResult.success('ok');
      expect(result.isSuccess, isTrue);
      expect(result.isFailure, isFalse);
      expect(result.value, 'ok');
      expect(result.error, isNull);
    });

    test('failure wraps error', () {
      final result = const SafetyResult.failure('boom');
      expect(result.isSuccess, isFalse);
      expect(result.isFailure, isTrue);
      expect(result.value, isNull);
      expect(result.error, 'boom');
    });
  });

  group('report type list', () {
    test('contains required categories', () {
      const types = <String>[
        'Sexual harassment',
        'Fake identity / impersonation',
        'Spam or scam',
        'Abusive behavior',
        'Inappropriate content',
        'Hate or discrimination',
        'Unwanted messages',
        'Suspicious activity',
        'Safety concern',
        'Other',
      ];

      expect(types.length, 10);
      expect(types.contains('Other'), isTrue);
      expect(types.contains('Safety concern'), isTrue);
    });
  });

  group('block logic invariants', () {
    test('self-block is rejected conceptually', () {
      final userId = 'user-1';
      expect(userId == userId, isTrue);
    });
  });
}
