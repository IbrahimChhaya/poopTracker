import 'dart:io';
import 'dart:math';

import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:poop_tracker/core/database/app_database.dart';
import 'package:poop_tracker/core/database/bootstrap.dart';
import 'package:poop_tracker/core/database/encryption.dart';
import 'package:poop_tracker/core/security/database_key.dart';
import 'package:poop_tracker/core/security/key_store.dart';

import '../../support/fake_key_store.dart';

/// Opener that records calls and returns scripted results. "Creating" a
/// database just writes a placeholder file.
class FakeOpener implements EncryptedDatabaseOpener {
  DatabaseCheck checkResult = DatabaseCheck.ok;
  Exception? openError;
  final List<String> calls = [];
  DatabaseKey? lastKey;

  @override
  Future<DatabaseCheck> check(File file, DatabaseKey key) async {
    calls.add('check');
    lastKey = key;
    return checkResult;
  }

  @override
  Future<AppDatabase> open(File file, DatabaseKey key) async {
    calls.add('open');
    lastKey = key;
    final error = openError;
    if (error != null) {
      await file.writeAsString('partial');
      throw error;
    }
    if (!await file.exists()) await file.writeAsString('placeholder');
    return AppDatabase(NativeDatabase.memory());
  }
}

void main() {
  late Directory dir;
  late File dbFile;
  late FakeKeyStore keys;
  late FakeOpener opener;
  final existingKey = DatabaseKey.generate(Random(1));
  final newKey = DatabaseKey.generate(Random(2));

  setUp(() {
    dir = Directory.systemTemp.createTempSync('morrow_boot_');
    dbFile = File('${dir.path}/journal/journal.db');
    keys = FakeKeyStore();
    opener = FakeOpener();
  });

  tearDown(() => dir.deleteSync(recursive: true));

  DatabaseBootstrap bootstrap() => DatabaseBootstrap(
    keyStore: keys,
    databaseFile: () async => dbFile,
    opener: opener,
    generateKey: () => newKey,
  );

  Future<StartupResult> start() async {
    final result = await bootstrap().start();
    if (result is StartupReady) await result.database.close();
    return result;
  }

  void givenExistingDatabase() {
    dbFile.parent.createSync(recursive: true);
    dbFile.writeAsStringSync('existing encrypted journal');
  }

  Matcher blocked(StartupBlockReason reason) =>
      isA<StartupBlocked>().having((b) => b.reason, 'reason', reason);

  group('first install', () {
    test('creates a key, then the database, then marks ready', () async {
      final result = await start();
      expect(result, isA<StartupReady>());
      expect((result as StartupReady).createdNew, isTrue);
      expect(keys.key!.sameAs(newKey), isTrue);
      expect(keys.marker, SetupMarker.ready);
      expect(opener.lastKey!.sameAs(newKey), isTrue);
      expect(opener.calls, ['open']);
    });

    test('removes leftover journal files before creating', () async {
      dbFile.parent.createSync(recursive: true);
      for (final s in companionSuffixes) {
        File('${dbFile.path}$s').writeAsStringSync('stale');
      }
      await start();
      for (final s in companionSuffixes) {
        expect(File('${dbFile.path}$s').existsSync(), isFalse, reason: s);
      }
    });

    test('blocks if the key cannot be written', () async {
      keys.failWrites = true;
      expect(await start(), blocked(StartupBlockReason.storageUnavailable));
      expect(dbFile.existsSync(), isFalse);
    });

    test('blocks if the key does not read back', () async {
      keys.loseWrites = true;
      expect(await start(), blocked(StartupBlockReason.storageUnavailable));
      expect(opener.calls, isEmpty);
      expect(dbFile.existsSync(), isFalse);
    });

    test('a failed create stays resumable with the same key', () async {
      opener.openError = Exception('disk full');
      expect(await start(), blocked(StartupBlockReason.setupFailed));
      expect(keys.marker, SetupMarker.creating);
      expect(keys.key!.sameAs(newKey), isTrue);
    });

    test('no encryption support: the new file is deleted', () async {
      opener.openError = const EncryptionUnavailableException();
      expect(await start(), blocked(StartupBlockReason.encryptionUnavailable));
      expect(dbFile.existsSync(), isFalse);
    });
  });

  group('interrupted setup', () {
    test('key written but no database: resumes with that key', () async {
      keys
        ..key = existingKey
        ..marker = SetupMarker.creating;
      final result = await start();
      expect(result, isA<StartupReady>());
      expect(keys.keyWrites, 0);
      expect(opener.lastKey!.sameAs(existingKey), isTrue);
      expect(keys.marker, SetupMarker.ready);
    });

    test('database created but not marked ready: opens and marks', () async {
      givenExistingDatabase();
      keys
        ..key = existingKey
        ..marker = SetupMarker.creating;
      final result = await start();
      expect(result, isA<StartupReady>());
      expect((result as StartupReady).createdNew, isFalse);
      expect(keys.marker, SetupMarker.ready);
    });

    test('marker written but no key yet: a fresh key is made', () async {
      keys.marker = SetupMarker.creating;
      expect(await start(), isA<StartupReady>());
      expect(keys.key!.sameAs(newKey), isTrue);
    });
  });

  group('reinstall (journal gone, stale key left behind)', () {
    test('a key marked ready is discarded and setup starts fresh', () async {
      keys
        ..key = existingKey
        ..marker = SetupMarker.ready;
      final result = await start();
      expect(result, isA<StartupReady>());
      expect((result as StartupReady).createdNew, isTrue);
      expect(keys.keyDeletes, 1);
      expect(keys.key!.sameAs(newKey), isTrue);
    });

    test('a key with no marker is also treated as stale', () async {
      keys.key = existingKey;
      expect(await start(), isA<StartupReady>());
      expect(keys.key!.sameAs(newKey), isTrue);
    });

    test('a damaged key with no journal is replaced', () async {
      keys.keyCorrupt = true;
      expect(await start(), isA<StartupReady>());
      expect(keys.key!.sameAs(newKey), isTrue);
    });

    test('blocks if the stale key cannot be removed', () async {
      keys
        ..key = existingKey
        ..marker = SetupMarker.ready
        ..failDeletes = true;
      expect(await start(), blocked(StartupBlockReason.storageUnavailable));
      expect(keys.key, same(existingKey));
    });
  });

  group('existing journal', () {
    setUp(givenExistingDatabase);

    test('opens with the stored key', () async {
      keys
        ..key = existingKey
        ..marker = SetupMarker.ready;
      final result = await start();
      expect(result, isA<StartupReady>());
      expect(opener.calls, ['check', 'open']);
      expect(opener.lastKey!.sameAs(existingKey), isTrue);
      expect(keys.keyWrites, 0);
    });

    Future<void> expectUntouched(StartupResult result) async {
      expect(result, isA<StartupBlocked>());
      expect(await dbFile.readAsString(), 'existing encrypted journal');
      expect(keys.keyWrites, 0);
      expect(keys.keyDeletes, 0);
      expect(opener.calls, isNot(contains('open')));
    }

    test('missing key: blocked, nothing created or replaced', () async {
      keys.marker = SetupMarker.ready;
      final result = await start();
      expect(result, blocked(StartupBlockReason.keyMissing));
      await expectUntouched(result);
      expect(keys.key, isNull);
    });

    test('damaged key: blocked as missing, nothing replaced', () async {
      keys.keyCorrupt = true;
      final result = await start();
      expect(result, blocked(StartupBlockReason.keyMissing));
      await expectUntouched(result);
    });

    final cases = {
      DatabaseCheck.wrongKey: StartupBlockReason.keyRejected,
      DatabaseCheck.notEncrypted: StartupBlockReason.notEncrypted,
      DatabaseCheck.encryptionUnavailable:
          StartupBlockReason.encryptionUnavailable,
      DatabaseCheck.unreadable: StartupBlockReason.databaseUnreadable,
    };
    for (final MapEntry(key: check, value: reason) in cases.entries) {
      test('$check: blocked as $reason, nothing replaced', () async {
        keys.key = existingKey;
        opener.checkResult = check;
        final result = await start();
        expect(result, blocked(reason));
        await expectUntouched(result);
        expect(keys.key, same(existingKey));
      });
    }

    test('a failure while opening does not touch the key', () async {
      keys.key = existingKey;
      opener.openError = Exception('io');
      expect(await start(), blocked(StartupBlockReason.databaseUnreadable));
      expect(keys.key, same(existingKey));
    });
  });

  group('secure storage unreadable', () {
    test('with a journal: blocked, nothing created', () async {
      givenExistingDatabase();
      keys.failReads = true;
      expect(await start(), blocked(StartupBlockReason.storageUnavailable));
      expect(opener.calls, isEmpty);
    });

    test(
      'without a journal: blocked, never treated as first install',
      () async {
        keys.failReads = true;
        expect(await start(), blocked(StartupBlockReason.storageUnavailable));
        expect(opener.calls, isEmpty);
        expect(dbFile.existsSync(), isFalse);
      },
    );
  });
}
