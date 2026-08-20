# Phase 9.2B-R2.1 — Final Photo + Verification Alignment

## Objective
Micro-refinement of the working R2. Fix verification badge position, correct photo height/crop, make atmosphere subtle, and ensure demo/real profiles share identical visual composition.

## Constraints
- DO NOT change discovery controls position (`top: screenHeight * 0.76`)
- DO NOT change identity block vertical position (`top: screenHeight * 0.70`)
- DO NOT change navigation pill position
- DO NOT change photo preload/cache/Supabase architecture
- DO NOT create separate layouts for demo vs real profiles (they already share `ImmersiveProfileView`)

## Verified Context
- Demo and real profiles both use the same `ImmersiveProfileView` → `_HeroSection` → `_PhotoGallery` → `_HeroPhoto` → `_IdentityBlock`
- No separate demo profile renderer exists; `home_discovery_components.dart` is dead code
- Greeting/filter pill: `top: media.padding.top + 10` (~4-5% from top on typical screens)
- Navigation pill visual top: `bottomInset + 92` from bottom (~84% from top on 800px screens)
- Current photo region: 23%→70% (47% height) — too short
- Current atmosphere: full-bleed, opacity 0.85, scale 1.35, blur sigma 50 — too aggressive

## Changes

### 1. `lib/features/home_discovery_profile.dart` — `_HeroPhoto`
**Change photo region from 23%→70% to 5%→80%:**
```dart
final photoTop = screenHeight * 0.05;
final photoBottom = screenHeight * 0.80;
final photoHeight = photoBottom - photoTop;
```

**Constrain atmosphere to photo region ±3% margin:**
```dart
final margin = screenHeight * 0.03;
final atmosphereTop = photoTop - margin;
final atmosphereBottom = photoBottom + margin;
final atmosphereHeight = atmosphereBottom - atmosphereTop;
```

**Compute dynamic gradient stops:**
```dart
final fadeEdge = margin / atmosphereHeight;
final topFadeEnd = fadeEdge;
final bottomFadeStart = 1.0 - fadeEdge;
```

**Pass stops to atmosphere and wrap in Positioned:**
```dart
final atmosphere = atmosphereProvider == null
    ? const SizedBox.shrink()
    : _HeroAtmosphere(
        provider: atmosphereProvider,
        topFadeStart: 0.0,
        topFadeEnd: topFadeEnd,
        bottomFadeStart: bottomFadeStart,
        bottomFadeEnd: 1.0,
      );

return Stack(
  fit: StackFit.expand,
  children: [
    Positioned(
      top: atmosphereTop,
      left: 0,
      right: 0,
      height: atmosphereHeight,
      child: atmosphere,
    ),
    Positioned(
      top: photoTop,
      left: 0,
      right: 0,
      height: photoHeight,
      child: child,
    ),
  ],
);
```

### 2. `lib/features/home_discovery_profile.dart` — `_HeroAtmosphere`
**Reduce intensity for subtle atmosphere:**
- Opacity: `0.85` → `0.5`
- Scale: `1.35` → `1.15`
- Blur: `sigmaX: 50, sigmaY: 50` → `sigmaX: 20, sigmaY: 20`

**Accept dynamic gradient stops:**
```dart
class _HeroAtmosphere extends StatelessWidget {
  const _HeroAtmosphere({
    required this.provider,
    this.topFadeStart = 0.0,
    this.topFadeEnd = 0.3,
    this.bottomFadeStart = 0.55,
    this.bottomFadeEnd = 1.0,
  });

  final ImageProvider provider;
  final double topFadeStart;
  final double topFadeEnd;
  final double bottomFadeStart;
  final double bottomFadeEnd;
```

Use these stops in the `LinearGradient`.

### 3. `lib/features/home_discovery_profile.dart` — `_IdentityBlock`
**Restructure to put verification badge beside age:**

Current (name + age + badge in one row):
```dart
Row(
  children: [
    Expanded(child: Text('${profile.name}, ${profile.age}')),
    if (verified) Icon(...)
  ],
),
if (distance != null) Text(distance),
```

New (name on first line, age + distance + badge on second line):
```dart
Text(
  profile.name,
  maxLines: 1,
  overflow: TextOverflow.ellipsis,
  style: const TextStyle(fontSize: 34, fontWeight: FontWeight.w800, ...),
),
Row(
  crossAxisAlignment: CrossAxisAlignment.center,
  children: [
    Text(
      '${profile.age}',
      style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w600, color: Color(0xFFEAEEF9), ...),
    ),
    if (distance != null) ...[
      const SizedBox(width: 6),
      Text(
        '·',
        style: TextStyle(fontSize: 15, fontWeight: FontWeight.w600, color: Color(0xFFEAEEF9).withValues(alpha: .7)),
      ),
      const SizedBox(width: 6),
      Text(
        distance,
        style: const TextStyle(color: Color(0xFFEAEEF9), fontSize: 15, fontWeight: FontWeight.w600, ...),
      ),
    ],
    if (profile.verified) ...[
      const SizedBox(width: 8),
      const Icon(Icons.verified_rounded, size: 26, color: Color(0xFF3B9EFF), ...),
    ],
  ],
),
```

No gap between name line and age line.

### 4. No changes needed
- `lib/features/home_screen.dart` — controls position unchanged
- `lib/features/home_discovery_skeleton.dart` — skeleton positions unchanged
- All preload/cache/Supabase files — unchanged

## Validation
1. `flutter analyze lib/features/home_discovery_profile.dart lib/features/home_screen.dart lib/features/home_discovery_skeleton.dart`
2. Build APK via `.\tool\build_apk.ps1` (do NOT run `flutter run` or `flutter build` directly)

## Expected Outcome
- Photo spans ~5%→80% of screen (taller, less cropped)
- Atmosphere is subtle (±3% margin, reduced blur/scale/opacity)
- Verification badge appears beside age, not beside name
- Identity block stays at `top: screenHeight * 0.70`
- Controls stay at `top: screenHeight * 0.76`
- Demo and real profiles use identical composition (shared widgets)
