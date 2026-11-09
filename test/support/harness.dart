import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:poop_tracker/ui/theme/morrow_theme.dart';

/// Phone sizes used by layout tests, in logical pixels.
const Size figmaPhone = Size(402, 874);
const Size smallPhone = Size(320, 640);

/// Text scales every shared widget must survive.
const List<double> textScales = [1.0, 2.0];

/// Sets the test view to [size] at 3x and restores it after the test.
void useScreenSize(WidgetTester tester, Size size) {
  tester.view.devicePixelRatio = 3;
  tester.view.physicalSize = size * 3;
  addTearDown(tester.view.reset);
}

/// Pumps [home] inside the morrow theme at the given text scale.
Future<void> pumpThemed(
  WidgetTester tester,
  Widget home, {
  double textScale = 1,
  Size size = figmaPhone,
}) async {
  useScreenSize(tester, size);
  await tester.pumpWidget(
    MaterialApp(
      theme: buildMorrowTheme(),
      builder: (context, child) => MediaQuery(
        data: MediaQuery.of(context)
            .copyWith(textScaler: TextScaler.linear(textScale)),
        child: child!,
      ),
      home: home,
    ),
  );
}

/// Wraps [child] in a scrolling page, the way screens will use it.
Widget page(Widget child) => Scaffold(
  body: SafeArea(
    child: SingleChildScrollView(
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
      child: child,
    ),
  ),
);
