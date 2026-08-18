import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';

import '../../../core/services/image_normalizer.dart';
import '../../../core/supabase/auth_service.dart';
import '../face_verification_client.dart';
import 'verification_components.dart';
import 'verification_status_view.dart';
import 'verification_theme.dart';

/// Orchestrates the premium three-angle capture + verification experience.
///
/// Capture uses `image_picker` (the proven, iOS-Safari-safe path). Upload uses
/// [FaceVerificationClient.verifyFaceMulti] — the same `package:http`
/// multipart transport as the single-photo flow. Pops `true` when verified.
class ThreeAngleCaptureScreen extends StatefulWidget {
  const ThreeAngleCaptureScreen({
    super.key,
    this.client = const FaceVerificationClient(),
  });

  final FaceVerificationClient client;

  @override
  State<ThreeAngleCaptureScreen> createState() =>
      _ThreeAngleCaptureScreenState();
}

enum _Phase { capture, processing, verified, failed, tips }

class _ThreeAngleCaptureScreenState extends State<ThreeAngleCaptureScreen> {
  static const _maxBytes = 5 * 1024 * 1024;
  static const _allowedExt = {'jpg', 'jpeg', 'png', 'webp', 'heic', 'heif'};

  final Map<VerifyAngle, Uint8List> _captures = {};
  VerifyAngle _current = VerifyAngle.front;
  _Phase _phase = _Phase.capture;
  bool _busy = false;
  String? _notice;
  String _failSubtitle =
      "We couldn't confidently match your\nverification photos.";

  bool get _currentCaptured => _captures[_current] != null;

  Future<void> _capture() async {
    if (_busy) return;
    setState(() {
      _busy = true;
      _notice = null;
    });
    try {
      final picker = ImagePicker();
      final xfile = await picker.pickImage(
        source: ImageSource.camera,
        preferredCameraDevice: CameraDevice.front,
      );
      if (xfile == null) return; // cancelled — stay on the aim view

      final raw = await xfile.readAsBytes();
      final ext = xfile.name.contains('.')
          ? xfile.name.split('.').last.toLowerCase()
          : '';
      if (ext.isNotEmpty && !_allowedExt.contains(ext)) {
        _setNotice('That file type isn\'t supported. Please use the camera.');
        return;
      }

      final normalized = await ConexoImageNormalizer.normalize(raw);
      if (normalized.bytes.length > _maxBytes) {
        _setNotice('That photo is too large. Please try again.');
        return;
      }

      if (!mounted) return;
      setState(() => _captures[_current] = normalized.bytes);
    } catch (_) {
      _setNotice('Couldn\'t capture that photo. Please try again.');
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  void _setNotice(String message) {
    if (!mounted) return;
    setState(() => _notice = message);
  }

  void _retakeCurrent() {
    setState(() {
      _captures.remove(_current);
      _notice = null;
    });
  }

  void _continueFromCapture() {
    if (_current == VerifyAngle.right) {
      _startVerification();
      return;
    }
    setState(() {
      _current = VerifyAngle.values[_current.index + 1];
      _notice = null;
    });
  }

  Future<void> _startVerification() async {
    setState(() => _phase = _Phase.processing);

    final token = AuthService.currentSession?.accessToken;
    if (token == null || token.isEmpty) {
      _toFailed('Your session expired. Please sign in again.');
      return;
    }

    try {
      final result = await widget.client.verifyFaceMulti(
        frontBytes: _captures[VerifyAngle.front]!,
        leftBytes: _captures[VerifyAngle.left]!,
        rightBytes: _captures[VerifyAngle.right]!,
        accessToken: token,
      );
      if (!mounted) return;
      if (result.match) {
        setState(() => _phase = _Phase.verified);
      } else {
        _toFailed(_mapReason(result.reason, result.angle));
      }
    } on FaceVerificationException catch (e) {
      _toFailed(e.message);
    } catch (_) {
      _toFailed(
        'Verification is temporarily unavailable. Please try again later.',
      );
    }
  }

  void _toFailed(String subtitle) {
    if (!mounted) return;
    setState(() {
      _phase = _Phase.failed;
      _failSubtitle = subtitle;
    });
  }

  void _retryAll() {
    setState(() {
      _captures.clear();
      _current = VerifyAngle.front;
      _phase = _Phase.capture;
      _notice = null;
    });
  }

  String _mapReason(String reason, String? angle) {
    final where = switch (angle) {
      'front' => ' on the front view',
      'left' => ' on the left view',
      'right' => ' on the right view',
      _ => '',
    };
    switch (reason) {
      case 'no_face':
        return 'We couldn\'t detect a face$where.\nPlease try again in good lighting.';
      case 'multiple_faces':
        return 'More than one face was visible$where.\nMake sure only you are in frame.';
      case 'low_similarity':
        return "We couldn't confidently match your\nverification photos.";
      case 'no_primary_photo':
        return 'Please add a profile photo before verifying.';
      case 'invalid_primary_photo':
      case 'primary_photo_embedding_failed':
        return 'Your profile photo couldn\'t be processed.\nPlease update it and try again.';
      case 'invalid_image':
      case 'invalid_file_type':
        return 'One of your photos couldn\'t be read.\nPlease try again.';
      case 'file_too_large':
        return 'One of your photos was too large.\nPlease try again.';
      case 'rate_limited':
        return 'You\'ve reached the attempt limit.\nPlease try again later.';
      case 'session_expired':
        return 'Your session expired.\nPlease sign in again.';
      default:
        return 'Verification is temporarily unavailable.\nPlease try again later.';
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: VerifyColors.bgBottom,
      body: VerifyBackground(
        glow: _phase == _Phase.verified
            ? VerifyColors.verified
            : VerifyColors.accent,
        child: SafeArea(
          child: AnimatedSwitcher(
            duration: const Duration(milliseconds: 320),
            switchInCurve: Curves.easeOutCubic,
            switchOutCurve: Curves.easeInOutCubic,
            child: _buildPhase(),
          ),
        ),
      ),
    );
  }

  Widget _buildPhase() {
    switch (_phase) {
      case _Phase.capture:
        return KeyedSubtree(
          key: ValueKey('capture_${_current}_$_currentCaptured'),
          child: _currentCaptured ? _capturedConfirm() : _aimView(),
        );
      case _Phase.processing:
        return const KeyedSubtree(
          key: ValueKey('processing'),
          child: _ProcessingView(),
        );
      case _Phase.verified:
        return KeyedSubtree(
          key: const ValueKey('verified'),
          child: VerifySuccessView(
            onContinue: () => Navigator.of(context).pop(true),
          ),
        );
      case _Phase.failed:
        return KeyedSubtree(
          key: const ValueKey('failed'),
          child: VerifyFailedView(
            subtitle: _failSubtitle,
            onRetry: _retryAll,
            onReviewTips: () => setState(() => _phase = _Phase.tips),
          ),
        );
      case _Phase.tips:
        return KeyedSubtree(
          key: const ValueKey('tips'),
          child: Padding(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 20),
            child: VerifyTipsView(
              onGotIt: () => setState(() => _phase = _Phase.failed),
              onBack: () => setState(() => _phase = _Phase.failed),
            ),
          ),
        );
    }
  }

  // ── Aim view (screens 4/6/7) ───────────────────────────────────────────────

  Widget _aimView() {
    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(12, 8, 12, 0),
          child: VerifyTopBar(
            onClose: () => Navigator.of(context).maybePop(),
            center: VerifyStepPill(label: '${_current.label} • ${_current.step} OF 3'),
          ),
        ),
        Expanded(
          child: ListView(
            physics: const BouncingScrollPhysics(),
            padding: const EdgeInsets.fromLTRB(24, 8, 24, 8),
            children: [
              Text(
                _current.title,
                textAlign: TextAlign.center,
                style: const TextStyle(
                  fontSize: 24,
                  height: 1.2,
                  fontWeight: FontWeight.w800,
                  letterSpacing: -0.5,
                  color: VerifyColors.text,
                ),
              ),
              const SizedBox(height: 20),
              VerifyGuideFrame(
                child: VerifyGuidePlaceholder(angle: _current),
              ),
              const SizedBox(height: 20),
              const _IndicatorRow(),
              if (_notice != null) ...[
                const SizedBox(height: 16),
                _NoticeText(_notice!),
              ],
            ],
          ),
        ),
        Padding(
          padding: const EdgeInsets.fromLTRB(24, 4, 24, 22),
          child: _ShutterButton(busy: _busy, onTap: _capture),
        ),
      ],
    );
  }

  // ── Captured confirmation (screen 5) ────────────────────────────────────────

  Widget _capturedConfirm() {
    final isLast = _current == VerifyAngle.right;
    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(12, 8, 12, 0),
          child: VerifyTopBar(onClose: () => Navigator.of(context).maybePop()),
        ),
        Expanded(
          child: ListView(
            physics: const BouncingScrollPhysics(),
            padding: const EdgeInsets.fromLTRB(24, 0, 24, 8),
            children: [
              const SizedBox(height: 4),
              const Center(
                child: VerifyGlowBadge(
                  size: 92,
                  colors: [VerifyColors.verified, VerifyColors.verified2],
                  glowColor: VerifyColors.verified,
                  glowStrength: .5,
                  child:
                      Icon(Icons.check_rounded, size: 44, color: Colors.white),
                ),
              ),
              const SizedBox(height: 20),
              Text(
                'Great!\n${_current.label.substring(0, 1)}${_current.label.substring(1).toLowerCase()} view captured',
                textAlign: TextAlign.center,
                style: const TextStyle(
                  fontSize: 22,
                  height: 1.25,
                  fontWeight: FontWeight.w800,
                  letterSpacing: -0.4,
                  color: VerifyColors.text,
                ),
              ),
              const SizedBox(height: 24),
              for (final a in VerifyAngle.values) ...[
                VerifyAngleProgressCard(
                  angle: a,
                  captured: _captures[a] != null,
                  thumbnail: _captures[a],
                  active: a == _current,
                ),
                if (a != VerifyAngle.right) const SizedBox(height: 10),
              ],
            ],
          ),
        ),
        Padding(
          padding: const EdgeInsets.fromLTRB(24, 4, 24, 22),
          child: Row(
            children: [
              Expanded(
                flex: 2,
                child: _SecondaryButton(
                  label: 'Retake',
                  onTap: _retakeCurrent,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                flex: 3,
                child: VerifyCta(
                  label: isLast ? 'Verify' : 'Continue',
                  onTap: _continueFromCapture,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

// ── Processing (screen 8) ────────────────────────────────────────────────────

class _ProcessingView extends StatelessWidget {
  const _ProcessingView();

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(24, 24, 24, 28),
      // Force the processing content to the full available width (minus the
      // existing 24px side padding). Without this, the Column receives loose
      // width from the AnimatedSwitcher's centered Stack and collapses to its
      // widest text line (~70%), leaving ~30% blank. Height is unchanged.
      child: SizedBox(
        width: double.infinity,
        child: Column(
          children: [
            const Spacer(),
            const VerifyingIndicator(size: 104),
            const SizedBox(height: 30),
            const Text(
              'All set!',
              style: TextStyle(
                fontSize: 26,
                fontWeight: FontWeight.w800,
                letterSpacing: -0.5,
                color: VerifyColors.text,
              ),
            ),
            const SizedBox(height: 10),
            const Text(
              "We're reviewing your photos.\nThis may take a few seconds — please\ndon't close the app.",
              textAlign: TextAlign.center,
              style:
                  TextStyle(fontSize: 14, height: 1.5, color: VerifyColors.soft),
            ),
            const Spacer(),
          ],
        ),
      ),
    );
  }
}

// ── Small building blocks ────────────────────────────────────────────────────

class _IndicatorRow extends StatelessWidget {
  const _IndicatorRow();

  @override
  Widget build(BuildContext context) {
    return VerifyGlass(
      radius: 18,
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 14),
      child: const Row(
        children: [
          Expanded(
            child: VerifyIndicatorChip(
              asset: VerifyAsset.lighting,
              label: 'Good lighting',
            ),
          ),
          Expanded(
            child: VerifyIndicatorChip(
              asset: VerifyAsset.distance,
              label: '3–4 ft distance',
            ),
          ),
          Expanded(
            child: VerifyIndicatorChip(
              asset: VerifyAsset.glasses,
              label: 'No glasses or mask',
            ),
          ),
        ],
      ),
    );
  }
}

class _NoticeText extends StatelessWidget {
  const _NoticeText(this.message);
  final String message;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        const Icon(Icons.info_outline_rounded,
            size: 16, color: VerifyColors.warn),
        const SizedBox(width: 8),
        Flexible(
          child: Text(
            message,
            textAlign: TextAlign.center,
            style: const TextStyle(fontSize: 12.5, color: VerifyColors.warn),
          ),
        ),
      ],
    );
  }
}

class _ShutterButton extends StatelessWidget {
  const _ShutterButton({required this.busy, required this.onTap});

  final bool busy;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: GestureDetector(
        onTap: busy ? null : onTap,
        child: Container(
          height: 78,
          width: 78,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            border: Border.all(
              color: Colors.white.withValues(alpha: .35),
              width: 3,
            ),
            boxShadow: [
              BoxShadow(
                color: VerifyColors.accent.withValues(alpha: .4),
                blurRadius: 26,
                spreadRadius: -2,
              ),
            ],
          ),
          child: Padding(
            padding: const EdgeInsets.all(6),
            child: Container(
              alignment: Alignment.center,
              decoration: const BoxDecoration(
                shape: BoxShape.circle,
                gradient: LinearGradient(
                  colors: [Colors.white, Color(0xFFE7E9F5)],
                ),
              ),
              child: busy
                  ? const SizedBox(
                      height: 24,
                      width: 24,
                      child: CircularProgressIndicator(
                        strokeWidth: 2.5,
                        color: VerifyColors.accent,
                      ),
                    )
                  : const Icon(Icons.camera_alt_rounded,
                      color: VerifyColors.accent, size: 26),
            ),
          ),
        ),
      ),
    );
  }
}

class _SecondaryButton extends StatelessWidget {
  const _SecondaryButton({required this.label, required this.onTap});

  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 56,
      child: TextButton(
        onPressed: onTap,
        style: TextButton.styleFrom(
          backgroundColor: Colors.white.withValues(alpha: .06),
          foregroundColor: VerifyColors.text,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
            side: BorderSide(color: VerifyColors.line),
          ),
        ),
        child: Text(
          label,
          style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w700),
        ),
      ),
    );
  }
}
