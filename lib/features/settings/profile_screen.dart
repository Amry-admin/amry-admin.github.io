import 'package:flutter/material.dart';

import '../../core/widgets/coming_soon.dart';

class ProfileScreen extends StatelessWidget {
  const ProfileScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return const ComingSoonScreen(
      title: 'Profile',
      icon: Icons.person_outline,
      message: 'Account, reminders, privacy, export and delete options '
          'will live here.',
    );
  }
}
