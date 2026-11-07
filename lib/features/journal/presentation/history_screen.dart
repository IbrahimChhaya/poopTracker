import 'package:flutter/material.dart';

import '../../../ui/widgets/page_body.dart';
import '../../../ui/widgets/states.dart';

/// History. Placeholder until M5.
class HistoryScreen extends StatelessWidget {
  const HistoryScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return const PageBody(
      title: 'Your history',
      children: [
        EmptyState(
          title: 'Nothing here yet',
          message: 'Your entries will appear here.',
        ),
      ],
    );
  }
}
