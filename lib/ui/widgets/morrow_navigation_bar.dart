import 'package:flutter/material.dart';

import '../theme/morrow_colors.dart';

/// The four top-level destinations, in bottom navigation order.
enum MorrowDestination { journal, history, trends, settings }

/// Bottom navigation for the app shell. Routing is added in M4; this widget
/// only shows the destinations and reports taps.
class MorrowNavigationBar extends StatelessWidget {
  const MorrowNavigationBar({
    required this.selected,
    required this.onSelected,
    super.key,
  });

  final MorrowDestination selected;
  final ValueChanged<MorrowDestination> onSelected;

  @override
  Widget build(BuildContext context) {
    final colors = MorrowColors.of(context);
    // Grow with the label so large text does not clip.
    final labelHeight = MediaQuery.textScalerOf(context).scale(11) * 1.2;
    final height = 50 + labelHeight;

    return DecoratedBox(
      decoration: BoxDecoration(
        border: Border(top: BorderSide(color: colors.line)),
      ),
      child: NavigationBar(
        height: height,
        selectedIndex: selected.index,
        onDestinationSelected: (i) => onSelected(MorrowDestination.values[i]),
        destinations: const [
          NavigationDestination(
            icon: Icon(Icons.menu_book_outlined),
            label: 'Journal',
          ),
          NavigationDestination(
            icon: Icon(Icons.schedule_outlined),
            label: 'History',
          ),
          NavigationDestination(
            icon: Icon(Icons.show_chart_outlined),
            label: 'Trends',
          ),
          NavigationDestination(icon: Icon(Icons.tune), label: 'Settings'),
        ],
      ),
    );
  }
}
