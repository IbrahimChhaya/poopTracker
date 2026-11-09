import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../app/lock/lock_controller.dart';
import '../../../app/scope.dart';
import '../../../core/security/device_auth.dart';
import '../../../ui/theme/morrow_colors.dart';
import '../../../ui/theme/morrow_tokens.dart';
import '../../../ui/widgets/card_group.dart';
import '../../../ui/widgets/morrow_button.dart';
import '../../../ui/widgets/overlays.dart';
import '../../../ui/widgets/page_layouts.dart';
import '../../../ui/widgets/setting_row.dart';
import 'onboarding_layout.dart';
import 'previews.dart';
import 'welcome_controller.dart';

const int _pageCount = 4;

/// The tour (1.2–1.5): four short pages that show the real app. Skip is on
/// every page but the last and keeps any switch already changed. The
/// switches are the real settings; app lock uses the phone's own prompt.
class TourScreen extends ConsumerStatefulWidget {
  const TourScreen({required this.mode, super.key});

  final TourMode mode;

  @override
  ConsumerState<TourScreen> createState() => _TourScreenState();
}

class _TourScreenState extends ConsumerState<TourScreen> {
  final _pages = PageController();
  int _page = 0;
  bool _lockBusy = false;

  /// The phone has no screen lock, so app lock can't be turned on (1.5d).
  bool _lockUnavailable = false;

  /// App lock was just turned on here (1.5c), confirmed on the stage
  /// rather than in a toast that would cover the button.
  bool _lockJustOn = false;

  @override
  void dispose() {
    _pages.dispose();
    super.dispose();
  }

  Future<void> _finish() async {
    if (widget.mode == TourMode.replay) {
      if (context.canPop()) context.pop();
      return;
    }
    await finishWelcome(context, ref);
  }

  void _next() {
    if (_page == _pageCount - 1) {
      _finish();
      return;
    }
    _pages.nextPage(
      duration: const Duration(milliseconds: 280),
      curve: Curves.easeOutCubic,
    );
  }

  void _back() => _pages.previousPage(
    duration: const Duration(milliseconds: 280),
    curve: Curves.easeOutCubic,
  );

  Future<void> _setLock(bool on) async {
    if (_lockBusy) return;
    setState(() => _lockBusy = true);
    final outcome = await ref
        .read(lockControllerProvider.notifier)
        .setEnabled(on);
    if (!mounted) return;
    setState(() {
      _lockBusy = false;
      _lockUnavailable = outcome == AuthOutcome.notAvailable;
      _lockJustOn = on && outcome == AuthOutcome.success;
    });
    final message = switch (outcome) {
      AuthOutcome.success => null,
      AuthOutcome.lockedOut => 'Too many tries. Wait a moment, then try again.',
      AuthOutcome.error => 'Couldn’t change app lock. Nothing changed.',
      // Cancelling is a choice; no screen lock is explained on the page.
      AuthOutcome.cancelled ||
      AuthOutcome.failed ||
      AuthOutcome.notAvailable => null,
    };
    if (message != null) showMorrowToast(context, message);
  }

  Widget _top() {
    final colors = MorrowColors.of(context);
    final iosBack = defaultTargetPlatform == TargetPlatform.iOS && _page > 0;
    return ConstrainedBox(
      constraints: const BoxConstraints(minHeight: MorrowSizes.minTouchTarget),
      child: Row(
        children: [
          if (iosBack) ...[
            IconButton(
              onPressed: _back,
              tooltip: 'Back',
              icon: const Icon(Icons.arrow_back_ios_new, size: 18),
            ),
            const SizedBox(width: MorrowSpacing.xs),
          ],
          // The dashes shrink before Skip does, at very large text.
          Expanded(
            child: Align(
              alignment: Alignment.centerLeft,
              child: FittedBox(
                fit: BoxFit.scaleDown,
                child: Semantics(
                  label: 'Page ${_page + 1} of $_pageCount',
                  excludeSemantics: true,
                  child: Row(
                    children: [
                      for (var i = 0; i < _pageCount; i++) ...[
                        if (i > 0) const SizedBox(width: 6),
                        // The current page is longer, not just darker.
                        Container(
                          width: i == _page ? 44 : 32,
                          height: 4,
                          decoration: BoxDecoration(
                            color: i <= _page ? colors.primary : colors.line,
                            borderRadius: BorderRadius.circular(2),
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
              ),
            ),
          ),
          if (_page < _pageCount - 1)
            TextButton(onPressed: _finish, child: const Text('Skip')),
        ],
      ),
    );
  }

  Widget _detailsPage() {
    final display = ref.watch(displayProvider);
    final repo = ref.read(settingsRepositoryProvider);
    final anyOn = display.showStoolForm || display.showContext;
    return OnboardingLayout(
      top: _top(),
      stage: LiveStage(
        children: [
          CardGroup(
            label: 'Optional details',
            children: [
              SettingRow.toggle(
                icon: Icons.notes,
                title: 'Stool form',
                subtitle:
                    'Add stool form to entries, and show it in your journal '
                    'and trends.',
                value: display.showStoolForm,
                onChanged: repo.setShowStoolForm,
              ),
              SettingRow.toggle(
                icon: Icons.tune,
                title: 'Context',
                subtitle:
                    'Add how it felt and what was going on to entries, and '
                    'show them in your journal.',
                value: display.showContext,
                onChanged: repo.setShowContext,
              ),
            ],
          ),
          if (anyOn)
            DetailsOnPreview(
              stoolForm: display.showStoolForm,
              context_: display.showContext,
            ),
        ],
      ),
      title: 'Add more, only if you want.',
      body:
          'Off unless you turn them on. Change them here or in Settings at '
          'any time. Turning one off never deletes anything.',
      actions: [MorrowButton(label: 'Next', onPressed: _next)],
    );
  }

  Widget _privacyPage() {
    final colors = MorrowColors.of(context);
    final text = Theme.of(context).textTheme;
    final lockOn = ref.watch(appLockEnabledProvider);
    return OnboardingLayout(
      top: _top(),
      stage: LiveStage(
        children: [
          const CardGroup(
            children: [
              InfoRow(
                icon: Icons.lock_outline,
                title: 'Encrypted on this phone',
                subtitle:
                    'Your journal is protected, with or without app lock.',
              ),
              InfoRow(
                icon: Icons.shield_outlined,
                title: 'No account, no cloud',
                subtitle: 'Nothing is sent anywhere. morrow works offline.',
              ),
              InfoRow(
                icon: Icons.save_alt_outlined,
                title: 'Your own backup',
                subtitle:
                    'Save an encrypted copy anywhere you like, and restore it '
                    'on a new phone.',
              ),
            ],
          ),
          CardGroup(
            children: [
              SettingRow.toggle(
                icon: Icons.fingerprint,
                title: 'App lock',
                subtitle: _lockUnavailable
                    ? 'Not available on this phone yet'
                    : '${lockOn ? 'On' : 'Off'} · fingerprint, face or phone '
                          'passcode',
                value: lockOn,
                onChanged: _lockBusy ? null : _setLock,
              ),
            ],
          ),
          if (_lockJustOn)
            Semantics(
              liveRegion: true,
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.check, size: 18, color: colors.primary),
                  const SizedBox(width: MorrowSpacing.sm),
                  Flexible(
                    child: Text(
                      'App lock is on',
                      style: text.titleSmall!.copyWith(color: colors.primary),
                    ),
                  ),
                ],
              ),
            ),
          if (_lockUnavailable)
            Semantics(
              liveRegion: true,
              child: Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 14,
                  vertical: 12,
                ),
                decoration: BoxDecoration(
                  color: colors.sand,
                  borderRadius: BorderRadius.circular(MorrowRadii.md),
                ),
                child: Text(
                  'Set up a screen lock in your phone’s settings first. You '
                  'can turn on app lock later in Settings > App lock.',
                  style: text.bodyMedium,
                ),
              ),
            ),
        ],
      ),
      title: 'Private by design.',
      body:
          'Turn on app lock now or later. Everything else is already taken '
          'care of.',
      actions: [
        MorrowButton(
          label: widget.mode == TourMode.replay ? 'Done' : 'Start your journal',
          onPressed: _next,
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    final pages = [
      OnboardingLayout(
        top: _top(),
        stage: const OneTapPreview(),
        title: 'One tap, and it’s logged.',
        body:
            'Only the date is needed. Add a time or a note whenever you '
            'like.',
        actions: [MorrowButton(label: 'Next', onPressed: _next)],
      ),
      _detailsPage(),
      OnboardingLayout(
        top: _top(),
        stage: const WeeklyPreview(),
        title: 'See your trends.',
        body:
            'See simple counts for each week. Add one gentle weekly reminder '
            'in Settings if you like.',
        actions: [MorrowButton(label: 'Next', onPressed: _next)],
      ),
      _privacyPage(),
    ];
    // System back steps back a page before it leaves the tour.
    return PopScope(
      canPop: _page == 0,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop && _page > 0) _back();
      },
      child: PageView(
        controller: _pages,
        onPageChanged: (i) => setState(() => _page = i),
        children: pages,
      ),
    );
  }
}
