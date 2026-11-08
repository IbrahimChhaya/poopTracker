import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../app/paths.dart';
import '../../../../app/providers.dart';
import '../../../../app/scope.dart';
import '../../../../core/clock.dart';
import '../../../../core/time/local_date.dart';
import '../../../../ui/widgets/overlays.dart';
import '../../domain/entry.dart';

/// State of the one-tap "Add an entry" button.
typedef QuickAddState = ({bool adding, bool failed});

/// "Add an entry" saves straight away (2.1, 2.2): an entry for today records
/// the current time; an entry for a past day has no time. Nothing else is
/// asked for.
class QuickAddController extends Notifier<QuickAddState> {
  @override
  QuickAddState build() => (adding: false, failed: false);

  /// Saves a new entry on [day] (today if null or not in the past). Returns
  /// null, without saving twice, while an add is already running, so a
  /// double tap creates one entry. Returns null after a failure, with
  /// [QuickAddState.failed] set.
  Future<Entry?> add({LocalDate? day}) async {
    if (state.adding) return null;
    state = (adding: true, failed: false);
    final clock = ref.read(clockProvider);
    final today = clock.today();
    final pastDay = day != null && day.isBefore(today) ? day : null;
    final time = pastDay == null
        ? (utc: clock.nowUtc(), offsetMinutes: clock.currentUtcOffsetMinutes())
        : clock.resolveLocal(
            pastDay.year,
            pastDay.month,
            pastDay.day,
            dateOnlyHour,
            0,
          );
    try {
      final entry = await ref
          .read(entryRepositoryProvider)
          .create(
            EntryDraft(
              occurredAtUtc: time.utc,
              originalUtcOffsetMinutes: time.offsetMinutes,
              hasTime: pastDay == null,
            ),
          );
      if (ref.mounted) state = (adding: false, failed: false);
      return entry;
    } on Object {
      if (ref.mounted) state = (adding: false, failed: true);
      return null;
    }
  }
}

final quickAddProvider = NotifierProvider<QuickAddController, QuickAddState>(
  QuickAddController.new,
  dependencies: [entryRepositoryProvider],
);

/// In-memory route data for the entry page: the entry's id, and whether it
/// was just added (which shows Undo). Never part of a route path.
typedef EntryRoute = ({int id, bool isNew});

/// Opens the entry page for an existing entry.
void openEntryPage(BuildContext context, int id) =>
    context.push(AppPaths.entry, extra: (id: id, isNew: false));

/// Adds an entry and opens it. With [toastOnFailure] a failure is reported
/// with a toast (where the screen shows no error banner).
Future<void> addEntryAndOpen(
  BuildContext context,
  WidgetRef ref, {
  LocalDate? day,
  bool toastOnFailure = false,
}) async {
  final entry = await ref.read(quickAddProvider.notifier).add(day: day);
  if (!context.mounted) return;
  if (entry == null) {
    if (toastOnFailure && ref.read(quickAddProvider).failed) {
      showMorrowToast(context, 'Couldn’t add an entry. Nothing was saved.');
    }
    return;
  }
  await context.push(AppPaths.entry, extra: (id: entry.id, isNew: true));
}
