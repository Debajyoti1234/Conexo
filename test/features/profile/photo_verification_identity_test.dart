import 'package:flutter_test/flutter_test.dart';

import 'package:conexo/features/profile/profile_data.dart';

/// Unit tests for the pure verification photo-identity helper.
///
/// Verification validity depends on photo CONTENT (the set of photo ids), not
/// order: reordering the same photos leaves the set unchanged, while add /
/// remove / replace all change the id set.
ProfilePhoto _photo(String id) =>
    ProfilePhoto(id: id, assetPath: 'assets/$id.jpg');

void main() {
  group('verifiedPhotoSetChanged', () {
    final base = [_photo('a'), _photo('b'), _photo('c')];

    test('same photo ids, reordered → false', () {
      final reordered = [_photo('c'), _photo('a'), _photo('b')];
      expect(verifiedPhotoSetChanged(base, reordered), isFalse);
    });

    test('identical set, same order → false', () {
      final same = [_photo('a'), _photo('b'), _photo('c')];
      expect(verifiedPhotoSetChanged(base, same), isFalse);
    });

    test('photo added → true', () {
      final added = [...base, _photo('d')];
      expect(verifiedPhotoSetChanged(base, added), isTrue);
    });

    test('photo removed → true', () {
      final removed = [_photo('a'), _photo('b')];
      expect(verifiedPhotoSetChanged(base, removed), isTrue);
    });

    test('photo replaced (new id) → true', () {
      final replaced = [_photo('a'), _photo('b'), _photo('replace_123')];
      expect(verifiedPhotoSetChanged(base, replaced), isTrue);
    });

    test('reorder that changes the primary (first) photo → false', () {
      // Moving a different photo to index 0 changes the primary but NOT the id
      // set, so verification must be preserved.
      final movedPrimary = [_photo('b'), _photo('c'), _photo('a')];
      expect(verifiedPhotoSetChanged(base, movedPrimary), isFalse);
    });
  });
}
