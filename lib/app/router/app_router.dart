import 'package:flutter/material.dart';

class AppRouter {
  const AppRouter._();

  static Route<T> slideRoute<T>(Widget page) => PageRouteBuilder<T>(
        pageBuilder: (_, animation, __) => FadeTransition(
          opacity: animation,
          child: SlideTransition(
            position: Tween<Offset>(begin: const Offset(0.08, 0), end: Offset.zero).animate(CurvedAnimation(parent: animation, curve: Curves.easeOutCubic)),
            child: page,
          ),
        ),
        transitionDuration: const Duration(milliseconds: 340),
      );
}
