import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../core/database/app_database.dart';
import '../features/journal/data/entry_repository.dart';
import 'providers.dart';

// Sensitive providers. They declare `dependencies`, which marks them as
// scoped: they only work inside [UnlockedScope], which overrides
// [appDatabaseProvider] with the open journal. Reading one anywhere else
// throws, so nothing sensitive can be read while locked or blocked.
//
// Rule for new providers: anything that reads journal data must depend on
// [appDatabaseProvider] (directly or through another sensitive provider) and
// list it in `dependencies`.

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
