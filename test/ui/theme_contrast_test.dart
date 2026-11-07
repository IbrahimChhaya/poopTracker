import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:poop_tracker/ui/theme/morrow_colors.dart';

import '../support/contrast.dart';

typedef _Pair = (String name, Color foreground, Color background);

void main() {
  const c = MorrowColors.light;

  group('contrast helper', () {
    test('matches known WCAG values', () {
      expect(
        contrastRatio(const Color(0xFF000000), const Color(0xFFFFFFFF)),
        closeTo(21, 0.01),
      );
      expect(contrastRatio(c.ink, c.ink), closeTo(1, 0.0001));
    });
  });

  group('text pairs meet 4.5:1', () {
    // Every foreground/background pair the shared widgets use for text.
    final pairs = <_Pair>[
      ('ink on background', c.ink, c.background),
      ('ink on card', c.ink, c.card),
      ('ink on tint', c.ink, c.tint),
      ('ink on sand', c.ink, c.sand),
      ('muted text on background', c.mutedText, c.background),
      ('muted text on card', c.mutedText, c.card),
      ('muted text on tint', c.mutedText, c.tint),
      ('disabled text on disabled button', c.disabledText, c.disabledSurface),
      ('primary on background', c.primary, c.background),
      ('primary on card', c.primary, c.card),
      ('primary on tint', c.primary, c.tint),
      ('on-primary on primary', c.onPrimary, c.primary),
      ('on-primary muted on primary', c.onPrimaryMuted, c.primary),
      ('danger on card', c.danger, c.card),
      ('danger on sand', c.danger, c.sand),
      ('on-primary on danger', c.onPrimary, c.danger),
      ('card on ink (toast)', c.card, c.ink),
      ('warm text on sand', c.warmText, c.sand),
      ('warm text on card', c.warmText, c.card),
      ('warm text on background', c.warmText, c.background),
    ];
    for (final (name, fg, bg) in pairs) {
      test(name, () {
        expect(contrastRatio(fg, bg), greaterThanOrEqualTo(4.5));
      });
    }
  });

  group('icons and indicators meet 3:1', () {
    final pairs = <_Pair>[
      ('muted icon on background', c.mutedIcon, c.background),
      ('muted icon on card', c.mutedIcon, c.card),
      ('primary icon on tint', c.primary, c.tint),
      ('warm icon on sand', c.warmIcon, c.sand),
      ('danger icon on sand', c.danger, c.sand),
      ('selected border on background', c.primary, c.background),
      ('switch off outline on card', c.mutedIcon, c.card),
      ('switch off outline on background', c.mutedIcon, c.background),
      ('switch off thumb on off track', c.mutedIcon, c.switchTrackOff),
      ('switch on track on card', c.primary, c.card),
      ('switch on thumb on on track', c.card, c.primary),
    ];
    for (final (name, fg, bg) in pairs) {
      test(name, () {
        expect(contrastRatio(fg, bg), greaterThanOrEqualTo(3));
      });
    }
  });
}
