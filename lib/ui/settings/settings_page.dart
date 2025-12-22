import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../ui/providers/app_provider.dart';
import '../../core/services/gemini_service.dart';
import '../../core/services/local_ai_service.dart';
import '../../core/services/onboarding_service.dart';
import 'api_key_dialog.dart';

/// Minimal settings page with clean design
class SettingsPage extends StatefulWidget {
  const SettingsPage({super.key});

  @override
  State<SettingsPage> createState() => _SettingsPageState();
}

class _SettingsPageState extends State<SettingsPage> {
  final _formKey = GlobalKey<FormState>();
  late TextEditingController _debounceController;
  late TextEditingController _minLengthController;
  late TextEditingController _maxLengthController;
  late String _selectedStyle;
  late String _selectedModel;
  bool _showAdvanced = false;

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
  void initState() {
    super.initState();
    final config = context.read<AppProvider>().config;
    _debounceController = TextEditingController(
      text: (config?.debounceMs ?? 1000).toString(),
    );
    _minLengthController = TextEditingController(
      text: (config?.minSentenceLength ?? 10).toString(),
    );
    _maxLengthController = TextEditingController(
      text: (config?.maxSentenceLength ?? 500).toString(),
    );
    _selectedStyle = config?.rewriteStyle ?? 'professional';
    _selectedModel = config?.modelType ?? 'gemini'; // Default to Gemini API
  }

  @override
  void dispose() {
    _debounceController.dispose();
    _minLengthController.dispose();
    _maxLengthController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return Scaffold(
      backgroundColor: colorScheme.surface,
      body: Consumer<AppProvider>(
        builder: (context, provider, child) {
          final config = provider.config;
          if (config == null) {
            return Center(
              child: CircularProgressIndicator(color: colorScheme.primary),
            );
          }

          return SafeArea(
            child: Form(
              key: _formKey,
              child: CustomScrollView(
                physics: const BouncingScrollPhysics(),
                slivers: [
                  // Minimal Header
                  SliverToBoxAdapter(
                    child: Padding(
                      padding: const EdgeInsets.fromLTRB(24, 32, 24, 20),
                      child: Text(
                        'Settings',
                        style: theme.textTheme.headlineSmall?.copyWith(
                          fontWeight: FontWeight.w600,
                          color: colorScheme.onSurface,
                          letterSpacing: -0.5,
                        ),
                      ),
                    ),
                  ),

                  // Status Toggle
                  SliverToBoxAdapter(
                    child: Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 24),
                      child: _StatusCard(
                        isEnabled: config.enabled,
                        hasApiKey: provider.hasApiKey,
                        onToggle: (value) {
                          provider.updateConfig(
                            config.copyWith(enabled: value),
                          );
                        },
                      ),
                    ),
                  ),

                  const SliverToBoxAdapter(child: SizedBox(height: 24)),

                  // Model Selection Section
                  SliverToBoxAdapter(
                    child: Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 24),
                      child: _ModelSelectionSection(
                        selectedModel: _selectedModel,
                        onModelSelected: (model) {
                          setState(() {
                            _selectedModel = model;
                          });
                          provider.updateConfig(
                            config.copyWith(modelType: model),
                          );
                        },
                      ),
                    ),
                  ),

                  const SliverToBoxAdapter(child: SizedBox(height: 24)),

                  // API Key Section (only shown for Gemini)
                  if (_selectedModel == 'gemini')
                    SliverToBoxAdapter(
                      child: Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 24),
                        child: _ApiKeySection(
                          hasApiKey: provider.hasApiKey,
                          onConfigure: () async {
                            final newKey = await showDialog<String>(
                              context: context,
                              builder: (context) => const ApiKeyDialog(),
                            );
                            if (newKey != null && newKey.isNotEmpty) {
                              await provider.updateConfig(
                                config.copyWith(apiKey: newKey),
                              );
                              // Mark onboarding as complete when API key is configured
                              // This ensures onboarding only shows once
                              final onboardingService = OnboardingService();
                              final hasCompleted = await onboardingService
                                  .hasCompletedOnboarding();
                              if (!hasCompleted) {
                                await onboardingService
                                    .markOnboardingComplete();
                                // Hide window after API key is configured (onboarding complete)
                                try {
                                  // Access windowManager through context if needed, or keep window visible
                                  // For now, keep window visible so user can continue configuring
                                } catch (e) {
                                  // Ignore errors
                                }
                              }
                            }
                          },
                        ),
                      ),
                    ),

                  // Spacing
                  const SliverToBoxAdapter(child: SizedBox(height: 24)),

                  const SliverToBoxAdapter(child: SizedBox(height: 24)),

                  // Writing Style Section
                  SliverToBoxAdapter(
                    child: Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 24),
                      child: _WritingStyleSection(
                        selectedStyle: _selectedStyle,
                        styleOptions: _styleOptions,
                        onStyleSelected: (style) {
                          setState(() {
                            _selectedStyle = style;
                          });
                          provider.updateConfig(
                            config.copyWith(rewriteStyle: style),
                          );
                        },
                      ),
                    ),
                  ),

                  const SliverToBoxAdapter(child: SizedBox(height: 24)),

                  // Rate Limit & Usage Section (only for Gemini)
                  if (_selectedModel == 'gemini')
                    SliverToBoxAdapter(
                      child: Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 24),
                        child: _RateLimitSection(provider: provider),
                      ),
                    ),
                  if (_selectedModel == 'gemini')
                    const SliverToBoxAdapter(child: SizedBox(height: 24)),

                  const SliverToBoxAdapter(child: SizedBox(height: 24)),

                  // Test Button
                  SliverToBoxAdapter(
                    child: Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 24),
                      child: _TestSection(provider: provider),
                    ),
                  ),

                  const SliverToBoxAdapter(child: SizedBox(height: 24)),

                  // Advanced Settings
                  SliverToBoxAdapter(
                    child: Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 24),
                      child: _AdvancedSettingsSection(
                        showAdvanced: _showAdvanced,
                        debounceController: _debounceController,
                        minLengthController: _minLengthController,
                        maxLengthController: _maxLengthController,
                        config: config,
                        provider: provider,
                        onToggle: () {
                          setState(() {
                            _showAdvanced = !_showAdvanced;
                          });
                        },
                      ),
                    ),
                  ),

                  const SliverToBoxAdapter(child: SizedBox(height: 32)),
                ],
              ),
            ),
          );
        },
      ),
    );
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

class _StatusCard extends StatelessWidget {
  final bool isEnabled;
  final bool hasApiKey;
  final ValueChanged<bool> onToggle;

  const _StatusCard({
    required this.isEnabled,
    required this.hasApiKey,
    required this.onToggle,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final isActive = isEnabled && hasApiKey;

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: colorScheme.surfaceContainerHighest.withValues(alpha: 0.5),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: colorScheme.outline.withValues(alpha: 0.1)),
      ),
      child: Row(
        children: [
          Icon(
            isActive ? Icons.check_circle_outline : Icons.error_outline,
            color: isActive
                ? const Color(0xFF10B981)
                : colorScheme.onSurface.withValues(alpha: 0.5),
            size: 24,
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  isActive
                      ? 'Active'
                      : hasApiKey
                      ? 'Disabled'
                      : 'Setup Required',
                  style: theme.textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.w600,
                    color: colorScheme.onSurface,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  isActive
                      ? 'Monitoring clipboard'
                      : hasApiKey
                      ? 'Enable to start'
                      : 'Configure API key',
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: colorScheme.onSurface.withValues(alpha: 0.6),
                  ),
                ),
              ],
            ),
          ),
          Switch(
            value: isEnabled,
            onChanged: hasApiKey ? onToggle : null,
            activeThumbColor: const Color(0xFF10B981),
          ),
        ],
      ),
    );
  }
}

class _ApiKeySection extends StatelessWidget {
  final bool hasApiKey;
  final VoidCallback onConfigure;

  const _ApiKeySection({required this.hasApiKey, required this.onConfigure});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'API Key',
          style: theme.textTheme.titleMedium?.copyWith(
            fontWeight: FontWeight.w600,
            color: colorScheme.onSurface,
          ),
        ),
        const SizedBox(height: 12),
        Material(
          color: Colors.transparent,
          child: InkWell(
            onTap: onConfigure,
            borderRadius: BorderRadius.circular(12),
            child: Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: colorScheme.surfaceContainerHighest.withValues(
                  alpha: 0.5,
                ),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(
                  color: colorScheme.outline.withValues(alpha: 0.1),
                ),
              ),
              child: Row(
                children: [
                  Icon(
                    hasApiKey ? Icons.key : Icons.key_off,
                    color: hasApiKey
                        ? const Color(0xFF10B981)
                        : colorScheme.onSurface.withValues(alpha: 0.5),
                    size: 20,
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      hasApiKey ? 'Configured' : 'Not configured',
                      style: theme.textTheme.bodyMedium?.copyWith(
                        color: colorScheme.onSurface,
                      ),
                    ),
                  ),
                  Icon(
                    Icons.chevron_right,
                    color: colorScheme.onSurface.withValues(alpha: 0.4),
                    size: 20,
                  ),
                ],
              ),
            ),
          ),
        ),
      ],
    );
  }
}

class _WritingStyleSection extends StatelessWidget {
  final String selectedStyle;
  final List<StyleOption> styleOptions;
  final ValueChanged<String> onStyleSelected;

  const _WritingStyleSection({
    required this.selectedStyle,
    required this.styleOptions,
    required this.onStyleSelected,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Writing Style',
          style: theme.textTheme.titleMedium?.copyWith(
            fontWeight: FontWeight.w600,
            color: colorScheme.onSurface,
          ),
        ),
        const SizedBox(height: 12),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: styleOptions.map((option) {
            final isSelected = selectedStyle == option.value;
            return _StyleCard(
              option: option,
              isSelected: isSelected,
              onTap: () => onStyleSelected(option.value),
            );
          }).toList(),
        ),
      ],
    );
  }
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
        borderRadius: BorderRadius.circular(10),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 150),
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          decoration: BoxDecoration(
            color: isSelected
                ? option.color.withValues(alpha: 0.1)
                : colorScheme.surfaceContainerHighest.withValues(alpha: 0.5),
            borderRadius: BorderRadius.circular(10),
            border: Border.all(
              color: isSelected
                  ? option.color
                  : colorScheme.outline.withValues(alpha: 0.1),
              width: isSelected ? 1.5 : 1,
            ),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                option.icon,
                size: 18,
                color: isSelected
                    ? option.color
                    : colorScheme.onSurface.withValues(alpha: 0.6),
              ),
              const SizedBox(width: 8),
              Text(
                option.label,
                style: theme.textTheme.bodyMedium?.copyWith(
                  fontWeight: isSelected ? FontWeight.w600 : FontWeight.normal,
                  color: isSelected ? option.color : colorScheme.onSurface,
                ),
              ),
              if (isSelected) ...[
                const SizedBox(width: 6),
                Icon(Icons.check, size: 16, color: option.color),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

class _AdvancedSettingsSection extends StatelessWidget {
  final bool showAdvanced;
  final TextEditingController debounceController;
  final TextEditingController minLengthController;
  final TextEditingController maxLengthController;
  final dynamic config;
  final AppProvider provider;
  final VoidCallback onToggle;

  const _AdvancedSettingsSection({
    required this.showAdvanced,
    required this.debounceController,
    required this.minLengthController,
    required this.maxLengthController,
    required this.config,
    required this.provider,
    required this.onToggle,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Material(
          color: Colors.transparent,
          child: InkWell(
            onTap: onToggle,
            borderRadius: BorderRadius.circular(8),
            child: Padding(
              padding: const EdgeInsets.symmetric(vertical: 4),
              child: Row(
                children: [
                  Text(
                    'Advanced',
                    style: theme.textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.w600,
                      color: colorScheme.onSurface,
                    ),
                  ),
                  const Spacer(),
                  AnimatedRotation(
                    turns: showAdvanced ? 0.5 : 0,
                    duration: const Duration(milliseconds: 200),
                    child: Icon(
                      Icons.keyboard_arrow_down,
                      color: colorScheme.onSurface.withValues(alpha: 0.6),
                      size: 20,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
        AnimatedSize(
          duration: const Duration(milliseconds: 200),
          curve: Curves.easeInOut,
          child: showAdvanced
              ? Column(
                  children: [
                    const SizedBox(height: 16),
                    _AdvancedSettingField(
                      label: 'Debounce Delay',
                      controller: debounceController,
                      suffix: 'ms',
                      icon: Icons.timer_outlined,
                      onChanged: (value) {
                        final ms = int.tryParse(value);
                        if (ms != null && ms > 0) {
                          provider.updateConfig(
                            config.copyWith(debounceMs: ms),
                          );
                        }
                      },
                    ),
                    const SizedBox(height: 12),
                    _AdvancedSettingField(
                      label: 'Min Length',
                      controller: minLengthController,
                      suffix: 'chars',
                      icon: Icons.text_decrease_rounded,
                      onChanged: (value) {
                        final len = int.tryParse(value);
                        if (len != null && len > 0) {
                          provider.updateConfig(
                            config.copyWith(minSentenceLength: len),
                          );
                        }
                      },
                    ),
                    const SizedBox(height: 12),
                    _AdvancedSettingField(
                      label: 'Max Length',
                      controller: maxLengthController,
                      suffix: 'chars',
                      icon: Icons.text_increase_rounded,
                      onChanged: (value) {
                        final len = int.tryParse(value);
                        if (len != null && len > 0) {
                          provider.updateConfig(
                            config.copyWith(maxSentenceLength: len),
                          );
                        }
                      },
                    ),
                  ],
                )
              : const SizedBox.shrink(),
        ),
      ],
    );
  }
}

class _AdvancedSettingField extends StatelessWidget {
  final String label;
  final TextEditingController controller;
  final String suffix;
  final IconData icon;
  final ValueChanged<String> onChanged;

  const _AdvancedSettingField({
    required this.label,
    required this.controller,
    required this.suffix,
    required this.icon,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return TextField(
      controller: controller,
      keyboardType: TextInputType.number,
      onChanged: onChanged,
      style: theme.textTheme.bodyMedium,
      decoration: InputDecoration(
        labelText: label,
        suffixText: suffix,
        prefixIcon: Icon(
          icon,
          size: 18,
          color: colorScheme.onSurface.withValues(alpha: 0.6),
        ),
        filled: true,
        fillColor: colorScheme.surfaceContainerHighest.withValues(alpha: 0.5),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(10),
          borderSide: BorderSide(
            color: colorScheme.outline.withValues(alpha: 0.1),
          ),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(10),
          borderSide: BorderSide(
            color: colorScheme.outline.withValues(alpha: 0.1),
          ),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(10),
          borderSide: BorderSide(color: colorScheme.primary, width: 1.5),
        ),
        contentPadding: const EdgeInsets.symmetric(
          horizontal: 16,
          vertical: 12,
        ),
        isDense: true,
      ),
    );
  }
}

class _RateLimitSection extends StatefulWidget {
  final AppProvider provider;

  const _RateLimitSection({required this.provider});

  @override
  State<_RateLimitSection> createState() => _RateLimitSectionState();
}

class _RateLimitSectionState extends State<_RateLimitSection> {
  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return FutureBuilder(
      future: widget.provider.rewriterService.rateLimitService.getStats(),
      builder: (context, snapshot) {
        if (!snapshot.hasData) {
          return const SizedBox.shrink();
        }

        final stats = snapshot.data!;

        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'API Usage',
              style: theme.textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.w600,
                color: colorScheme.onSurface,
              ),
            ),
            const SizedBox(height: 12),
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: colorScheme.surfaceContainerHighest.withValues(
                  alpha: 0.5,
                ),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(
                  color: colorScheme.outline.withValues(alpha: 0.1),
                ),
              ),
              child: Column(
                children: [
                  _UsageRow(
                    label: 'Today',
                    current: stats.requestsPerDay,
                    max: stats.maxRequestsPerDay,
                    percentage: stats.dayUsagePercentage,
                  ),
                  const SizedBox(height: 12),
                  _UsageRow(
                    label: 'This Hour',
                    current: stats.requestsPerHour,
                    max: stats.maxRequestsPerHour,
                    percentage: stats.hourUsagePercentage,
                  ),
                  const SizedBox(height: 12),
                  _UsageRow(
                    label: 'This Minute',
                    current: stats.requestsPerMinute,
                    max: stats.maxRequestsPerMinute,
                    percentage: stats.minuteUsagePercentage,
                  ),
                  const Divider(height: 24),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        'Total Requests',
                        style: theme.textTheme.bodyMedium?.copyWith(
                          color: colorScheme.onSurface.withValues(alpha: 0.7),
                        ),
                      ),
                      Text(
                        '${stats.totalRequests}',
                        style: theme.textTheme.titleMedium?.copyWith(
                          fontWeight: FontWeight.w600,
                          color: colorScheme.onSurface,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ],
        );
      },
    );
  }
}

class _UsageRow extends StatelessWidget {
  final String label;
  final int current;
  final int max;
  final double percentage;

  const _UsageRow({
    required this.label,
    required this.current,
    required this.max,
    required this.percentage,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final isWarning = percentage >= 80;
    final isCritical = percentage >= 95;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              label,
              style: theme.textTheme.bodySmall?.copyWith(
                color: colorScheme.onSurface.withValues(alpha: 0.7),
              ),
            ),
            Text(
              '$current / $max',
              style: theme.textTheme.bodySmall?.copyWith(
                fontWeight: FontWeight.w600,
                color: isCritical
                    ? Colors.red
                    : isWarning
                    ? Colors.orange
                    : colorScheme.onSurface,
              ),
            ),
          ],
        ),
        const SizedBox(height: 4),
        ClipRRect(
          borderRadius: BorderRadius.circular(4),
          child: LinearProgressIndicator(
            value: percentage / 100,
            minHeight: 6,
            backgroundColor: colorScheme.outline.withValues(alpha: 0.1),
            valueColor: AlwaysStoppedAnimation<Color>(
              isCritical
                  ? Colors.red
                  : isWarning
                  ? Colors.orange
                  : colorScheme.primary,
            ),
          ),
        ),
      ],
    );
  }
}

class _TestSection extends StatefulWidget {
  final AppProvider provider;

  const _TestSection({required this.provider});

  @override
  State<_TestSection> createState() => _TestSectionState();
}

class _TestSectionState extends State<_TestSection> {
  bool _isTesting = false;
  String? _testResult;

  Future<void> _testRewrite() async {
    final config = widget.provider.config;
    if (config == null) {
      _showError('Configuration not loaded');
      return;
    }

    if (config.modelType == 'gemini' && !widget.provider.hasApiKey) {
      _showError('Please configure your API key first');
      return;
    }

    setState(() {
      _isTesting = true;
      _testResult = null;
    });

    try {
      final rewriterService = widget.provider.rewriterService;

      if (config.modelType == 'local') {
        final localAIService = LocalAIService();
        await localAIService.initialize(
          modelUrl: config.modelUrl,
          kaggleUsername: config.kaggleUsername,
          kaggleKey: config.kaggleKey,
        );

        const testText =
            'This is a test sentence to verify the rewriting functionality.';
        final result = await localAIService.rewriteText(
          testText,
          style: config.rewriteStyle,
        );

        if (mounted) {
          setState(() {
            _isTesting = false;
            _testResult = result.success
                ? 'Success! Rewritten: "${result.rewrittenText}"'
                : 'Error: ${result.error}';
          });
        }

        localAIService.dispose();
      } else {
        final geminiService = GeminiService(
          apiKey: config.apiKey!,
          rateLimitService: rewriterService.rateLimitService,
        );

        const testText =
            'This is a test sentence to verify the rewriting functionality.';
        final result = await geminiService.rewriteText(
          testText,
          style: config.rewriteStyle,
        );

        if (mounted) {
          setState(() {
            _isTesting = false;
            _testResult = result.success
                ? 'Success! Rewritten: "${result.rewrittenText}"'
                : 'Error: ${result.error}';
          });
        }
      }
    } catch (e) {
      if (mounted) {
        final errorStr = e.toString().toLowerCase();
        String errorMessage;
        if (errorStr.contains('native assets not available') ||
            errorStr.contains('native-assets') ||
            errorStr.contains('symbol not found') ||
            errorStr.contains('couldn\'t resolve native')) {
          errorMessage =
              'Local AI native assets not configured.\n'
              'Enable native-assets: `flutter config --enable-native-assets`\n'
              'Then run `flutter pub get` and rebuild the app.\n'
              'Alternatively, switch to Gemini API in the model selection above.';
        } else {
          errorMessage = 'Error: $e';
        }
        setState(() {
          _isTesting = false;
          _testResult = errorMessage;
        });
      }
    }
  }

  void _showError(String message) {
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text(message)));
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Test Rewriting',
          style: theme.textTheme.titleMedium?.copyWith(
            fontWeight: FontWeight.w600,
            color: colorScheme.onSurface,
          ),
        ),
        const SizedBox(height: 12),
        OutlinedButton.icon(
          onPressed: _isTesting ? null : _testRewrite,
          icon: _isTesting
              ? SizedBox(
                  width: 16,
                  height: 16,
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    color: colorScheme.primary,
                  ),
                )
              : const Icon(Icons.play_arrow_rounded, size: 18),
          label: Text(_isTesting ? 'Testing...' : 'Test Rewrite'),
          style: OutlinedButton.styleFrom(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
          ),
        ),
        if (_testResult != null) ...[
          const SizedBox(height: 12),
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: _testResult!.contains('Success')
                  ? const Color(0xFF10B981).withValues(alpha: 0.1)
                  : Colors.red.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Icon(
                  _testResult!.contains('Success')
                      ? Icons.check_circle
                      : Icons.error_outline,
                  size: 20,
                  color: _testResult!.contains('Success')
                      ? const Color(0xFF10B981)
                      : Colors.red,
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    _testResult!,
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: colorScheme.onSurface,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ],
    );
  }
}

class _ModelSelectionSection extends StatelessWidget {
  final String selectedModel;
  final ValueChanged<String> onModelSelected;

  const _ModelSelectionSection({
    required this.selectedModel,
    required this.onModelSelected,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'AI Model',
          style: theme.textTheme.titleMedium?.copyWith(
            fontWeight: FontWeight.w600,
            color: colorScheme.onSurface,
          ),
        ),
        const SizedBox(height: 12),
        Row(
          children: [
            Expanded(
              child: _ModelCard(
                model: 'gemini',
                label: 'Gemini',
                icon: Icons.cloud,
                color: const Color(0xFF3B82F6),
                isSelected: selectedModel == 'gemini',
                onTap: () => onModelSelected('gemini'),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: _ModelCard(
                model: 'local',
                label: 'Local AI',
                icon: Icons.memory,
                color: const Color(0xFF8B5CF6),
                isSelected: selectedModel == 'local',
                onTap: () => onModelSelected('local'),
              ),
            ),
          ],
        ),
      ],
    );
  }
}

class _ModelCard extends StatelessWidget {
  final String model;
  final String label;
  final IconData icon;
  final Color color;
  final bool isSelected;
  final VoidCallback onTap;

  const _ModelCard({
    required this.model,
    required this.label,
    required this.icon,
    required this.color,
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
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 150),
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: isSelected
                ? color.withValues(alpha: 0.1)
                : colorScheme.surfaceContainerHighest.withValues(alpha: 0.5),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: isSelected
                  ? color
                  : colorScheme.outline.withValues(alpha: 0.1),
              width: isSelected ? 2 : 1,
            ),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Icon(
                    icon,
                    size: 20,
                    color: isSelected
                        ? color
                        : colorScheme.onSurface.withValues(alpha: 0.6),
                  ),
                  const Spacer(),
                  if (isSelected)
                    Icon(Icons.check_circle, size: 18, color: color),
                ],
              ),
              const SizedBox(height: 8),
              Text(
                label,
                style: theme.textTheme.titleSmall?.copyWith(
                  fontWeight: FontWeight.w600,
                  color: isSelected ? color : colorScheme.onSurface,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                model == 'gemini' ? 'Cloud-based' : 'Local (offline)',
                style: theme.textTheme.bodySmall?.copyWith(
                  color: colorScheme.onSurface.withValues(alpha: 0.6),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
