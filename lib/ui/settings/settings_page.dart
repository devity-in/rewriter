import 'dart:async';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:http/http.dart' as http;
import '../../ui/providers/app_provider.dart';
import '../../core/services/gemini_service.dart';
import '../../core/services/local_ai_service.dart';
import '../../core/services/onboarding_service.dart';
import 'api_key_dialog.dart';

/// Clean and user-friendly settings page
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
                  // Header
                  SliverToBoxAdapter(
                    child: Padding(
                      padding: const EdgeInsets.fromLTRB(24, 32, 24, 20),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Settings',
                            style: theme.textTheme.headlineSmall?.copyWith(
                              fontWeight: FontWeight.w600,
                              color: colorScheme.onSurface,
                              letterSpacing: -0.5,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            'Configure your rewriting preferences',
                            style: theme.textTheme.bodyMedium?.copyWith(
                              color: colorScheme.onSurface.withValues(
                                alpha: 0.6,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),

                  // Status Card - Most Important
                  SliverToBoxAdapter(
                    child: Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 24),
                      child: _StatusCard(
                        isEnabled: config.enabled,
                        hasApiKey: provider.hasApiKey,
                        modelType: _selectedModel,
                        isLocalAIInitializing: provider.isLocalAIInitializing,
                        onToggle: (value) {
                          provider.updateConfig(
                            config.copyWith(enabled: value),
                          );
                        },
                      ),
                    ),
                  ),

                  const SliverToBoxAdapter(child: SizedBox(height: 32)),

                  // AI Model Configuration Section
                  SliverToBoxAdapter(
                    child: Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 24),
                      child: _SectionHeader(
                        title: 'AI Model',
                        subtitle: 'Choose how text is rewritten',
                      ),
                    ),
                  ),
                  const SliverToBoxAdapter(child: SizedBox(height: 12)),

                  // Model Selection
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

                  const SliverToBoxAdapter(child: SizedBox(height: 20)),

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
                              final onboardingService = OnboardingService();
                              final hasCompleted = await onboardingService
                                  .hasCompletedOnboarding();
                              if (!hasCompleted) {
                                await onboardingService
                                    .markOnboardingComplete();
                              }
                            }
                          },
                        ),
                      ),
                    ),

                  // Local AI Configuration Section (only shown for Local AI)
                  if (_selectedModel == 'local') ...[
                    SliverToBoxAdapter(
                      child: Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 24),
                        child: _LocalAIConfigSection(
                          key: ValueKey(config.modelUrl), // Force rebuild when URL changes
                          modelUrl: config.modelUrl,
                          onModelUrlChanged: (url) async {
                            await provider.updateConfig(
                              config.copyWith(modelUrl: url),
                            );
                          },
                        ),
                      ),
                    ),
                    const SliverToBoxAdapter(child: SizedBox(height: 20)),
                    SliverToBoxAdapter(
                      child: Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 24),
                        child: _DownloadedModelsSection(),
                      ),
                    ),
                  ],

                  const SliverToBoxAdapter(child: SizedBox(height: 32)),

                  // Writing Style Section
                  SliverToBoxAdapter(
                    child: Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 24),
                      child: _SectionHeader(
                        title: 'Writing Style',
                        subtitle: 'How should text be rewritten?',
                      ),
                    ),
                  ),
                  const SliverToBoxAdapter(child: SizedBox(height: 12)),
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

                  const SliverToBoxAdapter(child: SizedBox(height: 32)),

                  // Rate Limit & Usage Section (only for Gemini)
                  if (_selectedModel == 'gemini')
                    SliverToBoxAdapter(
                      child: Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 24),
                        child: _SectionHeader(
                          title: 'API Usage',
                          subtitle: 'Monitor your API requests',
                        ),
                      ),
                    ),
                  if (_selectedModel == 'gemini')
                    const SliverToBoxAdapter(child: SizedBox(height: 12)),
                  if (_selectedModel == 'gemini')
                    SliverToBoxAdapter(
                      child: Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 24),
                        child: _RateLimitSection(provider: provider),
                      ),
                    ),
                  if (_selectedModel == 'gemini')
                    const SliverToBoxAdapter(child: SizedBox(height: 32)),

                  // Test Section
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
  final String modelType;
  final bool isLocalAIInitializing;
  final ValueChanged<bool> onToggle;

  const _StatusCard({
    required this.isEnabled,
    required this.hasApiKey,
    required this.modelType,
    this.isLocalAIInitializing = false,
    required this.onToggle,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final isConfigured = modelType == 'local' || hasApiKey;
    final isActive = isEnabled && isConfigured && !isLocalAIInitializing;

    String statusText;
    String statusSubtext;
    IconData statusIcon;
    Color statusColor;

    if (isLocalAIInitializing) {
      statusText = 'Initializing';
      statusSubtext = 'Downloading and setting up local AI model...';
      statusIcon = Icons.download;
      statusColor = const Color(0xFF3B82F6);
    } else if (isActive) {
      statusText = 'Active';
      statusSubtext = 'Rewriting clipboard text automatically';
      statusIcon = Icons.check_circle;
      statusColor = const Color(0xFF10B981);
    } else if (!isConfigured) {
      statusText = 'Setup Required';
      statusSubtext = modelType == 'local'
          ? 'Configure local AI model below'
          : 'Add your API key below to get started';
      statusIcon = Icons.info_outline;
      statusColor = const Color(0xFFF59E0B);
    } else {
      statusText = 'Paused';
      statusSubtext = 'Enable to start rewriting';
      statusIcon = Icons.pause_circle_outline;
      statusColor = colorScheme.onSurface.withValues(alpha: 0.6);
    }

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: isActive
            ? statusColor.withValues(alpha: 0.1)
            : colorScheme.surfaceContainerHighest.withValues(alpha: 0.5),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: isActive
              ? statusColor.withValues(alpha: 0.3)
              : colorScheme.outline.withValues(alpha: 0.1),
          width: isActive ? 1.5 : 1,
        ),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: statusColor.withValues(alpha: 0.1),
              shape: BoxShape.circle,
            ),
            child: Icon(statusIcon, color: statusColor, size: 24),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  statusText,
                  style: theme.textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.w600,
                    color: colorScheme.onSurface,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  statusSubtext,
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: colorScheme.onSurface.withValues(alpha: 0.7),
                  ),
                ),
              ],
            ),
          ),
          Switch(
            value: isEnabled,
            onChanged: isConfigured ? onToggle : null,
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

    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onConfigure,
        borderRadius: BorderRadius.circular(12),
        child: Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: colorScheme.surfaceContainerHighest.withValues(alpha: 0.5),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: hasApiKey
                  ? const Color(0xFF10B981).withValues(alpha: 0.3)
                  : colorScheme.outline.withValues(alpha: 0.1),
              width: hasApiKey ? 1.5 : 1,
            ),
          ),
          child: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color:
                      (hasApiKey
                              ? const Color(0xFF10B981)
                              : colorScheme.onSurface.withValues(alpha: 0.3))
                          .withValues(alpha: 0.1),
                  shape: BoxShape.circle,
                ),
                child: Icon(
                  hasApiKey ? Icons.key : Icons.key_off,
                  color: hasApiKey
                      ? const Color(0xFF10B981)
                      : colorScheme.onSurface.withValues(alpha: 0.5),
                  size: 20,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      hasApiKey ? 'API Key Configured' : 'Add API Key',
                      style: theme.textTheme.bodyMedium?.copyWith(
                        fontWeight: FontWeight.w600,
                        color: colorScheme.onSurface,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      hasApiKey
                          ? 'Tap to change your API key'
                          : 'Required for Gemini API',
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: colorScheme.onSurface.withValues(alpha: 0.6),
                      ),
                    ),
                  ],
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
    return Wrap(
      spacing: 10,
      runSpacing: 10,
      children: styleOptions.map((option) {
        final isSelected = selectedStyle == option.value;
        return _StyleCard(
          option: option,
          isSelected: isSelected,
          onTap: () => onStyleSelected(option.value),
        );
      }).toList(),
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
              padding: const EdgeInsets.symmetric(vertical: 8),
              child: Row(
                children: [
                  Icon(
                    Icons.tune,
                    size: 20,
                    color: colorScheme.onSurface.withValues(alpha: 0.7),
                  ),
                  const SizedBox(width: 8),
                  Text(
                    'Advanced Settings',
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
                      label: 'Wait Time',
                      helperText: 'Delay before rewriting (milliseconds)',
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
                      label: 'Minimum Length',
                      helperText: 'Shortest sentence to rewrite',
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
                      label: 'Maximum Length',
                      helperText: 'Longest sentence to rewrite',
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
  final String? helperText;
  final TextEditingController controller;
  final String suffix;
  final IconData icon;
  final ValueChanged<String> onChanged;

  const _AdvancedSettingField({
    required this.label,
    this.helperText,
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
        helperText: helperText,
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
        if (config.modelUrl == null || config.modelUrl!.isEmpty) {
          if (mounted) {
            setState(() {
              _isTesting = false;
              _testResult =
                  'Error: Model URL is required. MediaPipe GenAI requires models to be downloaded at runtime. Please configure a model URL in settings.';
            });
          }
          return;
        }

        final localAIService = LocalAIService();
        await localAIService.initialize(modelUrl: config.modelUrl!);

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
          'Test Connection',
          style: theme.textTheme.titleMedium?.copyWith(
            fontWeight: FontWeight.w600,
            color: colorScheme.onSurface,
          ),
        ),
        const SizedBox(height: 4),
        Text(
          'Verify your AI model is working correctly',
          style: theme.textTheme.bodySmall?.copyWith(
            color: colorScheme.onSurface.withValues(alpha: 0.6),
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
          label: Text(_isTesting ? 'Testing...' : 'Run Test'),
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
              border: Border.all(
                color: _testResult!.contains('Success')
                    ? const Color(0xFF10B981).withValues(alpha: 0.3)
                    : Colors.red.withValues(alpha: 0.3),
              ),
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

class _LocalAIConfigSection extends StatefulWidget {
  final String? modelUrl;
  final ValueChanged<String?> onModelUrlChanged;

  const _LocalAIConfigSection({
    super.key,
    required this.modelUrl,
    required this.onModelUrlChanged,
  });

  @override
  State<_LocalAIConfigSection> createState() => _LocalAIConfigSectionState();
}

class _SectionHeader extends StatelessWidget {
  final String title;
  final String subtitle;

  const _SectionHeader({required this.title, required this.subtitle});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          title,
          style: theme.textTheme.titleMedium?.copyWith(
            fontWeight: FontWeight.w600,
            color: colorScheme.onSurface,
          ),
        ),
        const SizedBox(height: 4),
        Text(
          subtitle,
          style: theme.textTheme.bodySmall?.copyWith(
            color: colorScheme.onSurface.withValues(alpha: 0.6),
          ),
        ),
      ],
    );
  }
}

class _LocalAIConfigSectionState extends State<_LocalAIConfigSection> {
  late TextEditingController _modelUrlController;
  bool _isValidating = false;
  String? _validationMessage;
  int? _downloadProgressBytes;
  int? _downloadTotalBytes;
  String? _downloadStatus; // 'downloading', 'initializing', 'ready', 'error'

  @override
  void initState() {
    super.initState();
    _modelUrlController = TextEditingController(text: widget.modelUrl ?? '');
    // Set up listeners immediately and also after frame
    _setupProgressListener();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _setupProgressListener();
    });
  }

  void _setupProgressListener() {
    if (!mounted) return;
    final provider = Provider.of<AppProvider>(context, listen: false);
    final localAIService = provider.rewriterService.localAIService;
    if (localAIService != null) {
      // Set up progress callback - ensure it's set before download starts
      localAIService.onDownloadProgress = (downloaded, total) {
        if (mounted) {
          setState(() {
            _downloadProgressBytes = downloaded;
            _downloadTotalBytes = total;
            // Only update status if not already initializing
            if (_downloadStatus != 'initializing' && _downloadStatus != 'ready') {
              _downloadStatus = 'downloading';
            }
          });
        }
      };
      
      // Set up status callback
      localAIService.onStatusChanged = (status) {
        if (mounted) {
          setState(() {
            _downloadStatus = status;
            if (status == 'ready' || status == 'error') {
              // Keep progress visible briefly, then clear
              Future.delayed(const Duration(seconds: 1), () {
                if (mounted) {
                  setState(() {
                    _downloadProgressBytes = null;
                    _downloadTotalBytes = null;
                  });
                }
              });
            }
          });
        }
      };
      
      // Check if already downloading/initializing
      if (localAIService.isInitializing) {
        setState(() {
          _downloadStatus = 'downloading';
        });
      }
    }
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    // Re-setup listeners when dependencies change (e.g., when model URL changes)
    _setupProgressListener();
  }
  
  @override
  void didUpdateWidget(_LocalAIConfigSection oldWidget) {
    super.didUpdateWidget(oldWidget);
    // Re-setup listeners when widget updates (e.g., model URL changes)
    if (oldWidget.modelUrl != widget.modelUrl) {
      _setupProgressListener();
    }
  }

  @override
  void dispose() {
    _modelUrlController.dispose();
    super.dispose();
  }

  Future<void> _validateUrl() async {
    final url = _modelUrlController.text.trim();
    if (url.isEmpty) {
      setState(() {
        _validationMessage = null;
      });
      widget.onModelUrlChanged(null);
      return;
    }

    setState(() {
      _isValidating = true;
      _validationMessage = null;
    });

    try {
      final uri = Uri.parse(url);
      if (!uri.hasScheme || (!uri.scheme.startsWith('http'))) {
        setState(() {
          _validationMessage = 'Invalid URL format. Use http:// or https://';
          _isValidating = false;
        });
        return;
      }

      // Use HEAD request to validate URL without downloading the file
      // This is much faster for large model files
      final client = http.Client();
      try {
        final response = await client
            .head(uri)
            .timeout(
              const Duration(seconds: 15),
              onTimeout: () {
                throw Exception('Connection timeout');
              },
            );

        if (response.statusCode == 200 || response.statusCode == 405) {
          // 405 Method Not Allowed is OK - some servers don't support HEAD
          // but the URL is still valid
          setState(() {
            _validationMessage = '✓ Model URL is valid';
            _isValidating = false;
          });
          widget.onModelUrlChanged(url);
        } else if (response.statusCode == 404) {
          setState(() {
            _validationMessage = 'File not found (404). Check the URL.';
            _isValidating = false;
          });
        } else {
          setState(() {
            _validationMessage =
                'Server returned status ${response.statusCode}. The URL may still work.';
            _isValidating = false;
          });
          // Still allow the URL even if status is not 200
          widget.onModelUrlChanged(url);
        }
      } finally {
        client.close();
      }
    } on http.ClientException catch (e) {
      setState(() {
        _validationMessage =
            'Connection failed: ${e.message}. Check your internet connection and try again.';
        _isValidating = false;
      });
    } on TimeoutException {
      setState(() {
        _validationMessage =
            'Connection timeout. The server may be slow or unreachable. You can still try using this URL.';
        _isValidating = false;
      });
      // Allow the URL even if validation times out - actual download has longer timeout
      widget.onModelUrlChanged(url);
    } catch (e) {
      final errorMsg = e.toString().toLowerCase();
      String message;
      if (errorMsg.contains('timeout')) {
        message =
            'Connection timeout. The server may be slow. You can still try using this URL.';
        // Allow the URL - actual download has longer timeout
        widget.onModelUrlChanged(url);
      } else if (errorMsg.contains('failed host lookup') ||
          errorMsg.contains('network') ||
          errorMsg.contains('connection')) {
        message =
            'Cannot reach server. Check your internet connection and the URL.';
      } else if (errorMsg.contains('invalid argument') ||
          errorMsg.contains('format')) {
        message = 'Invalid URL format. Please check the URL.';
      } else {
        message =
            'Could not validate URL. You can still try using it - validation may fail for some servers.';
        // Allow the URL - some servers may not respond to HEAD requests
        widget.onModelUrlChanged(url);
      }
      setState(() {
        _validationMessage = message;
        _isValidating = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        TextField(
          controller: _modelUrlController,
          decoration: InputDecoration(
            labelText: 'Model URL',
            hintText: 'http://localhost:8000/model.task',
            helperText: 'URL to download the model file (.task format)',
            prefixIcon: const Icon(Icons.link, size: 20),
            suffixIcon: _isValidating
                ? const SizedBox(
                    width: 20,
                    height: 20,
                    child: Padding(
                      padding: EdgeInsets.all(12),
                      child: CircularProgressIndicator(strokeWidth: 2),
                    ),
                  )
                : _modelUrlController.text.isNotEmpty &&
                      _validationMessage != null &&
                      _validationMessage!.startsWith('✓')
                ? const Icon(
                    Icons.check_circle,
                    size: 20,
                    color: Color(0xFF10B981),
                  )
                : null,
            filled: true,
            fillColor: colorScheme.surfaceContainerHighest.withValues(
              alpha: 0.5,
            ),
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: BorderSide(
                color: colorScheme.outline.withValues(alpha: 0.1),
              ),
            ),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: BorderSide(
                color: colorScheme.outline.withValues(alpha: 0.1),
              ),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: BorderSide(color: colorScheme.primary, width: 1.5),
            ),
            contentPadding: const EdgeInsets.symmetric(
              horizontal: 16,
              vertical: 12,
            ),
          ),
          onChanged: (value) {
            widget.onModelUrlChanged(value.isEmpty ? null : value);
            setState(() {
              _validationMessage = null;
            });
          },
          onSubmitted: (_) => _validateUrl(),
        ),
        if (_validationMessage != null) ...[
          const SizedBox(height: 8),
          Row(
            children: [
              Icon(
                _validationMessage!.startsWith('✓')
                    ? Icons.check_circle
                    : Icons.error_outline,
                size: 16,
                color: _validationMessage!.startsWith('✓')
                    ? const Color(0xFF10B981)
                    : Colors.orange,
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  _validationMessage!,
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: _validationMessage!.startsWith('✓')
                        ? const Color(0xFF10B981)
                        : Colors.orange,
                  ),
                ),
              ),
            ],
          ),
        ],
        // Download progress indicator
        if (_downloadStatus == 'downloading' ||
            _downloadStatus == 'initializing' ||
            (_downloadProgressBytes != null &&
                _downloadTotalBytes != null &&
                _downloadTotalBytes! > 0 &&
                _downloadProgressBytes! < _downloadTotalBytes!)) ...[
          const SizedBox(height: 12),
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: colorScheme.surfaceContainerHighest.withValues(alpha: 0.5),
              borderRadius: BorderRadius.circular(8),
              border: Border.all(
                color: colorScheme.outline.withValues(alpha: 0.1),
              ),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  _downloadStatus == 'downloading'
                      ? 'Downloading model...'
                      : _downloadStatus == 'initializing'
                          ? 'Initializing model...'
                          : 'Processing model...',
                  style: theme.textTheme.bodySmall?.copyWith(
                    fontWeight: FontWeight.w600,
                    color: colorScheme.onSurface,
                  ),
                ),
                if (_downloadProgressBytes != null &&
                    _downloadTotalBytes != null &&
                    _downloadTotalBytes! > 0) ...[
                  const SizedBox(height: 8),
                  LinearProgressIndicator(
                    value: _downloadProgressBytes! / _downloadTotalBytes!,
                    backgroundColor: colorScheme.outline.withValues(alpha: 0.1),
                    valueColor: AlwaysStoppedAnimation<Color>(
                      colorScheme.primary,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    '${(_downloadProgressBytes! / 1024 / 1024).toStringAsFixed(1)} MB / ${(_downloadTotalBytes! / 1024 / 1024).toStringAsFixed(1)} MB (${((_downloadProgressBytes! / _downloadTotalBytes!) * 100).toStringAsFixed(0)}%)',
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: colorScheme.onSurface.withValues(alpha: 0.7),
                      fontSize: 11,
                    ),
                  ),
                ],
              ],
            ),
          ),
        ],
        const SizedBox(height: 12),
        Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: colorScheme.surfaceContainerHighest.withValues(alpha: 0.3),
            borderRadius: BorderRadius.circular(8),
            border: Border.all(
              color: colorScheme.outline.withValues(alpha: 0.1),
            ),
          ),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Icon(
                Icons.info_outline,
                size: 16,
                color: colorScheme.onSurface.withValues(alpha: 0.7),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  'Enter a URL to download a .task model file. For local development, use the model server: run `python3 scripts/serve_models.py` and enter `http://localhost:8000/your_model.task`',
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: colorScheme.onSurface.withValues(alpha: 0.7),
                    height: 1.4,
                  ),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _DownloadedModelsSection extends StatefulWidget {
  const _DownloadedModelsSection();

  @override
  State<_DownloadedModelsSection> createState() =>
      _DownloadedModelsSectionState();
}

class _DownloadedModelsSectionState extends State<_DownloadedModelsSection> {
  List<Map<String, dynamic>> _models = [];
  bool _isLoading = true;
  String? _removingModelName;
  int? _removeProgressBytes;
  int? _removeTotalBytes;

  @override
  void initState() {
    super.initState();
    _loadModels();
    _setupRemoveProgressListener();
  }

  void _setupRemoveProgressListener() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      final provider = Provider.of<AppProvider>(context, listen: false);
      final localAIService = provider.rewriterService.localAIService;
      if (localAIService != null) {
        localAIService.onRemoveProgress = (removed, total, modelName) {
          if (mounted) {
            setState(() {
              _removeProgressBytes = removed;
              _removeTotalBytes = total;
              _removingModelName = modelName;
            });
          }
        };
      }
    });
  }

  Future<void> _loadModels() async {
    setState(() {
      _isLoading = true;
    });

    try {
      final provider = Provider.of<AppProvider>(context, listen: false);
      final localAIService = provider.rewriterService.localAIService;
      if (localAIService != null) {
        final models = await localAIService.listDownloadedModels();
        if (mounted) {
          setState(() {
            _models = models;
            _isLoading = false;
          });
        }
      } else {
        if (mounted) {
          setState(() {
            _models = [];
            _isLoading = false;
          });
        }
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _models = [];
          _isLoading = false;
        });
      }
    }
  }

  Future<void> _removeModel(String modelPath, String modelName) async {
    try {
      final provider = Provider.of<AppProvider>(context, listen: false);
      final localAIService = provider.rewriterService.localAIService;
      if (localAIService != null) {
        final success = await localAIService.removeModel(modelPath);
        if (success && mounted) {
          // Clear removal progress
          setState(() {
            _removingModelName = null;
            _removeProgressBytes = null;
            _removeTotalBytes = null;
          });
          // Reload models list
          await _loadModels();
        }
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _removingModelName = null;
          _removeProgressBytes = null;
          _removeTotalBytes = null;
        });
      }
    }
  }

  String _formatBytes(int bytes) {
    if (bytes < 1024) {
      return '$bytes B';
    } else if (bytes < 1024 * 1024) {
      return '${(bytes / 1024).toStringAsFixed(1)} KB';
    } else if (bytes < 1024 * 1024 * 1024) {
      return '${(bytes / (1024 * 1024)).toStringAsFixed(1)} MB';
    } else {
      return '${(bytes / (1024 * 1024 * 1024)).toStringAsFixed(1)} GB';
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Text(
              'Downloaded Models',
              style: theme.textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.w600,
                color: colorScheme.onSurface,
              ),
            ),
            const Spacer(),
            IconButton(
              icon: const Icon(Icons.refresh, size: 20),
              tooltip: 'Refresh',
              onPressed: _loadModels,
              color: colorScheme.onSurface.withValues(alpha: 0.7),
            ),
          ],
        ),
        const SizedBox(height: 12),
        if (_isLoading)
          Container(
            padding: const EdgeInsets.all(24),
            decoration: BoxDecoration(
              color: colorScheme.surfaceContainerHighest.withValues(alpha: 0.5),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(
                color: colorScheme.outline.withValues(alpha: 0.1),
              ),
            ),
            child: Center(
              child: CircularProgressIndicator(
                strokeWidth: 2,
                color: colorScheme.primary,
              ),
            ),
          )
        else if (_models.isEmpty)
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: colorScheme.surfaceContainerHighest.withValues(alpha: 0.5),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(
                color: colorScheme.outline.withValues(alpha: 0.1),
              ),
            ),
            child: Row(
              children: [
                Icon(
                  Icons.info_outline,
                  size: 16,
                  color: colorScheme.onSurface.withValues(alpha: 0.6),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    'No models downloaded yet. Models will appear here after downloading.',
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: colorScheme.onSurface.withValues(alpha: 0.7),
                    ),
                  ),
                ),
              ],
            ),
          )
        else
          ..._models.map((model) {
            final modelName = model['name'] as String;
            final modelPath = model['path'] as String;
            final modelSize = model['size'] as int;
            final isRemoving = _removingModelName == modelName;

            return Container(
              margin: const EdgeInsets.only(bottom: 8),
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: colorScheme.surfaceContainerHighest.withValues(alpha: 0.5),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(
                  color: colorScheme.outline.withValues(alpha: 0.1),
                ),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Icon(
                        Icons.storage,
                        size: 18,
                        color: colorScheme.primary,
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          modelName,
                          style: theme.textTheme.bodyMedium?.copyWith(
                            fontWeight: FontWeight.w500,
                            color: colorScheme.onSurface,
                          ),
                        ),
                      ),
                      Text(
                        _formatBytes(modelSize),
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: colorScheme.onSurface.withValues(alpha: 0.6),
                        ),
                      ),
                      const SizedBox(width: 8),
                      if (isRemoving)
                        SizedBox(
                          width: 16,
                          height: 16,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            color: colorScheme.primary,
                          ),
                        )
                      else
                        IconButton(
                          icon: const Icon(Icons.delete_outline, size: 18),
                          tooltip: 'Remove model',
                          onPressed: () => _removeModel(modelPath, modelName),
                          color: colorScheme.error,
                          padding: EdgeInsets.zero,
                          constraints: const BoxConstraints(
                            minWidth: 32,
                            minHeight: 32,
                          ),
                        ),
                    ],
                  ),
                  if (isRemoving &&
                      _removeProgressBytes != null &&
                      _removeTotalBytes != null &&
                      _removeTotalBytes! > 0) ...[
                    const SizedBox(height: 8),
                    LinearProgressIndicator(
                      value: _removeProgressBytes! / _removeTotalBytes!,
                      backgroundColor:
                          colorScheme.outline.withValues(alpha: 0.1),
                      valueColor: AlwaysStoppedAnimation<Color>(
                        colorScheme.error,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'Removing... ${((_removeProgressBytes! / _removeTotalBytes!) * 100).toStringAsFixed(0)}%',
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: colorScheme.onSurface.withValues(alpha: 0.7),
                        fontSize: 11,
                      ),
                    ),
                  ],
                ],
              ),
            );
          }),
      ],
    );
  }
}
