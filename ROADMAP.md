# Core Product Rules

These rules are permanent and apply across every module of Conexo. Future development must follow them unless the roadmap is officially updated.

---

## 1. Distance-First Discovery (Highest Priority)

Distance is the primary ranking signal throughout Conexo.

Every discovery experience must always show the nearest people and plans first.

Ranking priority:

1. Distance (Nearest → Farthest)
2. Context-specific ranking (availability, date, time, etc.)
3. Mutual interests and recommendation signals

Mutual interests improve relevance but never override physical proximity.

Example:

User A
• 200 meters away
• 0 mutual interests

User B
• 5 km away
• 10 mutual interests

User A appears first because Conexo is built around nearby real-world connections.

This rule applies to:
- People Discovery
- Plans Discovery
- Maps
- Future recommendation systems

---

## 2. Privacy Rules

Private Profile

When a user enables Private Profile:

- They are hidden from the People discovery feed.
- They do not appear in Nearby People.
- They remain fully able to use Conexo.

Plans

Privacy applies only to the user profile, not automatically to hosted plans.

If a private-profile user creates a Public Plan:

- The plan remains discoverable according to the standard distance-first ranking.

If they create a Private Plan:

- Visibility follows that plan's privacy rules only.

This allows users to stay private while still participating in community activities.

---

## 3. Location Handling

User coordinates are never displayed publicly.

The application stores location only for ranking and matching.

Users see only human-readable locations such as:

- City
- Area
- Locality

Latitude and longitude remain internal.

---

## 4. Single Ranking Engine

Sorting logic must never be duplicated.

All discovery modules must use one shared ranking pipeline.

Current implementation:

Distance → Date → Time

Future ranking improvements must extend the shared pipeline instead of creating new sorting logic.

---

## 5. Module Freeze Policy

Once a module is marked 🔒 Frozen:

- No new features may be added.
- Only bug fixes and critical maintenance are allowed.
- New functionality requires reopening the module through the roadmap.

---

## 6. Architecture Rules

- UI must never own business logic.
- Repository layer owns all persistence.
- Models remain immutable.
- Shared components must stay reusable.
- Navigation belongs to screen-level code, never reusable widgets.
- No duplicated filtering or sorting logic.

---

## 7. Development Philosophy

Conexo is designed for real-world social discovery.

The product prioritizes:

1. Nearby people
2. Real meetups
3. Simplicity
4. Privacy
5. Premium user experience

Every future feature should reinforce these principles rather than compete with them.



# Conexo Roadmap

A living, high-level map of what is built, what is frozen, and what comes
next. This root roadmap is authoritative for module status; the docs in
`docs/` remain the deep reference for conventions and design language.

---

## ✅ Completed Foundations

- Splash
- Onboarding
- Login
- Signup
- Premium UI redesign (dark-glass design language)

---

## 🧩 Phase 3 — Plans Module (FROZEN)

Phase 3 is **complete and frozen**. The entire Plans module shares one
premium dark-glass language, a single distance-first processing pipeline
(`applyPipeline`), and a single injected data layer (`PlanRepository`). No
screen touches `SharedPreferences` directly except `LocalPlanRepository`.

| Sub-phase | Feature | Status |
|-----------|---------|--------|
| 3.1 | Plans Discovery (hero, categories, curated rails, live search) | ✅ Complete |
| 3.2 | Plan Details (cinematic header, sections, sticky join bar) | ✅ Complete |
| 3.3 | Create Plan (multi-section flow, live preview, draft + publish) | ✅ Complete |
| 3.4 | My Plans (Hosting / Joined / Archived / Drafts, insights, filters) | ✅ Complete |

### Phase 3 architecture invariants

- **Single source of truth** — each screen owns its filter/tab state and
  derives every list from the shared pipeline. No widget filters or sorts
  independently.
- **Injected repository** — `PlanRepository` is passed through constructors.
  A future `FirestorePlanRepository` / `ApiPlanRepository` can replace
  `LocalPlanRepository` with **zero UI change**.
- **Reusable primitives** — `ExperienceCard` (4 variants), glass badges,
  chips, portraits, and empty states are shared across every Plans screen.
- **Motion discipline** — only Fade / Slide / Scale / AnimatedSwitcher /
  AnimatedSize with `easeOutCubic` / `easeInOutCubic`. No bounce, elastic,
  or overshoot.
- **Local assets only** — no network images anywhere in the module.

### Module Status block

```
Plans/
  ├── plans_screen.dart          ✅ Discovery (3.1)  + My Plans entry (3.4)
  ├── plans_sections.dart        ✅ Hero, category strip, rails
  ├── plans_cards.dart           ✅ ExperienceCard (immersive/stacked/floating/compact)
  ├── plans_widgets.dart         ✅ Shared glass primitives
  ├── plans_filter.dart          ✅ PlansFilterState + applyPipeline (single pipeline)
  ├── plans_data.dart            ✅ Experience model + demo dataset
  ├── plan_details_screen.dart   ✅ Details (3.2) + premiumPlanRoute
  ├── plan_details_sections.dart ✅ Info / host / participants / location / safety
  ├── plan_details_widgets.dart  ✅ Details primitives
  ├── plan_details_data.dart     ✅ Details-derived helpers
  ├── plan_join_controller.dart  ✅ Local join/request state (isolated rebuilds)
  ├── create_plan_screen.dart    ✅ Create flow (3.3) — uses injected repository
  ├── create_plan_sections.dart  ✅ Create sections
  ├── create_plan_widgets.dart   ✅ Create primitives
  ├── create_plan_preview.dart   ✅ Live preview
  ├── create_plan_data.dart      ✅ PlanDraft + PublishedPlan models + mapping
  ├── plan_repository.dart       ✅ PlanRepository + LocalPlanRepository (sole prefs owner)
  ├── my_plans_screen.dart       ✅ My Plans (3.4) + myPlansRoute
  ├── my_plans_sections.dart     ✅ Insights row + hosting/joined/archived/drafts lists
  ├── my_plans_widgets.dart      ✅ Tabs, insight card, status badge, action bar, dialogs
  └── my_plans_data.dart         ✅ published→Experience, time filters, insights (pipeline reuse)
```

---

## 🎯 Phase 4 — Profile (NEXT)

The next module is the premium Profile experience, reusing the same
dark-glass language, injected-repository pattern, and motion discipline
established in Phase 3.

Planned scope:

- Premium profile hero (avatar, name, trust/verification signals)
- Interests, stats, and hosted/joined history (reusing `ExperienceCard`)
- Edit profile flow (mirrors the Create Plan section pattern)
- A `ProfileRepository` abstraction injected the same way as `PlanRepository`

---

## 🔮 Later

- Firebase Authentication
- Firestore + Storage
- Realtime Chat
- Notifications
- Premium features — AI recommendations, trust score, verification
- Communities
- Memories
