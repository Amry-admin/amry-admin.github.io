import 'package:flutter/material.dart';

import '../../core/widgets/coming_soon.dart';

class LogScreen extends StatelessWidget {
  const LogScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return const ComingSoonScreen(
      title: 'Log',
      icon: Icons.edit_note_outlined,
      message: 'Log your period, flow, symptoms and mood here.',
    );
  }
}
