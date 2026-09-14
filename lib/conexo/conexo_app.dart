import 'package:flutter/material.dart';

import 'data/app_state.dart';
import 'data/data_source.dart';
import 'design/routes.dart';
import 'design/tokens.dart';
import 'design/widgets.dart';
import 'screens/auth/auth_routing.dart';

/// The redesigned Conexo front end. [source] decides where data comes from:
/// the live Supabase backend, or local demo data.
class ConexoRedesignApp extends StatefulWidget {
  const ConexoRedesignApp({required this.source, super.key});
  final ConexoDataSource source;

  @override
  State<ConexoRedesignApp> createState() => _ConexoRedesignAppState();
}

class _ConexoRedesignAppState extends State<ConexoRedesignApp> {
  late final _state = ConexoState(widget.source);

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

/// A short brand beat while the session is restored, then routes to the
/// right place: welcome, profile setup, or the app.
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
  String? _error;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _start());
  }

  Future<void> _start() async {
    final s = ConexoScope.read(context);
    setState(() => _error = null);
    try {
      final results = await Future.wait<Object?>([
        s.boot(),
        Future<void>.delayed(const Duration(milliseconds: 1500)),
      ]);
      if (!mounted) return;
      final stage = results.first! as SessionStage;
      Navigator.of(context).pushReplacement(cxRoute(destinationFor(stage, s)));
    } on ConexoFailure catch (e) {
      if (mounted) setState(() => _error = e.message);
    } catch (e) {
      debugPrint('Conexo boot failed: $e');
      if (mounted) setState(() => _error = 'We couldn\'t reach Conexo. Check your connection and try again.');
    }
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
            return Padding(
              padding: const EdgeInsets.symmetric(horizontal: 32),
              child: Column(
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
                  AnimatedSize(
                    duration: const Duration(milliseconds: 300),
                    child: _error == null
                        ? const SizedBox(width: double.infinity)
                        : Column(
                            children: [
                              const SizedBox(height: 36),
                              Text(
                                _error!,
                                textAlign: TextAlign.center,
                                style: ConexoType.body(c.inkSoft, size: 15),
                              ),
                              const SizedBox(height: 20),
                              SizedBox(
                                width: 200,
                                child: CxButton(
                                  label: 'Try again',
                                  variant: CxButtonVariant.ink,
                                  height: 50,
                                  onTap: _start,
                                ),
                              ),
                            ],
                          ),
                  ),
                ],
              ),
            );
          },
        ),
      ),
    );
  }
}
