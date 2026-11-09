import 'dart:async';
import 'dart:convert';

import 'package:poop_tracker/core/backup/backup_file.dart';
import 'package:poop_tracker/core/platform/file_import.dart';

/// A quick stand-in for Argon2id, for widget tests (which run in a
/// fake-async zone where an isolate never finishes). Different passphrases
/// or salts give different keys. Real Argon2id is covered by
/// backup_file_test.dart.
Future<List<int>> fastKeyDeriver(
  String passphrase,
  List<int> salt,
  KdfParams params,
) async {
  final input = [...utf8.encode(passphrase), 0, ...salt];
  final key = List<int>.filled(32, 0);
  for (var i = 0; i < input.length; i++) {
    key[i % 32] = (key[i % 32] * 31 + input[i] + i) & 0xff;
  }
  return key;
}

/// The phone's file picker, scripted.
class FakeFileImport implements FileImport {
  /// The next pick; null means the person cancels.
  PickedFile? next;

  /// When set, the picker stays open until it completes.
  Completer<void>? open;
  int picks = 0;

  @override
  Future<PickedFile?> pickBackup() async {
    picks++;
    await open?.future;
    return next;
  }
}
