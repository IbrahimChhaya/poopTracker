import 'package:flutter/material.dart';

import '../../../ui/widgets/page_body.dart';
import '../../../ui/widgets/states.dart';

/// Weekly trends. Placeholder until M7.
class TrendsScreen extends StatelessWidget {
  const TrendsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return const PageBody(
      title: 'Your weeks',
      children: [
        EmptyState(
          title: 'Not enough entries yet',
          message:
              'Weekly trends appear once you have entries from at least two '
              'different weeks.',
        ),
      ],
    );
  }
}
