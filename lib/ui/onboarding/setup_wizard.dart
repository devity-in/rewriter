import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../core/models/app_config.dart';
import '../../ui/providers/app_provider.dart';
import '../settings/api_key_dialog.dart';

/// Setup wizard for first-time configuration
class SetupWizard extends StatefulWidget {
  final VoidCallback onComplete;

  const SetupWizard({super.key, required this.onComplete});

  @override
  State<SetupWizard> createState() => _SetupWizardState();
}

class _SetupWizardState extends State<SetupWizard> {
  int _currentStep = 0;
  String? _apiKey;
  String _selectedStyle = 'professional';

  final List<StyleOption> _styleOptions = [
    StyleOption(
      value: 'professional',
      label: 'Professional',
      icon: Icons.business_center_rounded,
      color: const Color(0xFF3B82F6),
    ),
    StyleOption(
      value: 'casual',
      label: 'Casual',
      icon: Icons.chat_bubble_outline_rounded,
      color: const Color(0xFF10B981),
    ),
    StyleOption(
      value: 'concise',
      label: 'Concise',
      icon: Icons.compress_rounded,
      color: const Color(0xFFF59E0B),
    ),
    StyleOption(
      value: 'academic',
      label: 'Academic',
      icon: Icons.school_rounded,
      color: const Color(0xFF8B5CF6),
    ),
  ];

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
            // Progress indicator
            Row(
              children: [
                _buildStepIndicator(0, 'API Key'),
                Expanded(
                  child: Container(
                    height: 2,
                    color: _currentStep > 0
                        ? colorScheme.primary
                        : colorScheme.outline.withValues(alpha: 0.2),
                  ),
                ),
                _buildStepIndicator(1, 'Style'),
                Expanded(
                  child: Container(
                    height: 2,
                    color: _currentStep > 1
                        ? colorScheme.primary
                        : colorScheme.outline.withValues(alpha: 0.2),
                  ),
                ),
                _buildStepIndicator(2, 'Done'),
              ],
            ),
            const SizedBox(height: 32),

            // Step content
            if (_currentStep == 0) _buildApiKeyStep(),
            if (_currentStep == 1) _buildStyleStep(),
            if (_currentStep == 2) _buildCompleteStep(),

            const SizedBox(height: 24),

            // Navigation buttons
            Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                if (_currentStep > 0)
                  TextButton(
                    onPressed: () {
                      setState(() {
                        _currentStep--;
                      });
                    },
                    child: const Text('Back'),
                  ),
                if (_currentStep < 2) ...[
                  const SizedBox(width: 12),
                  FilledButton(
                    onPressed: _canProceed() ? _nextStep : null,
                    child: const Text('Next'),
                  ),
                ] else ...[
                  const SizedBox(width: 12),
                  FilledButton(
                    onPressed: _completeSetup,
                    child: const Text('Finish'),
                  ),
                ],
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildStepIndicator(int step, String label) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final isActive = _currentStep == step;
    final isCompleted = _currentStep > step;

    return Column(
      children: [
        Container(
          width: 32,
          height: 32,
          decoration: BoxDecoration(
            color: isCompleted || isActive
                ? colorScheme.primary
                : colorScheme.outline.withValues(alpha: 0.2),
            shape: BoxShape.circle,
          ),
          child: Center(
            child: isCompleted
                ? Icon(Icons.check, size: 18, color: colorScheme.onPrimary)
                : Text(
                    '${step + 1}',
                    style: TextStyle(
                      color: isActive
                          ? colorScheme.onPrimary
                          : colorScheme.onSurface.withValues(alpha: 0.5),
                      fontWeight: FontWeight.bold,
                    ),
                  ),
          ),
        ),
        const SizedBox(height: 4),
        Text(
          label,
          style: theme.textTheme.bodySmall?.copyWith(
            color: isActive || isCompleted
                ? colorScheme.primary
                : colorScheme.onSurface.withValues(alpha: 0.5),
            fontWeight: isActive ? FontWeight.w600 : FontWeight.normal,
          ),
        ),
      ],
    );
  }

  Widget _buildApiKeyStep() {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Step 1: API Key',
          style: theme.textTheme.titleLarge?.copyWith(
            fontWeight: FontWeight.bold,
          ),
        ),
        const SizedBox(height: 12),
        Text(
          'Enter your Google Gemini API key to enable rewriting. You can get one from Google AI Studio.',
          style: theme.textTheme.bodyMedium?.copyWith(
            color: colorScheme.onSurface.withValues(alpha: 0.7),
            height: 1.5,
          ),
        ),
        const SizedBox(height: 24),
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: colorScheme.surfaceContainerHighest.withValues(alpha: 0.5),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: _apiKey != null && _apiKey!.isNotEmpty
                  ? const Color(0xFF10B981)
                  : colorScheme.outline.withValues(alpha: 0.1),
            ),
          ),
          child: Row(
            children: [
              Icon(
                _apiKey != null && _apiKey!.isNotEmpty
                    ? Icons.check_circle
                    : Icons.key,
                color: _apiKey != null && _apiKey!.isNotEmpty
                    ? const Color(0xFF10B981)
                    : colorScheme.onSurface.withValues(alpha: 0.5),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  _apiKey != null && _apiKey!.isNotEmpty
                      ? 'API key configured'
                      : 'No API key',
                  style: theme.textTheme.bodyMedium,
                ),
              ),
              TextButton(
                onPressed: () async {
                  final key = await showDialog<String>(
                    context: context,
                    builder: (context) => const ApiKeyDialog(),
                  );
                  if (key != null && key.isNotEmpty) {
                    setState(() {
                      _apiKey = key;
                    });
                  }
                },
                child: Text(
                  _apiKey != null && _apiKey!.isNotEmpty
                      ? 'Change'
                      : 'Configure',
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 12),
        TextButton.icon(
          onPressed: () {
            // Open Google AI Studio
          },
          icon: const Icon(Icons.open_in_new, size: 16),
          label: const Text('Get API key from Google AI Studio'),
        ),
      ],
    );
  }

  Widget _buildStyleStep() {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Step 2: Writing Style',
          style: theme.textTheme.titleLarge?.copyWith(
            fontWeight: FontWeight.bold,
          ),
        ),
        const SizedBox(height: 12),
        Text(
          'Choose your preferred writing style. You can change this later in settings.',
          style: theme.textTheme.bodyMedium?.copyWith(
            color: colorScheme.onSurface.withValues(alpha: 0.7),
            height: 1.5,
          ),
        ),
        const SizedBox(height: 24),
        Wrap(
          spacing: 12,
          runSpacing: 12,
          children: _styleOptions.map((option) {
            final isSelected = _selectedStyle == option.value;
            return _StyleCard(
              option: option,
              isSelected: isSelected,
              onTap: () {
                setState(() {
                  _selectedStyle = option.value;
                });
              },
            );
          }).toList(),
        ),
      ],
    );
  }

  Widget _buildCompleteStep() {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        Container(
          padding: const EdgeInsets.all(24),
          decoration: BoxDecoration(
            color: const Color(0xFF10B981).withValues(alpha: 0.1),
            shape: BoxShape.circle,
          ),
          child: const Icon(
            Icons.check_circle,
            size: 64,
            color: Color(0xFF10B981),
          ),
        ),
        const SizedBox(height: 24),
        Text(
          'All Set!',
          style: theme.textTheme.headlineSmall?.copyWith(
            fontWeight: FontWeight.bold,
          ),
        ),
        const SizedBox(height: 12),
        Text(
          'Rewriter is ready to use. Copy any English text and it will be automatically rewritten.',
          textAlign: TextAlign.center,
          style: theme.textTheme.bodyMedium?.copyWith(
            color: colorScheme.onSurface.withValues(alpha: 0.7),
            height: 1.5,
          ),
        ),
      ],
    );
  }

  bool _canProceed() {
    if (_currentStep == 0) {
      return _apiKey != null && _apiKey!.isNotEmpty;
    }
    return true;
  }

  void _nextStep() {
    if (_canProceed()) {
      setState(() {
        _currentStep++;
      });
    }
  }

  Future<void> _completeSetup() async {
    final provider = context.read<AppProvider>();
    final config = AppConfig(
      enabled: true,
      apiKey: _apiKey,
      rewriteStyle: _selectedStyle,
    );
    await provider.updateConfig(config);
    // onComplete will mark onboarding as complete and hide window
    widget.onComplete();
  }
}

class StyleOption {
  final String value;
  final String label;
  final IconData icon;
  final Color color;

  StyleOption({
    required this.value,
    required this.label,
    required this.icon,
    required this.color,
  });
}

class _StyleCard extends StatelessWidget {
  final StyleOption option;
  final bool isSelected;
  final VoidCallback onTap;

  const _StyleCard({
    required this.option,
    required this.isSelected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: Container(
          width: 100,
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: isSelected
                ? option.color.withValues(alpha: 0.1)
                : colorScheme.surfaceContainerHighest.withValues(alpha: 0.5),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: isSelected
                  ? option.color
                  : colorScheme.outline.withValues(alpha: 0.1),
              width: isSelected ? 2 : 1,
            ),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                option.icon,
                size: 32,
                color: isSelected
                    ? option.color
                    : colorScheme.onSurface.withValues(alpha: 0.6),
              ),
              const SizedBox(height: 8),
              Text(
                option.label,
                style: theme.textTheme.bodySmall?.copyWith(
                  fontWeight: isSelected ? FontWeight.w600 : FontWeight.normal,
                  color: isSelected ? option.color : colorScheme.onSurface,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
