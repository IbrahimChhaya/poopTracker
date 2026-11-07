import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../core/database/app_database.dart';
import '../features/journal/data/entry_repository.dart';
import '../features/journal/domain/entry.dart';
import 'providers.dart';

// Sensitive providers. They declare `dependencies`, which marks them as
// scoped: they only work inside [UnlockedScope], which overrides
// [appDatabaseProvider] with the open journal. Reading one anywhere else
// throws, so nothing sensitive can be read while locked or blocked.
//
// Rule for new providers: anything that reads journal data, or holds state
// for the session (drafts, selections, search text), must list
// [appDatabaseProvider] or another sensitive provider in `dependencies`.
// Riverpod then creates it inside the unlocked scope, so it is disposed when
// the session ends.

/// Thrown when a sensitive provider is read outside the unlocked scope.
class OutsideUnlockedScopeError extends StateError {
  OutsideUnlockedScopeError()
    : super('Journal data is only available inside the unlocked scope');
}

/// The open journal database for this session.
final appDatabaseProvider = Provider<AppDatabase>(
  (ref) => throw OutsideUnlockedScopeError(),
  dependencies: const [],
);

final entryRepositoryProvider = Provider<EntryRepository>(
  (ref) =>
      EntryRepository(ref.watch(appDatabaseProvider), ref.watch(clockProvider)),
  dependencies: [appDatabaseProvider],
);

/// Every entry, newest first, kept up to date. The journal, History and
/// entry screens all derive from this one stream.
final entriesProvider = StreamProvider<List<Entry>>(
  (ref) => ref.watch(entryRepositoryProvider).watchAll(),
  dependencies: [entryRepositoryProvider],
);

/// Holds the sensitive providers for one unlocked session. Removing this
/// widget (on lock or when the journal is closed) disposes all of them.
class UnlockedScope extends StatelessWidget {
  const UnlockedScope({required this.database, required this.child, super.key});

  final AppDatabase database;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return ProviderScope(
      overrides: [appDatabaseProvider.overrideWithValue(database)],
      child: child,
    );
  }
}
