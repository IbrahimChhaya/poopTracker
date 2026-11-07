import 'dart:math';

import 'package:flutter_test/flutter_test.dart';
import 'package:poop_tracker/core/ids/uid.dart';
import 'package:poop_tracker/core/time/local_date.dart';
import 'package:poop_tracker/features/journal/domain/entry.dart';

import '../../support/entries.dart';

final DateTime _now = DateTime.utc(2026, 11, 6, 13, 41);

EntryDraft _draft({
  DateTime? at,
  int offset = 0,
  String? comment,
  int? stoolType,
  Set<Symptom> symptoms = const {},
}) => EntryDraft(
  occurredAtUtc: at ?? _now.subtract(const Duration(minutes: 6)),
  originalUtcOffsetMinutes: offset,
  comment: comment,
  stoolType: stoolType,
  symptoms: symptoms,
);

void main() {
  group('only date and time are required', () {
    test('a draft with just a time is valid', () {
      final d = _draft();
      expect(d.validate(nowUtc: _now), isEmpty);
      expect(d.comment, isNull);
      expect(d.stoolType, isNull);
      expect(d.ease, isNull);
      expect(d.symptoms, isEmpty);
      expect(d.tags, isEmpty);
    });
  });

  group('comment', () {
    test('is trimmed, and empty becomes null', () {
      expect(_draft(comment: '  Felt fine  ').comment, 'Felt fine');
      expect(_draft(comment: '   \n ').comment, isNull);
      expect(_draft(comment: '').comment, isNull);
    });

    test('keeps inner line breaks', () {
      expect(
        _draft(comment: 'Line one\nLine two').comment,
        'Line one\nLine two',
      );
    });

    test('500 characters is allowed, 501 is not', () {
      expect(_draft(comment: 'a' * 500).validate(nowUtc: _now), isEmpty);
      expect(_draft(comment: 'a' * 501).validate(nowUtc: _now), [
        EntryValidationError.commentTooLong,
      ]);
    });

    test('counts user-perceived characters, not code units', () {
      const family = '👨‍👩‍👧'; // one emoji, 8 UTF-16 code units
      const accent = 'é'; // é written as e + combining accent
      expect(commentLength(family), 1);
      expect(commentLength(accent), 1);
      expect(_draft(comment: family * 500).validate(nowUtc: _now), isEmpty);
      expect(_draft(comment: family * 501).validate(nowUtc: _now), [
        EntryValidationError.commentTooLong,
      ]);
    });

    test('surrounding whitespace does not count towards the limit', () {
      expect(
        _draft(comment: '  ${'a' * 500}  ').validate(nowUtc: _now),
        isEmpty,
      );
    });
  });

  group('stool type', () {
    test('1 to 7 are valid', () {
      for (var t = 1; t <= 7; t++) {
        expect(_draft(stoolType: t).validate(nowUtc: _now), isEmpty);
      }
    });

    test('0 and 8 are rejected', () {
      for (final t in [0, 8, -1]) {
        expect(_draft(stoolType: t).validate(nowUtc: _now), [
          EntryValidationError.stoolTypeOutOfRange,
        ]);
      }
    });
  });

  group('symptoms', () {
    test('"None" on its own is valid', () {
      expect(_draft(symptoms: {Symptom.none}).validate(nowUtc: _now), isEmpty);
    });

    test('several real symptoms are valid', () {
      expect(
        _draft(symptoms: {Symptom.bloating, Symptom.cramping})
            .validate(nowUtc: _now),
        isEmpty,
      );
    });

    test('"None" cannot be combined with another symptom', () {
      expect(
        _draft(symptoms: {Symptom.none, Symptom.bloating})
            .validate(nowUtc: _now),
        [EntryValidationError.noneWithOtherSymptoms],
      );
    });

    test('"None" and no answer both mean no symptoms', () {
      expect(
        entryAt(2026, 11, 6, 8, 0, symptoms: {Symptom.none}).hasSymptoms,
        isFalse,
      );
      expect(entryAt(2026, 11, 6, 8, 0).hasSymptoms, isFalse);
      expect(
        entryAt(2026, 11, 6, 8, 0, symptoms: {Symptom.urgency}).hasSymptoms,
        isTrue,
      );
    });
  });

  group('date and time', () {
    test('now and any past time are valid', () {
      expect(_draft(at: _now).validate(nowUtc: _now), isEmpty);
      expect(
        _draft(at: DateTime.utc(2019, 1, 1)).validate(nowUtc: _now),
        isEmpty,
      );
    });

    test('up to one minute ahead is tolerated, more is rejected', () {
      expect(
        _draft(at: _now.add(futureTolerance)).validate(nowUtc: _now),
        isEmpty,
      );
      expect(
        _draft(at: _now.add(futureTolerance + const Duration(seconds: 1)))
            .validate(nowUtc: _now),
        [EntryValidationError.inFuture],
      );
      expect(
        _draft(at: _now.add(const Duration(days: 1))).validate(nowUtc: _now),
        [EntryValidationError.inFuture],
      );
    });

    test('times must be UTC instants', () {
      final local = DateTime(2026, 11, 6, 13);
      expect(_draft(at: local).validate(nowUtc: _now), [
        EntryValidationError.timeNotUtc,
      ]);
    });

    test('offsets outside -12:00 to +14:00 are rejected', () {
      expect(_draft(offset: -720).validate(nowUtc: _now), isEmpty);
      expect(_draft(offset: 840).validate(nowUtc: _now), isEmpty);
      expect(_draft(offset: -721).validate(nowUtc: _now), [
        EntryValidationError.utcOffsetOutOfRange,
      ]);
      expect(_draft(offset: 841).validate(nowUtc: _now), [
        EntryValidationError.utcOffsetOutOfRange,
      ]);
    });

    test('several problems are all reported', () {
      final errors = EntryDraft(
        occurredAtUtc: _now.add(const Duration(hours: 1)),
        originalUtcOffsetMinutes: 0,
        comment: 'a' * 501,
        stoolType: 9,
        symptoms: {Symptom.none, Symptom.blood},
      ).validate(nowUtc: _now);
      expect(
        errors,
        unorderedEquals([
          EntryValidationError.commentTooLong,
          EntryValidationError.stoolTypeOutOfRange,
          EntryValidationError.noneWithOtherSymptoms,
          EntryValidationError.inFuture,
        ]),
      );
    });
  });

  group('Entry', () {
    test('local date and time use the offset it was recorded with', () {
      // 21:00 in New York on 5 November is 02:00 UTC on the 6th.
      final e = entryAt(2026, 11, 5, 21, 0, offsetMinutes: -300);
      expect(e.occurredAtUtc, DateTime.utc(2026, 11, 6, 2));
      expect(e.localDate, LocalDate(2026, 11, 5));
      expect((e.localWallClock.hour, e.localWallClock.minute), (21, 0));
    });

    test('sets are unmodifiable', () {
      final e = entryAt(2026, 11, 6, 8, 0, symptoms: {Symptom.bloating});
      expect(() => e.symptoms.add(Symptom.blood), throwsUnsupportedError);
      expect(() => e.tags.add(Tag.coffee), throwsUnsupportedError);
    });

    test('value equality ignores set order', () {
      final a = entryAt(
        2026,
        11,
        6,
        8,
        0,
        id: 1,
        symptoms: {Symptom.bloating, Symptom.cramping},
      );
      final b = entryAt(
        2026,
        11,
        6,
        8,
        0,
        id: 1,
        symptoms: {Symptom.cramping, Symptom.bloating},
      );
      expect(a, b);
      expect(a.hashCode, b.hashCode);
    });

    test('toString never includes the note', () {
      final e = entryAt(2026, 11, 6, 8, 0, id: 7, comment: 'Synthetic note');
      expect(e.toString(), isNot(contains('Synthetic note')));
    });

    test('round-trips through a draft', () {
      final e = entryAt(
        2026,
        11,
        6,
        8,
        0,
        comment: 'Quiet evening',
        stoolType: 4,
        ease: Ease.easy,
        symptoms: {Symptom.none},
        tags: {Tag.coffee, Tag.afterMeal},
      );
      final d = e.toDraft();
      expect(d.occurredAtUtc, e.occurredAtUtc);
      expect(d.originalUtcOffsetMinutes, e.originalUtcOffsetMinutes);
      expect(d.comment, e.comment);
      expect(d.stoolType, 4);
      expect(d.ease, Ease.easy);
      expect(d.symptoms, {Symptom.none});
      expect(d.tags, {Tag.coffee, Tag.afterMeal});
    });
  });

  group('stored codes', () {
    test('match the schema and round-trip', () {
      expect(Ease.values.map((e) => e.code), [
        'easy',
        'some_straining',
        'difficult',
      ]);
      expect(Symptom.values.map((e) => e.code), [
        'none',
        'bloating',
        'cramping',
        'urgency',
        'mucus',
        'blood',
      ]);
      expect(Tag.values.map((e) => e.code), [
        'after_meal',
        'coffee',
        'stress',
        'low_fluids',
        'medication',
        'exercise',
      ]);
      for (final e in Ease.values) {
        expect(Ease.fromCode(e.code), e);
      }
      for (final s in Symptom.values) {
        expect(Symptom.fromCode(s.code), s);
      }
      for (final t in Tag.values) {
        expect(Tag.fromCode(t.code), t);
      }
    });

    test('unknown codes give null', () {
      expect(Ease.fromCode('unknown'), isNull);
      expect(Symptom.fromCode(''), isNull);
      expect(Tag.fromCode('Coffee'), isNull);
    });
  });

  group('uid', () {
    test('is a lower-case version 4 UUID', () {
      for (var i = 0; i < 200; i++) {
        final uid = generateUid();
        expect(isValidUid(uid), isTrue, reason: uid);
      }
    });

    test('is deterministic with a seeded source and unique otherwise', () {
      expect(generateUid(Random(1)), generateUid(Random(1)));
      final seen = {for (var i = 0; i < 1000; i++) generateUid()};
      expect(seen.length, 1000);
    });

    test('rejects other formats', () {
      expect(isValidUid('fixture-1'), isFalse);
      expect(isValidUid('3F2B8C1E-9D4A-4F6B-8E2A-1C5D7E9F0A3B'), isFalse);
      expect(isValidUid('3f2b8c1e-9d4a-1f6b-8e2a-1c5d7e9f0a3b'), isFalse);
    });
  });
}
