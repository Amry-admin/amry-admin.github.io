import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:go_router/go_router.dart';
import 'package:share_plus/share_plus.dart';

import '../../core/constants/app_text.dart';
import '../../core/platform/platform_actions.dart';
import '../../core/theme/app_theme.dart';
import '../../core/widgets/common.dart';
import '../../routing/app_router.dart';

/// How to add the web app to a phone's home screen, plus sharing the link.
class InstallScreen extends StatefulWidget {
  const InstallScreen({super.key});

  @override
  State<InstallScreen> createState() => _InstallScreenState();
}

class _InstallScreenState extends State<InstallScreen> {
  late bool _iphone = kIsWeb && isAppleMobileBrowser();

  Future<void> _share() async {
    try {
      await SharePlus.instance.share(
        ShareParams(text: AppLinks.shareMessage(), subject: 'CycleSync'),
      );
    } catch (_) {
      await _copy();
    }
  }

  Future<void> _copy() async {
    await Clipboard.setData(const ClipboardData(text: AppLinks.webAppUrl));
    if (mounted) showMessage(context, 'Link copied');
  }

  void _done() {
    if (context.canPop()) {
      context.pop();
    } else {
      context.go(AppRoutes.home);
    }
  }

  @override
  Widget build(BuildContext context) {
    final steps = _iphone
        ? const [
            (Icons.language, 'Open this website in Safari'),
            (Icons.ios_share, 'Tap the Share button'),
            (Icons.add_box_outlined, 'Choose "Add to Home Screen", then Add'),
          ]
        : const [
            (Icons.language, 'Open this website in Chrome'),
            (Icons.more_vert, 'Tap the ⋮ menu (top right)'),
            (Icons.add_to_home_screen, 'Choose "Install app" or "Add to Home screen"'),
          ];

    return Scaffold(
      body: DecoratedBox(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [Color(0xFFF7D2E6), Color(0xFFE6D9FB)],
          ),
        ),
        child: SafeArea(
          child: Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 460),
              child: ListView(
                padding: const EdgeInsets.fromLTRB(24, 8, 24, 32),
                children: [
                  Align(
                    alignment: Alignment.centerLeft,
                    child: IconButton(
                      tooltip: 'Back',
                      onPressed: _done,
                      icon: const Icon(Icons.arrow_back,
                          color: AppTheme.plum),
                    ),
                  ),
                  const _PhoneIllustration(),
                  const SizedBox(height: 20),
                  const Text(
                    'Add CycleSync\nto your Home Screen',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontFamily: 'Poppins',
                      fontSize: 24,
                      fontWeight: FontWeight.w700,
                      color: Color(0xFF3F1F5C),
                    ),
                  ),
                  const SizedBox(height: 16),
                  Center(
                    child: SegmentedButton<bool>(
                      segments: const [
                        ButtonSegment(value: false, label: Text('Android')),
                        ButtonSegment(value: true, label: Text('iPhone')),
                      ],
                      selected: {_iphone},
                      onSelectionChanged: (s) =>
                          setState(() => _iphone = s.first),
                    ),
                  ),
                  const SizedBox(height: 20),
                  for (var i = 0; i < steps.length; i++)
                    _Step(number: i + 1, icon: steps[i].$1, text: steps[i].$2),
                  const SizedBox(height: 24),
                  GradientButton(label: 'Got it!', onPressed: _done),
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      Expanded(
                        child: OutlinedButton.icon(
                          onPressed: _share,
                          icon: const Icon(Icons.share_outlined),
                          label: const Text('Share'),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: OutlinedButton.icon(
                          onPressed: _copy,
                          icon: const Icon(Icons.link),
                          label: const Text('Copy link'),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  const Text(
                    'Then open CycleSync from your home screen like a native '
                    'app. Your cycle data is never included in a shared link.',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontFamily: 'Poppins',
                      color: Color(0xFF6B4F78),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _Step extends StatelessWidget {
  const _Step({required this.number, required this.icon, required this.text});

  final int number;
  final IconData icon;
  final String text;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 14),
      child: Row(
        children: [
          Container(
            width: 30,
            height: 30,
            alignment: Alignment.center,
            decoration: const BoxDecoration(
              color: Color(0xFFB79CF2),
              shape: BoxShape.circle,
            ),
            child: Text(
              '$number',
              style: const TextStyle(
                fontFamily: 'Poppins',
                color: Colors.white,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Text(
              text,
              style: const TextStyle(
                fontFamily: 'Poppins',
                fontSize: 15,
                fontWeight: FontWeight.w500,
                color: Color(0xFF3F1F5C),
              ),
            ),
          ),
          Icon(icon, color: AppTheme.plum),
        ],
      ),
    );
  }
}

class _PhoneIllustration extends StatelessWidget {
  const _PhoneIllustration();

  @override
  Widget build(BuildContext context) {
    return ExcludeSemantics(
      child: Center(
        child: SizedBox(
        width: 220,
        height: 190,
        child: Stack(
          alignment: Alignment.center,
          children: [
            Container(
              width: 110,
              height: 180,
              decoration: BoxDecoration(
                color: const Color(0xFF4A2378),
                borderRadius: BorderRadius.circular(22),
              ),
              padding: const EdgeInsets.all(8),
              child: Container(
                decoration: BoxDecoration(
                  color: const Color(0xFFFCE7F1),
                  borderRadius: BorderRadius.circular(16),
                ),
                alignment: Alignment.center,
                child: const AppLogo(size: 56),
              ),
            ),
            Positioned(
              right: 28,
              bottom: 18,
              child: Container(
                width: 44,
                height: 44,
                decoration: const BoxDecoration(
                  color: Color(0xFF2EBD8E),
                  shape: BoxShape.circle,
                ),
                child: const Icon(Icons.check, color: Colors.white, size: 28),
              ),
            ),
            const Positioned(
              left: 20,
              top: 20,
              child: Icon(Icons.auto_awesome, color: Color(0xFFF2A6C8), size: 26),
            ),
          ],
        ),
      ),
      ),
    );
  }
}
