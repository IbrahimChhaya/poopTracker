import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:poop_tracker/ui/theme/morrow_colors.dart';
import 'package:poop_tracker/ui/theme/morrow_theme.dart';

import '../support/contrast.dart';

void main() {
  final theme = buildMorrowTheme().switchTheme;
  const c = MorrowColors.light;
  const off = <WidgetState>{};
  const on = {WidgetState.selected};

  test('off switch has an outline with at least 3:1 against card and '
      'background', () {
    final outline = theme.trackOutlineColor!.resolve(off)!;
    expect(theme.trackOutlineWidth!.resolve(off), greaterThanOrEqualTo(2));
    expect(contrastRatio(outline, c.card), greaterThanOrEqualTo(3));
    expect(contrastRatio(outline, c.background), greaterThanOrEqualTo(3));
  });

  test('off thumb stands out from its track', () {
    expect(
      contrastRatio(
        theme.thumbColor!.resolve(off)!,
        theme.trackColor!.resolve(off)!,
      ),
      greaterThanOrEqualTo(3),
    );
  });

  test('on switch has a filled track, light thumb and a check mark', () {
    final track = theme.trackColor!.resolve(on)!;
    expect(contrastRatio(track, c.card), greaterThanOrEqualTo(3));
    expect(
      contrastRatio(theme.thumbColor!.resolve(on)!, track),
      greaterThanOrEqualTo(3),
    );
    expect(theme.thumbIcon!.resolve(on)?.icon, Icons.check);
  });

  test('off switch has no thumb icon, so its thumb stays small', () {
    expect(theme.thumbIcon!.resolve(off), isNull);
  });
}
