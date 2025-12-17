import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:window_manager/window_manager.dart';
import '../../core/services/clipboard_service.dart';

/// Preview window showing rewritten texts with modern, polished design
class PreviewWindow extends StatefulWidget {
  final String originalText;
  final List<String> rewrittenTexts;
  final ClipboardService clipboardService;
  final VoidCallback? onDismiss;
  final bool isLoading;

  const PreviewWindow({
    super.key,
    required this.originalText,
    required this.rewrittenTexts,
    required this.clipboardService,
    this.onDismiss,
    this.isLoading = false,
  });

  @override
  State<PreviewWindow> createState() => _PreviewWindowState();
}

class _PreviewWindowState extends State<PreviewWindow> {
  bool _isComparisonView = false;
  Timer? _autoDismissTimer;
  final FocusNode _focusNode = FocusNode();

  @override
  void initState() {
    super.initState();
    // Auto-dismiss after 60 seconds (increased from 30)
    _resetAutoDismissTimer();

    // Request focus to capture keyboard events
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _focusNode.requestFocus();
    });
  }

  @override
  void dispose() {
    _autoDismissTimer?.cancel();
    _focusNode.dispose();
    super.dispose();
  }

  @override
  void didUpdateWidget(PreviewWindow oldWidget) {
    super.didUpdateWidget(oldWidget);
    // Reset timer when content changes
    if (oldWidget.rewrittenTexts != widget.rewrittenTexts) {
      _resetAutoDismissTimer();
    }
  }

  void _resetAutoDismissTimer() {
    _autoDismissTimer?.cancel();
    _autoDismissTimer = Timer(const Duration(seconds: 60), () {
      if (mounted) {
        _dismiss();
      }
    });
  }

  Future<void> _dismiss() async {
    await windowManager.hide();
    widget.onDismiss?.call();
  }

  Future<void> _copyToClipboard(String text, int? version) async {
    await widget.clipboardService.setClipboardText(text);

    // Show feedback
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Row(
            children: [
              const Icon(Icons.check_circle_rounded, color: Colors.white),
              const SizedBox(width: 12),
              Text(
                version != null
                    ? 'Version $version copied to clipboard'
                    : 'Text copied to clipboard',
              ),
            ],
          ),
          backgroundColor: Colors.green.shade600,
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(10),
          ),
          duration: const Duration(seconds: 2),
        ),
      );
    }

    await Future.delayed(const Duration(milliseconds: 300));
    await _dismiss();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return KeyboardListener(
      focusNode: _focusNode,
      onKeyEvent: (event) {
        if (event is KeyDownEvent) {
          // Handle Esc key to dismiss
          if (event.logicalKey == LogicalKeyboardKey.escape) {
            _dismiss();
          }
        }
      },
      child: Material(
        color: colorScheme.surface,
        child: Container(
          decoration: BoxDecoration(
            color: colorScheme.surface,
            borderRadius: BorderRadius.circular(20),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.15),
                blurRadius: 30,
                offset: const Offset(0, 10),
                spreadRadius: 0,
              ),
            ],
          ),
          child: Column(
            children: [
              // Modern Header
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 20,
                  vertical: 18,
                ),
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                    colors: [
                      colorScheme.primary,
                      colorScheme.primary.withValues(alpha: 0.8),
                    ],
                  ),
                  borderRadius: const BorderRadius.only(
                    topLeft: Radius.circular(20),
                    topRight: Radius.circular(20),
                  ),
                ),
                child: Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: Colors.white.withValues(alpha: 0.2),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: const Icon(
                        Icons.auto_fix_high_rounded,
                        color: Colors.white,
                        size: 24,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            widget.isLoading
                                ? 'Processing...'
                                : 'Rewritten Text',
                            style: theme.textTheme.titleLarge?.copyWith(
                              fontWeight: FontWeight.bold,
                              color: Colors.white,
                              letterSpacing: -0.5,
                            ),
                          ),
                          Text(
                            widget.isLoading
                                ? 'Rewriting your text with AI'
                                : '${widget.rewrittenTexts.length} version${widget.rewrittenTexts.length > 1 ? 's' : ''} available',
                            style: theme.textTheme.bodySmall?.copyWith(
                              color: Colors.white.withValues(alpha: 0.9),
                            ),
                          ),
                        ],
                      ),
                    ),
                    Material(
                      color: Colors.transparent,
                      child: InkWell(
                        onTap: _dismiss,
                        borderRadius: BorderRadius.circular(8),
                        child: Container(
                          padding: const EdgeInsets.all(8),
                          child: const Icon(
                            Icons.close_rounded,
                            color: Colors.white,
                            size: 24,
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),

              // Content
              Expanded(
                child: widget.isLoading
                    ? _buildLoadingState(context)
                    : SingleChildScrollView(
                        physics: const BouncingScrollPhysics(),
                        padding: const EdgeInsets.all(20),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            // View toggle button
                            if (widget.rewrittenTexts.isNotEmpty)
                              Row(
                                children: [
                                  const Spacer(),
                                  _buildViewToggleButton(context),
                                ],
                              ),
                            if (widget.rewrittenTexts.isNotEmpty)
                              const SizedBox(height: 16),

                            // Original text section
                            _buildTextSection(
                              context,
                              'Original Text',
                              widget.originalText,
                              Icons.text_fields_rounded,
                              const Color(0xFF6B7280),
                              false,
                            ),
                            const SizedBox(height: 20),

                            // Rewritten versions
                            if (_isComparisonView &&
                                widget.rewrittenTexts.isNotEmpty)
                              _buildComparisonView(context)
                            else
                              ...widget.rewrittenTexts.asMap().entries.map((
                                entry,
                              ) {
                                final index = entry.key;
                                final text = entry.value;
                                final colors = [
                                  [
                                    const Color(0xFF3B82F6),
                                    const Color(0xFF2563EB),
                                  ],
                                  [
                                    const Color(0xFF10B981),
                                    const Color(0xFF059669),
                                  ],
                                  [
                                    const Color(0xFFF59E0B),
                                    const Color(0xFFD97706),
                                  ],
                                  [
                                    const Color(0xFF8B5CF6),
                                    const Color(0xFF7C3AED),
                                  ],
                                ];
                                final colorPair = colors[index % colors.length];

                                return Padding(
                                  padding: const EdgeInsets.only(bottom: 20),
                                  child: _buildRewrittenSection(
                                    context,
                                    'Version ${index + 1}',
                                    text,
                                    index + 1,
                                    colorPair[0],
                                    colorPair[1],
                                  ),
                                );
                              }),

                            // Keyboard shortcuts hint
                            if (widget.rewrittenTexts.isNotEmpty) ...[
                              const SizedBox(height: 24),
                              _buildKeyboardShortcutsHint(context),
                            ],
                          ],
                        ),
                      ),
              ),

              // Modern Footer with actions
              if (!widget.isLoading)
                Container(
                  padding: const EdgeInsets.all(20),
                  decoration: BoxDecoration(
                    color: colorScheme.surfaceContainerHighest,
                    borderRadius: const BorderRadius.only(
                      bottomLeft: Radius.circular(20),
                      bottomRight: Radius.circular(20),
                    ),
                    border: Border(
                      top: BorderSide(
                        color: colorScheme.outline.withValues(alpha: 0.1),
                      ),
                    ),
                  ),
                  child: Row(
                    children: [
                      Expanded(
                        child: OutlinedButton.icon(
                          onPressed: _dismiss,
                          icon: const Icon(Icons.close_rounded, size: 18),
                          label: const Text('Dismiss (Esc)'),
                          style: OutlinedButton.styleFrom(
                            padding: const EdgeInsets.symmetric(vertical: 14),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(width: 12),
                      ...widget.rewrittenTexts.asMap().entries.map((entry) {
                        final index = entry.key;
                        final text = entry.value;
                        final versionNum = index + 1;
                        final colors = [
                          [const Color(0xFF3B82F6), const Color(0xFF2563EB)],
                          [const Color(0xFF10B981), const Color(0xFF059669)],
                          [const Color(0xFFF59E0B), const Color(0xFFD97706)],
                          [const Color(0xFF8B5CF6), const Color(0xFF7C3AED)],
                        ];
                        final colorPair = colors[index % colors.length];

                        return Padding(
                          padding: EdgeInsets.only(left: index > 0 ? 12 : 0),
                          child: Flexible(
                            child: Container(
                              decoration: BoxDecoration(
                                gradient: LinearGradient(colors: colorPair),
                                borderRadius: BorderRadius.circular(12),
                                boxShadow: [
                                  BoxShadow(
                                    color: colorPair[0].withValues(alpha: 0.3),
                                    blurRadius: 12,
                                    offset: const Offset(0, 4),
                                  ),
                                ],
                              ),
                              child: Material(
                                color: Colors.transparent,
                                child: InkWell(
                                  onTap: () =>
                                      _copyToClipboard(text, versionNum),
                                  borderRadius: BorderRadius.circular(12),
                                  child: Container(
                                    padding: const EdgeInsets.symmetric(
                                      vertical: 14,
                                      horizontal: 20,
                                    ),
                                    child: Row(
                                      mainAxisSize: MainAxisSize.min,
                                      children: [
                                        const Icon(
                                          Icons.content_copy_rounded,
                                          color: Colors.white,
                                          size: 18,
                                        ),
                                        const SizedBox(width: 8),
                                        Text(
                                          'Copy $versionNum',
                                          style: const TextStyle(
                                            color: Colors.white,
                                            fontWeight: FontWeight.w600,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                ),
                              ),
                            ),
                          ),
                        );
                      }),
                    ],
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildTextSection(
    BuildContext context,
    String title,
    String text,
    IconData icon,
    Color color,
    bool isRewritten,
  ) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: color.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Icon(icon, size: 18, color: color),
            ),
            const SizedBox(width: 10),
            Text(
              title,
              style: theme.textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.bold,
                color: colorScheme.onSurface,
                letterSpacing: -0.3,
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),
        Container(
          width: double.infinity,
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: isRewritten
                ? color.withValues(alpha: 0.08)
                : colorScheme.surfaceContainerHighest,
            borderRadius: BorderRadius.circular(14),
            border: Border.all(
              color: isRewritten
                  ? color.withValues(alpha: 0.2)
                  : colorScheme.outline.withValues(alpha: 0.1),
              width: isRewritten ? 1.5 : 1,
            ),
          ),
          child: SelectableText(
            text,
            style: theme.textTheme.bodyLarge?.copyWith(
              color: colorScheme.onSurface,
              height: 1.6,
              letterSpacing: 0.2,
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildRewrittenSection(
    BuildContext context,
    String title,
    String text,
    int versionNumber,
    Color primaryColor,
    Color secondaryColor,
  ) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [primaryColor, secondaryColor],
                ),
                borderRadius: BorderRadius.circular(8),
                boxShadow: [
                  BoxShadow(
                    color: primaryColor.withValues(alpha: 0.3),
                    blurRadius: 8,
                    offset: const Offset(0, 2),
                  ),
                ],
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(
                    Icons.auto_fix_high_rounded,
                    color: Colors.white,
                    size: 16,
                  ),
                  const SizedBox(width: 6),
                  Text(
                    title,
                    style: theme.textTheme.titleSmall?.copyWith(
                      fontWeight: FontWeight.bold,
                      color: Colors.white,
                    ),
                  ),
                ],
              ),
            ),
            const Spacer(),
            Material(
              color: Colors.transparent,
              child: InkWell(
                onTap: () => _copyToClipboard(text, versionNumber),
                borderRadius: BorderRadius.circular(8),
                child: Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 8,
                  ),
                  decoration: BoxDecoration(
                    color: primaryColor.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        Icons.content_copy_rounded,
                        size: 16,
                        color: primaryColor,
                      ),
                      const SizedBox(width: 6),
                      Text(
                        'Copy',
                        style: theme.textTheme.bodySmall?.copyWith(
                          fontWeight: FontWeight.w600,
                          color: primaryColor,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),
        Container(
          width: double.infinity,
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [
                primaryColor.withValues(alpha: 0.1),
                secondaryColor.withValues(alpha: 0.05),
              ],
            ),
            borderRadius: BorderRadius.circular(14),
            border: Border.all(
              color: primaryColor.withValues(alpha: 0.3),
              width: 2,
            ),
          ),
          child: SelectableText(
            text,
            style: theme.textTheme.bodyLarge?.copyWith(
              color: colorScheme.onSurface,
              height: 1.6,
              letterSpacing: 0.2,
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildLoadingState(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          SizedBox(
            width: 80,
            height: 80,
            child: CircularProgressIndicator(
              strokeWidth: 4,
              valueColor: AlwaysStoppedAnimation<Color>(colorScheme.primary),
            ),
          ),
          const SizedBox(height: 24),
          Text(
            'Rewriting your text...',
            style: theme.textTheme.titleMedium?.copyWith(
              fontWeight: FontWeight.w600,
              color: colorScheme.onSurface,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'This may take a few seconds',
            style: theme.textTheme.bodySmall?.copyWith(
              color: colorScheme.onSurface.withValues(alpha: 0.6),
            ),
          ),
          const SizedBox(height: 32),
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: colorScheme.surfaceContainerHighest,
              borderRadius: BorderRadius.circular(12),
            ),
            child: SelectableText(
              widget.originalText,
              style: theme.textTheme.bodyMedium?.copyWith(
                color: colorScheme.onSurface.withValues(alpha: 0.8),
                height: 1.5,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildViewToggleButton(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: () {
          setState(() {
            _isComparisonView = !_isComparisonView;
          });
        },
        borderRadius: BorderRadius.circular(10),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          decoration: BoxDecoration(
            color: _isComparisonView
                ? colorScheme.primaryContainer
                : colorScheme.surfaceContainerHighest,
            borderRadius: BorderRadius.circular(10),
            border: Border.all(
              color: _isComparisonView
                  ? colorScheme.primary
                  : colorScheme.outline.withValues(alpha: 0.2),
            ),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                _isComparisonView
                    ? Icons.view_agenda_rounded
                    : Icons.compare_arrows_rounded,
                size: 16,
                color: _isComparisonView
                    ? colorScheme.onPrimaryContainer
                    : colorScheme.onSurface,
              ),
              const SizedBox(width: 6),
              Text(
                _isComparisonView ? 'Stacked View' : 'Compare View',
                style: theme.textTheme.bodySmall?.copyWith(
                  fontWeight: FontWeight.w600,
                  color: _isComparisonView
                      ? colorScheme.onPrimaryContainer
                      : colorScheme.onSurface,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildComparisonView(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Original text
        Expanded(
          child: _buildTextSection(
            context,
            'Original',
            widget.originalText,
            Icons.text_fields_rounded,
            const Color(0xFF6B7280),
            false,
          ),
        ),
        const SizedBox(width: 16),
        // Rewritten versions side by side
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: widget.rewrittenTexts.asMap().entries.map((entry) {
              final index = entry.key;
              final text = entry.value;
              final colors = [
                [const Color(0xFF3B82F6), const Color(0xFF2563EB)],
                [const Color(0xFF10B981), const Color(0xFF059669)],
                [const Color(0xFFF59E0B), const Color(0xFFD97706)],
                [const Color(0xFF8B5CF6), const Color(0xFF7C3AED)],
              ];
              final colorPair = colors[index % colors.length];

              return Padding(
                padding: EdgeInsets.only(
                  bottom: index < widget.rewrittenTexts.length - 1 ? 16 : 0,
                ),
                child: _buildRewrittenSection(
                  context,
                  'Version ${index + 1}',
                  text,
                  index + 1,
                  colorPair[0],
                  colorPair[1],
                ),
              );
            }).toList(),
          ),
        ),
      ],
    );
  }

  Widget _buildKeyboardShortcutsHint(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: colorScheme.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: colorScheme.outline.withValues(alpha: 0.1)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(
                Icons.keyboard_rounded,
                size: 18,
                color: colorScheme.primary,
              ),
              const SizedBox(width: 8),
              Text(
                'Keyboard Shortcuts',
                style: theme.textTheme.bodyMedium?.copyWith(
                  fontWeight: FontWeight.w600,
                  color: colorScheme.onSurface,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Wrap(
            spacing: 16,
            runSpacing: 8,
            children: [
              _buildShortcutHint(context, 'Cmd+Shift+R', 'Show/Hide Preview'),
              _buildShortcutHint(context, 'Cmd+Shift+1', 'Copy Version 1'),
              if (widget.rewrittenTexts.length > 1)
                _buildShortcutHint(context, 'Cmd+Shift+2', 'Copy Version 2'),
              _buildShortcutHint(context, 'Esc', 'Dismiss'),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildShortcutHint(
    BuildContext context,
    String shortcut,
    String action,
  ) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
          decoration: BoxDecoration(
            color: colorScheme.primaryContainer,
            borderRadius: BorderRadius.circular(6),
          ),
          child: Text(
            shortcut,
            style: theme.textTheme.bodySmall?.copyWith(
              fontWeight: FontWeight.w600,
              color: colorScheme.onPrimaryContainer,
              fontSize: 11,
              fontFeatures: [const FontFeature.tabularFigures()],
            ),
          ),
        ),
        const SizedBox(width: 6),
        Text(
          action,
          style: theme.textTheme.bodySmall?.copyWith(
            color: colorScheme.onSurface.withValues(alpha: 0.7),
            fontSize: 12,
          ),
        ),
      ],
    );
  }
}
