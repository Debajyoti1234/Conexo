import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';

import '../../../app/theme/app_theme.dart';
import '../../../core/services/image_normalizer.dart';
import '../privacy_verification_screen.dart';
import 'manual_verification_service.dart';
import 'verification_status_view.dart';
import 'verification_theme.dart';

class ManualVerificationScreen extends StatefulWidget {
  const ManualVerificationScreen({super.key});

  @override
  State<ManualVerificationScreen> createState() =>
      _ManualVerificationScreenState();
}

class _ManualVerificationScreenState extends State<ManualVerificationScreen> {
  final ManualVerificationService _service = const ManualVerificationService();
  final ImagePicker _picker = ImagePicker();

  Uint8List? _selfieBytes;
  Uint8List? _idFrontBytes;
  Uint8List? _idBackBytes;

  ManualVerificationRequest? _pendingRequest;
  ManualVerificationStage _stage = ManualVerificationStage.idle;
  bool _hasExisting = false;
  bool _busy = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    _checkExisting();
  }

  Future<void> _checkExisting() async {
    if (_hasExisting) return;
    setState(() => _stage = ManualVerificationStage.checking);
    try {
      final existing = await _service.checkExistingPending();
      if (!mounted) return;
      if (existing != null) {
        setState(() {
          _pendingRequest = existing;
          _hasExisting = true;
          _stage = ManualVerificationStage.idle;
        });
      } else {
        setState(() => _stage = ManualVerificationStage.idle);
      }
    } catch (_) {
      if (!mounted) return;
      setState(() => _stage = ManualVerificationStage.idle);
    }
  }

  Future<void> _pickImage(String target) async {
    if (_busy) return;
    final source = target == 'selfie'
        ? ImageSource.camera
        : ImageSource.gallery;

    try {
      final xfile = await _picker.pickImage(
        source: source,
        preferredCameraDevice: CameraDevice.front,
        maxWidth: 1024,
        maxHeight: 1024,
        imageQuality: 85,
      );
      if (xfile == null) return;

      final raw = await xfile.readAsBytes();
      final normalized = await ConexoImageNormalizer.normalize(raw);

      setState(() {
        switch (target) {
          case 'selfie':
            _selfieBytes = normalized.bytes;
          case 'idFront':
            _idFrontBytes = normalized.bytes;
          case 'idBack':
            _idBackBytes = normalized.bytes;
        }
        _error = null;
      });
    } catch (e) {
      setState(() => _error = 'Could not process that image. Please try again.');
    }
  }

  bool get _canSubmit =>
      _selfieBytes != null &&
      _idFrontBytes != null &&
      _stage != ManualVerificationStage.submitting &&
      _stage != ManualVerificationStage.uploading;

  Future<void> _submit() async {
    if (!_canSubmit) return;
    setState(() {
      _busy = true;
      _stage = ManualVerificationStage.uploading;
      _error = null;
    });

    try {
      final request = await _service.submit(
        selfieBytes: _selfieBytes!,
        idFrontBytes: _idFrontBytes!,
        idBackBytes: _idBackBytes,
      );

      if (!mounted) return;
      if (request != null) {
        setState(() {
          _stage = ManualVerificationStage.done;
          _pendingRequest = request;
          _busy = false;
        });
      } else {
        setState(() {
          _stage = ManualVerificationStage.idle;
          _busy = false;
          _error = 'Submission failed. Please try again.';
        });
      }
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _stage = ManualVerificationStage.idle;
        _busy = false;
        _error = 'Submission failed. Please check your connection and try again.';
      });
    }
  }

  void _backToConexo() {
    Navigator.of(context).pushReplacement(
      premiumPrivacyVerificationRoute(),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: context.cxCanvas,
      body: SafeArea(
        child: _buildBody(),
      ),
    );
  }

  Widget _buildBody() {
    if (_stage == ManualVerificationStage.checking) {
      return _buildChecking();
    }
    if (_hasExisting && _pendingRequest != null && _stage != ManualVerificationStage.done) {
      return _buildPendingState();
    }
    if (_stage == ManualVerificationStage.done) {
      return _buildSuccess();
    }
    return _buildSubmissionForm();
  }

  Widget _buildChecking() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const VerifyingIndicator(size: 72),
          const SizedBox(height: 20),
          Text(
            'Checking your status',
            style: TextStyle(
              fontSize: 18,
              fontFamily: 'Fraunces',
              fontWeight: FontWeight.w600,
              color: context.cxInk,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            'Please wait…',
            style: TextStyle(
              fontSize: 14,
              color: context.cxSoft,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPendingState() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 32),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            VerifyGlowBadge(
              size: 92,
              colors: [
                const Color(0xFFC98A1E),
                const Color(0xFFC98A1E),
              ],
              glowColor: const Color(0xFFC98A1E),
              glowStrength: .4,
              child: VerifyGlyph(
                VerifyAsset.shieldCheck,
                size: 40,
                color: context.cxInk,
              ),
            ),
            const SizedBox(height: 24),
            Text(
              'Already submitted',
              style: TextStyle(
                fontSize: 24,
                fontFamily: 'Fraunces',
                fontWeight: FontWeight.w600,
                color: context.cxInk,
              ),
            ),
            const SizedBox(height: 10),
            Text(
              'Your verification request is under review. It will take 24–72 hours.',
              style: TextStyle(
                fontSize: 14,
                height: 1.5,
                color: context.cxSoft,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 32),
            VerifyCta(
              label: 'Back to Conexo',
              onTap: _backToConexo,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSubmissionForm() {
    return Column(
      children: [
        Expanded(
          child: SingleChildScrollView(
            padding: const EdgeInsets.fromLTRB(24, 16, 24, 16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _buildHeader(),
                const SizedBox(height: 20),
                _buildPrivacyNotice(),
                const SizedBox(height: 28),
                _buildSectionTitle('Selfie'),
                const SizedBox(height: 12),
                _buildDocumentCard(
                  label: 'Selfie',
                  subtitle: 'Take a clear photo of your face',
                  imageBytes: _selfieBytes,
                  onTap: () => _pickImage('selfie'),
                  asset: VerifyAsset.faceFront,
                ),
                const SizedBox(height: 20),
                _buildSectionTitle('National ID'),
                const SizedBox(height: 12),
                _buildDocumentCard(
                  label: 'Front',
                  subtitle: 'Aadhaar, Passport, Voter ID, or Licence',
                  imageBytes: _idFrontBytes,
                  onTap: () => _pickImage('idFront'),
                  asset: VerifyAsset.shieldFace,
                ),
                const SizedBox(height: 12),
                _buildDocumentCard(
                  label: 'Back',
                  subtitle: 'Optional — where applicable',
                  imageBytes: _idBackBytes,
                  onTap: () => _pickImage('idBack'),
                  asset: VerifyAsset.shieldCheck,
                ),
                if (_error != null) ...[
                  const SizedBox(height: 16),
                  Container(
                    padding: const EdgeInsets.all(14),
                    decoration: BoxDecoration(
                      color: context.cxDanger.withValues(alpha: .1),
                      borderRadius: BorderRadius.circular(14),
                      border: Border.all(
                        color: context.cxDanger.withValues(alpha: .3),
                      ),
                    ),
                    child: Row(
                      children: [
                        Icon(
                          Icons.error_outline,
                          size: 18,
                          color: context.cxDanger,
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Text(
                            _error!,
                            style: TextStyle(
                              fontSize: 13,
                              color: context.cxDanger,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
                const SizedBox(height: 32),
                Center(
                  child: SizedBox(
                    width: double.infinity,
                    child: VerifyCta(
                      label: 'Submit for Review',
                      icon: Icons.send_outlined,
                      loading: _stage == ManualVerificationStage.uploading,
                      enabled: _canSubmit,
                      onTap: _canSubmit ? _submit : null,
                    ),
                  ),
                ),
                const SizedBox(height: 8),
                if (_selfieBytes == null || _idFrontBytes == null)
                  Center(
                    child: Text(
                      'A selfie and National ID front are required',
                      style: TextStyle(
                        fontSize: 12,
                        color: context.cxMuted,
                      ),
                    ),
                  ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildHeader() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Manual Verification',
          style: TextStyle(
            fontSize: 28,
            fontFamily: 'Fraunces',
            fontWeight: FontWeight.w600,
            letterSpacing: -0.5,
            color: context.cxInk,
          ),
        ),
        const SizedBox(height: 6),
        Text(
          'Provide your documents for review',
          style: TextStyle(
            fontSize: 15,
            color: context.cxSoft,
          ),
        ),
      ],
    );
  }

  Widget _buildPrivacyNotice() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: context.cxAccent.withValues(alpha: .08),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: context.cxAccent.withValues(alpha: .2),
        ),
      ),
      child: Row(
        children: [
          Container(
            height: 36,
            width: 36,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: context.cxAccent.withValues(alpha: .15),
            ),
            child: VerifyGlyph(
              VerifyAsset.privacy,
              size: 18,
              color: context.cxAccentSoft,
            ),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Your documents are secure',
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w700,
                    color: context.cxInk,
                  ),
                ),
                const SizedBox(height: 3),
                Text(
                  'Documents are used only for identity verification and are stored privately.',
                  style: TextStyle(
                    fontSize: 12.5,
                    height: 1.4,
                    color: context.cxSoft,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSectionTitle(String title) {
    return Text(
      title,
      style: TextStyle(
        fontSize: 15,
        fontWeight: FontWeight.w700,
        color: context.cxInk,
      ),
    );
  }

  Widget _buildDocumentCard({
    required String label,
    required String subtitle,
    Uint8List? imageBytes,
    required VoidCallback onTap,
    required String asset,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: imageBytes != null
                ? context.cxAccent.withValues(alpha: .3)
                : context.cxLine,
          ),
          color: context.cxSurface.withValues(alpha: .5),
        ),
        child: Row(
          children: [
            Container(
              height: 72,
              width: 72,
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(14),
                color: context.cxCanvas,
                border: Border.all(
                  color: context.cxLine,
                ),
              ),
              child: imageBytes != null
                  ? ClipRRect(
                      borderRadius: BorderRadius.circular(12),
                      child: Image.memory(
                        imageBytes,
                        fit: BoxFit.cover,
                      ),
                    )
                  : Center(
                      child: VerifyGlyph(
                        asset,
                        size: 28,
                        color: context.cxMuted,
                      ),
                    ),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    label,
                    style: TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.w700,
                      color: context.cxInk,
                    ),
                  ),
                  const SizedBox(height: 3),
                  Text(
                    imageBytes != null
                        ? 'Captured'
                        : subtitle,
                    style: TextStyle(
                      fontSize: 13,
                      color: imageBytes != null
                          ? context.cxSuccess
                          : context.cxSoft,
                    ),
                  ),
                ],
              ),
            ),
            Container(
              height: 32,
              width: 32,
              alignment: Alignment.center,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: context.cxAccent.withValues(alpha: .1),
              ),
              child: Icon(
                imageBytes != null
                    ? Icons.check_circle_rounded
                    : Icons.camera_alt_rounded,
                size: 18,
                color: imageBytes != null
                    ? context.cxSuccess
                    : context.cxAccentSoft,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSuccess() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 32),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            VerifyGlowBadge(
              size: 104,
              colors: [
                context.cxSuccess,
                context.cxSuccess,
              ],
              glowColor: context.cxSuccess,
              glowStrength: .5,
              child: VerifyGlyph(
                VerifyAsset.shieldCheck,
                size: 48,
                color: context.cxInk,
              ),
            ),
            const SizedBox(height: 28),
            Text(
              'We are reviewing\nyour status.',
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 26,
                fontFamily: 'Fraunces',
                fontWeight: FontWeight.w600,
                height: 1.25,
                letterSpacing: -0.3,
                color: context.cxInk,
              ),
            ),
            const SizedBox(height: 14),
            Text(
              'It will take 24–72 hours.',
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 15,
                color: context.cxSoft,
              ),
            ),
            const SizedBox(height: 40),
            SizedBox(
              width: double.infinity,
              child: VerifyCta(
                label: 'Back to Conexo',
                onTap: _backToConexo,
              ),
            ),
          ],
        ),
      ),
    );
  }

  @override
  void dispose() {
    super.dispose();
  }
}