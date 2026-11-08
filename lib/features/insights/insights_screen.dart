import 'package:flutter/material.dart';

import '../../core/widgets/coming_soon.dart';

class InsightsScreen extends StatelessWidget {
  const InsightsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return const ComingSoonScreen(
      title: 'Insights',
      icon: Icons.insights_outlined,
      message: 'Cycle history and patterns from your own logs will appear '
          'here once you have recorded a few periods.',
    );
  }
}
