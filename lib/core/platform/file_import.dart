import 'dart:io';

import 'package:file_picker/file_picker.dart';

import '../backup/backup_file.dart';

/// A file the person picked, read into memory.
final class PickedFile {
  const PickedFile({required this.name, required this.bytes});

  final String name;
  final List<int> bytes;
}

/// Opens the phone's own file picker for a backup the person saved earlier.
/// morrow never browses storage itself.
abstract interface class FileImport {
  /// Null when the person cancelled. Throws [BackupException] for a file
  /// too large to be a backup.
  Future<PickedFile?> pickBackup();
}

/// [FileImport] using file_picker. Any file type can be picked (Android has
/// no type for `.morrow`); the contents are checked afterwards.
class PlatformFileImport implements FileImport {
  const PlatformFileImport();

  @override
  Future<PickedFile?> pickBackup() async {
    try {
      final file = await FilePicker.pickFile();
      if (file == null) return null;
      final size = file.lengthSync() ?? await file.length();
      if (size == null || size > maxBackupBytes) {
        throw const BackupException(BackupProblem.notBackup);
      }
      return PickedFile(name: file.name, bytes: await file.readAsBytes());
    } finally {
      // Android and iOS copy the picked file into the app's cache; it is
      // encrypted, but is removed as soon as it has been read.
      if (Platform.isAndroid || Platform.isIOS) {
        await FilePicker.clearTemporaryFiles();
      }
    }
  }
}
