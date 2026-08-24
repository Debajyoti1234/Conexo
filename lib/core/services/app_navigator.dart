import 'package:flutter/material.dart';

final class AppNavigator {
  AppNavigator._();

  static final AppNavigator instance = AppNavigator._();

  final GlobalKey<NavigatorState> key = GlobalKey<NavigatorState>();

  NavigatorState? get navigator => key.currentState;

  Future<T?> push<T extends Object?>(Route<T> route) {
    final navigator = key.currentState;
    if (navigator == null) {
      throw StateError('AppNavigator: navigator not ready');
    }
    return navigator.push(route);
  }

  bool get isReady => key.currentState != null;
}
