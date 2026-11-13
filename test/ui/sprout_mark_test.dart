import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:poop_tracker/ui/widgets/sprout_mark.dart';

void main() {
  testWidgets('the sprout mark paints at its size and is silent', (
    tester,
  ) async {
    final semantics = tester.ensureSemantics();
    await tester.pumpWidget(
      const Directionality(
        textDirection: TextDirection.ltr,
        child: Center(child: SproutMark(color: Color(0xFF3D6552), size: 40)),
      ),
    );

    expect(tester.getSize(find.byType(SproutMark)), const Size(40, 40));
    expect(
      find.descendant(
        of: find.byType(SproutMark),
        matching: find.byType(CustomPaint),
      ),
      findsOneWidget,
    );
    expect(tester.getSemantics(find.byType(SproutMark)), matchesSemantics());
    semantics.dispose();
  });
}
