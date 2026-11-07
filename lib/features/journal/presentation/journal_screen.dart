import 'package:flutter/material.dart';

import '../../../ui/widgets/page_body.dart';
import '../../../ui/widgets/states.dart';

/// Journal home. Placeholder until M5.
class JournalScreen extends StatelessWidget {
  const JournalScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return const PageBody(
      title: 'morrow',
      wordmarkTitle: true,
      children: [
        EmptyState(
          title: 'Nothing here yet',
          message:
              'Add an entry whenever you’re ready. It stays on this phone.',
        ),
      ],
    );
  }
}
