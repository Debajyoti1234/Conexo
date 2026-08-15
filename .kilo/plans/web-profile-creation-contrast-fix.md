# Conexo Phase 10.1 — Web Profile Creation UI Contrast Fix

## 1. Root Cause

The Web Profile Creation UI appears washed out due to three interacting issues:

### A. Transparent Scaffold exposes browser default background
`ProfileCreationScreen` (`profile_creation_screen.dart:165`) uses:
```dart
Scaffold(
  backgroundColor: Colors.transparent,
  ...
)
```
On Android, the native system window provides a dark background behind the transparent Scaffold, so the intended dark Conexo UI renders correctly. On Flutter Web, there is no native system background — the browser default is white. The transparent Scaffold therefore exposes white, destroying the dark theme.

### B. Implicit text colors resolve differently on Web
Multiple text widgets rely on implicit `Theme.of(context).textTheme` or `DefaultTextStyle` inheritance instead of explicit `color`:
- `SectionShell` title (`profile_creation_widgets.dart:102-109`) — no `color`
- `ProfileCreationScreen._header()` "Create your profile" (`profile_creation_screen.dart:327-333`) — no `color`
- `AuthHeader` title (`auth_components.dart:225`) — uses `Theme.of(context).textTheme.headlineMedium?.copyWith(...)` without explicit color

Under Material 3, Web theme resolution can yield lighter/default colors for these implicit styles compared to Android.

### C. Very low-opacity borders/fills become invisible on Web
Several UI elements use opacities that are too subtle for Web compositing:
- `_EmptyPhotoSlot` border: `Colors.white.withValues(alpha: .08)`
- `GlassCard` border: `Colors.white.withValues(alpha: .09)`
- `GlassTextField` borders: `Colors.white.withValues(alpha: .1)`
- `_kFieldFill`: `Color(0x14FFFFFF)` (~8% white)

On Android, native GPU compositing makes these subtle layers visible against the dark background. On Web, CSS/Canvas compositing renders them as nearly invisible, making cards, fields, and photo slots appear pale.

---

## 2. Current Rendering Path

### ProfileCreationScreen background
```
Scaffold(backgroundColor: Colors.transparent)
  → Material widget with transparent color
  → On Android: native system background (dark) shows through
  → On Web: browser default background (white) shows through
  → Result: white/washed-out background on Web
```

### SectionShell title
```
Text(title, style: TextStyle(...))
  → No explicit color
  → Inherits from DefaultTextStyle / Theme
  → On Android: resolves to light color from dark theme
  → On Web: Material 3 resolves to lighter/default color
  → Result: poor contrast on Web
```

### GlassCard / _EmptyPhotoSlot borders
```
BorderSide(Colors.white.withValues(alpha: .09))
  → Android: native compositing makes subtle white border visible on dark bg
  → Web: CSS compositing makes 9% white nearly invisible
  → Result: pale/flat cards on Web
```

---

## 3. Proposed Minimal Fix

### Fix 1: Explicit dark Scaffold background
Change `ProfileCreationScreen`'s Scaffold background from `Colors.transparent` to `const Color(0xFF0B1020)` (matching `AppTheme.scaffoldBackgroundColor`). This ensures the intended dark background is painted regardless of platform.

### Fix 2: Explicit text colors
Add `color: Colors.white` (or near-white) to text widgets that currently lack an explicit color:
- `SectionShell` title
- `ProfileCreationScreen._header()` "Create your profile"
- `AuthHeader` title

### Fix 3: Web-specific border/opacity adjustments
For elements where low opacity works on Android but is invisible on Web, add `kIsWeb` guards to slightly increase opacity:
- `_EmptyPhotoSlot` border: `alpha: .15` on Web (vs `.08` on Android)
- `GlassCard` border: `alpha: .14` on Web (vs `.09` on Android)
- `GlassTextField` borders: `alpha: .16` on Web (vs `.1` on Android)

These are minimal adjustments that preserve the Android look while making the Web UI readable.

---

## 4. Exact Files

| File | Current Behavior | Proposed Change | Why Required |
|------|-----------------|-----------------|--------------|
| `lib/features/profile/profile_creation_screen.dart` | `Scaffold(backgroundColor: Colors.transparent)` exposes white on Web. Header title "Create your profile" has no explicit color. | 1. Change Scaffold background to `Color(0xFF0B1020)`. 2. Add `color: Colors.white` to header title. | 1. Prevents white background on Web. 2. Ensures header text is readable on Web. |
| `lib/features/profile/profile_creation_widgets.dart` | `SectionShell` title has no explicit color. `_EmptyPhotoSlot` border is `alpha: .08`. `GlassCard` border is `alpha: .09`. `GlassTextField` borders are `alpha: .1`. | 1. Add `color: Colors.white` to `SectionShell` title. 2. Add `kIsWeb` guards to increase border opacities on Web. | 1. Ensures section headings are readable. 2. Makes borders/controls visible on Web without changing Android. |
| `lib/features/auth_components.dart` | `AuthHeader` title uses `Theme.of(context).textTheme.headlineMedium?.copyWith(...)` without explicit color. | Add `color: Colors.white` to the `copyWith`. | Ensures the auth header title is readable on Web. |

---

## 5. Android Protection

Android remains visually unchanged because:
- The Scaffold background change from `Colors.transparent` to `Color(0xFF0B1020)` is a no-op on Android — the native system already provides a dark background behind transparent Scaffolds, and `Color(0xFF0B1020)` matches the existing theme exactly.
- Explicit text colors (`Colors.white`) override whatever the theme provides, but on Android the dark theme already resolves these to light/white colors. The explicit color is redundant but not visually different.
- `kIsWeb` guards ensure border opacity increases only on Web. Android retains the original `alpha: .08`, `.09`, and `.1` values.

---

## 6. Regression Protection

These remain untouched:
- Profile creation logic (draft state, validation, progressive reveal)
- Camera/gallery flow
- Location detection
- Authentication
- Supabase / Storage
- Phase 9.5.2 Chat
- Connections
- Plans
- Android files
- `permission_manager.dart`
- `live_location_tracker.dart`
- OAuth flow
- Splash/startup
- `pubspec.yaml`

---

## 7. Validation Plan

### Android
- Run the app on an Android device/emulator
- Navigate to Profile Creation
- Compare before/after screenshots
- Confirm: no visual regression — background, text, cards, borders, and controls look identical to the current Android appearance

### Local Web
```bash
flutter analyze
.\tool\run.ps1 -d chrome --web-port 5000
```
- Navigate to Profile Creation
- Verify:
  - Background is dark (not white/washed out)
  - Text is readable with strong contrast
  - Section headings are visible
  - Icons and controls are easy to see
  - Photo cards have visible borders
  - Glass effects are preserved
  - No layout changes

### Vercel
- Not required for this sub-phase
- If needed later, deploy and verify the same checklist as Local Web

---

## 8. Risk

- **Low risk**: Changes are additive (explicit colors, slightly higher opacities on Web only)
- **No logic changes**: No profile, auth, or navigation code is touched
- **Reversible**: Each change is isolated and can be reverted independently
- **Android safety**: `kIsWeb` guards and explicit dark colors protect Android appearance

---

## 9. Approval Gate

PLAN READY — AWAITING APPROVAL
