import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

import '../ui/gallery/ui_kit_gallery.dart';
import '../ui/theme/morrow_theme.dart';
import '../ui/theme/morrow_tokens.dart';
import '../ui/theme/morrow_typography.dart';
import '../ui/widgets/card_group.dart';
import '../ui/widgets/morrow_navigation_bar.dart';
import '../ui/widgets/setting_row.dart';
import '../ui/widgets/states.dart';

/// Root widget. Routing, bootstrap and the lock gate are added in later
/// milestones (see docs/implementation-plan.md).
class MorrowApp extends StatelessWidget {
  const MorrowApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'morrow',
      debugShowCheckedModeBanner: false,
      theme: buildMorrowTheme(),
      home: const _PlaceholderShell(),
    );
  }
}

/// Temporary shell until routing lands in M4.
class _PlaceholderShell extends StatefulWidget {
  const _PlaceholderShell();

  @override
  State<_PlaceholderShell> createState() => _PlaceholderShellState();
}

class _PlaceholderShellState extends State<_PlaceholderShell> {
  MorrowDestination _selected = MorrowDestination.journal;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(child: _body(context)),
      bottomNavigationBar: MorrowNavigationBar(
        selected: _selected,
        onSelected: (d) => setState(() => _selected = d),
      ),
    );
  }

  Widget _body(BuildContext context) {
    final text = Theme.of(context).textTheme;
    final (String title, Widget content) = switch (_selected) {
      MorrowDestination.journal => (
        'morrow',
        const EmptyState(
          title: 'Nothing here yet',
          message:
              'Add an entry whenever you’re ready. It stays on this phone.',
        ),
      ),
      MorrowDestination.history => (
        'Your history',
        const EmptyState(
          title: 'Nothing here yet',
          message: 'Your entries will appear here.',
        ),
      ),
      MorrowDestination.trends => (
        'Trends',
        const EmptyState(
          title: 'Not enough entries yet',
          message: 'Weekly summaries will appear here.',
        ),
      ),
      MorrowDestination.settings => (
        'Settings',
        kDebugMode
            ? CardGroup(
                label: 'Developer',
                children: [
                  SettingRow.navigation(
                    icon: Icons.palette_outlined,
                    title: 'UI kit preview',
                    subtitle: 'Debug builds only',
                    onTap: () => Navigator.of(context).push(
                      MaterialPageRoute<void>(
                        builder: (_) => const UiKitGallery(),
                      ),
                    ),
                  ),
                ],
              )
            : const SizedBox.shrink(),
      ),
    };

    return ListView(
      padding: const EdgeInsets.fromLTRB(24, 12, 24, 24),
      children: [
        Semantics(
          header: true,
          child: Text(
            title,
            style: _selected == MorrowDestination.journal
                ? MorrowTextStyles.of(context).wordmark
                : text.headlineLarge,
          ),
        ),
        const SizedBox(height: MorrowSpacing.xxl),
        content,
      ],
    );
  }
}
