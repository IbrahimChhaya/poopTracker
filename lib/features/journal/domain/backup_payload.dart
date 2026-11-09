import 'dart:convert';

import '../../../core/backup/backup_file.dart';
import '../../../core/ids/uid.dart';
import 'entry.dart';

/// The journal schema the payload describes. Matches
/// `AppDatabase.schemaVersion` (a test checks they agree). A backup from an
/// earlier schema restores; a later one is refused as [BackupProblem.newerVersion].
const int backupSchemaVersion = 2;

/// One entry as it travels in a backup: everything the person recorded,
/// with its stable [uid] so restoring twice adds nothing.
final class BackupEntry {
  const BackupEntry({
    required this.uid,
    required this.draft,
    required this.createdAtUtc,
    required this.updatedAtUtc,
  });

  factory BackupEntry.of(Entry e) => BackupEntry(
    uid: e.uid,
    draft: e.toDraft(),
    createdAtUtc: e.createdAtUtc,
    updatedAtUtc: e.updatedAtUtc,
  );

  final String uid;
  final EntryDraft draft;
  final DateTime createdAtUtc;
  final DateTime updatedAtUtc;
}

/// The JSON inside a backup (format 1). Reminders, settings and app lock are
/// never included.
List<int> encodeBackupPayload(
  List<Entry> entries, {
  required DateTime exportedAtUtc,
}) {
  final json = <String, Object?>{
    'format': backupFormatVersion,
    'schemaVersion': backupSchemaVersion,
    'exportedAtUtc': exportedAtUtc.toUtc().toIso8601String(),
    'entries': [
      for (final e in entries)
        {
          'uid': e.uid,
          'occurredAtUtc': e.occurredAtUtc.toIso8601String(),
          'originalUtcOffsetMinutes': e.originalUtcOffsetMinutes,
          'hasTime': e.hasTime,
          'comment': e.comment,
          'stoolType': e.stoolType,
          'ease': e.ease?.code,
          'tags': [for (final t in e.tags) t.code]..sort(),
          'createdAtUtc': e.createdAtUtc.toIso8601String(),
          'updatedAtUtc': e.updatedAtUtc.toIso8601String(),
        },
    ],
  };
  return utf8.encode(jsonEncode(json));
}

/// Reads and validates every entry before anything is written. Throws
/// [BackupException] for anything malformed: the restore is all or nothing.
List<BackupEntry> decodeBackupPayload(List<int> bytes) {
  const damaged = BackupException(BackupProblem.notBackup);
  final Object? root;
  try {
    root = jsonDecode(utf8.decode(bytes));
  } on FormatException {
    throw damaged;
  }
  if (root is! Map<String, Object?>) throw damaged;
  final format = root['format'];
  final schema = root['schemaVersion'];
  final list = root['entries'];
  if (format is! int || schema is! int || list is! List<Object?>) {
    throw damaged;
  }
  if (format > backupFormatVersion || schema > backupSchemaVersion) {
    throw const BackupException(BackupProblem.newerVersion);
  }
  if (format != backupFormatVersion || schema < 1) throw damaged;

  return [
    for (final item in list) _entry(item, schema: schema) ?? (throw damaged),
  ];
}

BackupEntry? _entry(Object? item, {required int schema}) {
  if (item is! Map<String, Object?>) return null;
  final uid = item['uid'];
  final occurred = _utc(item['occurredAtUtc']);
  final offset = item['originalUtcOffsetMinutes'];
  // Schema 1 had no date-only entries.
  final hasTime = schema < 2 ? (item['hasTime'] ?? true) : item['hasTime'];
  final comment = item['comment'];
  final stool = item['stoolType'];
  final easeCode = item['ease'];
  final tagCodes = item['tags'] ?? const <Object?>[];
  final created = _utc(item['createdAtUtc']);
  final updated = _utc(item['updatedAtUtc']);

  if (uid is! String || !isValidUid(uid)) return null;
  if (occurred == null || created == null || updated == null) return null;
  if (offset is! int || offset < minUtcOffsetMinutes) return null;
  if (offset > maxUtcOffsetMinutes) return null;
  if (hasTime is! bool) return null;
  if (comment != null && comment is! String) return null;
  if (comment is String && commentLength(comment) > maxCommentLength) {
    return null;
  }
  if (stool != null && (stool is! int || stool < 1 || stool > 7)) {
    return null;
  }
  Ease? ease;
  if (easeCode != null) {
    if (easeCode is! String) return null;
    ease = Ease.fromCode(easeCode);
    if (ease == null) return null;
  }
  if (tagCodes is! List<Object?>) return null;
  final tags = <Tag>{};
  for (final code in tagCodes) {
    final tag = code is String ? Tag.fromCode(code) : null;
    if (tag == null) return null;
    tags.add(tag);
  }
  return BackupEntry(
    uid: uid,
    draft: EntryDraft(
      occurredAtUtc: occurred,
      originalUtcOffsetMinutes: offset,
      hasTime: hasTime,
      comment: comment as String?,
      stoolType: stool as int?,
      ease: ease,
      tags: tags,
    ),
    createdAtUtc: created,
    updatedAtUtc: updated,
  );
}

/// An ISO 8601 instant in UTC (ending in Z), or null.
DateTime? _utc(Object? value) {
  if (value is! String || !value.endsWith('Z')) return null;
  final parsed = DateTime.tryParse(value);
  return parsed != null && parsed.isUtc ? parsed : null;
}
