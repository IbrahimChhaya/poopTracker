import 'package:flutter/material.dart';

/// Root widget. Theme, routing, bootstrap and the lock gate are added in
/// later milestones (see docs/implementation-plan.md).
class MorrowApp extends StatelessWidget {
  const MorrowApp({super.key});

  @override
  Widget build(BuildContext context) {
    return const MaterialApp(
      title: 'morrow',
      debugShowCheckedModeBanner: false,
      home: _PlaceholderHome(),
    );
  }
}

class _PlaceholderHome extends StatelessWidget {
  const _PlaceholderHome();

  @override
  Widget build(BuildContext context) {
    return const Scaffold(body: Center(child: Text('morrow')));
  }
}
