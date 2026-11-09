import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:poop_tracker/features/backup/presentation/passphrase_field.dart';
import 'package:poop_tracker/ui/theme/morrow_theme.dart';

void main() {
  testWidgets('each passphrase field is named for screen readers', (
    tester,
  ) async {
    final handle = tester.ensureSemantics();
    final a = TextEditingController();
    final b = TextEditingController();
    addTearDown(a.dispose);
    addTearDown(b.dispose);
    await tester.pumpWidget(
      MaterialApp(
        theme: buildMorrowTheme(),
        home: Scaffold(
          body: Column(
            children: [
              PassphraseField(
                label: 'Protect it with a passphrase',
                controller: a,
              ),
              PassphraseField(label: 'Confirm passphrase', controller: b),
            ],
          ),
        ),
      ),
    );
    for (final (label, controller) in [
      ('Protect it with a passphrase', a),
      ('Confirm passphrase', b),
    ]) {
      final field = find.byType(TextField).at(label.startsWith('C') ? 1 : 0);
      expect(
        tester.getSemantics(field),
        isSemantics(label: label, isTextField: true, isObscured: true),
        reason: label,
      );
      // Still named once something is typed.
      await tester.enterText(field, 'synthetic');
      await tester.pump();
      expect(
        tester.getSemantics(field),
        isSemantics(label: label, isTextField: true),
        reason: '$label with text',
      );
      expect(controller.text, 'synthetic');
    }
    handle.dispose();
  });
}
