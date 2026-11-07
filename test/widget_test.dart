import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:poop_tracker/app/app.dart';
import 'package:poop_tracker/ui/theme/morrow_colors.dart';

import 'support/harness.dart';

void main() {
  testWidgets('shows the morrow placeholder home in the morrow theme', (
    tester,
  ) async {
    await tester.pumpWidget(const MorrowApp());

    expect(find.text('morrow'), findsOneWidget);
    final context = tester.element(find.text('morrow'));
    expect(Theme.of(context).extension<MorrowColors>(), MorrowColors.light);
    expect(
      Theme.of(context).scaffoldBackgroundColor,
      MorrowColors.light.background,
    );
  });

  for (final scale in textScales) {
    testWidgets('every tab lays out at ${(scale * 100).toInt()}% text', (
      tester,
    ) async {
      useScreenSize(tester, smallPhone);
      await tester.pumpWidget(
        MediaQuery(
          data: MediaQueryData(
            size: smallPhone,
            textScaler: TextScaler.linear(scale),
          ),
          child: const MorrowApp(),
        ),
      );
      for (final tab in ['History', 'Trends', 'Settings', 'Journal']) {
        await tester.tap(find.text(tab).last);
        await tester.pumpAndSettle();
        expect(tester.takeException(), isNull, reason: tab);
      }
    });
  }

  testWidgets('UI kit preview opens from Settings in debug builds', (
    tester,
  ) async {
    await tester.pumpWidget(const MorrowApp());
    await tester.tap(find.text('Settings').last);
    await tester.pumpAndSettle();
    await tester.tap(find.text('UI kit preview'));
    await tester.pumpAndSettle();
    expect(find.text('UI kit'), findsOneWidget);
  });
}
