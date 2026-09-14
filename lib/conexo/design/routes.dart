import 'package:flutter/material.dart';

/// The single page transition: a short fade with a gentle forward drift.
Route<T> cxRoute<T>(Widget page, {bool fullscreen = false}) => PageRouteBuilder<T>(
  fullscreenDialog: fullscreen,
  transitionDuration: const Duration(milliseconds: 420),
  reverseTransitionDuration: const Duration(milliseconds: 300),
  pageBuilder: (_, _, _) => page,
  transitionsBuilder: (context, animation, secondary, child) {
    final curved = CurvedAnimation(
      parent: animation,
      curve: Curves.easeOutCubic,
      reverseCurve: Curves.easeInCubic,
    );
    final begin = fullscreen ? const Offset(0, .08) : const Offset(.06, 0);
    return FadeTransition(
      opacity: curved,
      child: SlideTransition(
        position: Tween(begin: begin, end: Offset.zero).animate(curved),
        child: child,
      ),
    );
  },
);
