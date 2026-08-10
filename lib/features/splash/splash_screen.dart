import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../app/router/app_router.dart';
import '../../core/services/permission_manager.dart';
import '../../core/supabase/auth_service.dart';
import '../../core/supabase/auth_gate.dart';
import '../onboarding_screen.dart';

class SplashScreen extends StatefulWidget {
  const SplashScreen({super.key});

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;
  bool _showError = false;
  String? _errorMessage;

  static const _permissionsRequestedKey = 'conexo_permissions_requested_v1';

  @override
  void initState() {
    super.initState();
    _controller =
        AnimationController(
          vsync: this,
          duration: const Duration(milliseconds: 4700),
        )..addStatusListener((status) async {
          if (status == AnimationStatus.completed && mounted) {
            final hasSession = AuthService.currentSession != null;
            if (!mounted) return;

            if (!hasSession) {
              if (!mounted) return;
              Navigator.of(
                context,
              ).pushReplacement(AppRouter.slideRoute(const OnboardingScreen()));
              return;
            }

            await _ensureFirstLaunchPermissions();

            if (!mounted) return;
            final target = await AuthGate.navigateToTarget();
            if (!mounted) return;

            if (target == null) {
              setState(() {
                _showError = true;
                _errorMessage = 'Unable to load profile. Please check your connection and try again.';
              });
              return;
            }

            if (!mounted) return;
            Navigator.of(
              context,
            ).pushReplacement(AppRouter.slideRoute(target));
          }
        });
    _controller.forward();
  }

  Future<void> _ensureFirstLaunchPermissions() async {
    final prefs = await SharedPreferences.getInstance();
    final alreadyRequested = prefs.getBool(_permissionsRequestedKey) ?? false;
    if (alreadyRequested) return;

    const permissions = [
      PermissionType.camera,
      PermissionType.photos,
      PermissionType.locationWhenInUse,
      PermissionType.notifications,
      PermissionType.microphone,
    ];

    for (final permission in permissions) {
      final status = await PermissionManager.check(permission);
      if (status == PermissionStatus.granted) continue;

      if (status == PermissionStatus.permanentlyDenied) {
        if (!mounted) return;
        final open = await showDialog<bool>(
          context: context,
          builder: (context) => AlertDialog(
            title: Text('${_permissionLabel(permission)} Permission Required'),
            content: Text(
                '${_permissionLabel(permission)} permission is needed for core Conexo features. Please enable it in app settings.'),
            actions: [
              TextButton(
                  onPressed: () => Navigator.pop(context, false),
                  child: const Text('Cancel')),
              TextButton(
                  onPressed: () => Navigator.pop(context, true),
                  child: const Text('Open Settings')),
            ],
          ),
        );
        if (open == true) await PermissionManager.openAppSettings();
      } else {
        await PermissionManager.request(permission);
      }
    }

    await prefs.setBool(_permissionsRequestedKey, true);
  }

  String _permissionLabel(PermissionType type) {
    switch (type) {
      case PermissionType.camera:
        return 'Camera';
      case PermissionType.photos:
        return 'Photos/Media';
      case PermissionType.locationWhenInUse:
        return 'Location';
      case PermissionType.notifications:
        return 'Notifications';
      case PermissionType.microphone:
        return 'Microphone';
    }
  }

  void _retry() {
    setState(() {
      _showError = false;
      _errorMessage = null;
    });
    _controller.forward(from: 0);
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (_showError) {
      return Scaffold(
        body: Center(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Icon(Icons.wifi_off_rounded, size: 64, color: Colors.redAccent),
                const SizedBox(height: 24),
                Text(
                  _errorMessage ?? 'Something went wrong',
                  textAlign: TextAlign.center,
                  style: const TextStyle(fontSize: 16, color: Colors.white),
                ),
                const SizedBox(height: 24),
                ElevatedButton.icon(
                  onPressed: _retry,
                  icon: const Icon(Icons.refresh_rounded),
                  label: const Text('Retry'),
                ),
              ],
            ),
          ),
        ),
      );
    }

    return Scaffold(
      body: AnimatedBuilder(
        animation: _controller,
        builder: (context, _) {
          final progress = _controller.value;
          final navyOpacity = _interval(progress, 0.0, 0.085);
          final blobOpacity = _interval(progress, 0.17, 0.32);
          final particleOpacity = _interval(progress, 0.68, 0.75) * 0.08;
          final logoOpacity = _interval(progress, 0.255, 0.37);
          final logoScale = Tween<double>(begin: 0.85, end: 1).transform(
            Curves.easeOutCubic.transform(_interval(progress, 0.255, 0.37)),
          );
          final glowFade = _interval(progress, 0.383, 0.49);
          final pulse =
              (math.sin((progress * 4.7 - 1.8) * math.pi * 2 / 3) + 1) / 2;
          final glowOpacity = glowFade * (.16 + pulse * .05);
          final titleOpacity = _interval(progress, 0.49, 0.58);
          final titleOffset =
              16 * (1 - Curves.easeOutCubic.transform(titleOpacity));
          final taglineOpacity = _interval(progress, 0.596, 0.68) * 0.7;
          final exitOpacity = 1 - _interval(progress, 0.915, 1.0);
          final logoSize = math.min(
            180.0,
            MediaQuery.sizeOf(context).width * 0.56,
          );

          return Opacity(
            opacity: exitOpacity,
            child: Stack(
              fit: StackFit.expand,
              children: [
                const ColoredBox(color: Colors.black),
                Opacity(
                  opacity: navyOpacity,
                  child: const ColoredBox(color: Color(0xFF090B14)),
                ),
                RepaintBoundary(
                  child: CustomPaint(
                    painter: _AmbientBackgroundPainter(
                      progress: progress,
                      blobOpacity: blobOpacity,
                      particleOpacity: particleOpacity,
                    ),
                  ),
                ),
                SafeArea(
                  child: Center(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        SizedBox(
                          height: logoSize + 68,
                          width: logoSize + 68,
                          child: Stack(
                            alignment: Alignment.center,
                            children: [
                              Opacity(
                                opacity: glowOpacity,
                                child: Container(
                                  height: logoSize * .76,
                                  width: logoSize * .76,
                                  decoration: const BoxDecoration(
                                    shape: BoxShape.circle,
                                    boxShadow: [
                                      BoxShadow(
                                        color: Color(0xFF7C3AED),
                                        blurRadius: 54,
                                        spreadRadius: 12,
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                              Opacity(
                                opacity: logoOpacity,
                                child: Transform.scale(
                                  scale: logoScale,
                                  child: _LogoArtwork(size: logoSize),
                                ),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(height: 22),
                        Transform.translate(
                          offset: Offset(0, titleOffset),
                          child: Opacity(
                            opacity: titleOpacity,
                            child: const Text(
                              'Conexo',
                              style: TextStyle(
                                color: Colors.white,
                                fontSize: 42,
                                fontWeight: FontWeight.w700,
                                letterSpacing: 0.6,
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(height: 10),
                        Opacity(
                          opacity: taglineOpacity,
                          child: const Text(
                            'Meet • Connect • Explore',
                            style: TextStyle(
                              color: Colors.white,
                              fontSize: 16,
                              fontWeight: FontWeight.w500,
                              letterSpacing: 0.15,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          );
        },
      ),
    );
  }
}

class _LogoArtwork extends StatelessWidget {
  const _LogoArtwork({required this.size});

  final double size;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: size,
      width: size,
      child: Image.asset(
        'assets/logo/conexo_logo.png.png',
        fit: BoxFit.contain,
      ),
    );
  }
}

double _interval(double value, double begin, double end) {
  return Curves.easeInOut.transform(
    ((value - begin) / (end - begin)).clamp(0.0, 1.0),
  );
}

class _AmbientBackgroundPainter extends CustomPainter {
  const _AmbientBackgroundPainter({
    required this.progress,
    required this.blobOpacity,
    required this.particleOpacity,
  });

  final double progress;
  final double blobOpacity;
  final double particleOpacity;

  static const _particles = [
    Offset(0.08, 0.16),
    Offset(0.22, 0.72),
    Offset(0.36, 0.28),
    Offset(0.54, 0.13),
    Offset(0.67, 0.74),
    Offset(0.82, 0.29),
    Offset(0.92, 0.60),
    Offset(0.15, 0.48),
    Offset(0.43, 0.87),
    Offset(0.72, 0.48),
    Offset(0.29, 0.08),
    Offset(0.56, 0.62),
  ];

  @override
  void paint(Canvas canvas, Size size) {
    final time = progress * math.pi * 2;
    _paintBlob(
      canvas,
      size,
      Offset(
        size.width * (0.16 + math.sin(time * .35) * .05),
        size.height * .17,
      ),
      size.width * .56,
      const Color(0xFF7C3AED).withValues(alpha: .20 * blobOpacity),
    );
    _paintBlob(
      canvas,
      size,
      Offset(
        size.width * .86,
        size.height * (.72 + math.cos(time * .30) * .05),
      ),
      size.width * .62,
      const Color(0xFF22D3EE).withValues(alpha: .12 * blobOpacity),
    );
    _paintBlob(
      canvas,
      size,
      Offset(
        size.width * (.48 + math.sin(time * .24) * .07),
        size.height * .96,
      ),
      size.width * .42,
      const Color(0xFFFF4D8D).withValues(alpha: .09 * blobOpacity),
    );

    final particlePaint = Paint()
      ..color = Colors.white.withValues(alpha: particleOpacity);
    for (var index = 0; index < _particles.length; index++) {
      final seed = index * 0.73;
      final point = _particles[index];
      final dx = math.sin(time * .35 + seed) * 7;
      final dy = math.cos(time * .28 + seed) * 9;
      canvas.drawCircle(
        Offset(point.dx * size.width + dx, point.dy * size.height + dy),
        index.isEven ? 1.5 : 1,
        particlePaint,
      );
    }
  }

  void _paintBlob(
    Canvas canvas,
    Size size,
    Offset center,
    double radius,
    Color color,
  ) {
    final paint = Paint()
      ..shader = RadialGradient(
        colors: [color, color.withValues(alpha: 0)],
      ).createShader(Rect.fromCircle(center: center, radius: radius));
    canvas.drawCircle(center, radius, paint);
  }

  @override
  bool shouldRepaint(covariant _AmbientBackgroundPainter oldDelegate) {
    return oldDelegate.progress != progress ||
        oldDelegate.blobOpacity != blobOpacity ||
        oldDelegate.particleOpacity != particleOpacity;
  }
}
