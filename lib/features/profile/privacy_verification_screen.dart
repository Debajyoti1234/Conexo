import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

import '../home_discovery_animations.dart';
import '../../core/supabase/auth_service.dart';
import 'face_verification_client.dart';
import 'privacy_verification_sections.dart';
import 'privacy_verification_widgets.dart';
import 'profile_data.dart';
import 'profile_repository.dart';
import 'selfie_capture_screen.dart';
import 'session_aware_profile_repository.dart';
import 'verification_dialogs.dart';
import 'verification/verification_guidance_screen.dart';
import 'verification/verification_theme.dart';

/// The premium Privacy & Verification module (Phase 4.3).
///
/// Loads the finalized [UserProfile] through the injected [ProfileRepository]
/// and lets the user edit ONLY [ProfileVisibility]. Verification is purely
/// informational — the "Verify Identity" action opens a coming-soon dialog and
/// performs no backend / camera / permission work. Saving writes back through
/// the repository only when the visibility actually changed, preserving the
/// profile's id + createdAt, and plays a subtle success overlay.
///
/// This screen contains only UI + flow orchestration. Models and persistence
/// live in their own files. Local-only — no Firebase / backend / navigation
/// changes, and it never alters Discovery filtering (visibility is
/// informational here).
class PrivacyVerificationScreen extends StatefulWidget {
  const PrivacyVerificationScreen({
    super.key,
    this.repository = const SessionAwareProfileRepository(),
  });

  /// Injected repository (defaults to the local implementation). A future
  /// backend repository can be supplied without changing this screen.
  final ProfileRepository repository;

  @override
  State<PrivacyVerificationScreen> createState() =>
      _PrivacyVerificationScreenState();
}

class _PrivacyVerificationScreenState extends State<PrivacyVerificationScreen> {
  /// The loaded profile — its id + createdAt are preserved on save.
  UserProfile? _profile;

  /// The visibility snapshot as loaded, used for pure dirty-detection.
  ProfileVisibility _originalVisibility = ProfileVisibility.public;

  /// The live, editable visibility value.
  ProfileVisibility _visibility = ProfileVisibility.public;

  VerificationStatus _verificationStatus = VerificationStatus.notVerified;

  bool _loading = true;
  bool _notFound = false;
  bool _saving = false;
  bool _saved = false;
  bool _verifying = false;

  final FaceVerificationClient _verificationClient = const FaceVerificationClient();

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final profile = await widget.repository.loadProfile();
    if (!mounted) return;
    if (profile == null) {
      setState(() {
        _loading = false;
        _notFound = true;
      });
      return;
    }
    setState(() {
      _profile = profile;
      _originalVisibility = profile.profileVisibility;
      _visibility = profile.profileVisibility;
      _verificationStatus = profile.verificationStatus;
      _loading = false;
    });
  }

  /// True when the editable visibility differs from what was loaded.
  bool get _isDirty => _visibility != _originalVisibility;

  void _onVisibilityChanged(ProfileVisibility value) {
    if (value == _visibility) return;
    setState(() => _visibility = value);
  }

  /// Persists the visibility change, preserving id + createdAt (only
  /// updatedAt changes). No-ops (without writing) when nothing changed.
  Future<void> _save() async {
    final profile = _profile;
    if (profile == null || _saving || !_isDirty) return;

    setState(() => _saving = true);
    await Future<void>.delayed(const Duration(milliseconds: 500));
    final updated = profile.copyWith(
      profileVisibility: _visibility,
      updatedAt: DateTime.now(),
    );
    await widget.repository.saveProfile(updated);
    if (!mounted) return;

    setState(() {
      _profile = updated;
      _originalVisibility = _visibility;
      _saving = false;
      _saved = true;
    });

    await Future<void>.delayed(const Duration(milliseconds: 1300));
    if (!mounted) return;
    Navigator.of(context).maybePop();
  }

  /// Controlled fallback switch. The premium three-angle flow is used by
  /// default; set this to `true` to restore the proven single-photo
  /// verification (kept fully intact) without any other change.
  bool get _useSinglePhotoFallback => false;

  Future<void> _onVerifyIdentity() async {
    if (_verifying) return;

    final profile = _profile;
    if (profile == null) {
      if (!mounted) return;
      await showVerificationErrorDialog(
        context,
        'Profile not found. Please complete your profile first.',
      );
      return;
    }

    if (profile.primaryPhoto == null) {
      if (!mounted) return;
      await showVerificationErrorDialog(
        context,
        'Please add a profile photo before verification.',
      );
      return;
    }

    if (_useSinglePhotoFallback) {
      await _verifyWithSinglePhoto(profile);
      return;
    }

    // Premium three-angle verification flow. It manages capture, upload and its
    // own success/failed states; the backend updates verification_status.
    await Navigator.of(context).push<bool>(
      verifyFadeSlideRoute(const VerificationGuidanceScreen()),
    );
    if (!mounted) return;

    final refreshed = await widget.repository.loadProfile();
    if (!mounted) return;
    if (refreshed != null) {
      setState(() {
        _profile = refreshed;
        _verificationStatus = refreshed.verificationStatus;
      });
    }
  }

  /// The proven single-photo verification path, preserved as a controlled
  /// fallback (see [_useSinglePhotoFallback]). Uses the same transport and the
  /// existing `/api/v1/verify-face` endpoint.
  Future<void> _verifyWithSinglePhoto(UserProfile profile) async {
    final result = await Navigator.of(context).push<SelfieCaptureResult>(
      MaterialPageRoute(builder: (_) => const SelfieCaptureScreen()),
    );

    if (!mounted || result == null || result.bytes == null) {
      return;
    }

    final bytes = result.bytes!;
    if (bytes.isEmpty) return;

    final session = AuthService.currentSession;
    final accessToken = session?.accessToken;
    if (accessToken == null || accessToken.isEmpty) {
      if (!mounted) return;
      await showVerificationErrorDialog(
        context,
        'Your session expired. Please sign in again.',
      );
      return;
    }

    if (!mounted) return;
    setState(() => _verifying = true);
    showVerificationLoadingDialog(context);

    try {
      final verificationResult = await _verificationClient.verifyFace(
        selfieBytes: bytes,
        accessToken: accessToken,
      );

      if (!mounted) return;
      Navigator.of(context).pop(); // close loading

      final refreshed = await widget.repository.loadProfile();
      if (!mounted) return;

      if (refreshed != null) {
        setState(() {
          _profile = refreshed;
          _verificationStatus = refreshed.verificationStatus;
        });
      }

      if (verificationResult.match) {
        await showVerificationSuccessDialog(context);
      } else {
        final message = _mapVerificationMessage(verificationResult.reason);
        await showVerificationErrorDialog(context, message);
      }
    } on FaceVerificationException catch (e) {
      if (!mounted) return;
      Navigator.of(context).pop();
      await showVerificationErrorDialog(context, e.message);
    } catch (e) {
      if (!mounted) return;
      Navigator.of(context).pop();
      await showVerificationErrorDialog(
        context,
        'Verification is temporarily unavailable. Please try again later.',
      );
    } finally {
      if (mounted) {
        setState(() => _verifying = false);
      }
    }
  }

  String _mapVerificationMessage(String reason) {
    switch (reason) {
      case 'no_face':
        return 'No face detected. Please try again with your face clearly visible.';
      case 'multiple_faces':
        return 'Only one face should be visible. Please try again.';
      case 'low_similarity':
        return 'We couldn\'t match your selfie with your profile photo. Please try again.';
      case 'no_primary_photo':
        return 'Please add a profile photo before verification.';
      case 'invalid_primary_photo':
        return 'Your profile photo couldn\'t be processed. Please update it.';
      case 'file_too_large':
        return 'Photo is too large. Please use a photo under 5 MB.';
      case 'invalid_file_type':
        return 'Please use a JPEG, PNG, or WebP photo.';
      case 'profile_not_found':
        return 'Profile not found. Please complete your profile first.';
      case 'storage_failure':
        return 'Unable to access your profile photo. Please try again later.';
      case 'primary_photo_embedding_failed':
        return 'Your profile photo couldn\'t be processed. Please update it.';
      case 'rate_limited':
        return 'You\'ve reached the verification attempt limit. Please try again later.';
      case 'session_expired':
        return 'Your session expired. Please sign in again.';
      case 'internal_error':
      default:
        return 'Verification is temporarily unavailable. Please try again later.';
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: kIsWeb ? Colors.black : Colors.transparent,
      body: SafeArea(
        child: Stack(
          children: [
            _buildBody(),
            if (!_loading && !_notFound)
              Positioned(
                left: 20,
                right: 20,
                bottom: 20,
                child: _SavePrivacyButton(
                  enabled: _isDirty,
                  loading: _saving,
                  onTap: _save,
                ),
              ),
            AnimatedSwitcher(
              duration: const Duration(milliseconds: 500),
              switchInCurve: Curves.easeOutCubic,
              switchOutCurve: Curves.easeInOutCubic,
              child: _saved
                  ? const SaveSuccessOverlay(message: 'Privacy updated')
                  : const SizedBox.shrink(),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildBody() {
    if (_loading) {
      return const Center(
        child: CircularProgressIndicator(color: Color(0xFF8B5CF6)),
      );
    }
    if (_notFound) {
      return _EmptyState(onBack: () => Navigator.of(context).maybePop());
    }
    return _buildForm();
  }

  Widget _buildForm() {
    return ListView(
      physics: const BouncingScrollPhysics(
        parent: AlwaysScrollableScrollPhysics(),
      ),
      padding: const EdgeInsets.fromLTRB(20, 8, 20, 100),
      children: [
        _header(),
        const SizedBox(height: 8),
        EntranceFade(
          child: PrivacySection(
            visibility: _visibility,
            onVisibilityChanged: _onVisibilityChanged,
          ),
        ),
        const SizedBox(height: 28),
        EntranceFade(
          child: VerificationSection(
            status: _verificationStatus,
            onVerifyIdentity: _onVerifyIdentity,
            verifying: _verifying,
          ),
        ),
      ],
    );
  }

  Widget _header() {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        children: [
          IconButton(
            onPressed: () => Navigator.of(context).maybePop(),
            icon: const Icon(Icons.arrow_back_rounded),
            tooltip: 'Back',
          ),
          const SizedBox(width: 4),
          const Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Privacy & Verification',
                  style: TextStyle(
                    fontSize: 24,
                    fontWeight: FontWeight.w800,
                    letterSpacing: -0.5,
                  ),
                ),
                SizedBox(height: 4),
                Text(
                  'Control your visibility and trust.',
                  style: TextStyle(fontSize: 14, color: Color(0xFFB9C3DC)),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

// ── Save button (gradient CTA with press feedback) ──────────────────────────

class _SavePrivacyButton extends StatefulWidget {
  const _SavePrivacyButton({
    required this.enabled,
    required this.loading,
    required this.onTap,
  });

  final bool enabled;
  final bool loading;
  final VoidCallback onTap;

  @override
  State<_SavePrivacyButton> createState() => _SavePrivacyButtonState();
}

class _SavePrivacyButtonState extends State<_SavePrivacyButton> {
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
              gradient: const LinearGradient(
                colors: [Color(0xFF8B5CF6), Color(0xFF587BE2)],
              ),
              borderRadius: BorderRadius.circular(16),
              boxShadow: active
                  ? [
                      BoxShadow(
                        color: const Color(0xFF8B5CF6).withValues(alpha: .5),
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
                    'Save changes',
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

// ── Empty state (no saved profile) ──────────────────────────────────────────

class _EmptyState extends StatelessWidget {
  const _EmptyState({required this.onBack});

  final VoidCallback onBack;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: EntranceFade(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 32),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(
                Icons.privacy_tip_outlined,
                size: 56,
                color: Color(0xFFB9C3DC),
              ),
              const SizedBox(height: 16),
              const Text(
                'No profile yet',
                style: TextStyle(fontSize: 20, fontWeight: FontWeight.w800),
              ),
              const SizedBox(height: 8),
              const Text(
                'Create your profile first to manage privacy and verification.',
                textAlign: TextAlign.center,
                style: TextStyle(fontSize: 14, color: Color(0xFFB9C3DC)),
              ),
              const SizedBox(height: 20),
              FilledButton(
                onPressed: onBack,
                style: FilledButton.styleFrom(
                  backgroundColor: const Color(0xFF8B5CF6),
                ),
                child: const Text('Go back'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ── Route (matches Conexo's premium fade + slide transition) ────────────────

/// Premium route into the Privacy & Verification module.
///
/// Uses the same fade + slide transition language as the other Profile routes
/// for a consistent feel across Conexo.
Route<void> premiumPrivacyVerificationRoute({ProfileRepository? repository}) {
  return PageRouteBuilder<void>(
    transitionDuration: const Duration(milliseconds: 420),
    reverseTransitionDuration: const Duration(milliseconds: 320),
    pageBuilder: (context, animation, secondaryAnimation) =>
        PrivacyVerificationScreen(
      repository: repository ?? const SessionAwareProfileRepository(),
    ),
    transitionsBuilder: (context, animation, secondaryAnimation, child) {
      final curved = CurvedAnimation(
        parent: animation,
        curve: Curves.easeOutCubic,
        reverseCurve: Curves.easeInOutCubic,
      );
      return FadeTransition(
        opacity: curved,
        child: SlideTransition(
          position: Tween<Offset>(
            begin: const Offset(0, 0.04),
            end: Offset.zero,
          ).animate(curved),
          child: child,
        ),
      );
    },
  );
}
