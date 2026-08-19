import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:conexo/features/main_shell.dart';

void main() {
  testWidgets('MainShell bottom navigation remains interactive',
      (WidgetTester tester) async {
    int? selectedIndex;
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: const SizedBox.shrink(),
          bottomNavigationBar: FloatingNavDock(
            selectedIndex: 0,
            onSelected: (index) => selectedIndex = index,
          ),
        ),
      ),
    );

    expect(find.byType(FloatingNavDock), findsOneWidget);
    expect(find.byKey(const ValueKey('People')), findsOneWidget);
    expect(find.byKey(const ValueKey('Plans')), findsOneWidget);

    await tester.tap(find.byKey(const ValueKey('People')));
    await tester.pump();

    expect(selectedIndex, 1);
  });
}
