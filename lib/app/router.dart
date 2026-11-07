import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../core/diagnostics/encryption_self_check.dart';
import '../features/journal/presentation/history_screen.dart';
import '../features/journal/presentation/journal_screen.dart';
import '../features/settings/presentation/settings_screen.dart';
import '../features/trends/presentation/trends_screen.dart';
import '../ui/gallery/ui_kit_gallery.dart';
import '../ui/widgets/morrow_navigation_bar.dart';
import 'debug/self_check_screen.dart';

/// Top-level paths, in bottom navigation order.
abstract final class AppPaths {
  static const String journal = '/journal';
  static const String history = '/history';
  static const String trends = '/trends';
  static const String settings = '/settings';
}

/// Builds the router for one unlocked session. It is created inside the
/// unlocked scope and thrown away with it, so no sensitive route exists while
/// the app is locked or the journal is blocked. Route paths and parameters
/// never carry journal content.
GoRouter buildAppRouter({String initialLocation = AppPaths.journal}) {
  return GoRouter(
    initialLocation: initialLocation,
    routes: [
      StatefulShellRoute.indexedStack(
        builder: (context, state, shell) => AppShell(shell: shell),
        branches: [
          StatefulShellBranch(
            routes: [
              GoRoute(
                path: AppPaths.journal,
                builder: (_, _) => const JournalScreen(),
              ),
            ],
          ),
          StatefulShellBranch(
            routes: [
              GoRoute(
                path: AppPaths.history,
                builder: (_, _) => const HistoryScreen(),
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
