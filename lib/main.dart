import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'app/app.dart';
import 'app/providers.dart';
import 'core/diagnostics/diagnostic_log.dart';

void main() {
  LicenseRegistry.addLicense(_interLicence);
  final container = ProviderContainer()
    ..read(diagnosticLogProvider).record(DiagnosticEvent.appStarted);
  runApp(
    UncontrolledProviderScope(container: container, child: const MorrowApp()),
  );
}

Stream<LicenseEntry> _interLicence() async* {
  final text = await rootBundle.loadString('assets/fonts/Inter-OFL.txt');
  yield LicenseEntryWithLineBreaks(const ['Inter'], text);
}
