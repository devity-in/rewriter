import 'package:flutter/material.dart';
import 'package:window_manager/window_manager.dart';
import '../../core/services/clipboard_service.dart';

/// Preview window showing rewritten texts with modern, polished design
class PreviewWindow extends StatefulWidget {
  final String originalText;
  final List<String> rewrittenTexts;
  final ClipboardService clipboardService;
  final VoidCallback? onDismiss;

  const PreviewWindow({
    super.key,
    required this.originalText,
    required this.rewrittenTexts,
    required this.clipboardService,
    this.onDismiss,
  });

  @override
  State<PreviewWindow> createState() => _PreviewWindowState();
}

class _PreviewWindowState extends State<PreviewWindow> {
  @override
  void initState() {
    super.initState();
    // Auto-dismiss after 30 seconds
    Future.delayed(const Duration(seconds: 30), () {
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

    return Material(
      color: colorScheme.surface,
      child: Container(
        decoration: BoxDecoration(
          color: colorScheme.surface,
          borderRadius: BorderRadius.circular(20),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.15),
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
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 18),
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: [
                    colorScheme.primary,
                    colorScheme.primary.withOpacity(0.8),
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
                      color: Colors.white.withOpacity(0.2),
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
                          'Rewritten Text',
                          style: theme.textTheme.titleLarge?.copyWith(
                            fontWeight: FontWeight.bold,
                            color: Colors.white,
                            letterSpacing: -0.5,
                          ),
                        ),
                        Text(
                          '${widget.rewrittenTexts.length} version${widget.rewrittenTexts.length > 1 ? 's' : ''} available',
                          style: theme.textTheme.bodySmall?.copyWith(
                            color: Colors.white.withOpacity(0.9),
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
              child: SingleChildScrollView(
                physics: const BouncingScrollPhysics(),
                padding: const EdgeInsets.all(20),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
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
                    ...widget.rewrittenTexts.asMap().entries.map((entry) {
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
                  ],
                ),
              ),
            ),

            // Modern Footer with actions
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
                    color: colorScheme.outline.withOpacity(0.1),
                  ),
                ),
              ),
              child: Row(
                children: [
                  Expanded(
                    child: OutlinedButton.icon(
                      onPressed: _dismiss,
                      icon: const Icon(Icons.close_rounded, size: 18),
                      label: const Text('Dismiss'),
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
                      padding: EdgeInsets.only(
                        left: index > 0 ? 12 : 0,
                      ),
                      child: Flexible(
                        child: Container(
                          decoration: BoxDecoration(
                            gradient: LinearGradient(
                              colors: colorPair,
                            ),
                            borderRadius: BorderRadius.circular(12),
                            boxShadow: [
                              BoxShadow(
                                color: colorPair[0].withOpacity(0.3),
                                blurRadius: 12,
                                offset: const Offset(0, 4),
                              ),
                            ],
                          ),
                          child: Material(
                            color: Colors.transparent,
                            child: InkWell(
                              onTap: () => _copyToClipboard(text, versionNum),
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
                color: color.withOpacity(0.1),
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
                ? color.withOpacity(0.08)
                : colorScheme.surfaceContainerHighest,
            borderRadius: BorderRadius.circular(14),
            border: Border.all(
              color: isRewritten
                  ? color.withOpacity(0.2)
                  : colorScheme.outline.withOpacity(0.1),
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
                    color: primaryColor.withOpacity(0.3),
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
                    color: primaryColor.withOpacity(0.1),
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
                primaryColor.withOpacity(0.1),
                secondaryColor.withOpacity(0.05),
              ],
            ),
            borderRadius: BorderRadius.circular(14),
            border: Border.all(
              color: primaryColor.withOpacity(0.3),
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
}
