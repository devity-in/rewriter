import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../core/models/app_config.dart';
import '../../core/services/onboarding_service.dart';
import '../../ui/providers/app_provider.dart';

class WelcomeDialog extends StatefulWidget {
  final OnboardingService onboardingService;
  final VoidCallback onComplete;

  const WelcomeDialog({
    super.key,
    required this.onboardingService,
    required this.onComplete,
  });

  @override
  State<WelcomeDialog> createState() => _WelcomeDialogState();
}

class _WelcomeDialogState extends State<WelcomeDialog> {
  int _page = 0;
  String _selectedModel = 'nobodywho';
  String _selectedStyle = 'professional';

  static const _totalPages = 3;

  void _next() {
    if (_page < _totalPages - 1) {
      setState(() => _page++);
    } else {
      _finish();
    }
  }

  void _back() {
    if (_page > 0) setState(() => _page--);
  }

  Future<void> _finish() async {
    final provider = context.read<AppProvider>();
    final config = (provider.config ?? AppConfig()).copyWith(
      enabled: true,
      modelType: _selectedModel,
      rewriteStyle: _selectedStyle,
    );
    await provider.updateConfig(config);
    await widget.onboardingService.markWelcomeSeen();
    await widget.onboardingService.markOnboardingComplete();
    if (mounted && Navigator.of(context).canPop()) {
      Navigator.of(context).pop();
    }
    widget.onComplete();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
      child: Container(
        constraints: const BoxConstraints(maxWidth: 540, maxHeight: 560),
        padding: const EdgeInsets.all(36),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Progress dots
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: List.generate(_totalPages, (i) {
                final active = i == _page;
                return AnimatedContainer(
                  duration: const Duration(milliseconds: 250),
                  margin: const EdgeInsets.symmetric(horizontal: 4),
                  width: active ? 24 : 8,
                  height: 8,
                  decoration: BoxDecoration(
                    color: active
                        ? colorScheme.primary
                        : colorScheme.outline.withValues(alpha: 0.2),
                    borderRadius: BorderRadius.circular(4),
                  ),
                );
              }),
            ),
            const SizedBox(height: 24),

            // Page content — scrollable
            Flexible(
              child: SingleChildScrollView(
                child: AnimatedSwitcher(
                  duration: const Duration(milliseconds: 200),
                  child: _buildPage(theme, colorScheme),
                ),
              ),
            ),

            const SizedBox(height: 24),

            // Navigation — always pinned at bottom
            Row(
              children: [
                if (_page > 0)
                  TextButton(
                    onPressed: _back,
                    child: const Text('Back'),
                  ),
                const Spacer(),
                FilledButton(
                  onPressed: _next,
                  style: FilledButton.styleFrom(
                    padding: const EdgeInsets.symmetric(horizontal: 28, vertical: 14),
                  ),
                  child: Text(_page == _totalPages - 1 ? 'Get Started' : 'Next'),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildPage(ThemeData theme, ColorScheme colorScheme) {
    switch (_page) {
      case 0:
        return _WelcomePage(key: const ValueKey(0));
      case 1:
        return _ModelPage(
          key: const ValueKey(1),
          selected: _selectedModel,
          onChanged: (v) => setState(() => _selectedModel = v),
        );
      case 2:
        return _StylePage(
          key: const ValueKey(2),
          selected: _selectedStyle,
          onChanged: (v) => setState(() => _selectedStyle = v),
        );
      default:
        return const SizedBox.shrink();
    }
  }
}

// ---------------------------------------------------------------------------
// Page 1: Welcome / value prop
// ---------------------------------------------------------------------------

class _WelcomePage extends StatelessWidget {
  const _WelcomePage({super.key});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: colorScheme.primary.withValues(alpha: 0.1),
            borderRadius: BorderRadius.circular(16),
          ),
          child: Icon(Icons.auto_fix_high_rounded, size: 40, color: colorScheme.primary),
        ),
        const SizedBox(height: 24),
        Text(
          'Welcome to Rewriter',
          style: theme.textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.bold),
        ),
        const SizedBox(height: 10),
        Text(
          'Rewriter polishes the text you copy — so your Slack messages, '
          'emails, and comments sound clear and professional without extra effort.',
          style: theme.textTheme.bodyLarge?.copyWith(
            color: colorScheme.onSurface.withValues(alpha: 0.7),
            height: 1.6,
          ),
        ),
        const SizedBox(height: 28),
        _HowItWorksStep(
          number: '1',
          icon: Icons.content_copy_rounded,
          title: 'Copy text anywhere',
          subtitle: 'Select text in Slack, email, or any app and copy it.',
        ),
        const SizedBox(height: 14),
        _HowItWorksStep(
          number: '2',
          icon: Icons.auto_fix_high_rounded,
          title: 'Instant rewrite',
          subtitle: 'Rewriter detects the change and rewrites it in the background.',
        ),
        const SizedBox(height: 14),
        _HowItWorksStep(
          number: '3',
          icon: Icons.paste_rounded,
          title: 'Paste the polished version',
          subtitle: 'Your clipboard already has the improved text — just paste.',
        ),
      ],
    );
  }
}

class _HowItWorksStep extends StatelessWidget {
  final String number;
  final IconData icon;
  final String title;
  final String subtitle;

  const _HowItWorksStep({
    required this.number,
    required this.icon,
    required this.title,
    required this.subtitle,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          width: 28,
          height: 28,
          decoration: BoxDecoration(
            color: colorScheme.primary.withValues(alpha: 0.1),
            shape: BoxShape.circle,
          ),
          child: Center(
            child: Text(
              number,
              style: theme.textTheme.labelMedium?.copyWith(
                fontWeight: FontWeight.w700,
                color: colorScheme.primary,
              ),
            ),
          ),
        ),
        const SizedBox(width: 14),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(title, style: theme.textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w600)),
              const SizedBox(height: 2),
              Text(
                subtitle,
                style: theme.textTheme.bodySmall?.copyWith(
                  color: colorScheme.onSurface.withValues(alpha: 0.6),
                  height: 1.4,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

// ---------------------------------------------------------------------------
// Page 2: Choose AI model
// ---------------------------------------------------------------------------

class _ModelPage extends StatelessWidget {
  final String selected;
  final ValueChanged<String> onChanged;

  const _ModelPage({super.key, required this.selected, required this.onChanged});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Choose your AI engine',
          style: theme.textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.bold),
        ),
        const SizedBox(height: 8),
        Text(
          'You can change this anytime in Settings.',
          style: theme.textTheme.bodyMedium?.copyWith(
            color: colorScheme.onSurface.withValues(alpha: 0.6),
          ),
        ),
        const SizedBox(height: 24),
        _ModelOption(
          value: 'nobodywho',
          title: 'On-Device (Recommended)',
          subtitle: 'Runs a small language model locally. Private — nothing leaves your Mac.',
          icon: Icons.laptop_mac_rounded,
          color: const Color(0xFF10B981),
          selected: selected == 'nobodywho',
          badge: 'Private',
          onTap: () => onChanged('nobodywho'),
        ),
        const SizedBox(height: 10),
        _ModelOption(
          value: 'gemini',
          title: 'Google Gemini',
          subtitle: 'Fast cloud model. Requires a free API key from Google AI Studio.',
          icon: Icons.cloud_outlined,
          color: const Color(0xFF3B82F6),
          selected: selected == 'gemini',
          onTap: () => onChanged('gemini'),
        ),
        const SizedBox(height: 10),
        _ModelOption(
          value: 'ollama',
          title: 'Ollama (Self-hosted)',
          subtitle: 'Connect to a local Ollama server. For power users with custom models.',
          icon: Icons.dns_outlined,
          color: const Color(0xFFF59E0B),
          selected: selected == 'ollama',
          onTap: () => onChanged('ollama'),
        ),
      ],
    );
  }
}

class _ModelOption extends StatelessWidget {
  final String value;
  final String title;
  final String subtitle;
  final IconData icon;
  final Color color;
  final bool selected;
  final String? badge;
  final VoidCallback onTap;

  const _ModelOption({
    required this.value,
    required this.title,
    required this.subtitle,
    required this.icon,
    required this.color,
    required this.selected,
    this.badge,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return Material(
      color: selected
          ? color.withValues(alpha: 0.08)
          : colorScheme.surfaceContainerHighest.withValues(alpha: 0.35),
      borderRadius: BorderRadius.circular(14),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(14),
        child: Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(14),
            border: Border.all(
              color: selected ? color.withValues(alpha: 0.5) : colorScheme.outline.withValues(alpha: 0.1),
              width: selected ? 1.5 : 1,
            ),
          ),
          child: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: color.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Icon(icon, size: 22, color: color),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Text(
                          title,
                          style: theme.textTheme.titleSmall?.copyWith(
                            fontWeight: FontWeight.w600,
                            color: selected ? color : colorScheme.onSurface,
                          ),
                        ),
                        if (badge != null) ...[
                          const SizedBox(width: 8),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
                            decoration: BoxDecoration(
                              color: color.withValues(alpha: 0.15),
                              borderRadius: BorderRadius.circular(6),
                            ),
                            child: Text(
                              badge!,
                              style: theme.textTheme.labelSmall?.copyWith(
                                color: color,
                                fontWeight: FontWeight.w600,
                                fontSize: 10,
                              ),
                            ),
                          ),
                        ],
                      ],
                    ),
                    const SizedBox(height: 3),
                    Text(
                      subtitle,
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: colorScheme.onSurface.withValues(alpha: 0.6),
                        height: 1.4,
                      ),
                    ),
                  ],
                ),
              ),
              Container(
                width: 22,
                height: 22,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  border: Border.all(
                    color: selected ? color : colorScheme.outline.withValues(alpha: 0.3),
                    width: selected ? 2 : 1.5,
                  ),
                  color: selected ? color.withValues(alpha: 0.15) : Colors.transparent,
                ),
                child: selected
                    ? Center(child: Container(
                        width: 10, height: 10,
                        decoration: BoxDecoration(shape: BoxShape.circle, color: color),
                      ))
                    : null,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Page 3: Choose writing style
// ---------------------------------------------------------------------------

class _StylePage extends StatelessWidget {
  final String selected;
  final ValueChanged<String> onChanged;

  const _StylePage({super.key, required this.selected, required this.onChanged});

  static const _styles = [
    _StyleDef('professional', 'Professional', 'Clear and polished — great for work messages.', Icons.business_center_rounded, Color(0xFF3B82F6)),
    _StyleDef('casual', 'Casual', 'Friendly and natural — keeps your personality.', Icons.chat_bubble_outline_rounded, Color(0xFF10B981)),
    _StyleDef('concise', 'Concise', 'Straight to the point — removes fluff.', Icons.compress_rounded, Color(0xFFF59E0B)),
    _StyleDef('academic', 'Academic', 'Formal and precise — for papers and docs.', Icons.school_rounded, Color(0xFF8B5CF6)),
  ];

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Pick a writing style',
          style: theme.textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.bold),
        ),
        const SizedBox(height: 8),
        Text(
          'This sets the default tone. You can add custom styles later.',
          style: theme.textTheme.bodyMedium?.copyWith(
            color: colorScheme.onSurface.withValues(alpha: 0.6),
          ),
        ),
        const SizedBox(height: 24),
        Wrap(
          spacing: 10,
          runSpacing: 10,
          children: _styles.map((s) {
            final active = selected == s.value;
            return _StyleCard(def: s, active: active, onTap: () => onChanged(s.value));
          }).toList(),
        ),
      ],
    );
  }
}

class _StyleDef {
  final String value;
  final String label;
  final String description;
  final IconData icon;
  final Color color;
  const _StyleDef(this.value, this.label, this.description, this.icon, this.color);
}

class _StyleCard extends StatelessWidget {
  final _StyleDef def;
  final bool active;
  final VoidCallback onTap;

  const _StyleCard({required this.def, required this.active, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return Material(
      color: active
          ? def.color.withValues(alpha: 0.08)
          : colorScheme.surfaceContainerHighest.withValues(alpha: 0.35),
      borderRadius: BorderRadius.circular(14),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(14),
        child: Container(
          width: 220,
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(14),
            border: Border.all(
              color: active ? def.color.withValues(alpha: 0.5) : colorScheme.outline.withValues(alpha: 0.1),
              width: active ? 1.5 : 1,
            ),
          ),
          child: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: def.color.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Icon(def.icon, size: 20, color: active ? def.color : colorScheme.onSurface.withValues(alpha: 0.5)),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      def.label,
                      style: theme.textTheme.titleSmall?.copyWith(
                        fontWeight: FontWeight.w600,
                        color: active ? def.color : colorScheme.onSurface,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      def.description,
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: colorScheme.onSurface.withValues(alpha: 0.55),
                        height: 1.3,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
