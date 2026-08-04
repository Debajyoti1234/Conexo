import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

import 'create_plan_data.dart';

/// The single data-access layer for the entire Plans module.
///
/// Every Plans screen (Create Plan, My Plans, Plan Details, and any future
/// Plans feature) must communicate ONLY through a [PlanRepository]. This keeps
/// a single source of truth for local persistence today and a single swap
/// point for a future backend.
///
/// The repository is *injected* through constructors (no global singleton, no
/// service locator) so a future `FirestorePlanRepository` / `ApiPlanRepository`
/// can replace [LocalPlanRepository] WITHOUT touching any UI or business logic.
abstract class PlanRepository {
  /// Loads the in-progress editable draft (or `null` if none).
  Future<PlanDraft?> loadDraft();

  /// Persists the in-progress editable draft.
  Future<void> saveDraft(PlanDraft draft);

  /// Clears the in-progress editable draft.
  Future<void> clearDraft();

  /// Loads every locally published plan (newest last — insertion order).
  Future<List<PublishedPlan>> loadPublished();

  /// Appends a newly published plan.
  Future<void> savePublished(PublishedPlan plan);

  /// Removes a published plan by its stable [PublishedPlan.id].
  Future<void> removePublished(String id);
}

/// The local, on-device implementation backed by [SharedPreferences].
///
/// This is the ONLY class in the project that touches [SharedPreferences].
/// When a backend arrives, implement [PlanRepository] elsewhere and inject it;
/// nothing else needs to change.
class LocalPlanRepository implements PlanRepository {
  const LocalPlanRepository();

  static const _draftKey = 'conexo_plan_draft_v1';
  static const _publishedKey = 'conexo_published_plans_v1';

  @override
  Future<PlanDraft?> loadDraft() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_draftKey);
    if (raw == null || raw.isEmpty) return null;
    try {
      final map = jsonDecode(raw) as Map<String, dynamic>;
      return PlanDraft.fromJson(map);
    } catch (_) {
      return null;
    }
  }

  @override
  Future<void> saveDraft(PlanDraft draft) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_draftKey, jsonEncode(draft.toJson()));
  }

  @override
  Future<void> clearDraft() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_draftKey);
  }

  @override
  Future<List<PublishedPlan>> loadPublished() async {
    final prefs = await SharedPreferences.getInstance();
    final list = prefs.getStringList(_publishedKey) ?? const <String>[];
    final result = <PublishedPlan>[];
    for (final raw in list) {
      try {
        final map = jsonDecode(raw) as Map<String, dynamic>;
        result.add(PublishedPlan.fromJson(map));
      } catch (_) {
        // Skip any corrupt entry rather than failing the whole load.
      }
    }
    return result;
  }

  @override
  Future<void> savePublished(PublishedPlan plan) async {
    final prefs = await SharedPreferences.getInstance();
    final list = prefs.getStringList(_publishedKey) ?? <String>[];
    list.add(jsonEncode(plan.toJson()));
    await prefs.setStringList(_publishedKey, list);
  }

  @override
  Future<void> removePublished(String id) async {
    final prefs = await SharedPreferences.getInstance();
    final list = prefs.getStringList(_publishedKey) ?? <String>[];
    list.removeWhere((raw) {
      try {
        final map = jsonDecode(raw) as Map<String, dynamic>;
        return map['id'] == id;
      } catch (_) {
        return false;
      }
    });
    await prefs.setStringList(_publishedKey, list);
  }
}
