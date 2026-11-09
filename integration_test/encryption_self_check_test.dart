import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:poop_tracker/core/diagnostics/encryption_self_check.dart';

/// Runs the encryption self-check on a real device or simulator.
///
/// `flutter test integration_test/encryption_self_check_test.dart -d DEVICE`
void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('encrypted database and secure storage work on device', (
    tester,
  ) async {
    final steps = await runEncryptionSelfCheck();
    for (final s in steps) {
      // Safe to print: steps hold check names only, never data or keys.
      // ignore: avoid_print
      print(
        '${s.passed ? 'PASS' : 'FAIL'}: ${s.name}'
        '${s.detail == null || s.detail!.isEmpty ? '' : ' (${s.detail})'}',
      );
    }
    expect(steps, isNotEmpty);
    expect(steps.where((s) => !s.passed).map((s) => s.name), isEmpty);
  });
}
