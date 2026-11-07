import 'dart:io';

import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';

/// The journal database file, in app-private storage.
///
/// Application Support is private to the app on both platforms, is not a
/// cache folder the OS may clear, and is not shown in the iOS Files app.
/// Backup exclusions are added in M10.
Future<File> journalDatabaseFile() async {
  final dir = await getApplicationSupportDirectory();
  return File(p.join(dir.path, 'journal', 'journal.db'));
}
