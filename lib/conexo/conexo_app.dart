import 'package:flutter/material.dart';

import 'data/app_state.dart';
import 'design/routes.dart';
import 'design/tokens.dart';
import 'design/widgets.dart';
import 'screens/auth/welcome_screen.dart';

/// The redesigned Conexo front end, running entirely on mock data.
/// No Supabase, Firebase, or location services are touched in this mode.
class ConexoRedesignApp extends StatefulWidget {
  const ConexoRedesignApp({super.key});

  @override
  State<ConexoRedesignApp> createState() => _ConexoRedesignAppState();
}

class _ConexoRedesignAppState extends State<ConexoRedesignApp> {
  final _state = ConexoState();

  @override
  void dispose() {
    _state.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return ConexoScope(
      state: _state,
      child: ListenableBuilder(
        listenable: _state,
        builder: (context, _) => MaterialApp(
          debugShowCheckedModeBanner: false,
          title: 'Conexo',
          theme: ConexoTheme.build(ConexoColors.day),
          darkTheme: ConexoTheme.build(ConexoColors.night),
          themeMode: _state.night ? ThemeMode.dark : ThemeMode.light,
          themeAnimationDuration: const Duration(milliseconds: 420),
          builder: (context, child) => _PhoneFrame(child: child!),
          home: const _Splash(),
        ),
      ),
    );
  }
}

/// On wide screens (desktop web review), present the app in a phone-sized
/// canvas so layouts match what people see on their devices.
class _PhoneFrame extends StatelessWidget {
  const _PhoneFrame({required this.child});
  final Widget child;

  @override
  Widget build(BuildContext context) {
    final size = MediaQuery.sizeOf(context);
    if (size.width < 600) return child;
    final c = context.cx;
    final h = size.height.clamp(0.0, 900.0) - 32;
    final w = (h * 9 / 19.5).clamp(360.0, 430.0);
    return ColoredBox(
      color: c.isNight ? const Color(0xFF05070F) : const Color(0xFFE9E4F7),
      child: Center(
        child: Container(
          width: w,
          height: h,
          clipBehavior: Clip.antiAlias,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(36),
            boxShadow: [
              BoxShadow(
                color: c.shadow.withValues(alpha: c.isNight ? .6 : .18),
                blurRadius: 60,
                offset: const Offset(0, 24),
              ),
            ],
          ),
          child: MediaQuery(
            data: MediaQuery.of(context).copyWith(size: Size(w, h)),
            child: child,
          ),
        ),
      ),
    );
  }
}

/// A short brand beat: the mark settles in, the wordmark follows.
class _Splash extends StatefulWidget {
  const _Splash();

  @override
  State<_Splash> createState() => _SplashState();
}

class _SplashState extends State<_Splash> with SingleTickerProviderStateMixin {
  late final AnimationController _c = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 1500),
  )..forward();

  @override
  void initState() {
    super.initState();
    _c.addStatusListener((status) {
      if (status == AnimationStatus.completed && mounted) {
        Navigator.of(context).pushReplacement(cxRoute(const WelcomeScreen()));
      }
    });
  }

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final c = context.cx;
    return Scaffold(
      backgroundColor: c.bg,
      body: Center(
        child: AnimatedBuilder(
          animation: _c,
          builder: (context, _) {
            double seg(double a, double b, Curve k) => k.transform(((_c.value - a) / (b - a)).clamp(0.0, 1.0));
            final mark = seg(0, .45, Curves.easeOutBack);
            final word = seg(.35, .75, Curves.easeOutCubic);
            return Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Opacity(
                  opacity: seg(0, .3, Curves.easeOut),
                  child: Transform.scale(scale: .7 + .3 * mark, child: const ConexoMark(size: 112)),
                ),
                const SizedBox(height: 18),
                Opacity(
                  opacity: word,
                  child: Transform.translate(
                    offset: Offset(0, 12 * (1 - word)),
                    child: const ConexoWordmark(size: 40),
                  ),
                ),
              ],
            );
          },
        ),
      ),
    );
  }
}
