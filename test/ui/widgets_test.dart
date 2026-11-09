import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:poop_tracker/core/time/local_date.dart';
import 'package:poop_tracker/ui/widgets/card_group.dart';
import 'package:poop_tracker/ui/widgets/morrow_button.dart';
import 'package:poop_tracker/ui/widgets/morrow_chip.dart';
import 'package:poop_tracker/ui/widgets/morrow_navigation_bar.dart';
import 'package:poop_tracker/ui/widgets/overlays.dart';
import 'package:poop_tracker/ui/widgets/setting_row.dart';
import 'package:poop_tracker/ui/widgets/states.dart';
import 'package:poop_tracker/ui/widgets/week_strip.dart';

import '../support/harness.dart';

final List<WeekStripDay> _week = [
  for (var d = 2; d <= 8; d++)
    WeekStripDay(
      date: LocalDate(2026, 11, d),
      hasEntries: d <= 6,
      isToday: d == 6,
    ),
];

void main() {
  group('MorrowButton', () {
    testWidgets('busy state blocks repeat taps and shows the busy label', (
      tester,
    ) async {
      var taps = 0;
      var busy = false;
      await pumpThemed(
        tester,
        page(
          StatefulBuilder(
            builder: (context, setState) => MorrowButton(
              label: 'Save entry',
              busyLabel: 'Saving…',
              busy: busy,
              onPressed: () => setState(() {
                taps++;
                busy = true;
              }),
            ),
          ),
        ),
      );

      await tester.tap(find.text('Save entry'));
      await tester.pump();
      expect(find.text('Saving…'), findsOneWidget);
      await tester.tap(find.text('Saving…'), warnIfMissed: false);
      await tester.pump();

      expect(taps, 1);
      expect(
        tester.getSemantics(find.byType(FilledButton)),
        isSemantics(label: 'Saving…', isButton: true, isEnabled: false),
      );
    });

    for (final variant in MorrowButtonVariant.values) {
      testWidgets('$variant is an enabled, labelled button', (tester) async {
        await pumpThemed(
          tester,
          page(MorrowButton(label: 'Go', variant: variant, onPressed: () {})),
        );
        expect(
          tester.getSemantics(find.text('Go')),
          isSemantics(label: 'Go', isButton: true, isEnabled: true),
        );
      });
    }
  });

  group('SettingRow', () {
    testWidgets('a text action is read with the row: "Time, 6:00 pm"', (
      tester,
    ) async {
      await pumpThemed(
        tester,
        page(
          CardGroup(
            children: [
              SettingRow.navigation(
                icon: Icons.schedule,
                title: 'Time',
                subtitle: 'Follows your phone’s local time',
                actionLabel: '6:00 pm',
                onTap: () {},
              ),
            ],
          ),
        ),
      );
      expect(
        find.bySemanticsLabel(RegExp(r'Time[\s\S]*6:00 pm')),
        findsOneWidget,
      );
    });

    testWidgets('a switch row does not repeat On or Off', (tester) async {
      await pumpThemed(
        tester,
        page(
          CardGroup(
            children: [
              SettingRow.toggle(
                icon: Icons.lock_outline,
                title: 'Require unlock',
                subtitle: 'On',
                value: true,
                onChanged: (_) {},
              ),
            ],
          ),
        ),
      );
      expect(find.bySemanticsLabel(RegExp(r'On')), findsNothing);
    });

    testWidgets('toggle row announces title, subtitle and state, and the '
        'whole row toggles', (tester) async {
      var value = false;
      await pumpThemed(
        tester,
        page(
          StatefulBuilder(
            builder: (context, setState) => CardGroup(
              label: 'Journal',
              children: [
                SettingRow.toggle(
                  icon: Icons.notes,
                  title: 'Example setting',
                  subtitle: 'Shows an optional step.',
                  value: value,
                  onChanged: (v) => setState(() => value = v),
                ),
              ],
            ),
          ),
        ),
      );

      final node = tester.getSemantics(find.byType(SettingRow));
      expect(
        node,
        isSemantics(
          label: 'Example setting\nShows an optional step.',
          hasToggledState: true,
          isToggled: false,
          hasTapAction: true,
        ),
      );

      await tester.tap(find.text('Example setting'));
      await tester.pump();
      expect(value, isTrue);
      expect(
        tester.getSemantics(find.byType(SettingRow)),
        isSemantics(hasToggledState: true, isToggled: true),
      );
    });

    testWidgets('navigation row is a button and reports taps', (tester) async {
      var taps = 0;
      await pumpThemed(
        tester,
        page(
          CardGroup(
            children: [
              SettingRow.navigation(
                icon: Icons.lock_outline,
                title: 'App lock',
                subtitle: 'Off',
                onTap: () => taps++,
              ),
            ],
          ),
        ),
      );
      expect(
        tester.getSemantics(find.byType(SettingRow)),
        isSemantics(label: 'App lock\nOff', isButton: true, hasTapAction: true),
      );
      await tester.tap(find.text('App lock'));
      expect(taps, 1);
    });

    testWidgets('group label is a heading', (tester) async {
      await pumpThemed(
        tester,
        page(
          CardGroup(
            label: 'Privacy',
            children: [
              SettingRow.navigation(
                icon: Icons.lock_outline,
                title: 'App lock',
                onTap: () {},
              ),
            ],
          ),
        ),
      );
      expect(
        tester.getSemantics(find.text('Privacy')),
        isSemantics(label: 'Privacy', isHeader: true),
      );
    });
  });

  group('WeekStrip', () {
    testWidgets('labels days with date, today and entries', (tester) async {
      await pumpThemed(
        tester,
        page(WeekStrip(days: _week, onSelected: (_) {})),
      );
      expect(
        find.bySemanticsLabel('Friday 6 November, today, has entries'),
        findsOneWidget,
      );
      expect(
        find.bySemanticsLabel('Sunday 8 November, no entries'),
        findsOneWidget,
      );
    });

    testWidgets('selected day is exposed as selected', (tester) async {
      await pumpThemed(
        tester,
        page(
          WeekStrip(
            days: _week,
            selected: LocalDate(2026, 11, 4),
            onSelected: (_) {},
          ),
        ),
      );
      expect(
        tester.getSemantics(
          find.bySemanticsLabel('Wednesday 4 November, has entries'),
        ),
        isSemantics(isSelected: true, isButton: true),
      );
      expect(
        tester.getSemantics(
          find.bySemanticsLabel('Tuesday 3 November, has entries'),
        ),
        isSemantics(isSelected: false),
      );
    });

    testWidgets('tapping anywhere in a day reports its date', (tester) async {
      LocalDate? tapped;
      await pumpThemed(
        tester,
        page(WeekStrip(days: _week, onSelected: (d) => tapped = d)),
      );
      await tester.tap(find.text('5'));
      expect(tapped, LocalDate(2026, 11, 5));
    });

    test('rejects a week that is not seven days', () {
      expect(
        () => WeekStrip(days: _week.sublist(1), onSelected: (_) {}),
        throwsAssertionError,
      );
    });
  });

  group('MorrowChip', () {
    testWidgets('selection is exposed to screen readers', (tester) async {
      await pumpThemed(
        tester,
        page(
          ChipWrap(
            children: [
              MorrowChip(label: 'Easy', selected: true, onSelected: (_) {}),
              MorrowChip(
                label: 'Difficult',
                selected: false,
                onSelected: (_) {},
              ),
            ],
          ),
        ),
      );
      expect(
        tester.getSemantics(find.text('Easy')),
        isSemantics(label: 'Easy', isSelected: true),
      );
      expect(
        tester.getSemantics(find.text('Difficult')),
        isSemantics(label: 'Difficult', isSelected: false),
      );
    });
  });

  group('MorrowNavigationBar', () {
    testWidgets('marks the selected destination and reports taps', (
      tester,
    ) async {
      MorrowDestination? tapped;
      await pumpThemed(
        tester,
        Scaffold(
          bottomNavigationBar: MorrowNavigationBar(
            selected: MorrowDestination.journal,
            onSelected: (d) => tapped = d,
          ),
        ),
      );
      expect(
        tester.getSemantics(find.text('Journal')),
        isSemantics(isSelected: true),
      );
      await tester.tap(find.text('Trends'));
      expect(tapped, MorrowDestination.trends);
    });
  });

  group('states', () {
    testWidgets('error banner is a live region', (tester) async {
      await pumpThemed(
        tester,
        page(
          const ErrorBanner(
            title: 'Couldn’t save your entry',
            message: 'Your draft is still here.',
          ),
        ),
      );
      expect(
        tester.getSemantics(find.byType(ErrorBanner)),
        isSemantics(isLiveRegion: true),
      );
    });

    testWidgets('loading state announces its label', (tester) async {
      await pumpThemed(tester, page(const LoadingState(label: 'Loading…')));
      expect(
        tester.getSemantics(find.byType(LoadingState)),
        isSemantics(label: 'Loading…', isLiveRegion: true),
      );
    });
  });

  group('overlays', () {
    Future<Future<bool>> openDialog(WidgetTester tester) async {
      late Future<bool> result;
      await pumpThemed(
        tester,
        Scaffold(
          body: Builder(
            builder: (context) => TextButton(
              onPressed: () => result = showMorrowConfirmDialog(
                context,
                title: 'Discard this entry?',
                message: 'You haven’t saved it yet.',
                confirmLabel: 'Discard',
                cancelLabel: 'Keep editing',
                destructive: true,
              ),
              child: const Text('Open'),
            ),
          ),
        ),
      );
      await tester.tap(find.text('Open'));
      await tester.pumpAndSettle();
      return result;
    }

    testWidgets('destructive dialog puts the safe choice first', (
      tester,
    ) async {
      await openDialog(tester);
      final keep = tester.getTopLeft(find.text('Keep editing'));
      final discard = tester.getTopLeft(find.text('Discard'));
      expect(keep.dy, lessThan(discard.dy));
    });

    testWidgets('dialog completes true only on confirm', (tester) async {
      var result = await openDialog(tester);
      await tester.tap(find.text('Discard'));
      await tester.pumpAndSettle();
      expect(await result, isTrue);

      result = await openDialog(tester);
      await tester.tap(find.text('Keep editing'));
      await tester.pumpAndSettle();
      expect(await result, isFalse);
    });

    testWidgets('dismissing the dialog counts as cancel', (tester) async {
      final result = await openDialog(tester);
      await tester.tapAt(const Offset(10, 10));
      await tester.pumpAndSettle();
      expect(await result, isFalse);
    });

    testWidgets('sheet shows a heading and its content', (tester) async {
      await pumpThemed(
        tester,
        Scaffold(
          body: Builder(
            builder: (context) => TextButton(
              onPressed: () => showMorrowSheet<void>(
                context,
                title: 'Filter entries',
                builder: (_) => const Text('Last 4 weeks'),
              ),
              child: const Text('Open'),
            ),
          ),
        ),
      );
      await tester.tap(find.text('Open'));
      await tester.pumpAndSettle();
      expect(
        tester.getSemantics(find.text('Filter entries')),
        isSemantics(isHeader: true),
      );
      expect(find.text('Last 4 weeks'), findsOneWidget);
    });

    testWidgets('toast shows its message', (tester) async {
      await pumpThemed(
        tester,
        Scaffold(
          body: Builder(
            builder: (context) => TextButton(
              onPressed: () => showMorrowToast(context, 'Entry saved'),
              child: const Text('Open'),
            ),
          ),
        ),
      );
      await tester.tap(find.text('Open'));
      await tester.pump();
      expect(find.text('Entry saved'), findsOneWidget);
    });
  });
}
