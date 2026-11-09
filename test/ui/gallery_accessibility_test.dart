import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:poop_tracker/ui/gallery/ui_kit_gallery.dart';

import '../support/harness.dart';

/// Scrolls the gallery from top to bottom so every widget is built and laid
/// out. Any overflow or layout error fails the test.
Future<void> scrollThrough(WidgetTester tester) async {
  final list = find.byType(Scrollable).first;
  for (var i = 0; i < 40; i++) {
    final position = tester.state<ScrollableState>(list).position;
    if (position.pixels >= position.maxScrollExtent) break;
    await tester.drag(list, const Offset(0, -300));
    await tester.pump();
  }
}

/// The gallery has an indeterminate spinner, so it never settles. Pump long
/// enough for route and sheet transitions to finish instead.
Future<void> settle(WidgetTester tester) async {
  await tester.pump();
  await tester.pump(const Duration(seconds: 1));
}

/// Scrolls [label] into view, then taps it.
Future<void> tapVisible(WidgetTester tester, String label) async {
  await tester.ensureVisible(find.text(label));
  await tester.pump();
  await tester.tap(find.text(label));
}

Future<void> checkGuidelines(WidgetTester tester) async {
  await expectLater(tester, meetsGuideline(textContrastGuideline));
  await expectLater(tester, meetsGuideline(androidTapTargetGuideline));
  await expectLater(tester, meetsGuideline(iOSTapTargetGuideline));
  await expectLater(tester, meetsGuideline(labeledTapTargetGuideline));
}

void main() {
  for (final size in [figmaPhone, smallPhone]) {
    for (final scale in textScales) {
      final name = '${size.width.toInt()}pt wide, ${(scale * 100).toInt()}%';

      testWidgets('gallery lays out without overflow ($name)', (tester) async {
        await pumpThemed(
          tester,
          const UiKitGallery(),
          textScale: scale,
          size: size,
        );
        await scrollThrough(tester);
        expect(tester.takeException(), isNull);
      });

      testWidgets('dialog, sheet and toast fit ($name)', (tester) async {
        await pumpThemed(
          tester,
          const UiKitGallery(),
          textScale: scale,
          size: size,
        );
        await scrollThrough(tester);

        await tapVisible(tester, 'Show dialog');
        await settle(tester);
        expect(find.text('Discard this entry?'), findsOneWidget);
        expect(tester.takeException(), isNull);
        await tapVisible(tester, 'Keep editing');
        await settle(tester);

        await tapVisible(tester, 'Show sheet');
        await settle(tester);
        expect(find.text('Filter entries'), findsOneWidget);
        expect(tester.takeException(), isNull);
        await tapVisible(tester, 'Apply');
        await settle(tester);

        await tapVisible(tester, 'Show toast');
        await tester.pump();
        expect(find.text('Entry saved'), findsOneWidget);
        expect(tester.takeException(), isNull);
      });
    }
  }

  testWidgets('gallery meets contrast, tap target and label guidelines', (
    tester,
  ) async {
    final semantics = tester.ensureSemantics();
    await pumpThemed(tester, const UiKitGallery());

    final list = find.byType(Scrollable).first;
    for (var i = 0; i < 12; i++) {
      await checkGuidelines(tester);
      final position = tester.state<ScrollableState>(list).position;
      if (position.pixels >= position.maxScrollExtent) break;
      await tester.drag(list, const Offset(0, -500));
      await settle(tester);
    }
    semantics.dispose();
  });

  testWidgets('dialog meets the guidelines', (tester) async {
    final semantics = tester.ensureSemantics();
    await pumpThemed(tester, const UiKitGallery());
    await scrollThrough(tester);
    await tapVisible(tester, 'Show dialog');
    await settle(tester);
    await checkGuidelines(tester);
    semantics.dispose();
  });
}
