import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../ui/providers/app_provider.dart';
import '../../core/services/history_service.dart';
import '../../core/models/rewrite_history_item.dart';
import 'api_key_dialog.dart';

/// Settings page widget with modern, polished design
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
      description: 'Clear and formal',
      color: const Color(0xFF3B82F6),
      gradient: [const Color(0xFF3B82F6), const Color(0xFF2563EB)],
    ),
    StyleOption(
      value: 'casual',
      label: 'Casual',
      icon: Icons.chat_bubble_outline_rounded,
      description: 'Friendly and relaxed',
      color: const Color(0xFF10B981),
      gradient: [const Color(0xFF10B981), const Color(0xFF059669)],
    ),
    StyleOption(
      value: 'concise',
      label: 'Concise',
      icon: Icons.compress_rounded,
      description: 'Short and direct',
      color: const Color(0xFFF59E0B),
      gradient: [const Color(0xFFF59E0B), const Color(0xFFD97706)],
    ),
    StyleOption(
      value: 'academic',
      label: 'Academic',
      icon: Icons.school_rounded,
      description: 'Scholarly and precise',
      color: const Color(0xFF8B5CF6),
      gradient: [const Color(0xFF8B5CF6), const Color(0xFF7C3AED)],
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
                  // Modern Header
                  SliverToBoxAdapter(
                    child: Container(
                      padding: const EdgeInsets.fromLTRB(28, 40, 28, 24),
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                          colors: [
                            colorScheme.primaryContainer.withOpacity(0.3),
                            colorScheme.surface,
                          ],
                        ),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Container(
                                padding: const EdgeInsets.all(12),
                                decoration: BoxDecoration(
                                  gradient: LinearGradient(
                                    colors: [
                                      colorScheme.primary,
                                      colorScheme.primary.withOpacity(0.8),
                                    ],
                                  ),
                                  borderRadius: BorderRadius.circular(14),
                                  boxShadow: [
                                    BoxShadow(
                                      color: colorScheme.primary.withOpacity(0.3),
                                      blurRadius: 12,
                                      offset: const Offset(0, 4),
                                    ),
                                  ],
                                ),
                                child: Icon(
                                  Icons.tune_rounded,
                                  size: 28,
                                  color: Colors.white,
                                ),
                              ),
                              const SizedBox(width: 16),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      'Settings',
                                      style: theme.textTheme.headlineMedium?.copyWith(
                                        fontWeight: FontWeight.bold,
                                        color: colorScheme.onSurface,
                                        letterSpacing: -0.5,
                                      ),
                                    ),
                                    const SizedBox(height: 4),
                                    Text(
                                      'Customize your rewriting experience',
                                      style: theme.textTheme.bodyMedium?.copyWith(
                                        color: colorScheme.onSurface.withOpacity(0.7),
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                  ),

                  // Status Card - Enhanced
                  SliverToBoxAdapter(
                    child: Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 28),
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

                  const SliverToBoxAdapter(child: SizedBox(height: 28)),

                  // API Key Section - Enhanced
                  SliverToBoxAdapter(
                    child: Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 28),
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

                  const SliverToBoxAdapter(child: SizedBox(height: 28)),

                  // Writing Style Section - Enhanced
                  SliverToBoxAdapter(
                    child: Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 28),
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

                  const SliverToBoxAdapter(child: SizedBox(height: 28)),

                  // Advanced Settings - Enhanced
                  SliverToBoxAdapter(
                    child: Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 28),
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

                  const SliverToBoxAdapter(child: SizedBox(height: 28)),

                  // History Section - Enhanced
                  SliverToBoxAdapter(
                    child: Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 28),
                      child: const _HistorySection(),
                    ),
                  ),

                  const SliverToBoxAdapter(child: SizedBox(height: 40)),
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
  final String description;
  final Color color;
  final List<Color> gradient;

  StyleOption({
    required this.value,
    required this.label,
    required this.icon,
    required this.description,
    required this.color,
    required this.gradient,
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
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: isActive
              ? [
                  const Color(0xFF10B981).withOpacity(0.1),
                  const Color(0xFF059669).withOpacity(0.05),
                ]
              : [
                  colorScheme.surfaceContainerHighest,
                  colorScheme.surfaceContainerHighest.withOpacity(0.5),
                ],
        ),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: isActive
              ? const Color(0xFF10B981).withOpacity(0.3)
              : colorScheme.outline.withOpacity(0.15),
          width: 1.5,
        ),
        boxShadow: [
          BoxShadow(
            color: isActive
                ? const Color(0xFF10B981).withOpacity(0.1)
                : Colors.black.withOpacity(0.03),
            blurRadius: 20,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: isActive
                    ? [const Color(0xFF10B981), const Color(0xFF059669)]
                    : [Colors.grey.shade400, Colors.grey.shade500],
              ),
              shape: BoxShape.circle,
              boxShadow: [
                BoxShadow(
                  color: (isActive ? const Color(0xFF10B981) : Colors.grey)
                      .withOpacity(0.3),
                  blurRadius: 12,
                  offset: const Offset(0, 4),
                ),
              ],
            ),
            child: Icon(
              isActive ? Icons.check_circle_rounded : Icons.error_outline_rounded,
              color: Colors.white,
              size: 28,
            ),
          ),
          const SizedBox(width: 20),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  isActive
                      ? 'Rewriter Active'
                      : hasApiKey
                          ? 'Rewriter Disabled'
                          : 'Setup Required',
                  style: theme.textTheme.titleLarge?.copyWith(
                    fontWeight: FontWeight.bold,
                    color: colorScheme.onSurface,
                    letterSpacing: -0.3,
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  isActive
                      ? 'Monitoring clipboard and ready to rewrite'
                      : hasApiKey
                          ? 'Enable to start rewriting text'
                          : 'Configure API key to get started',
                  style: theme.textTheme.bodyMedium?.copyWith(
                    color: colorScheme.onSurface.withOpacity(0.7),
                    height: 1.4,
                  ),
                ),
              ],
            ),
          ),
          Transform.scale(
            scale: 1.1,
            child: Switch(
              value: isEnabled,
              onChanged: hasApiKey ? onToggle : null,
              activeColor: const Color(0xFF10B981),
            ),
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
          'API Configuration',
          style: theme.textTheme.titleLarge?.copyWith(
            fontWeight: FontWeight.bold,
            color: colorScheme.onSurface,
            letterSpacing: -0.3,
          ),
        ),
        const SizedBox(height: 16),
        Material(
          color: Colors.transparent,
          child: InkWell(
            onTap: onConfigure,
            borderRadius: BorderRadius.circular(16),
            child: Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: colorScheme.surfaceContainerHighest,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(
                  color: colorScheme.outline.withOpacity(0.1),
                ),
              ),
              child: Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        colors: hasApiKey
                            ? [const Color(0xFF10B981), const Color(0xFF059669)]
                            : [Colors.grey.shade400, Colors.grey.shade500],
                      ),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Icon(
                      hasApiKey ? Icons.key_rounded : Icons.key_off_rounded,
                      color: Colors.white,
                      size: 24,
                    ),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          hasApiKey ? 'API Key Configured' : 'No API Key',
                          style: theme.textTheme.titleMedium?.copyWith(
                            fontWeight: FontWeight.w600,
                            color: colorScheme.onSurface,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          hasApiKey
                              ? 'Your API key is securely stored'
                              : 'Add your Gemini API key to continue',
                          style: theme.textTheme.bodySmall?.copyWith(
                            color: colorScheme.onSurface.withOpacity(0.6),
                          ),
                        ),
                      ],
                    ),
                  ),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                    decoration: BoxDecoration(
                      color: colorScheme.primary.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(
                          hasApiKey ? Icons.edit_rounded : Icons.add_rounded,
                          size: 18,
                          color: colorScheme.primary,
                        ),
                        const SizedBox(width: 6),
                        Text(
                          hasApiKey ? 'Change' : 'Configure',
                          style: theme.textTheme.bodyMedium?.copyWith(
                            fontWeight: FontWeight.w600,
                            color: colorScheme.primary,
                          ),
                        ),
                      ],
                    ),
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

class _HistorySection extends StatefulWidget {
  const _HistorySection();

  @override
  State<_HistorySection> createState() => _HistorySectionState();
}

class _HistorySectionState extends State<_HistorySection> {
  final HistoryService _historyService = HistoryService();
  List<RewriteHistoryItem> _history = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadHistory();
  }

  Future<void> _loadHistory() async {
    setState(() => _isLoading = true);
    final history = await _historyService.getHistory(limit: 10);
    setState(() {
      _history = history;
      _isLoading = false;
    });
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
              'Recent Rewrites',
              style: theme.textTheme.titleLarge?.copyWith(
                fontWeight: FontWeight.bold,
                color: colorScheme.onSurface,
                letterSpacing: -0.3,
              ),
            ),
            const Spacer(),
            if (_history.isNotEmpty)
              TextButton.icon(
                onPressed: () async {
                  await _historyService.clearHistory();
                  await _loadHistory();
                },
                icon: const Icon(Icons.delete_outline_rounded, size: 18),
                label: const Text('Clear'),
                style: TextButton.styleFrom(
                  foregroundColor: Colors.red.shade600,
                ),
              ),
          ],
        ),
        const SizedBox(height: 16),
        if (_isLoading)
          Center(
            child: Padding(
              padding: const EdgeInsets.all(32.0),
              child: CircularProgressIndicator(
                color: colorScheme.primary,
              ),
            ),
          )
        else if (_history.isEmpty)
          Container(
            padding: const EdgeInsets.all(40),
            decoration: BoxDecoration(
              color: colorScheme.surfaceContainerHighest,
              borderRadius: BorderRadius.circular(16),
            ),
            child: Center(
              child: Column(
                children: [
                  Icon(
                    Icons.history_rounded,
                    size: 56,
                    color: colorScheme.onSurface.withOpacity(0.3),
                  ),
                  const SizedBox(height: 16),
                  Text(
                    'No rewrite history yet',
                    style: theme.textTheme.bodyLarge?.copyWith(
                      color: colorScheme.onSurface.withOpacity(0.6),
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Your rewritten texts will appear here',
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: colorScheme.onSurface.withOpacity(0.5),
                    ),
                  ),
                ],
              ),
            ),
          )
        else
          ..._history.map((item) => _HistoryItemCard(item: item)),
      ],
    );
  }
}

class _HistoryItemCard extends StatelessWidget {
  final RewriteHistoryItem item;

  const _HistoryItemCard({required this.item});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: colorScheme.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: colorScheme.outline.withOpacity(0.1),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(
                Icons.access_time_rounded,
                size: 16,
                color: colorScheme.onSurface.withOpacity(0.6),
              ),
              const SizedBox(width: 6),
              Text(
                _formatTime(item.timestamp),
                style: theme.textTheme.bodySmall?.copyWith(
                  color: colorScheme.onSurface.withOpacity(0.6),
                  fontWeight: FontWeight.w500,
                ),
              ),
              const Spacer(),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: colorScheme.primaryContainer,
                  borderRadius: BorderRadius.circular(6),
                ),
                child: Text(
                  item.style,
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: colorScheme.onPrimaryContainer,
                    fontSize: 11,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          _buildTextPreview(
            context,
            'Original',
            item.originalText,
            Icons.text_fields_rounded,
            colorScheme.onSurface.withOpacity(0.8),
          ),
          if (item.rewrittenTexts.isNotEmpty) ...[
            const SizedBox(height: 10),
            _buildTextPreview(
              context,
              'Rewritten',
              item.rewrittenTexts.first,
              Icons.auto_fix_high_rounded,
              colorScheme.primary,
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildTextPreview(
    BuildContext context,
    String label,
    String text,
    IconData icon,
    Color color,
  ) {
    final theme = Theme.of(context);
    final displayText = text.length > 80 ? '${text.substring(0, 77)}...' : text;

    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(icon, size: 16, color: color),
        const SizedBox(width: 8),
        Expanded(
          child: Text(
            displayText,
            style: theme.textTheme.bodyMedium?.copyWith(
              color: color,
              height: 1.5,
            ),
          ),
        ),
      ],
    );
  }

  String _formatTime(DateTime timestamp) {
    final now = DateTime.now();
    final difference = now.difference(timestamp);

    if (difference.inMinutes < 1) {
      return 'Just now';
    } else if (difference.inMinutes < 60) {
      return '${difference.inMinutes}m ago';
    } else if (difference.inHours < 24) {
      return '${difference.inHours}h ago';
    } else if (difference.inDays < 7) {
      return '${difference.inDays}d ago';
    } else {
      return '${timestamp.day}/${timestamp.month}/${timestamp.year}';
    }
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
          style: theme.textTheme.titleLarge?.copyWith(
            fontWeight: FontWeight.bold,
            color: colorScheme.onSurface,
            letterSpacing: -0.3,
          ),
        ),
        const SizedBox(height: 8),
        Text(
          'Choose how you want text to be rewritten',
          style: theme.textTheme.bodySmall?.copyWith(
            color: colorScheme.onSurface.withOpacity(0.7),
          ),
        ),
        const SizedBox(height: 20),
        Wrap(
          spacing: 12,
          runSpacing: 12,
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
    final width = (MediaQuery.of(context).size.width - 84) / 2;

    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(16),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          width: width,
          padding: const EdgeInsets.all(18),
          decoration: BoxDecoration(
            gradient: isSelected
                ? LinearGradient(
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                    colors: [
                      option.gradient[0].withOpacity(0.15),
                      option.gradient[1].withOpacity(0.1),
                    ],
                  )
                : null,
            color: isSelected ? null : colorScheme.surfaceContainerHighest,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(
              color: isSelected
                  ? option.color
                  : colorScheme.outline.withOpacity(0.15),
              width: isSelected ? 2 : 1,
            ),
            boxShadow: isSelected
                ? [
                    BoxShadow(
                      color: option.color.withOpacity(0.2),
                      blurRadius: 12,
                      offset: const Offset(0, 4),
                    ),
                  ]
                : null,
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        colors: option.gradient,
                      ),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Icon(
                      option.icon,
                      color: Colors.white,
                      size: 20,
                    ),
                  ),
                  const Spacer(),
                  if (isSelected)
                    Container(
                      padding: const EdgeInsets.all(4),
                      decoration: BoxDecoration(
                        color: option.color,
                        shape: BoxShape.circle,
                      ),
                      child: const Icon(
                        Icons.check_rounded,
                        color: Colors.white,
                        size: 14,
                      ),
                    ),
                ],
              ),
              const SizedBox(height: 12),
              Text(
                option.label,
                style: theme.textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.bold,
                  color: colorScheme.onSurface,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                option.description,
                style: theme.textTheme.bodySmall?.copyWith(
                  color: colorScheme.onSurface.withOpacity(0.6),
                  fontSize: 12,
                ),
              ),
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
            borderRadius: BorderRadius.circular(12),
            child: Padding(
              padding: const EdgeInsets.symmetric(vertical: 8),
              child: Row(
                children: [
                  Text(
                    'Advanced Settings',
                    style: theme.textTheme.titleLarge?.copyWith(
                      fontWeight: FontWeight.bold,
                      color: colorScheme.onSurface,
                      letterSpacing: -0.3,
                    ),
                  ),
                  const Spacer(),
                  AnimatedRotation(
                    turns: showAdvanced ? 0.5 : 0,
                    duration: const Duration(milliseconds: 200),
                    child: Icon(
                      Icons.keyboard_arrow_down_rounded,
                      color: colorScheme.onSurface,
                      size: 28,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
        AnimatedSize(
          duration: const Duration(milliseconds: 300),
          curve: Curves.easeInOut,
          child: showAdvanced
              ? Column(
                  children: [
                    const SizedBox(height: 20),
                    _AdvancedSettingField(
                      label: 'Debounce Delay',
                      controller: debounceController,
                      suffix: 'ms',
                      helperText: 'Wait time before processing clipboard',
                      icon: Icons.timer_outlined,
                      onChanged: (value) {
                        final ms = int.tryParse(value);
                        if (ms != null && ms > 0) {
                          provider.updateConfig(config.copyWith(debounceMs: ms));
                        }
                      },
                    ),
                    const SizedBox(height: 20),
                    _AdvancedSettingField(
                      label: 'Min Sentence Length',
                      controller: minLengthController,
                      suffix: 'chars',
                      helperText: 'Minimum characters to process',
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
                    const SizedBox(height: 20),
                    _AdvancedSettingField(
                      label: 'Max Sentence Length',
                      controller: maxLengthController,
                      suffix: 'chars',
                      helperText: 'Maximum characters to process',
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
  final String helperText;
  final IconData icon;
  final ValueChanged<String> onChanged;

  const _AdvancedSettingField({
    required this.label,
    required this.controller,
    required this.suffix,
    required this.helperText,
    required this.icon,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Icon(icon, size: 18, color: colorScheme.primary),
            const SizedBox(width: 8),
            Text(
              label,
              style: theme.textTheme.bodyLarge?.copyWith(
                fontWeight: FontWeight.w600,
                color: colorScheme.onSurface,
              ),
            ),
          ],
        ),
        const SizedBox(height: 10),
        TextField(
          controller: controller,
          keyboardType: TextInputType.number,
          onChanged: onChanged,
          decoration: InputDecoration(
            hintText: 'Enter value',
            helperText: helperText,
            suffixText: suffix,
            prefixIcon: Icon(icon, size: 20, color: colorScheme.primary.withOpacity(0.6)),
          ),
        ),
      ],
    );
  }
}
