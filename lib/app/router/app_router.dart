import 'package:flutter/material.dart';

class AppRouter {
  const AppRouter._();

  static Route<T> slideRoute<T>(Widget page) => PageRouteBuilder<T>(
    pageBuilder: (_, animation, _) => FadeTransition(
      opacity: animation,
      child: SlideTransition(
        position: Tween<Offset>(begin: const Offset(0.08, 0), end: Offset.zero)
            .animate(
              CurvedAnimation(parent: animation, curve: Curves.easeOutCubic),
            ),
        child: page,
      ),
    ),
    transitionDuration: const Duration(milliseconds: 340),
  );

  /// Shared premium transition for Profile sub-screens (Safety, Help & Support,
  /// About Conexo, Contact Support, Report a Problem, Blocked Users, Safety
  /// Tips). A subtle fade + short vertical slide that reads as premium and
  /// intentional without a heavy modal feel. Keep this the single source of
  /// truth so every Profile route feels identical.
  static Route<T> premiumProfileRoute<T>(Widget page) => PageRouteBuilder<T>(
    transitionDuration: const Duration(milliseconds: 420),
    reverseTransitionDuration: const Duration(milliseconds: 320),
    pageBuilder: (context, animation, secondaryAnimation) => page,
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
