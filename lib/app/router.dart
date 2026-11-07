import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../core/diagnostics/encryption_self_check.dart';
import '../core/time/local_date.dart';
import '../features/journal/presentation/editor/entry_editor_screen.dart';
import '../features/journal/presentation/entry_detail_screen.dart';
import '../features/journal/presentation/history_screen.dart';
import '../features/journal/presentation/journal_screen.dart';
import '../features/settings/presentation/settings_screen.dart';
import '../features/trends/presentation/trends_screen.dart';
import '../ui/gallery/ui_kit_gallery.dart';
import '../ui/widgets/morrow_navigation_bar.dart';
import 'debug/self_check_screen.dart';
import 'paths.dart';

/// Builds the router for one unlocked session. It is created inside the
/// unlocked scope and thrown away with it, so no sensitive route exists while
/// the app is locked or the journal is blocked. Route paths and parameters
/// never carry journal content.
GoRouter buildAppRouter({String initialLocation = AppPaths.journal}) {
  return GoRouter(
    initialLocation: initialLocation,
    routes: [
      // Full-screen editor above the tab bar (no bottom navigation).
      GoRoute(
        path: AppPaths.newEntry,
        builder: (_, state) => NewEntryScreen(
          initialDate: state.extra is LocalDate
              ? state.extra! as LocalDate
              : null,
        ),
      ),
      GoRoute(
        path: AppPaths.editEntry,
        builder: (_, state) => EditEntryScreen(entryId: _entryId(state)),
      ),
      StatefulShellRoute.indexedStack(
        builder: (context, state, shell) => AppShell(shell: shell),
        branches: [
          StatefulShellBranch(
            routes: [
              GoRoute(
                path: AppPaths.journal,
                builder: (_, _) => const JournalScreen(),
                routes: [
                  GoRoute(
                    path: 'entry',
                    builder: (_, state) =>
                        EntryDetailScreen(entryId: _entryId(state)),
                  ),
                ],
              ),
            ],
          ),
          StatefulShellBranch(
            routes: [
              GoRoute(
                path: AppPaths.history,
                builder: (_, _) => const HistoryScreen(),
                routes: [
                  GoRoute(
                    path: 'entry',
                    builder: (_, state) =>
                        EntryDetailScreen(entryId: _entryId(state)),
                  ),
                ],
              ),
            ],
          ),
          StatefulShellBranch(
            routes: [
              GoRoute(
                path: AppPaths.trends,
                builder: (_, _) => const TrendsScreen(),
              ),
            ],
          ),
          StatefulShellBranch(
            routes: [
              GoRoute(
                path: AppPaths.settings,
                builder: (_, _) => const SettingsScreen(),
                routes: [
                  if (kDebugMode)
                    GoRoute(
                      path: 'ui-kit',
                      builder: (_, _) => const UiKitGallery(),
                    ),
                  if (kDebugMode || diagnosticsEnabled)
                    GoRoute(
                      path: 'self-check',
                      builder: (_, _) => const SelfCheckScreen(),
                    ),
                ],
              ),
            ],
          ),
        ],
      ),
    ],
  );
}

/// The entry id passed as in-memory route data. Null if missing (for
/// example after the app was restored by the OS), in which case the screen
/// closes itself.
int? _entryId(GoRouterState state) =>
    state.extra is int ? state.extra! as int : null;

/// The bottom-navigation shell around the four tabs.
class AppShell extends StatelessWidget {
  const AppShell({required this.shell, super.key});

  final StatefulNavigationShell shell;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: shell,
      bottomNavigationBar: MorrowNavigationBar(
        selected: MorrowDestination.values[shell.currentIndex],
        // Tapping the current tab again returns to its first page.
        onSelected: (d) => shell.goBranch(
          d.index,
          initialLocation: d.index == shell.currentIndex,
        ),
      ),
    );
  }
}
