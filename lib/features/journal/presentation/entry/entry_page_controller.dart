import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../app/providers.dart';
import '../../../../app/scope.dart';
import '../../../../core/clock.dart';
import '../../../../core/diagnostics/diagnostic_log.dart';
import '../../../../core/time/local_date.dart';
import '../../data/entry_repository.dart';
import '../../domain/entry.dart';

/// Outcome of pressing Save.
enum SaveOutcome { saved, failed, invalid, ignored }

/// The optional details of an entry.
final class EntryDetails {
  const EntryDetails({this.stoolType, this.ease, this.tags = const {}});

  factory EntryDetails.of(Entry e) =>
      EntryDetails(stoolType: e.stoolType, ease: e.ease, tags: e.tags);

  final int? stoolType;
  final Ease? ease;
  final Set<Tag> tags;

  /// True when nothing on the Context page is filled in.
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

/// The entry page's state: the stored entry plus any unsaved date, time or
/// note changes. Kept only in memory inside the unlocked scope, so unsaved
/// changes are discarded when the app locks (the entry itself is already
/// saved).
final class EntryPageState {
  const EntryPageState({
    required this.saved,
    required this.date,
    required this.hour,
    required this.minute,
    required this.hasTime,
    required this.comment,
    required this.details,
    this.timeChanged = false,
    this.commentChanged = false,
    this.saving = false,
    this.saveFailed = false,
    this.detailsFailed = false,
    this.errors = const [],
  });

  /// The entry as last stored.
  final Entry saved;

  /// Local date and wall-clock time being edited.
  final LocalDate date;
  final int hour;
  final int minute;

  /// False when the entry has no time of day ([hour] and [minute] are then
  /// only a starting point for the wheels).
  final bool hasTime;

  /// The note as typed (trimmed only when saved).
  final String comment;

  /// The optional details as shown. They save as soon as they are chosen,
  /// so they are never an unsaved change.
  final EntryDetails details;

  final bool timeChanged;
  final bool commentChanged;
  final bool saving;

  /// The last Save failed. The changes are kept so the user can try again.
  final bool saveFailed;

  /// The last detail choice could not be stored and was put back.
  final bool detailsFailed;
  final List<EntryValidationError> errors;

  /// Unsaved date, time or note changes: the button reads "Save".
  bool get hasChanges => timeChanged || commentChanged;

  /// Wall-clock fields as a [DateTime], for formatting.
  DateTime get wall =>
      DateTime.utc(date.year, date.month, date.day, hour, minute);

  EntryPageState copyWith({
    Entry? saved,
    LocalDate? date,
    int? hour,
    int? minute,
    bool? hasTime,
    String? comment,
    EntryDetails? details,
    bool? timeChanged,
    bool? commentChanged,
    bool? saving,
    bool? saveFailed,
    bool? detailsFailed,
    List<EntryValidationError>? errors,
  }) => EntryPageState(
    saved: saved ?? this.saved,
    date: date ?? this.date,
    hour: hour ?? this.hour,
    minute: minute ?? this.minute,
    hasTime: hasTime ?? this.hasTime,
    comment: comment ?? this.comment,
    details: details ?? this.details,
    timeChanged: timeChanged ?? this.timeChanged,
    commentChanged: commentChanged ?? this.commentChanged,
    saving: saving ?? this.saving,
    saveFailed: saveFailed ?? this.saveFailed,
    detailsFailed: detailsFailed ?? this.detailsFailed,
    errors: errors ?? this.errors,
  );
}

/// What the entry page shows: a stored entry, and whether it was just added
/// by "Add an entry" (which shows the Undo banner).
typedef EntryTarget = ({Entry entry, bool isNew});

/// View model for the entry page: one page to view and change an entry.
class EntryPageController extends Notifier<EntryPageState> {
  EntryPageController(this.target);

  final EntryTarget target;

  /// Detail writes run one at a time, in order, and Save waits for them.
  Future<void> _writes = Future.value();

  /// True once something on this page has been stored (a detail choice).
  bool _storedChange = false;

  Clock get _clock => ref.read(clockProvider);
  EntryRepository get _repo => ref.read(entryRepositoryProvider);

  @override
  EntryPageState build() => _fromSaved(target.entry);

  EntryPageState _fromSaved(Entry e) {
    final wall = e.localTime ?? _clock.nowLocalWall();
    return EntryPageState(
      saved: e,
      date: e.localDate,
      hour: wall.hour,
      minute: wall.minute,
      hasTime: e.hasTime,
      comment: e.comment ?? '',
      details: EntryDetails.of(e),
    );
  }

  /// True when the entry has been changed since the page opened, stored or
  /// not. Undo then asks first.
  bool get edited => state.hasChanges || _storedChange;

  // Date, time and note: unsaved until Save.

  void setComment(String value) {
    state = state.copyWith(
      comment: value,
      commentChanged: value != (state.saved.comment ?? ''),
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
    final o = state.saved;
    final unchanged =
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
      timeChanged: !unchanged,
      errors: const [],
    );
  }

  /// Stores the date, time and note changes. Ignored while a save is
  /// running, so a double tap saves once. Reports success only after the
  /// database commit.
  Future<SaveOutcome> save() async {
    if (state.saving || !state.hasChanges) return SaveOutcome.ignored;
    state = state.copyWith(saving: true, saveFailed: false, errors: const []);
    await _writes;
    if (!ref.mounted) return SaveOutcome.ignored;
    final o = state.saved;
    // Keep the stored instant and offset unless the time was changed, so an
    // entry recorded in another time zone keeps its meaning.
    final ({DateTime utc, int offsetMinutes}) time = state.timeChanged
        ? _clock.resolveLocal(
            state.date.year,
            state.date.month,
            state.date.day,
            state.hasTime ? state.hour : dateOnlyHour,
            state.hasTime ? state.minute : 0,
          )
        : (utc: o.occurredAtUtc, offsetMinutes: o.originalUtcOffsetMinutes);
    // Details come from the stored entry: they are saved as chosen, and
    // values hidden by a setting are kept unchanged.
    final draft = EntryDraft(
      occurredAtUtc: time.utc,
      originalUtcOffsetMinutes: time.offsetMinutes,
      hasTime: state.hasTime,
      comment: state.comment,
      stoolType: o.stoolType,
      ease: o.ease,
      tags: o.tags,
    );
    try {
      final stored = await _repo.update(o.id, draft);
      if (ref.mounted) state = _fromSaved(stored);
      return SaveOutcome.saved;
    } on EntryValidationException catch (e) {
      if (ref.mounted) state = state.copyWith(saving: false, errors: e.errors);
      return SaveOutcome.invalid;
    } on Object {
      _log(DiagnosticEvent.entrySaveFailed);
      if (ref.mounted) state = state.copyWith(saving: false, saveFailed: true);
      return SaveOutcome.failed;
    }
  }

  // Optional details: stored as soon as they are chosen.

  /// Chooses a stool form type, or clears it if [type] is already chosen.
  Future<bool> toggleStoolType(int type) {
    final d = state.details;
    return _setDetails(
      EntryDetails(
        stoolType: d.stoolType == type ? null : type,
        ease: d.ease,
        tags: d.tags,
      ),
    );
  }

  /// Chooses how it felt, or clears it if already chosen.
  Future<bool> toggleEase(Ease ease) {
    final d = state.details;
    return _setDetails(
      EntryDetails(
        stoolType: d.stoolType,
        ease: d.ease == ease ? null : ease,
        tags: d.tags,
      ),
    );
  }

  Future<bool> toggleTag(Tag tag) {
    final d = state.details;
    final next = {...d.tags};
    if (!next.remove(tag)) next.add(tag);
    return _setDetails(
      EntryDetails(stoolType: d.stoolType, ease: d.ease, tags: next),
    );
  }

  /// "Clear" on the Context page: removes ease and tags.
  Future<bool> clearContext() =>
      _setDetails(EntryDetails(stoolType: state.details.stoolType));

  /// "Clear" on the Stool form page.
  Future<bool> clearStoolForm() => _setDetails(
    EntryDetails(ease: state.details.ease, tags: state.details.tags),
  );

  /// Shows [d] straight away and stores it. If storing fails, the stored
  /// details are put back and [EntryPageState.detailsFailed] is set.
  Future<bool> _setDetails(EntryDetails d) {
    if (d == state.details) return Future.value(true);
    state = state.copyWith(details: d, detailsFailed: false);
    final id = state.saved.id;
    final result = _writes.then((_) async {
      try {
        final stored = await _repo.updateDetails(
          id,
          stoolType: d.stoolType,
          ease: d.ease,
          tags: d.tags,
        );
        _storedChange = true;
        if (ref.mounted) state = state.copyWith(saved: stored);
        return true;
      } on Object {
        _log(DiagnosticEvent.entryDetailFailed);
        if (ref.mounted) {
          state = state.copyWith(
            details: EntryDetails.of(state.saved),
            detailsFailed: true,
          );
        }
        return false;
      }
    });
    _writes = result;
    return result;
  }

  /// Undo for a just-added entry: deletes it. True when it is gone.
  Future<bool> undo() async {
    await _writes;
    try {
      await _repo.delete(state.saved.id);
    } on EntryNotFoundException {
      // Already gone.
    } on Object {
      _log(DiagnosticEvent.entryUndoFailed);
      return false;
    }
    return true;
  }

  void _log(DiagnosticEvent e) => ref.read(diagnosticLogProvider).record(e);
}

/// One controller per entry page. Scoped to the unlocked session and
/// disposed when the page closes.
final entryPageProvider = NotifierProvider.autoDispose
    .family<EntryPageController, EntryPageState, EntryTarget>(
      EntryPageController.new,
      dependencies: [entryRepositoryProvider],
    );

/// The stored entry with [id], read once when its page opens (null if it no
/// longer exists).
final entryByIdProvider = FutureProvider.autoDispose.family<Entry?, int>(
  (ref, id) => ref.read(entryRepositoryProvider).byId(id),
  dependencies: [entryRepositoryProvider],
);
