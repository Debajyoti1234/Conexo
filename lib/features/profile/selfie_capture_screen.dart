import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';

import '../../core/services/image_normalizer.dart';
import '../../core/services/permission_manager.dart';

class SelfieCaptureScreen extends StatefulWidget {
  const SelfieCaptureScreen({super.key});

  @override
  State<SelfieCaptureScreen> createState() => _SelfieCaptureScreenState();
}

class _SelfieCaptureScreenState extends State<SelfieCaptureScreen> {
  bool _capturing = false;
  String? _permissionError;

  @override
  void initState() {
    super.initState();
    _checkPermission();
  }

  Future<void> _checkPermission() async {
    if (kIsWeb) return;
    final status = await PermissionManager.check(PermissionType.camera);
    if (!mounted) return;
    if (status == PermissionStatus.permanentlyDenied) {
      setState(() => _permissionError = 'permanentlyDenied');
    } else if (status != PermissionStatus.granted) {
      final result = await PermissionManager.request(PermissionType.camera);
      if (!mounted) return;
      if (result != PermissionStatus.granted) {
        setState(() => _permissionError = 'denied');
      }
    }
  }

  Future<void> _capture() async {
    if (_capturing) return;
    setState(() {
      _capturing = true;
      _permissionError = null;
    });

    try {
      print('[SelfieCapture] step=capture-start platform=${kIsWeb ? "web" : "mobile"}');
      final picker = ImagePicker();
      final xfile = await picker.pickImage(
        source: ImageSource.camera,
        preferredCameraDevice: CameraDevice.front,
      );
      print('[SelfieCapture] step=picker-result xfile=${xfile != null} name=${xfile?.name ?? "null"}');

      if (!mounted) return;
      if (xfile == null) {
        Navigator.of(context).pop(null);
        return;
      }

      if (kDebugMode) {
        // Temporary diagnostic trace for the iOS Safari selfie transport.
        // Captures the ORIGINAL browser/camera representation so it can be
        // compared against what is finally sent in the multipart request.
        // ignore: avoid_print
        print('[FaceVerificationWebTrace] step=source-file-received');
        // ignore: avoid_print
        print('[FaceVerificationWebTrace] step=source-filename value=${xfile.name}');
        // ignore: avoid_print
        print('[FaceVerificationWebTrace] step=source-mime value=${xfile.mimeType}');
      }

      final bytes = await xfile.readAsBytes();
      if (kDebugMode) {
        // ignore: avoid_print
        print('[FaceVerificationWebTrace] step=source-byte-length value=${bytes.length}');
      }
      print('[SelfieCapture] step=bytes-read length=${bytes.length}');
      if (!mounted) return;

      final extension = xfile.name.contains('.')
          ? xfile.name.split('.').last.toLowerCase()
          : '';
      final allowed = <String>{'jpg', 'jpeg', 'png', 'webp', 'heic', 'heif'};
      if (extension.isNotEmpty && !allowed.contains(extension)) {
        print('[SelfieCapture] step=validation-failed reason=invalid_file_type extension=$extension');
        if (!mounted) return;
        Navigator.of(context).pop(
          const SelfieCaptureResult.error('invalid_file_type'),
        );
        return;
      }

      final normalized = await ConexoImageNormalizer.normalize(bytes);
      print(
        '[SelfieCapture] step=normalized original=${bytes.length} '
        'normalized=${normalized.bytes.length}',
      );

      const maxSize = 5 * 1024 * 1024;
      if (normalized.bytes.length > maxSize) {
        print('[SelfieCapture] step=validation-failed reason=file_too_large');
        if (!mounted) return;
        Navigator.of(context).pop(
          const SelfieCaptureResult.error('file_too_large'),
        );
        return;
      }

      print('[SelfieCapture] step=pop-success bytes=${normalized.bytes.length}');
      Navigator.of(context).pop(SelfieCaptureResult.success(normalized.bytes));
    } catch (e) {
      print('[SelfieCapture] step=capture-error error=$e');
      if (!mounted) return;
      Navigator.of(context).pop(
        const SelfieCaptureResult.error('capture_failed'),
      );
    } finally {
      if (mounted) {
        setState(() => _capturing = false);
      }
    }
  }

  Future<void> _openSettings() async {
    await PermissionManager.openAppSettings();
    if (!mounted) return;
    await _checkPermission();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF0A0F1F),
      body: SafeArea(
        child: Stack(
          children: [
            Column(
              children: [
                Expanded(
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 24),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        const Text(
                          'Verify your identity',
                          style: TextStyle(
                            fontSize: 24,
                            fontWeight: FontWeight.w800,
                            letterSpacing: -0.5,
                          ),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          'Take a clear selfie to match your profile photo.',
                          style: const TextStyle(
                            fontSize: 14,
                            color: Color(0xFFB9C3DC),
                          ),
                          textAlign: TextAlign.center,
                        ),
                        const SizedBox(height: 48),
                        CustomPaint(
                          size: const Size(220, 220),
                          painter: _FaceOvalPainter(),
                        ),
                        const SizedBox(height: 24),
                        Text(
                          'Position your face inside the oval',
                          style: const TextStyle(
                            fontSize: 13,
                            color: Color(0xFFB9C3DC),
                          ),
                        ),
                        if (_permissionError != null) ...[
                          const SizedBox(height: 24),
                          Container(
                            padding: const EdgeInsets.all(16),
                            decoration: BoxDecoration(
                              color: const Color(0xFF182039).withValues(
                                alpha: .92,
                              ),
                              borderRadius: BorderRadius.circular(16),
                              border: Border.all(
                                color: Colors.white.withValues(alpha: .09),
                              ),
                            ),
                            child: Column(
                              children: [
                                const Icon(
                                  Icons.camera_alt_outlined,
                                  size: 28,
                                  color: Color(0xFFB9C3DC),
                                ),
                                const SizedBox(height: 10),
                                Text(
                                  _permissionError == 'permanentlyDenied'
                                      ? 'Camera permission was permanently denied.'
                                      : 'Camera permission is required to take a selfie.',
                                  style: const TextStyle(
                                    fontSize: 13,
                                    color: Color(0xFFB9C3DC),
                                  ),
                                  textAlign: TextAlign.center,
                                ),
                                const SizedBox(height: 12),
                                FilledButton(
                                  onPressed: _openSettings,
                                  style: FilledButton.styleFrom(
                                    backgroundColor: const Color(0xFF8B5CF6),
                                  ),
                                  child: const Text('Open Settings'),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ],
                    ),
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.fromLTRB(24, 0, 24, 32),
                  child: Row(
                    children: [
                      Expanded(
                        child: _SelfieActionButton(
                          label: 'Cancel',
                          onTap: () => Navigator.of(context).pop(null),
                          backgroundColor: Colors.white.withValues(alpha: .08),
                          foregroundColor: const Color(0xFFEAEEF9),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: _SelfieActionButton(
                          label: _capturing ? 'Capturing...' : 'Take Selfie',
                          onTap: _permissionError == null ? _capture : null,
                          backgroundColor: const Color(0xFF8B5CF6),
                          foregroundColor: Colors.white,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            Positioned(
              top: 12,
              left: 12,
              child: IconButton(
                onPressed: () => Navigator.of(context).pop(null),
                style: IconButton.styleFrom(
                  backgroundColor: Colors.black.withValues(alpha: .35),
                ),
                icon: const Icon(
                  Icons.arrow_back_rounded,
                  color: Colors.white,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _SelfieActionButton extends StatelessWidget {
  const _SelfieActionButton({
    required this.label,
    required this.onTap,
    required this.backgroundColor,
    required this.foregroundColor,
  });

  final String label;
  final VoidCallback? onTap;
  final Color backgroundColor;
  final Color foregroundColor;

  @override
  Widget build(BuildContext context) {
    final active = onTap != null;
    return GestureDetector(
      onTap: active ? onTap : null,
      child: AnimatedOpacity(
        duration: const Duration(milliseconds: 200),
        opacity: active ? 1 : 0.5,
        child: Container(
          height: 54,
          alignment: Alignment.center,
          decoration: BoxDecoration(
            color: backgroundColor,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(
              color: Colors.white.withValues(alpha: .1),
            ),
          ),
          child: Text(
            label,
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w800,
              color: foregroundColor,
            ),
          ),
        ),
      ),
    );
  }
}

class _FaceOvalPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final paint = Paint()
      ..color = Colors.white.withValues(alpha: .12)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2;
    canvas.drawOval(
      Rect.fromCenter(center: center, width: size.width * 0.7, height: size.height * 0.85),
      paint,
    );

    final glowPaint = Paint()
      ..color = const Color(0xFF8B5CF6).withValues(alpha: .18)
      ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 18);
    canvas.drawOval(
      Rect.fromCenter(center: center, width: size.width * 0.7, height: size.height * 0.85),
      glowPaint,
    );
  }

  @override
  bool shouldRepaint(_FaceOvalPainter oldDelegate) => false;
}

class SelfieCaptureResult {
  const SelfieCaptureResult._({required this.bytes, required this.reason});

  const SelfieCaptureResult.success(Uint8List bytes)
      : this._(bytes: bytes, reason: null);

  const SelfieCaptureResult.error(String reason)
      : this._(bytes: null, reason: reason);

  final Uint8List? bytes;
  final String? reason;
}
