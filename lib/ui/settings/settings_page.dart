import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../ui/providers/app_provider.dart';
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
              child: CircularProgressIndicator(
                color: colorScheme.primary,
              ),
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

                  // API Key Section
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
                          }
                        },
                      ),
                    ),
                  ),

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
        color: colorScheme.surfaceContainerHighest.withOpacity(0.5),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: colorScheme.outline.withOpacity(0.1),
        ),
      ),
      child: Row(
        children: [
          Icon(
            isActive ? Icons.check_circle_outline : Icons.error_outline,
            color: isActive ? const Color(0xFF10B981) : colorScheme.onSurface.withOpacity(0.5),
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
                    color: colorScheme.onSurface.withOpacity(0.6),
                  ),
                ),
              ],
            ),
          ),
          Switch(
            value: isEnabled,
            onChanged: hasApiKey ? onToggle : null,
            activeColor: const Color(0xFF10B981),
          ),
        ],
      ),
    );
  }
}

class _ApiKeySection extends StatelessWidget {
  final bool hasApiKey;
  final VoidCallback onConfigure;

  const _ApiKeySection({
    required this.hasApiKey,
    required this.onConfigure,
  });

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
                color: colorScheme.surfaceContainerHighest.withOpacity(0.5),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(
                  color: colorScheme.outline.withOpacity(0.1),
                ),
              ),
              child: Row(
                children: [
                  Icon(
                    hasApiKey ? Icons.key : Icons.key_off,
                    color: hasApiKey ? const Color(0xFF10B981) : colorScheme.onSurface.withOpacity(0.5),
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
                    color: colorScheme.onSurface.withOpacity(0.4),
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
                ? option.color.withOpacity(0.1)
                : colorScheme.surfaceContainerHighest.withOpacity(0.5),
            borderRadius: BorderRadius.circular(10),
            border: Border.all(
              color: isSelected
                  ? option.color
                  : colorScheme.outline.withOpacity(0.1),
              width: isSelected ? 1.5 : 1,
            ),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                option.icon,
                size: 18,
                color: isSelected ? option.color : colorScheme.onSurface.withOpacity(0.6),
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
                Icon(
                  Icons.check,
                  size: 16,
                  color: option.color,
                ),
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
                      color: colorScheme.onSurface.withOpacity(0.6),
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
                          provider.updateConfig(config.copyWith(debounceMs: ms));
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
        prefixIcon: Icon(icon, size: 18, color: colorScheme.onSurface.withOpacity(0.6)),
        filled: true,
        fillColor: colorScheme.surfaceContainerHighest.withOpacity(0.5),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(10),
          borderSide: BorderSide(color: colorScheme.outline.withOpacity(0.1)),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(10),
          borderSide: BorderSide(color: colorScheme.outline.withOpacity(0.1)),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(10),
          borderSide: BorderSide(color: colorScheme.primary, width: 1.5),
        ),
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        isDense: true,
      ),
    );
  }
}

