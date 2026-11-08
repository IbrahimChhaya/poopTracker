import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../app/providers.dart';
import '../../../../app/scope.dart';
import '../../../../core/clock.dart';
import '../../../../core/time/local_date.dart';
import '../../data/entry_repository.dart';
import '../../domain/entry.dart';

/// Outcome of pressing save.
enum SaveOutcome { saved, failed, invalid, ignored }

/// The editor's draft. Kept only in memory, inside the unlocked scope, so it
/// is discarded when the session ends (see the draft policy in the plan).
final class EntryEditorState {
  const EntryEditorState({
    required this.date,
    required this.hour,
    required this.minute,
    required this.comment,
    required this.timeChanged,
    required this.commentChanged,
    this.hasTime = true,
    this.details = const EntryDetails(),
    this.detailsChanged = false,
    this.saving = false,
    this.saveFailed = false,
    this.errors = const [],
  });

  /// Local date and wall-clock time of the entry.
  final LocalDate date;
  final int hour;
  final int minute;

  /// The note as typed (trimmed only when saved).
  final String comment;
  final bool timeChanged;
  final bool commentChanged;

  /// False when the entry has no time of day ([hour] and [minute] are then
  /// only a starting point for the wheels).
  final bool hasTime;
  final bool saving;

  /// The last save failed. The draft is kept so the user can try again.
  final bool saveFailed;
  final List<EntryValidationError> errors;

  /// Optional details. Kept even while their setting is off, so saving
  /// never drops stored values the user cannot currently see.
  final EntryDetails details;
  final bool detailsChanged;

  bool get hasChanges => timeChanged || commentChanged || detailsChanged;

  /// Wall-clock fields as a [DateTime], for formatting.
  DateTime get wall =>
      DateTime.utc(date.year, date.month, date.day, hour, minute);

  EntryEditorState copyWith({
    LocalDate? date,
    int? hour,
    int? minute,
    String? comment,
    bool? timeChanged,
    bool? commentChanged,
    bool? hasTime,
    EntryDetails? details,
    bool? detailsChanged,
    bool? saving,
    bool? saveFailed,
    List<EntryValidationError>? errors,
  }) => EntryEditorState(
    date: date ?? this.date,
    hour: hour ?? this.hour,
    minute: minute ?? this.minute,
    comment: comment ?? this.comment,
    timeChanged: timeChanged ?? this.timeChanged,
    commentChanged: commentChanged ?? this.commentChanged,
    hasTime: hasTime ?? this.hasTime,
    details: details ?? this.details,
    detailsChanged: detailsChanged ?? this.detailsChanged,
    saving: saving ?? this.saving,
    saveFailed: saveFailed ?? this.saveFailed,
    errors: errors ?? this.errors,
  );
}

/// The optional details of a draft.
final class EntryDetails {
  const EntryDetails({this.stoolType, this.ease, this.tags = const {}});

  factory EntryDetails.of(Entry e) =>
      EntryDetails(stoolType: e.stoolType, ease: e.ease, tags: e.tags);

  final int? stoolType;
  final Ease? ease;
  final Set<Tag> tags;

  /// True when nothing on the "A little context" step is filled in.
  bool get contextEmpty => ease == null && tags.isEmpty;

  @override
  bool operator ==(Object other) =>
      other is EntryDetails &&
      other.stoolType == stoolType &&
      other.ease == ease &&
      other.tags.length == tags.length &&
      other.tags.containsAll(tags);

  @override
  int get hashCode =>
      Object.hash(stoolType, ease, Object.hashAllUnordered(tags));
}

/// What the editor opens: an existing entry, or a new entry, optionally on
/// a chosen day (for example the day selected on the journal home).
typedef EditorTarget = ({Entry? original, LocalDate? initialDate});

/// View model for adding ([original] null) or editing an entry.
class EntryEditorController extends Notifier<EntryEditorState> {
  EntryEditorController(this.target);

  final EditorTarget target;

  /// The saved entry being edited, or null for a new entry.
  Entry? get original => target.original;

  /// True while a new entry still means "exactly now".
  bool _isExactlyNow = false;

  Clock get _clock => ref.read(clockProvider);

  @override
  EntryEditorState build() {
    final o = original;
    if (o == null) {
      final now = _clock.nowLocalWall();
      final today = LocalDate(now.year, now.month, now.day);
      final day = target.initialDate;
      // Today defaults to now. A chosen past day has no time unless the
      // user adds one: the current time of day would be a guess.
      final useDay = day != null && day.isBefore(today);
      _isExactlyNow = !useDay;
      return EntryEditorState(
        date: useDay ? day : today,
        hour: now.hour,
        minute: now.minute,
        hasTime: !useDay,
        comment: '',
        timeChanged: false,
        commentChanged: false,
      );
    }
    final wall = o.localTime ?? _clock.nowLocalWall();
    return EntryEditorState(
      date: o.localDate,
      hour: wall.hour,
      minute: wall.minute,
      hasTime: o.hasTime,
      comment: o.comment ?? '',
      timeChanged: false,
      commentChanged: false,
      details: EntryDetails.of(o),
    );
  }

  EntryDetails get _initialDetails {
    final o = original;
    return o == null ? const EntryDetails() : EntryDetails.of(o);
  }

  void _setDetails(EntryDetails d) => state = state.copyWith(
    details: d,
    detailsChanged: d != _initialDetails,
    errors: const [],
  );

  /// Chooses a stool form type, or clears it if [type] is already chosen.
  void toggleStoolType(int type) {
    final d = state.details;
    _setDetails(
      EntryDetails(
        stoolType: d.stoolType == type ? null : type,
        ease: d.ease,
        tags: d.tags,
      ),
    );
  }

  /// Chooses how it felt, or clears it if already chosen.
  void toggleEase(Ease ease) {
    final d = state.details;
    _setDetails(
      EntryDetails(
        stoolType: d.stoolType,
        ease: d.ease == ease ? null : ease,
        tags: d.tags,
      ),
    );
  }

  void toggleTag(Tag tag) {
    final d = state.details;
    final next = {...d.tags};
    if (!next.remove(tag)) next.add(tag);
    _setDetails(EntryDetails(stoolType: d.stoolType, ease: d.ease, tags: next));
  }

  bool get isEditing => original != null;

  void setComment(String value) {
    final initial = original?.comment ?? '';
    state = state.copyWith(
      comment: value,
      commentChanged: value != initial,
      errors: const [],
    );
  }

  /// True when [date] (at [hour]:[minute] if [hasTime]) has not happened yet.
  /// Without a time only the day counts, so today is always allowed.
  bool isInFuture(LocalDate date, int hour, int minute, {bool hasTime = true}) {
    if (!hasTime) return date.isAfter(_clock.today());
    final r = _clock.resolveLocal(
      date.year,
      date.month,
      date.day,
      hour,
      minute,
    );
    return r.utc.isAfter(_clock.nowUtc().add(futureTolerance));
  }

  void setDateTime(
    LocalDate date,
    int hour,
    int minute, {
    bool hasTime = true,
  }) {
    final o = original;
    final unchanged =
        o != null &&
        date == o.localDate &&
        hasTime == o.hasTime &&
        (!hasTime ||
            (hour == o.localWallClock.hour &&
                minute == o.localWallClock.minute));
    state = state.copyWith(
      date: date,
      hour: hour,
      minute: minute,
      hasTime: hasTime,
      timeChanged: o == null ? true : !unchanged,
      errors: const [],
    );
    if (o == null) _isExactlyNow = false;
  }

  /// Saves the draft. Ignored while a save is already running, so a double
  /// tap creates one entry. Reports success only after the database commit.
  Future<SaveOutcome> save() async {
    if (state.saving) return SaveOutcome.ignored;
    state = state.copyWith(saving: true, saveFailed: false, errors: const []);
    final draft = _toDraft();
    final repo = ref.read(entryRepositoryProvider);
    try {
      final o = original;
      if (o == null) {
        await repo.create(draft);
      } else {
        await repo.update(o.id, draft);
      }
    } on EntryValidationException catch (e) {
      if (ref.mounted) state = state.copyWith(saving: false, errors: e.errors);
      return SaveOutcome.invalid;
    } on Object {
      if (ref.mounted) state = state.copyWith(saving: false, saveFailed: true);
      return SaveOutcome.failed;
    }
    if (ref.mounted) state = state.copyWith(saving: false);
    return SaveOutcome.saved;
  }

  EntryDraft _toDraft() {
    final o = original;
    // Keep the original instant and offset unless the time was changed, so
    // an entry recorded in another time zone keeps its meaning.
    final ({DateTime utc, int offsetMinutes}) time;
    if (o != null && !state.timeChanged) {
      time = (utc: o.occurredAtUtc, offsetMinutes: o.originalUtcOffsetMinutes);
    } else if (o == null && _isExactlyNow) {
      time = (
        utc: _clock.nowUtc(),
        offsetMinutes: _clock.currentUtcOffsetMinutes(),
      );
    } else {
      time = _clock.resolveLocal(
        state.date.year,
        state.date.month,
        state.date.day,
        state.hasTime ? state.hour : dateOnlyHour,
        state.hasTime ? state.minute : 0,
      );
    }
    // Details hidden by a setting are still in the draft, unchanged.
    final d = state.details;
    return EntryDraft(
      occurredAtUtc: time.utc,
      originalUtcOffsetMinutes: time.offsetMinutes,
      hasTime: state.hasTime,
      comment: state.comment,
      stoolType: d.stoolType,
      ease: d.ease,
      tags: d.tags,
    );
  }
}

/// One editor per target (records compare by value). Scoped to the
/// unlocked session and disposed when its screen closes.
final entryEditorProvider = NotifierProvider.autoDispose
    .family<EntryEditorController, EntryEditorState, EditorTarget>(
      EntryEditorController.new,
      dependencies: [entryRepositoryProvider],
    );
