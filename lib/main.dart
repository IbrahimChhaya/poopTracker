import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'app/app.dart';

void main() {
  LicenseRegistry.addLicense(_interLicence);
  runApp(const ProviderScope(child: MorrowApp()));
}

Stream<LicenseEntry> _interLicence() async* {
  final text = await rootBundle.loadString('assets/fonts/Inter-OFL.txt');
  yield LicenseEntryWithLineBreaks(const ['Inter'], text);
}
