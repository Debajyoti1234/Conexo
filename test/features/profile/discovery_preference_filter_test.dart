import 'package:flutter_test/flutter_test.dart';

import 'package:conexo/features/profile/discovery_helpers.dart';

/// Phase 9.1B — unit tests for the pure discovery-preference filter helpers
/// that connect the saved Distance + Age Range preferences to the existing
/// People/Discovery backend. These are the exact predicates used by
/// `DiscoveryRepository.fetchNearby`.
void main() {
  group('ageWithinDiscoveryPreference', () {
    test('inclusive 18–30 boundaries', () {
      expect(ageWithinDiscoveryPreference(18, 18, 30), isTrue);
      expect(ageWithinDiscoveryPreference(25, 18, 30), isTrue);
      expect(ageWithinDiscoveryPreference(30, 18, 30), isTrue);
      expect(ageWithinDiscoveryPreference(17, 18, 30), isFalse);
      expect(ageWithinDiscoveryPreference(31, 18, 30), isFalse);
    });

    test('null minimum applies only an upper bound', () {
      expect(ageWithinDiscoveryPreference(17, null, 30), isTrue);
      expect(ageWithinDiscoveryPreference(30, null, 30), isTrue);
      expect(ageWithinDiscoveryPreference(31, null, 30), isFalse);
    });

    test('null maximum applies only a lower bound', () {
      expect(ageWithinDiscoveryPreference(25, 25, null), isTrue);
      expect(ageWithinDiscoveryPreference(80, 25, null), isTrue);
      expect(ageWithinDiscoveryPreference(24, 25, null), isFalse);
    });

    test('both null means no age filtering', () {
      expect(ageWithinDiscoveryPreference(18, null, null), isTrue);
      expect(ageWithinDiscoveryPreference(99, null, null), isTrue);
    });

    test('invalid range (min > max) does not hide everyone', () {
      expect(ageWithinDiscoveryPreference(25, 40, 20), isTrue);
    });
  });

  group('distanceWithinDiscoveryPreference', () {
    test('10 km preference includes 5 km and excludes 15 km', () {
      expect(distanceWithinDiscoveryPreference(5000, 10), isTrue);
      expect(distanceWithinDiscoveryPreference(15000, 10), isFalse);
    });

    test('boundary is inclusive', () {
      expect(distanceWithinDiscoveryPreference(10000, 10), isTrue);
      expect(distanceWithinDiscoveryPreference(10001, 10), isFalse);
    });

    test('null (Any) applies no distance restriction', () {
      expect(distanceWithinDiscoveryPreference(0, null), isTrue);
      expect(distanceWithinDiscoveryPreference(999999, null), isTrue);
    });
  });

  group('combined distance + age (25 km, age 20–30)', () {
    bool eligible(double distanceMeters, int age) =>
        distanceWithinDiscoveryPreference(distanceMeters, 25) &&
        ageWithinDiscoveryPreference(age, 20, 30);

    test('10 km + age 25 is included', () {
      expect(eligible(10000, 25), isTrue);
    });

    test('30 km + age 25 is excluded (distance)', () {
      expect(eligible(30000, 25), isFalse);
    });

    test('10 km + age 35 is excluded (age)', () {
      expect(eligible(10000, 35), isFalse);
    });

    test('30 km + age 35 is excluded (both)', () {
      expect(eligible(30000, 35), isFalse);
    });
  });

  test('all preferences unset does not filter anything', () {
    expect(distanceWithinDiscoveryPreference(500000, null), isTrue);
    expect(ageWithinDiscoveryPreference(16, null, null), isTrue);
  });
}
