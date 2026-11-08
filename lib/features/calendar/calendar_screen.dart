import 'package:flutter/material.dart';

import '../../core/widgets/coming_soon.dart';

class CalendarScreen extends StatelessWidget {
  const CalendarScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return const ComingSoonScreen(
      title: 'Calendar',
      icon: Icons.calendar_month_outlined,
      message: 'Your logged and estimated period days will appear here.',
    );
  }
}
