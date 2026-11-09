import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../app/paths.dart';
import '../../../app/providers.dart';

/// How the tour was opened: on a new journal (it ends in the journal with
/// the first-run hint), or again from Settings (it ends where it began).
enum TourMode { firstRun, replay }

/// True when startup has just created a journal and the welcome hasn't been
/// seen on this phone. If secure storage can't be read, the welcome is
/// skipped rather than blocking the journal.
Future<bool> welcomeDue(
  WelcomeStoreReader read, {
  required bool createdNew,
}) async {
  if (!createdNew) return false;
  try {
    return !await read();
  } on Object {
    return false;
  }
}

typedef WelcomeStoreReader = Future<bool> Function();

/// The one-time "Start with one tap" hint on the journal (1.6). Shown after
/// the welcome; gone after "Got it" or the first entry.
class FirstRunHint extends Notifier<bool> {
  @override
  bool build() => false;

  void show() => state = true;

  void dismiss() => state = false;
}

final firstRunHintProvider = NotifierProvider<FirstRunHint, bool>(
  FirstRunHint.new,
);

/// Leaves the welcome for the journal: remembers that it was seen (so it
/// never shows again), shows the first-run hint, and opens the journal.
Future<void> finishWelcome(BuildContext context, WidgetRef ref) async {
  try {
    await ref.read(welcomeStoreProvider).markSeen();
  } on Object {
    // Not remembered: the welcome may show once more, which is harmless.
  }
  ref.read(firstRunHintProvider.notifier).show();
  if (context.mounted) context.go(AppPaths.journal);
}
