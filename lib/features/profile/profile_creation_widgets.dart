import 'dart:async';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

import '../../app/theme/app_widgets.dart';
import '../../core/services/location_service.dart';
import '../../core/services/permission_manager.dart';
import '../home_discovery_animations.dart';
import 'profile_data.dart';
import 'supabase_profile_repository.dart';

/// Reusable premium primitives for the Profile Creation flow.
///
/// Everything reuses the established Conexo dark-glass language (GlassCard,
/// EntranceFade, existing gradients / spacing / typography). Motion is limited
/// to AnimatedContainer / AnimatedSwitcher / AnimatedSize / AnimatedScale /
/// Fade / Slide with easeOutCubic / easeInOutCubic — no bounce or overshoot.

const _kAccent = Color(0xFF8B5CF6);
const _kAccent2 = Color(0xFF587BE2);
const _kSoftText = Color(0xFFB9C3DC);
const _kFieldFill = Color(0x14FFFFFF);

// ── ProfilePhotoViewer ───────────────────────────────────────────────────────

/// Renders a profile photo from either a bundled asset, a local file path,
/// or a Supabase Storage object path.
///
/// Asset paths are displayed with [Image.asset]; local file paths are displayed
/// with [Image.file]; Supabase Storage paths are displayed with a signed URL
/// fetched via [SupabaseProfileRepository.getSignedPhotoUrl].
class ProfilePhotoViewer extends StatelessWidget {
  const ProfilePhotoViewer({
    required this.path,
    this.remoteUrl,
    this.fit = BoxFit.cover,
    this.width,
    this.height,
    super.key,
  });

  final String path;
  final String? remoteUrl;
  final BoxFit fit;
  final double? width;
  final double? height;

  @override
  Widget build(BuildContext context) {
    if (remoteUrl != null && remoteUrl!.startsWith('profiles/')) {
      return _RemotePhotoImage(
        storagePath: remoteUrl!,
        fit: fit,
        width: width,
        height: height,
      );
    }
    if (path.startsWith('assets/')) {
      return Image.asset(
        path,
        fit: fit,
        width: width,
        height: height,
      );
    }
    if (kIsWeb && path.startsWith('blob:')) {
      return Image.network(
        path,
        fit: fit,
        width: width,
        height: height,
      );
    }
    if (kIsWeb) {
      return const SizedBox.shrink();
    }
    return Image.file(
      File(path),
      fit: fit,
      width: width,
      height: height,
    );
  }
}

class _RemotePhotoImage extends StatefulWidget {
  const _RemotePhotoImage({
    required this.storagePath,
    this.fit = BoxFit.cover,
    this.width,
    this.height,
  });

  final String storagePath;
  final BoxFit fit;
  final double? width;
  final double? height;

  @override
  State<_RemotePhotoImage> createState() => _RemotePhotoImageState();
}

class _RemotePhotoImageState extends State<_RemotePhotoImage> {
  String? _signedUrl;
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _loadSignedUrl();
  }

  Future<void> _loadSignedUrl() async {
    final url = await const SupabaseProfileRepository()
        .getSignedPhotoUrl(widget.storagePath);
    if (!mounted) return;
    setState(() {
      _signedUrl = url;
      _loading = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return const ColoredBox(color: Color(0xFF1A2138));
    }
    if (_signedUrl == null) {
      return const ColoredBox(color: Color(0xFF1A2138));
    }
    return Image.network(
      _signedUrl!,
      fit: widget.fit,
      width: widget.width,
      height: widget.height,
      errorBuilder: (context, error, stackTrace) =>
          const ColoredBox(color: Color(0xFF1A2138)),
    );
  }
}

// ── SectionShell ────────────────────────────────────────────────────────────

/// Wraps each input section with a large title, optional subtitle, and a
/// subtle ✓ that fades in the moment the section is complete.
class SectionShell extends StatelessWidget {
  const SectionShell({
    required this.title,
    required this.child,
    super.key,
    this.subtitle,
    this.completed = false,
  });

  final String title;
  final String? subtitle;
  final Widget child;
  final bool completed;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 0, 20, 26),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  title,
                  style: TextStyle(
                    fontSize: 21,
                    fontWeight: FontWeight.w800,
                    letterSpacing: -0.3,
                    color: kIsWeb ? Colors.white : null,
                  ),
                ),
              ),
              AnimatedSwitcher(
                duration: const Duration(milliseconds: 320),
                switchInCurve: Curves.easeOutCubic,
                switchOutCurve: Curves.easeInOutCubic,
                transitionBuilder: (child, animation) => FadeTransition(
                  opacity: animation,
                  child: ScaleTransition(scale: animation, child: child),
                ),
                child: completed
                    ? const _CompletionCheck(key: ValueKey('done'))
                    : const SizedBox(key: ValueKey('empty'), width: 22),
              ),
            ],
          ),
          if (subtitle != null) ...[
            const SizedBox(height: 4),
            Text(
              subtitle!,
              style: const TextStyle(fontSize: 13.5, color: _kSoftText),
            ),
          ],
          const SizedBox(height: 14),
          child,
        ],
      ),
    );
  }
}

class _CompletionCheck extends StatelessWidget {
  const _CompletionCheck({super.key});

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 22,
      width: 22,
      decoration: const BoxDecoration(
        shape: BoxShape.circle,
        gradient: LinearGradient(
          colors: [Color(0xFF47D7A5), Color(0xFF22BFE0)],
        ),
      ),
      child: const Icon(Icons.check_rounded, size: 15, color: Colors.white),
    );
  }
}

// ── PhotoGrid ───────────────────────────────────────────────────────────────

/// A slot-based photo picker with exactly [kMaxProfilePhotos] premium glass
/// cards. Empty slots show a "+" icon; filled slots show the selected photo.
///
/// Tapping an empty slot triggers [onAddPhoto]. Tapping the remove button on a
/// filled slot triggers [onRemove] with that photo's index. When [onReorder]
/// is provided, up/down arrows are shown for reordering.
class PhotoGrid extends StatelessWidget {
  const PhotoGrid({
    required this.selected,
    required this.onAddPhoto,
    required this.onRemove,
    this.onReplace,
    this.onReorder,
    super.key,
  });

  final List<ProfilePhoto> selected;

  final VoidCallback onAddPhoto;

  final ValueChanged<int> onRemove;

  final void Function(int index)? onReplace;

  final void Function(int oldIndex, int newIndex)? onReorder;

  @override
  Widget build(BuildContext context) {
    if (onReorder != null) {
      return _ReorderablePhotoGrid(
        photos: selected,
        onAddPhoto: onAddPhoto,
        onRemove: onRemove,
        onReplace: onReplace,
        onReorder: onReorder!,
      );
    }

    final slots = <Widget>[];
    for (var i = 0; i < kMaxProfilePhotos; i++) {
      if (i < selected.length) {
        slots.add(_FilledPhotoSlot(
          photo: selected[i],
          index: i,
          onRemove: () => onRemove(i),
          onReplace: onReplace != null ? () => onReplace!(i) : null,
        ));
      } else {
        slots.add(_EmptyPhotoSlot(onTap: onAddPhoto));
      }
    }

    return GridView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      itemCount: slots.length,
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 3,
        mainAxisSpacing: 10,
        crossAxisSpacing: 10,
        childAspectRatio: 0.78,
      ),
      itemBuilder: (context, index) => slots[index],
    );
  }
}

class _ReorderablePhotoGrid extends StatefulWidget {
  const _ReorderablePhotoGrid({
    required this.photos,
    required this.onAddPhoto,
    required this.onRemove,
    this.onReplace,
    required this.onReorder,
  });

  final List<ProfilePhoto> photos;
  final VoidCallback onAddPhoto;
  final ValueChanged<int> onRemove;
  final void Function(int index)? onReplace;
  final void Function(int oldIndex, int newIndex) onReorder;

  @override
  State<_ReorderablePhotoGrid> createState() => _ReorderablePhotoGridState();
}

class _ReorderablePhotoGridState extends State<_ReorderablePhotoGrid> {
  String? _dragPhotoId;
  String? _targetPhotoId;

  void _onDragStarted(String photoId) {
    setState(() {
      _dragPhotoId = photoId;
      _targetPhotoId = null;
    });
  }

  void _onDragEnded() {
    setState(() {
      _dragPhotoId = null;
      _targetPhotoId = null;
    });
  }

  void _onDragOver(String targetPhotoId) {
    if (_targetPhotoId != targetPhotoId) {
      setState(() => _targetPhotoId = targetPhotoId);
    }
  }

  void _onDragLeft() {
    setState(() => _targetPhotoId = null);
  }

  @override
  Widget build(BuildContext context) {
    final slots = <Widget>[];
    for (var i = 0; i < kMaxProfilePhotos; i++) {
      if (i < widget.photos.length) {
        final photo = widget.photos[i];
        final isDragging = _dragPhotoId == photo.id;
        final isTarget = _targetPhotoId == photo.id && _dragPhotoId != photo.id;
        slots.add(_DraggablePhotoSlot(
          key: ValueKey(photo.id),
          photo: photo,
          index: i,
          onRemove: () => widget.onRemove(i),
          onReplace: widget.onReplace != null ? () => widget.onReplace!(i) : null,
          isDragging: isDragging,
          isTarget: isTarget,
          onDragStarted: _onDragStarted,
          onDragEnded: _onDragEnded,
          onDragMoved: _onDragOver,
          onDragLeft: _onDragLeft,
          onReorder: widget.onReorder,
          photos: widget.photos,
        ));
      } else {
        slots.add(_EmptyPhotoSlot(
          key: ValueKey('empty_$i'),
          onTap: widget.onAddPhoto,
        ));
      }
    }

    return GridView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      itemCount: slots.length,
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 3,
        mainAxisSpacing: 10,
        crossAxisSpacing: 10,
        childAspectRatio: 0.78,
      ),
      itemBuilder: (context, index) => slots[index],
    );
  }
}

class _DraggablePhotoSlot extends StatelessWidget {
  const _DraggablePhotoSlot({
    super.key,
    required this.photo,
    required this.index,
    required this.onRemove,
    this.onReplace,
    required this.isDragging,
    required this.isTarget,
    required this.onDragStarted,
    required this.onDragEnded,
    required this.onDragMoved,
    required this.onDragLeft,
    required this.onReorder,
    required this.photos,
  });

  final ProfilePhoto photo;
  final int index;
  final VoidCallback onRemove;
  final VoidCallback? onReplace;
  final bool isDragging;
  final bool isTarget;
  final void Function(String) onDragStarted;
  final VoidCallback onDragEnded;
  final void Function(String) onDragMoved;
  final VoidCallback onDragLeft;
  final void Function(int oldIndex, int newIndex) onReorder;
  final List<ProfilePhoto> photos;

  @override
  Widget build(BuildContext context) {
    if (isDragging) {
      return _EmptyPhotoSlot(onTap: () {});
    }

    Widget child = _FilledPhotoSlot(
      photo: photo,
      index: index,
      onRemove: onRemove,
      onTap: onReplace,
    );

    return LongPressDraggable<_DragPhotoData>(
      data: _DragPhotoData(photo: photo, index: index),
      onDragStarted: () => onDragStarted(photo.id),
      onDragEnd: (_) => onDragEnded(),
      feedback: Material(
        elevation: 12,
        borderRadius: BorderRadius.circular(16),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(16),
          child: ProfilePhotoViewer(
            path: photo.assetPath,
            remoteUrl: photo.remoteUrl,
            fit: BoxFit.cover,
            width: 120,
            height: 156,
          ),
        ),
      ),
      child: DragTarget<_DragPhotoData>(
        onAcceptWithDetails: (details) {
          final sourceId = details.data.photo.id;
          final targetId = photo.id;
          if (sourceId == targetId) {
            onDragEnded();
            return;
          }
          final sourceIndex = photos.indexWhere((p) => p.id == sourceId);
          final targetIndex = photos.indexWhere((p) => p.id == targetId);
          if (sourceIndex < 0 || targetIndex < 0) {
            onDragEnded();
            return;
          }
          onReorder(sourceIndex, targetIndex);
          onDragEnded();
        },
        onMove: (_) => onDragMoved(photo.id),
        onLeave: (_) => onDragLeft(),
        builder: (context, candidateData, rejectedData) {
          return AnimatedContainer(
            duration: const Duration(milliseconds: 180),
            curve: Curves.easeOutCubic,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(16),
              border: Border.all(
                color: isTarget ? _kAccent : Colors.transparent,
                width: 2,
              ),
              boxShadow: isTarget
                  ? [
                      BoxShadow(
                        color: _kAccent.withValues(alpha: .55),
                        blurRadius: 18,
                        spreadRadius: 1,
                      ),
                    ]
                  : null,
            ),
            child: child,
          );
        },
      ),
    );
  }
}

class _DragPhotoData {
  const _DragPhotoData({required this.photo, required this.index});
  final ProfilePhoto photo;
  final int index;
}

class _EmptyPhotoSlot extends StatelessWidget {
  const _EmptyPhotoSlot({super.key, required this.onTap});

  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 220),
        curve: Curves.easeOutCubic,
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: kIsWeb
                ? Colors.white.withValues(alpha: .15)
                : Colors.white.withValues(alpha: .08),
            width: 1,
          ),
        ),
        child: Center(
          child: Icon(
            Icons.add_rounded,
            size: 28,
            color: Colors.white.withValues(alpha: .35),
          ),
        ),
      ),
    );
  }
}

class _FilledPhotoSlot extends StatelessWidget {
  const _FilledPhotoSlot({
    required this.photo,
    required this.index,
    required this.onRemove,
    this.onReplace,
    this.onTap,
  });

  final ProfilePhoto photo;
  final int index;
  final VoidCallback onRemove;
  final VoidCallback? onReplace;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap ?? onRemove,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 220),
        curve: Curves.easeOutCubic,
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: _kAccent,
            width: 2,
          ),
          boxShadow: [
            BoxShadow(
              color: _kAccent.withValues(alpha: .4),
              blurRadius: 16,
              spreadRadius: 1,
            ),
          ],
        ),
        clipBehavior: Clip.antiAlias,
        child: Stack(
          fit: StackFit.expand,
          children: [
            ProfilePhotoViewer(
              path: photo.assetPath,
              remoteUrl: photo.remoteUrl,
              fit: BoxFit.cover,
            ),
            Positioned(
              top: 6,
              right: 6,
              child: GestureDetector(
                onTap: onRemove,
                child: Container(
                  height: 24,
                  width: 24,
                  decoration: const BoxDecoration(
                    shape: BoxShape.circle,
                    color: Colors.black54,
                  ),
                  child: const Icon(
                    Icons.close_rounded,
                    size: 14,
                    color: Colors.white,
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ── SelectableChip ──────────────────────────────────────────────────────────

/// A premium selectable chip (fills with the accent gradient when selected).
class SelectableChip extends StatelessWidget {
  const SelectableChip({
    required this.label,
    required this.selected,
    required this.onTap,
    super.key,
    this.icon,
  });

  final String label;
  final bool selected;
  final VoidCallback onTap;
  final IconData? icon;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 240),
        curve: Curves.easeOutCubic,
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 11),
        decoration: BoxDecoration(
          gradient: selected
              ? const LinearGradient(colors: [_kAccent, _kAccent2])
              : null,
          color: selected ? null : _kFieldFill,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(
            color: selected
                ? Colors.transparent
                : Colors.white.withValues(alpha: .1),
          ),
          boxShadow: selected
              ? [
                  BoxShadow(
                    color: _kAccent.withValues(alpha: .38),
                    blurRadius: 14,
                    offset: const Offset(0, 5),
                  ),
                ]
              : null,
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (icon != null) ...[
              Icon(
                icon,
                size: 16,
                color: selected ? Colors.white : const Color(0xFFB7A5FF),
              ),
              const SizedBox(width: 6),
            ],
            Text(
              label,
              style: TextStyle(
                fontSize: 13,
                fontWeight: selected ? FontWeight.w700 : FontWeight.w600,
                letterSpacing: -0.1,
                color: selected ? Colors.white : const Color(0xFFDDE3F4),
              ),
            ),
          ],
        ),
      ),

    );
  }
}

// ── MultiChipField ──────────────────────────────────────────────────────────

/// A wrap of [SelectableChip]s for multi-select fields (interests, languages).
class MultiChipField extends StatelessWidget {
  const MultiChipField({
    required this.options,
    required this.selected,
    required this.onToggle,
    super.key,
  });

  final List<String> options;
  final List<String> selected;
  final ValueChanged<String> onToggle;

  @override
  Widget build(BuildContext context) {
    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: [
        for (final option in options)
          SelectableChip(
            label: option,
            selected: selected.contains(option),
            onTap: () => onToggle(option),
          ),
      ],
    );
  }
}

// ── GlassTextField ──────────────────────────────────────────────────────────

/// A dark-glass text field matching the Conexo input language.
class GlassTextField extends StatelessWidget {
  const GlassTextField({
    required this.controller,
    required this.hint,
    super.key,
    this.icon,
    this.maxLines = 1,
    this.maxLength,
    this.keyboardType,
    this.onChanged,
    this.suffixIcon,
    this.onSuffixTap,
    this.suffixBusy = false,
    this.focusNode,
  });

  final TextEditingController controller;
  final String hint;
  final IconData? icon;
  final int maxLines;
  final int? maxLength;
  final TextInputType? keyboardType;
  final ValueChanged<String>? onChanged;

  /// Optional trailing action icon (e.g. "use current location"). Kept visually
  /// minimal so the field's premium glass language is preserved.
  final IconData? suffixIcon;

  /// Tap handler for [suffixIcon]. When null, no suffix affordance is shown.
  final VoidCallback? onSuffixTap;

  /// When true, the suffix shows a small spinner instead of the icon.
  final bool suffixBusy;

  final FocusNode? focusNode;

  @override
  Widget build(BuildContext context) {
    final hasSuffix = suffixIcon != null || suffixBusy;
    return TextField(
      controller: controller,
      focusNode: focusNode,
      onChanged: onChanged,
      maxLines: maxLines,
      maxLength: maxLength,
      keyboardType: keyboardType,
      style: const TextStyle(
        fontSize: 15,
        height: 1.4,
        fontWeight: FontWeight.w500,
      ),
      decoration: InputDecoration(
        hintText: hint,
        hintStyle: const TextStyle(
          fontSize: 14.5,
          color: _kSoftText,
          fontWeight: FontWeight.w500,
        ),
        prefixIcon: icon != null
            ? Icon(icon, size: 20, color: const Color(0xFFB7A5FF))
            : null,
        suffixIcon: hasSuffix
            ? _GlassFieldSuffix(
                icon: suffixIcon,
                busy: suffixBusy,
                onTap: onSuffixTap,
              )
            : null,
        filled: true,
        fillColor: _kFieldFill,
        contentPadding: const EdgeInsets.symmetric(
          horizontal: 16,
          vertical: 16,
        ),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: BorderSide(
            color: kIsWeb
                ? Colors.white.withValues(alpha: .16)
                : Colors.white.withValues(alpha: .1),
          ),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: BorderSide(
            color: kIsWeb
                ? Colors.white.withValues(alpha: .16)
                : Colors.white.withValues(alpha: .1),
          ),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: const BorderSide(color: _kAccent, width: 1.6),
        ),
      ),
    );

  }
}

/// A subtle, tappable suffix used inside [GlassTextField] (e.g. the GPS
/// "detect" affordance). Shows a small spinner while [busy].
class _GlassFieldSuffix extends StatelessWidget {
  const _GlassFieldSuffix({
    required this.icon,
    required this.busy,
    required this.onTap,
  });

  final IconData? icon;
  final bool busy;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    return IconButton(
      onPressed: busy ? null : onTap,
      splashRadius: 20,
      visualDensity: VisualDensity.compact,
      icon: busy
          ? const SizedBox(
              height: 18,
              width: 18,
              child: CircularProgressIndicator(
                strokeWidth: 2,
                color: Color(0xFFB7A5FF),
              ),
            )
          : Icon(icon, size: 20, color: const Color(0xFFB7A5FF)),
    );
  }
}

// ── LocationDetectField ─────────────────────────────────────────────────────

/// A [GlassTextField] specialised for location entry with a subtle GPS suffix.
///
/// The whole field triggers detection when empty (via [readOnlyTapWhenEmpty]),
/// and the suffix icon triggers detection at any time; either way the text stays
/// editable so the resolved area name can be corrected by hand. All GPS /
/// geocoding lives in [LocationService]; this widget only orchestrates UI state
/// and surfaces failures.
class LocationDetectField extends StatefulWidget {
  const LocationDetectField({
    required this.controller,
    required this.onLocationNameChanged,
    required this.onLocationDetected,
    super.key,
    this.hint = 'e.g. Bengaluru, India',
  });

  final TextEditingController controller;

  /// Called when the user manually edits the location name.
  final ValueChanged<String> onLocationNameChanged;

  /// Called when location coordinates are resolved, either from GPS detection
  /// or from a manual suggestion selection. When the user is typing manually
  /// without selecting a suggestion, coordinates are cleared by passing null.
  final void Function(String? areaName, double? latitude, double? longitude)
      onLocationDetected;

  final String hint;

  @override
  State<LocationDetectField> createState() => _LocationDetectFieldState();
}

class _LocationDetectFieldState extends State<LocationDetectField> {
  bool _busy = false;

  /// After the first detection attempt, tapping the field no longer auto-detects
  /// (so manual typing is never interrupted). Re-detection stays on the GPS icon.
  bool _autoDetectSuppressed = false;

  List<LocationSuggestion> _suggestions = [];
  bool _searching = false;
  Timer? _debounceTimer;
  final FocusNode _focusNode = FocusNode();
  bool _showSuggestions = false;

  @override
  void initState() {
    super.initState();
    _focusNode.addListener(_onFocusChanged);
  }

  @override
  void dispose() {
    _focusNode.removeListener(_onFocusChanged);
    _focusNode.dispose();
    _debounceTimer?.cancel();
    super.dispose();
  }

  void _onFocusChanged() {
    if (!_focusNode.hasFocus) {
      setState(() => _showSuggestions = false);
    }
  }

  Future<void> _detect() async {
    if (_busy) return;
    setState(() {
      _busy = true;
      _autoDetectSuppressed = true;
    });

    final result = await LocationService.detectCurrentLocation();
    if (!mounted) return;

    setState(() => _busy = false);

    switch (result.outcome) {
      case LocationOutcome.success:
        final name = result.areaName;
        if (name != null && name.isNotEmpty) {
          widget.controller.text = name;
          widget.controller.selection = TextSelection.collapsed(
            offset: name.length,
          );
        }
        widget.onLocationDetected(name, result.latitude, result.longitude);
        _showSnack(
          name != null && name.isNotEmpty
              ? 'Location detected'
              : 'Coordinates captured. Add a location name.',
        );
      case LocationOutcome.permissionDenied:
        _showSnack('Location permission denied. You can type it manually.');
      case LocationOutcome.permissionPermanentlyDenied:
        _showSettingsSnack();
      case LocationOutcome.serviceDisabled:
        _showSnack('Turn on location services, or type your location.');
      case LocationOutcome.failed:
        _showSnack("Couldn't get your location. You can type it manually.");
    }
  }

  void _onTextChanged(String value) {
    widget.onLocationNameChanged(value);
    _debounceTimer?.cancel();
    if (value.trim().isEmpty) {
      setState(() {
        _suggestions = [];
        _showSuggestions = false;
      });
      return;
    }
    setState(() => _searching = true);
    _debounceTimer = Timer(const Duration(milliseconds: 300), () async {
      final results = await LocationService.searchLocations(value);
      if (!mounted) return;
      setState(() {
        _suggestions = results.take(5).toList();
        _searching = false;
        _showSuggestions = _suggestions.isNotEmpty && _focusNode.hasFocus;
      });
    });
    widget.onLocationDetected(null, null, null);
  }

  Future<void> _selectSuggestion(LocationSuggestion suggestion) async {
    final name = suggestion.displayName;
    widget.controller.text = name;
    widget.controller.selection = TextSelection.collapsed(offset: name.length);
    widget.onLocationNameChanged(name);
    widget.onLocationDetected(name, suggestion.latitude, suggestion.longitude);
    setState(() {
      _showSuggestions = false;
      _suggestions = [];
    });
    _focusNode.unfocus();
  }

  void _showSnack(String message) {
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(content: Text(message)));
  }

  void _showSettingsSnack() {
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(
        SnackBar(
          content: const Text('Location permission is off in Settings.'),
          action: SnackBarAction(
            label: 'Settings',
            onPressed: PermissionManager.openAppSettings,
          ),
        ),
      );
  }

  @override
  Widget build(BuildContext context) {
    final canAutoDetect =
        !_autoDetectSuppressed && widget.controller.text.trim().isEmpty && !_busy;
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        GestureDetector(
          behavior: HitTestBehavior.translucent,
          onTap: canAutoDetect ? _detect : null,
          child: GlassTextField(
            controller: widget.controller,
            hint: widget.hint,
            icon: Icons.location_on_outlined,
            suffixIcon: Icons.my_location_rounded,
            suffixBusy: _busy,
            onSuffixTap: _detect,
            onChanged: _onTextChanged,
            focusNode: _focusNode,
          ),
        ),
        if (_showSuggestions && _suggestions.isNotEmpty)
          _SuggestionsPanel(
            suggestions: _suggestions,
            searching: _searching,
            onSelect: _selectSuggestion,
          ),
      ],
    );
  }
}

class _SuggestionsPanel extends StatelessWidget {
  const _SuggestionsPanel({
    required this.suggestions,
    required this.searching,
    required this.onSelect,
  });

  final List<LocationSuggestion> suggestions;
  final bool searching;
  final ValueChanged<LocationSuggestion> onSelect;

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(top: 8),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: Colors.white.withValues(alpha: .1),
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: .35),
            blurRadius: 20,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(16),
        child: ListView.separated(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          itemCount: searching ? 1 : suggestions.length,
          separatorBuilder: (_, _) => Divider(
            height: 1,
            color: Colors.white.withValues(alpha: .08),
          ),
          itemBuilder: (context, index) {
            if (searching) {
              return const SizedBox(
                height: 56,
                child: Center(
                  child: SizedBox(
                    height: 20,
                    width: 20,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      color: Color(0xFF8B5CF6),
                    ),
                  ),
                ),
              );
            }
            final suggestion = suggestions[index];
            return InkWell(
              onTap: () => onSelect(suggestion),
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                child: Row(
                  children: [
                    Icon(
                      Icons.place_outlined,
                      size: 18,
                      color: const Color(0xFFB7A5FF),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Text(
                        suggestion.displayName,
                        style: const TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w500,
                          color: Color(0xFFEAEEF9),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            );
          },
        ),
      ),
    );
  }
}

// ── GenderSelector ──────────────────────────────────────────────────────────

/// A single-select set of gender chips.
class GenderSelector extends StatelessWidget {
  const GenderSelector({
    required this.options,
    required this.value,
    required this.onSelected,
    super.key,
  });

  final List<String> options;
  final String value;
  final ValueChanged<String> onSelected;

  @override
  Widget build(BuildContext context) {
    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: [
        for (final option in options)
          SelectableChip(
            label: option,
            selected: value == option,
            onTap: () => onSelected(option),
          ),
      ],
    );
  }
}

// ── DateOfBirthField ────────────────────────────────────────────────────────

/// A tappable, read-only date-of-birth field that opens the native Material
/// date picker. Never a free-text field. The picker's `lastDate` is today, so a
/// future date can never be chosen; the empty state prompts a selection.
class DateOfBirthField extends StatelessWidget {
  const DateOfBirthField({
    required this.value,
    required this.onChanged,
    super.key,
  });

  final DateTime? value;
  final ValueChanged<DateTime> onChanged;

  static const _months = [
    'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun',
    'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec',
  ];

  String _formatDisplay(DateTime d) =>
      '${d.day} ${_months[d.month - 1]} ${d.year}';

  Future<void> _pick(BuildContext context) async {
    final now = DateTime.now();
    final latestAllowed = DateTime(now.year - 18, now.month, now.day);
    final seed = value ?? latestAllowed;
    final initial = seed.isAfter(latestAllowed) ? latestAllowed : seed;
    final picked = await showDatePicker(
      context: context,
      initialDate: initial,
      firstDate: DateTime(1900),
      lastDate: latestAllowed,
      helpText: 'Select your date of birth',
      initialEntryMode: DatePickerEntryMode.calendar,
    );
    if (picked != null) {
      onChanged(DateTime(picked.year, picked.month, picked.day));
    }
  }

  @override
  Widget build(BuildContext context) {
    final hasValue = value != null;
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: () => _pick(context),
        borderRadius: BorderRadius.circular(16),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
          decoration: BoxDecoration(
            color: _kFieldFill,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: Colors.white.withValues(alpha: .1)),
          ),
          child: Row(
            children: [
              const Icon(
                Icons.cake_outlined,
                size: 20,
                color: Color(0xFFB7A5FF),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  hasValue
                      ? _formatDisplay(value!)
                      : 'Select your date of birth',
                  style: TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w500,
                    color: hasValue ? Colors.white : _kSoftText,
                  ),
                ),
              ),
              const Icon(
                Icons.expand_more_rounded,
                size: 20,
                color: Color(0xFF8592B4),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ── SocialLinkField ─────────────────────────────────────────────────────────

/// A row that captures one social link: a platform chip + a URL/handle field.
class SocialLinkField extends StatelessWidget {
  const SocialLinkField({
    required this.platforms,
    required this.platform,
    required this.controller,
    required this.onPlatformChanged,
    required this.onUrlChanged,
    super.key,
  });

  final List<String> platforms;
  final String platform;
  final TextEditingController controller;
  final ValueChanged<String> onPlatformChanged;
  final ValueChanged<String> onUrlChanged;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            for (final p in platforms)
              SelectableChip(
                label: p,
                selected: platform == p,
                onTap: () => onPlatformChanged(p),
              ),
          ],
        ),
        const SizedBox(height: 12),
        GlassTextField(
          controller: controller,
          hint: 'Your $platform handle or URL',
          icon: Icons.link_rounded,
          keyboardType: TextInputType.url,
          onChanged: onUrlChanged,
        ),
      ],
    );
  }
}

// ── RestoreBanner ───────────────────────────────────────────────────────────

/// A premium banner prompting the user to restore a saved draft.
class RestoreBanner extends StatelessWidget {
  const RestoreBanner({
    required this.onRestore,
    required this.onDiscard,
    super.key,
  });

  final VoidCallback onRestore;
  final VoidCallback onDiscard;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 0, 20, 20),
      child: EntranceFade(
        child: GlassCard(
          child: Row(
            children: [
              const Icon(Icons.history_rounded, color: Color(0xFFB7A5FF)),
              const SizedBox(width: 12),
              const Expanded(
                child: Text(
                  'Continue where you left off?',
                  style: TextStyle(fontWeight: FontWeight.w700),
                ),
              ),
              TextButton(
                onPressed: onDiscard,
                child: const Text('Discard'),
              ),
              const SizedBox(width: 4),
              FilledButton(
                onPressed: onRestore,
                style: FilledButton.styleFrom(backgroundColor: _kAccent),
                child: const Text('Restore'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ── CompletionMeter ─────────────────────────────────────────────────────────

/// A slim animated progress meter reflecting [progress] (0..1).
class CompletionMeter extends StatelessWidget {
  const CompletionMeter({required this.progress, super.key});

  final double progress;

  @override
  Widget build(BuildContext context) {
    final pct = (progress.clamp(0.0, 1.0) * 100).round();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            const Text(
              'Profile completeness',
              style: TextStyle(fontSize: 13, color: _kSoftText),
            ),
            const Spacer(),
            Text(
              '$pct%',
              style: const TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w800,
                color: Color(0xFFB7A5FF),
              ),
            ),
          ],
        ),
        const SizedBox(height: 8),
        ClipRRect(
          borderRadius: BorderRadius.circular(8),
          child: Stack(
            children: [
              Container(height: 8, color: Colors.white.withValues(alpha: .08)),
              LayoutBuilder(
                builder: (context, constraints) {
                  return AnimatedContainer(
                    duration: const Duration(milliseconds: 400),
                    curve: Curves.easeOutCubic,
                    height: 8,
                    width: constraints.maxWidth * progress.clamp(0.0, 1.0),
                    decoration: const BoxDecoration(
                      gradient: LinearGradient(
                        colors: [_kAccent, _kAccent2],
                      ),
                    ),
                  );
                },
              ),
            ],
          ),
        ),
      ],
    );
  }
}

// ── CompleteProfileButton ───────────────────────────────────────────────────

/// The primary CTA. Enabled only when the draft is complete; shows a loading
/// spinner while saving with animated press feedback.
class CompleteProfileButton extends StatefulWidget {
  const CompleteProfileButton({
    required this.enabled,
    required this.loading,
    required this.onTap,
    super.key,
  });

  final bool enabled;
  final bool loading;
  final VoidCallback onTap;

  @override
  State<CompleteProfileButton> createState() => _CompleteProfileButtonState();
}

class _CompleteProfileButtonState extends State<CompleteProfileButton> {
  bool _pressed = false;

  @override
  Widget build(BuildContext context) {
    final active = widget.enabled && !widget.loading;
    return GestureDetector(
      onTapDown: active ? (_) => setState(() => _pressed = true) : null,
      onTapUp: active ? (_) => setState(() => _pressed = false) : null,
      onTapCancel: () => setState(() => _pressed = false),
      onTap: active ? widget.onTap : null,
      child: AnimatedScale(
        scale: _pressed ? 0.97 : 1.0,
        duration: const Duration(milliseconds: 160),
        curve: Curves.easeOutCubic,
        child: AnimatedOpacity(
          duration: const Duration(milliseconds: 240),
          opacity: active ? 1 : 0.5,
          child: Container(
            height: 56,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              gradient: const LinearGradient(colors: [_kAccent, _kAccent2]),
              borderRadius: BorderRadius.circular(16),
              boxShadow: active
                  ? [
                      BoxShadow(
                        color: _kAccent.withValues(alpha: .5),
                        blurRadius: 24,
                        offset: const Offset(0, 10),
                      ),
                    ]
                  : null,
            ),
            child: widget.loading
                ? const SizedBox(
                    height: 22,
                    width: 22,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      color: Colors.white,
                    ),
                  )
                : const Text(
                    'Complete profile',
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w800,
                      color: Colors.white,
                    ),
                  ),
          ),
        ),
      ),
    );
  }
}

// ── ProfilePreviewCard ──────────────────────────────────────────────────────

/// A premium, continuously-updating preview of the profile.
///
/// Consumes only [ProfilePreviewData], so it never depends on mutable screen
/// state or a specific model (draft vs. finalized). This keeps it reusable
/// unchanged across future profile screens.
class ProfilePreviewCard extends StatelessWidget {
  const ProfilePreviewCard({required this.data, super.key});

  final ProfilePreviewData data;

  @override
  Widget build(BuildContext context) {
    final hero = data.primaryPhotoAsset;
    return RepaintBoundary(
      child: GlassCard(
        padding: const EdgeInsets.all(0),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              AspectRatio(
                aspectRatio: 16 / 11,
                child: Stack(
                  fit: StackFit.expand,
                  children: [
                    if (hero != null)
                      ProfilePhotoViewer(
                        path: hero,
                        remoteUrl: data.primaryPhotoRemoteUrl,
                        fit: BoxFit.cover,
                      )
                    else
                      const ColoredBox(color: Color(0xFF1A2138)),
                    const DecoratedBox(
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          begin: Alignment.topCenter,
                          end: Alignment.bottomCenter,
                          colors: [
                            Color(0x00000000),
                            Color(0xCC0A0F1F),
                          ],
                          stops: [0.5, 1.0],
                        ),
                      ),
                    ),
                    Positioned(
                      left: 16,
                      right: 16,
                      bottom: 14,
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          if (data.location.isNotEmpty)
                            Row(
                              children: [
                                const Icon(
                                  Icons.near_me_rounded,
                                  size: 15,
                                  color: Color(0xFFEAEEF9),
                                ),
                                const SizedBox(width: 5),
                                Text(
                                  data.location,
                                  style: const TextStyle(
                                    color: Color(0xFFEAEEF9),
                                    fontWeight: FontWeight.w600,
                                    shadows: [
                                      Shadow(
                                        color: Color(0x99000000),
                                        blurRadius: 10,
                                      ),
                                    ],
                                  ),
                                ),
                              ],
                            ),
                          if (data.gender.isNotEmpty) ...[
                            const SizedBox(height: 4),
                            Text(
                              data.gender,
                              style: const TextStyle(
                                color: Color(0xFFC7D0E6),
                                fontSize: 13,
                              ),
                            ),
                          ],
                        ],
                      ),
                    ),
                  ],
                ),
              ),
              Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    if (data.bio.isNotEmpty)
                      Text(
                        data.bio,
                        style: const TextStyle(
                          fontSize: 15,
                          height: 1.4,
                          color: Color(0xFFEAEEF9),
                        ),
                      ),
                    if (data.interests.isNotEmpty) ...[
                      const SizedBox(height: 14),
                      _PreviewLabel('Interests'),
                      const SizedBox(height: 8),
                      _PreviewChips(values: data.interests),
                    ],
                    if (data.languages.isNotEmpty) ...[
                      const SizedBox(height: 14),
                      _PreviewLabel('Languages'),
                      const SizedBox(height: 8),
                      _PreviewChips(values: data.languages),
                    ],
                    if (data.occupation.isNotEmpty)
                      _PreviewDetail(
                        icon: Icons.work_outline_rounded,
                        value: data.occupation,
                      ),
                    if (data.college.isNotEmpty)
                      _PreviewDetail(
                        icon: Icons.school_outlined,
                        value: data.college,
                      ),
                    if (data.hometown.isNotEmpty)
                      _PreviewDetail(
                        icon: Icons.home_outlined,
                        value: data.hometown,
                      ),
                    if (data.socialLinks.isNotEmpty) ...[
                      const SizedBox(height: 14),
                      _PreviewLabel('Socials'),
                      const SizedBox(height: 8),
                      _PreviewChips(
                        values: [
                          for (final s in data.socialLinks)
                            if (s.url.trim().isNotEmpty) s.platform,
                        ],
                      ),
                    ],
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _PreviewLabel extends StatelessWidget {
  const _PreviewLabel(this.text);

  final String text;

  @override
  Widget build(BuildContext context) {
    return Text(
      text,
      style: const TextStyle(
        fontSize: 13,
        fontWeight: FontWeight.w800,
        letterSpacing: .2,
        color: Color(0xFFB7A5FF),
      ),
    );
  }
}

class _PreviewChips extends StatelessWidget {
  const _PreviewChips({required this.values});

  final List<String> values;

  @override
  Widget build(BuildContext context) {
    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: [
        for (final value in values)
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 13, vertical: 8),
            decoration: BoxDecoration(

              color: Colors.white.withValues(alpha: .07),
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: Colors.white.withValues(alpha: .1)),
            ),
            child: Text(
              value,
              style: const TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w600,
                letterSpacing: -0.1,
                color: Color(0xFFDDE3F4),
              ),
            ),
          ),

      ],
    );
  }
}

class _PreviewDetail extends StatelessWidget {
  const _PreviewDetail({required this.icon, required this.value});

  final IconData icon;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(top: 10),
      child: Row(
        children: [
          Icon(icon, size: 16, color: const Color(0xFFB7A5FF)),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              value,
              style: const TextStyle(fontSize: 13, color: Color(0xFFC7D0E6)),
            ),
          ),
        ],
      ),
    );
  }
}
