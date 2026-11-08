import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../core/constants/app_text.dart';
import '../../core/theme/app_theme.dart';
import '../../core/widgets/common.dart';
import '../../routing/app_router.dart';

class WelcomeScreen extends StatelessWidget {
  const WelcomeScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return GradientScaffold(
      body: Stack(
        children: [
          const _SoftBlobs(),
          SafeArea(
            child: Center(
              child: SingleChildScrollView(
                padding: const EdgeInsets.symmetric(horizontal: 28, vertical: 24),
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 420),
                  child: Column(
                    children: [
                      const SizedBox(height: 24),
                      const AppLogo(size: 170),
                      const SizedBox(height: 28),
                      const _BrandTitle(),
                      const SizedBox(height: 12),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Flexible(
                            child: Text(
                              AppText.tagline,
                              textAlign: TextAlign.center,
                              style: context.text.titleMedium?.copyWith(
                                color: AppTheme.plum,
                                fontWeight: FontWeight.w500,
                                height: 1.4,
                              ),
                            ),
                          ),
                          const SizedBox(width: 6),
                          Icon(Icons.favorite_border,
                              color: context.colors.primary, size: 22),
                        ],
                      ),
                      const SizedBox(height: 56),
                      SizedBox(
                        width: double.infinity,
                        child: GradientButton(
                          label: 'Get Started',
                          trailingIcon: Icons.arrow_forward,
                          onPressed: () => context.push(AppRoutes.signUp),
                        ),
                      ),
                      const SizedBox(height: 12),
                      TextButton(
                        onPressed: () => context.push(AppRoutes.signIn),
                        child: const Text('Sign In'),
                      ),
                      if (kIsWeb) ...[
                        const SizedBox(height: 4),
                        TextButton.icon(
                          onPressed: () => context.push(AppRoutes.install),
                          icon: const Icon(Icons.add_to_home_screen, size: 18),
                          label: const Text('Add to your home screen'),
                        ),
                      ],
                      const SizedBox(height: 16),
                      Text(
                        'Private by design. Estimates only, not medical advice.',
                        textAlign: TextAlign.center,
                        style: context.text.bodySmall
                            ?.copyWith(color: context.cycle.muted),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _BrandTitle extends StatelessWidget {
  const _BrandTitle();

  @override
  Widget build(BuildContext context) {
    return Semantics(
      header: true,
      child: ShaderMask(
        shaderCallback: (rect) => const LinearGradient(
          colors: [AppTheme.plum, AppTheme.magenta],
        ).createShader(rect),
        child: const Text(
          AppText.appName,
          style: TextStyle(
            fontFamily: 'Poppins',
            fontSize: 44,
            fontWeight: FontWeight.w700,
            color: Colors.white,
            letterSpacing: -0.5,
          ),
        ),
      ),
    );
  }
}

/// Soft decorative petals in the corners.
class _SoftBlobs extends StatelessWidget {
  const _SoftBlobs();

  @override
  Widget build(BuildContext context) {
    final c = context.cycle;
    Widget blob(double size, Color color) => Container(
          width: size,
          height: size,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: color,
          ),
        );
    return IgnorePointer(
      child: Stack(
        children: [
          Positioned(top: -60, left: -50, child: blob(200, c.periodSoft)),
          Positioned(top: 120, right: -70, child: blob(160, c.fertileSoft)),
          Positioned(bottom: -80, left: -40, child: blob(220, c.fertileSoft)),
          Positioned(bottom: 60, right: -50, child: blob(140, c.periodSoft)),
        ],
      ),
    );
  }
}
