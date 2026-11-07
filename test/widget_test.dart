import 'package:flutter_test/flutter_test.dart';
import 'package:poop_tracker/app/app.dart';

void main() {
  testWidgets('shows the morrow placeholder home', (tester) async {
    await tester.pumpWidget(const MorrowApp());

    expect(find.text('morrow'), findsOneWidget);
  });
}
