import 'dart:io';
import 'dart:typed_data';

import 'package:file_picker/file_picker.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';

/// What happened when a file was handed to the phone's share sheet.
enum ShareOutcome { shared, dismissed, unknown }

/// Hands a file the user asked for to the phone's own save sheet or share
/// sheet. morrow never chooses a location or sends anything itself.
abstract interface class FileExport {
  /// Opens the save sheet. True when the user saved the file.
  Future<bool> save({
    required String fileName,
    required List<int> bytes,
    required String mimeType,
  });

  /// Opens the share sheet with the file attached (for example to email
  /// it). The temporary copy made for sharing is deleted afterwards.
  Future<ShareOutcome> share({
    required String fileName,
    required List<int> bytes,
    required String mimeType,
    required String subject,
  });
}

/// [FileExport] using file_picker (save sheet) and share_plus (share sheet).
class PlatformFileExport implements FileExport {
  const PlatformFileExport();

  @override
  Future<bool> save({
    required String fileName,
    required List<int> bytes,
    required String mimeType,
  }) async {
    final uri = await FilePicker.saveFile(
      fileName: fileName,
      bytes: Uint8List.fromList(bytes),
      mimeType: mimeType,
    );
    return uri != null;
  }

  @override
  Future<ShareOutcome> share({
    required String fileName,
    required List<int> bytes,
    required String mimeType,
    required String subject,
  }) async {
    // A private temporary folder, removed as soon as the sheet closes.
    final dir = await (await getTemporaryDirectory()).createTemp('share_');
    final file = File(p.join(dir.path, fileName));
    try {
      await file.writeAsBytes(bytes, flush: true);
      final result = await SharePlus.instance.share(
        ShareParams(
          files: [XFile(file.path, mimeType: mimeType)],
          subject: subject,
        ),
      );
      return switch (result.status) {
        ShareResultStatus.success => ShareOutcome.shared,
        ShareResultStatus.dismissed => ShareOutcome.dismissed,
        ShareResultStatus.unavailable => ShareOutcome.unknown,
      };
    } finally {
      if (await dir.exists()) await dir.delete(recursive: true);
    }
  }
}
