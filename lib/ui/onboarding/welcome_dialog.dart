import 'package:flutter/material.dart';
import '../../core/services/onboarding_service.dart';

/// Welcome dialog shown on first launch
class WelcomeDialog extends StatelessWidget {
  final OnboardingService onboardingService;
  final VoidCallback onComplete;

  const WelcomeDialog({
    super.key,
    required this.onboardingService,
    required this.onComplete,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
      child: Container(
        constraints: const BoxConstraints(maxWidth: 500),
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Icon
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: colorScheme.primary.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(16),
              ),
              child: Icon(
                Icons.auto_fix_high_rounded,
                size: 48,
                color: colorScheme.primary,
              ),
            ),
            const SizedBox(height: 24),

            // Title
            Text(
              'Welcome to Rewriter',
              style: theme.textTheme.headlineSmall?.copyWith(
                fontWeight: FontWeight.bold,
                color: colorScheme.onSurface,
              ),
            ),
            const SizedBox(height: 12),

            // Description
            Text(
              'Rewriter automatically rewrites English text from your clipboard using AI. Here\'s how it works:',
              style: theme.textTheme.bodyLarge?.copyWith(
                color: colorScheme.onSurface.withValues(alpha: 0.7),
                height: 1.5,
              ),
            ),
            const SizedBox(height: 24),

            // Features list
            _FeatureItem(
              icon: Icons.content_copy_rounded,
              title: 'Copy Text',
              description: 'Copy any English text to your clipboard',
            ),
            const SizedBox(height: 16),
            _FeatureItem(
              icon: Icons.auto_fix_high_rounded,
              title: 'Automatic Rewriting',
              description: 'Rewriter detects and rewrites it automatically',
            ),
            const SizedBox(height: 16),
            _FeatureItem(
              icon: Icons.preview_rounded,
              title: 'Preview & Choose',
              description: 'View the rewritten text and copy it if you like it',
            ),
            const SizedBox(height: 32),

            // Action button
            Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                FilledButton(
                  onPressed: () async {
                    final navigator = Navigator.of(context);
                    await onboardingService.markWelcomeSeen();
                    // Return true to indicate user wants to configure settings
                    // Window will stay visible for user to configure
                    if (navigator.canPop()) {
                      navigator.pop(true);
                    }
                    onComplete();
                  },
                  style: FilledButton.styleFrom(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 24,
                      vertical: 12,
                    ),
                  ),
                  child: const Text('Get Started'),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _FeatureItem extends StatelessWidget {
  final IconData icon;
  final String title;
  final String description;

  const _FeatureItem({
    required this.icon,
    required this.title,
    required this.description,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(
            color: colorScheme.primary.withValues(alpha: 0.1),
            borderRadius: BorderRadius.circular(8),
          ),
          child: Icon(icon, size: 20, color: colorScheme.primary),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: theme.textTheme.titleSmall?.copyWith(
                  fontWeight: FontWeight.w600,
                  color: colorScheme.onSurface,
                ),
              ),
              const SizedBox(height: 2),
              Text(
                description,
                style: theme.textTheme.bodySmall?.copyWith(
                  color: colorScheme.onSurface.withValues(alpha: 0.6),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}
