import 'dart:convert';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:intl/intl.dart';
import 'package:path_provider/path_provider.dart';
import '../../core/models/rewrite_history_item.dart';
import '../../core/services/rewriter_service.dart';
import '../providers/app_provider.dart';
import '../settings/settings_page.dart';

/// Dashboard: default home with metrics, manual rewrite, history, and settings entry.
class DashboardPage extends StatefulWidget {
  const DashboardPage({super.key});

  @override
  State<DashboardPage> createState() => _DashboardPageState();
}

class _DashboardPageState extends State<DashboardPage> {
  List<RewriteHistoryItem> _history = [];
  List<RewriteHistoryItem> _filteredHistory = [];
  List<({DateTime date, int success, int error})> _statsData = [];
  int _todayCount = 0;
  int _totalCount = 0;
  bool _loading = true;
  bool _clearingHistory = false;
  int _chartDays = 7;
  RewriterService? _rewriterService;

  // Manual rewrite state
  final _inputController = TextEditingController();
  List<String> _manualResults = [];
  String? _lastOriginalForUndo;
  bool _isRewriting = false;

  // History search
  final _searchController = TextEditingController();
  String _searchQuery = '';

  Future<void> _loadData() async {
    final provider = context.read<AppProvider>();
    final historyService = provider.rewriterService.historyService;
    final history = await historyService.getHistory(limit: 50);
    final today = await historyService.getTodayCount();
    final total = await historyService.getTotalCount();
    final stats = await historyService.getStatsByDay(_chartDays);
    if (mounted) {
      setState(() {
        _history = history;
        _applySearchFilter();
        _todayCount = today;
        _totalCount = total;
        _statsData = stats;
        _loading = false;
      });
    }
  }

  void _applySearchFilter() {
    if (_searchQuery.isEmpty) {
      _filteredHistory = List.from(_history);
    } else {
      final q = _searchQuery.toLowerCase();
      _filteredHistory = _history.where((item) {
        return item.originalText.toLowerCase().contains(q) ||
            item.rewrittenTexts.any((t) => t.toLowerCase().contains(q)) ||
            item.style.toLowerCase().contains(q);
      }).toList();
    }
  }

  Future<void> _setChartDays(int days) async {
    if (_chartDays == days) return;
    setState(() => _chartDays = days);
    final provider = context.read<AppProvider>();
    final stats = await provider.rewriterService.historyService.getStatsByDay(days);
    if (mounted) setState(() => _statsData = stats);
  }

  @override
  void initState() {
    super.initState();
    _searchController.addListener(() {
      setState(() {
        _searchQuery = _searchController.text;
        _applySearchFilter();
      });
    });
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _loadData();
      final rewriterService = context.read<AppProvider>().rewriterService;
      _rewriterService = rewriterService;
      rewriterService.onStatsChanged = () {
        if (mounted) _loadData();
      };
    });
  }

  @override
  void dispose() {
    _rewriterService?.onStatsChanged = null;
    _rewriterService = null;
    _inputController.dispose();
    _searchController.dispose();
    super.dispose();
  }

  void _openSettings() {
    Navigator.of(context).push(
      MaterialPageRoute(builder: (context) => const SettingsPage()),
    ).then((_) {
      if (mounted) _loadData();
    });
  }

  String _timeAgo(DateTime dateTime) {
    final now = DateTime.now();
    final diff = now.difference(dateTime);
    if (diff.inDays > 0) return '${diff.inDays}d ago';
    if (diff.inHours > 0) return '${diff.inHours}h ago';
    if (diff.inMinutes > 0) return '${diff.inMinutes}m ago';
    if (diff.inSeconds > 0) return '${diff.inSeconds}s ago';
    return 'Just now';
  }

  Future<void> _clearHistory() async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Clear history?'),
        content: const Text(
          'This will remove all rewrite history. This cannot be undone.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            style: FilledButton.styleFrom(
              backgroundColor: Theme.of(context).colorScheme.error,
            ),
            child: const Text('Clear'),
          ),
        ],
      ),
    );
    if (confirm != true || !mounted) return;
    setState(() => _clearingHistory = true);
    final historyService = context.read<AppProvider>().rewriterService.historyService;
    await historyService.clearHistory();
    if (mounted) {
      setState(() {
        _history = [];
        _filteredHistory = [];
        _statsData = [];
        _todayCount = 0;
        _totalCount = 0;
        _clearingHistory = false;
      });
    }
  }

  Future<void> _manualRewrite() async {
    final text = _inputController.text.trim();
    if (text.isEmpty) return;

    setState(() {
      _isRewriting = true;
      _manualResults = [];
    });

    final provider = context.read<AppProvider>();
    final results = await provider.rewriterService.manualRewriteMultiple(text, count: 3);

    if (mounted) {
      setState(() {
        _isRewriting = false;
        _manualResults = results;
        if (results.isNotEmpty) {
          _lastOriginalForUndo = text;
        }
      });
    }
  }

  void _copyResult(String text) {
    Clipboard.setData(ClipboardData(text: text));
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Copied to clipboard'),
        behavior: SnackBarBehavior.floating,
        duration: Duration(seconds: 1),
      ),
    );
  }

  void _undoRewrite() {
    if (_lastOriginalForUndo != null) {
      Clipboard.setData(ClipboardData(text: _lastOriginalForUndo!));
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Original text restored to clipboard'),
          behavior: SnackBarBehavior.floating,
          duration: Duration(seconds: 1),
        ),
      );
    }
  }

  Future<void> _exportHistory(String format) async {
    if (_history.isEmpty) return;

    try {
      String content;
      String extension;

      if (format == 'csv') {
        extension = 'csv';
        final buffer = StringBuffer();
        buffer.writeln('Timestamp,Style,Original,Rewritten');
        for (final item in _history) {
          final rewritten = item.rewrittenTexts.isNotEmpty ? item.rewrittenTexts.first : '';
          buffer.writeln(
            '"${item.timestamp.toIso8601String()}","${item.style}","${item.originalText.replaceAll('"', '""')}","${rewritten.replaceAll('"', '""')}"',
          );
        }
        content = buffer.toString();
      } else {
        extension = 'json';
        content = const JsonEncoder.withIndent('  ').convert(
          _history.map((item) => item.toJson()).toList(),
        );
      }

      final dir = await getDownloadsDirectory() ?? await getApplicationDocumentsDirectory();
      final timestamp = DateFormat('yyyyMMdd_HHmmss').format(DateTime.now());
      final file = File('${dir.path}/rewriter_history_$timestamp.$extension');
      await file.writeAsString(content);

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Exported to ${file.path}'),
            behavior: SnackBarBehavior.floating,
            duration: const Duration(seconds: 3),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Export failed: $e'),
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return Scaffold(
      backgroundColor: colorScheme.surface,
      body: Consumer<AppProvider>(
        builder: (context, provider, _) {
          final isConfigured = provider.hasApiKey;
          final isEnabled = provider.isEnabled;

          return SafeArea(
            child: RefreshIndicator(
              onRefresh: () async {
                await _loadData();
              },
              child: CustomScrollView(
                physics: const AlwaysScrollableScrollPhysics(
                  parent: BouncingScrollPhysics(),
                ),
                slivers: [
                // App bar
                SliverToBoxAdapter(
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(24, 20, 16, 16),
                    child: Row(
                      children: [
                        Text(
                          'Rewriter',
                          style: theme.textTheme.headlineSmall?.copyWith(
                            fontWeight: FontWeight.w700,
                            color: colorScheme.onSurface,
                            letterSpacing: -0.5,
                          ),
                        ),
                        const Spacer(),
                        // Theme toggle
                        _ThemeToggleButton(provider: provider),
                        const SizedBox(width: 4),
                        IconButton.filled(
                          onPressed: _openSettings,
                          icon: const Icon(Icons.settings_rounded),
                          tooltip: 'Settings',
                          style: IconButton.styleFrom(
                            backgroundColor: colorScheme.primaryContainer,
                            foregroundColor: colorScheme.onPrimaryContainer,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),

                // Setup CTA when not configured
                if (!isConfigured)
                  SliverToBoxAdapter(
                    child: Padding(
                      padding: const EdgeInsets.fromLTRB(24, 0, 24, 24),
                      child: _SetupCard(onOpenSettings: _openSettings),
                    ),
                  ),

                // Manual Rewrite Input
                SliverToBoxAdapter(
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(24, 0, 24, 16),
                    child: _ManualRewriteCard(
                      inputController: _inputController,
                      isRewriting: _isRewriting,
                      results: _manualResults,
                      hasUndo: _lastOriginalForUndo != null,
                      isConfigured: isConfigured,
                      onRewrite: _manualRewrite,
                      onCopy: _copyResult,
                      onUndo: _undoRewrite,
                    ),
                  ),
                ),

                // Metrics
                SliverToBoxAdapter(
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 24),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Overview',
                          style: theme.textTheme.titleMedium?.copyWith(
                            fontWeight: FontWeight.w600,
                            color: colorScheme.onSurface,
                          ),
                        ),
                        const SizedBox(height: 12),
                        _loading
                            ? const Padding(
                                padding: EdgeInsets.symmetric(vertical: 24),
                                child: Center(child: CircularProgressIndicator()),
                              )
                            : Row(
                                children: [
                                  Expanded(
                                    child: _MetricCard(
                                      label: "Today's rewrites",
                                      value: '$_todayCount',
                                      icon: Icons.today_rounded,
                                      color: const Color(0xFF3B82F6),
                                    ),
                                  ),
                                  const SizedBox(width: 12),
                                  Expanded(
                                    child: _MetricCard(
                                      label: 'Total rewrites',
                                      value: '$_totalCount',
                                      icon: Icons.auto_awesome_rounded,
                                      color: const Color(0xFF8B5CF6),
                                    ),
                                  ),
                                  const SizedBox(width: 12),
                                  Expanded(
                                    child: _MetricCard(
                                      label: 'Status',
                                      value: isEnabled ? 'Active' : 'Paused',
                                      icon: isEnabled
                                          ? Icons.check_circle_rounded
                                          : Icons.pause_circle_rounded,
                                      color: isEnabled
                                          ? const Color(0xFF10B981)
                                          : const Color(0xFF6B7280),
                                    ),
                                  ),
                                ],
                              ),
                      ],
                    ),
                  ),
                ),

                const SliverToBoxAdapter(child: SizedBox(height: 32)),

                // Chart
                SliverToBoxAdapter(
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 24),
                    child: _SuccessErrorLineChartSection(
                      statsData: _statsData,
                      chartDays: _chartDays,
                      loading: _loading,
                      onFilterChanged: _setChartDays,
                      colorScheme: colorScheme,
                      theme: theme,
                    ),
                  ),
                ),

                const SliverToBoxAdapter(child: SizedBox(height: 32)),

                // History header with search, export, clear
                SliverToBoxAdapter(
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 24),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Text(
                              'Recent history',
                              style: theme.textTheme.titleMedium?.copyWith(
                                fontWeight: FontWeight.w600,
                                color: colorScheme.onSurface,
                              ),
                            ),
                            const Spacer(),
                            if (_history.isNotEmpty) ...[
                              PopupMenuButton<String>(
                                icon: Icon(Icons.file_download_outlined, size: 20, color: colorScheme.primary),
                                tooltip: 'Export history',
                                onSelected: _exportHistory,
                                itemBuilder: (context) => [
                                  const PopupMenuItem(value: 'json', child: Text('Export as JSON')),
                                  const PopupMenuItem(value: 'csv', child: Text('Export as CSV')),
                                ],
                              ),
                              TextButton.icon(
                                onPressed: _clearingHistory ? null : _clearHistory,
                                icon: _clearingHistory
                                    ? SizedBox(
                                        width: 16,
                                        height: 16,
                                        child: CircularProgressIndicator(
                                          strokeWidth: 2,
                                          color: colorScheme.primary,
                                        ),
                                      )
                                    : const Icon(Icons.delete_outline_rounded, size: 18),
                                label: Text(_clearingHistory ? 'Clearing...' : 'Clear'),
                              ),
                            ],
                          ],
                        ),
                        if (_history.isNotEmpty) ...[
                          const SizedBox(height: 12),
                          TextField(
                            controller: _searchController,
                            decoration: InputDecoration(
                              hintText: 'Search history...',
                              prefixIcon: const Icon(Icons.search, size: 20),
                              suffixIcon: _searchQuery.isNotEmpty
                                  ? IconButton(
                                      icon: const Icon(Icons.clear, size: 18),
                                      onPressed: () => _searchController.clear(),
                                    )
                                  : null,
                              isDense: true,
                              contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                              filled: true,
                              fillColor: colorScheme.surfaceContainerHighest.withValues(alpha: 0.5),
                              border: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(12),
                                borderSide: BorderSide(color: colorScheme.outline.withValues(alpha: 0.1)),
                              ),
                              enabledBorder: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(12),
                                borderSide: BorderSide(color: colorScheme.outline.withValues(alpha: 0.1)),
                              ),
                            ),
                          ),
                        ],
                      ],
                    ),
                  ),
                ),
                const SliverToBoxAdapter(child: SizedBox(height: 12)),

                if (_filteredHistory.isEmpty && !_loading)
                  SliverToBoxAdapter(
                    child: Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 32),
                      child: _searchQuery.isNotEmpty
                          ? Center(
                              child: Text(
                                'No results for "$_searchQuery"',
                                style: theme.textTheme.bodyMedium?.copyWith(
                                  color: colorScheme.onSurface.withValues(alpha: 0.6),
                                ),
                              ),
                            )
                          : _EmptyHistoryCard(isConfigured: isConfigured),
                    ),
                  )
                else
                  SliverList(
                    delegate: SliverChildBuilderDelegate(
                      (context, index) {
                        final item = _filteredHistory[index];
                        final rewritten = item.rewrittenTexts.isNotEmpty
                            ? item.rewrittenTexts.first
                            : '';
                        return _HistoryTile(
                          original: item.originalText,
                          rewritten: rewritten,
                          timeAgo: _timeAgo(item.timestamp),
                          style: item.style,
                          onCopy: () {
                            Clipboard.setData(ClipboardData(text: rewritten));
                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(
                                content: Text('Copied to clipboard'),
                                behavior: SnackBarBehavior.floating,
                                duration: Duration(seconds: 1),
                              ),
                            );
                          },
                          onRestoreOriginal: () {
                            Clipboard.setData(ClipboardData(text: item.originalText));
                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(
                                content: Text('Original text restored to clipboard'),
                                behavior: SnackBarBehavior.floating,
                                duration: Duration(seconds: 1),
                              ),
                            );
                          },
                        );
                      },
                      childCount: _filteredHistory.length,
                    ),
                  ),

                const SliverToBoxAdapter(child: SizedBox(height: 48)),
                ],
              ),
            ),
          );
        },
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Theme toggle button
// ---------------------------------------------------------------------------

class _ThemeToggleButton extends StatelessWidget {
  final AppProvider provider;

  const _ThemeToggleButton({required this.provider});

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final currentMode = provider.config?.themeMode ?? 'system';

    IconData icon;
    String tooltip;
    switch (currentMode) {
      case 'light':
        icon = Icons.light_mode_rounded;
        tooltip = 'Light mode (tap to switch)';
      case 'dark':
        icon = Icons.dark_mode_rounded;
        tooltip = 'Dark mode (tap to switch)';
      default:
        icon = Icons.brightness_auto_rounded;
        tooltip = 'System theme (tap to switch)';
    }

    return IconButton(
      onPressed: () {
        final next = switch (currentMode) {
          'system' => 'light',
          'light' => 'dark',
          _ => 'system',
        };
        final config = provider.config;
        if (config != null) {
          provider.updateConfig(config.copyWith(themeMode: next));
        }
      },
      icon: Icon(icon),
      tooltip: tooltip,
      style: IconButton.styleFrom(
        backgroundColor: colorScheme.surfaceContainerHighest,
        foregroundColor: colorScheme.onSurface,
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Manual Rewrite Card
// ---------------------------------------------------------------------------

class _ManualRewriteCard extends StatelessWidget {
  final TextEditingController inputController;
  final bool isRewriting;
  final List<String> results;
  final bool hasUndo;
  final bool isConfigured;
  final VoidCallback onRewrite;
  final void Function(String) onCopy;
  final VoidCallback onUndo;

  const _ManualRewriteCard({
    required this.inputController,
    required this.isRewriting,
    required this.results,
    required this.hasUndo,
    required this.isConfigured,
    required this.onRewrite,
    required this.onCopy,
    required this.onUndo,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return Card(
      elevation: 0,
      color: colorScheme.surfaceContainerHighest.withValues(alpha: 0.3),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: BorderSide(color: colorScheme.outline.withValues(alpha: 0.1)),
      ),
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(Icons.edit_note_rounded, size: 22, color: colorScheme.primary),
                const SizedBox(width: 8),
                Text(
                  'Rewrite Text',
                  style: theme.textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.w600,
                    color: colorScheme.onSurface,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            TextField(
              controller: inputController,
              maxLines: 3,
              minLines: 2,
              decoration: InputDecoration(
                hintText: 'Paste or type text to rewrite...',
                filled: true,
                fillColor: colorScheme.surface,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide(color: colorScheme.outline.withValues(alpha: 0.2)),
                ),
                enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide(color: colorScheme.outline.withValues(alpha: 0.2)),
                ),
                contentPadding: const EdgeInsets.all(14),
              ),
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                FilledButton.icon(
                  onPressed: isRewriting || !isConfigured ? null : onRewrite,
                  icon: isRewriting
                      ? SizedBox(
                          width: 16,
                          height: 16,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            color: colorScheme.onPrimary,
                          ),
                        )
                      : const Icon(Icons.auto_awesome_rounded, size: 18),
                  label: Text(isRewriting ? 'Generating variants...' : 'Rewrite'),
                ),
                if (hasUndo) ...[
                  const SizedBox(width: 8),
                  OutlinedButton.icon(
                    onPressed: onUndo,
                    icon: const Icon(Icons.undo_rounded, size: 18),
                    label: const Text('Restore Original'),
                  ),
                ],
              ],
            ),
            if (results.isNotEmpty) ...[
              const SizedBox(height: 16),
              Text(
                '${results.length} variant${results.length > 1 ? 's' : ''} generated',
                style: theme.textTheme.labelMedium?.copyWith(
                  fontWeight: FontWeight.w600,
                  color: const Color(0xFF10B981),
                ),
              ),
              const SizedBox(height: 8),
              ...results.asMap().entries.map((entry) {
                final idx = entry.key;
                final text = entry.value;
                return Padding(
                  padding: EdgeInsets.only(bottom: idx < results.length - 1 ? 8 : 0),
                  child: Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(14),
                    decoration: BoxDecoration(
                      color: const Color(0xFF10B981).withValues(alpha: 0.06 + idx * 0.02),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(
                        color: const Color(0xFF10B981).withValues(alpha: 0.2),
                      ),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                              decoration: BoxDecoration(
                                color: const Color(0xFF10B981).withValues(alpha: 0.15),
                                borderRadius: BorderRadius.circular(4),
                              ),
                              child: Text(
                                'Option ${idx + 1}',
                                style: theme.textTheme.labelSmall?.copyWith(
                                  fontWeight: FontWeight.w700,
                                  color: const Color(0xFF10B981),
                                  fontSize: 10,
                                ),
                              ),
                            ),
                            const Spacer(),
                            IconButton(
                              onPressed: () => onCopy(text),
                              icon: const Icon(Icons.copy_rounded, size: 16),
                              tooltip: 'Copy this variant',
                              style: IconButton.styleFrom(
                                padding: const EdgeInsets.all(4),
                                minimumSize: const Size(28, 28),
                                backgroundColor: const Color(0xFF10B981).withValues(alpha: 0.1),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 6),
                        SelectableText(
                          text,
                          style: theme.textTheme.bodyMedium?.copyWith(
                            color: colorScheme.onSurface,
                          ),
                        ),
                      ],
                    ),
                  ),
                );
              }),
            ],
          ],
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Setup card
// ---------------------------------------------------------------------------

class _SetupCard extends StatelessWidget {
  final VoidCallback onOpenSettings;

  const _SetupCard({required this.onOpenSettings});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return Card(
      elevation: 0,
      color: colorScheme.primaryContainer.withValues(alpha: 0.5),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: BorderSide(color: colorScheme.primary.withValues(alpha: 0.3)),
      ),
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(Icons.tips_and_updates_rounded, color: colorScheme.primary, size: 28),
                const SizedBox(width: 12),
                Text(
                  'Complete setup to start rewriting',
                  style: theme.textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.w600,
                    color: colorScheme.onSurface,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Text(
              'Choose an AI model (Gemini, Ollama, or Local AI) and configure it. '
              'Then copy text in English and the app will rewrite it automatically.',
              style: theme.textTheme.bodyMedium?.copyWith(
                color: colorScheme.onSurface.withValues(alpha: 0.8),
              ),
            ),
            const SizedBox(height: 16),
            FilledButton.icon(
              onPressed: onOpenSettings,
              icon: const Icon(Icons.settings_rounded, size: 20),
              label: const Text('Open Settings'),
              style: FilledButton.styleFrom(
                padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Metric card
// ---------------------------------------------------------------------------

class _MetricCard extends StatelessWidget {
  final String label;
  final String value;
  final IconData icon;
  final Color color;

  const _MetricCard({
    required this.label,
    required this.value,
    required this.icon,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return Card(
      elevation: 0,
      color: colorScheme.surfaceContainerHighest.withValues(alpha: 0.5),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: BorderSide(color: colorScheme.outline.withValues(alpha: 0.1)),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(icon, size: 22, color: color),
            const SizedBox(height: 8),
            Text(
              value,
              style: theme.textTheme.headlineSmall?.copyWith(
                fontWeight: FontWeight.w700,
                color: colorScheme.onSurface,
              ),
            ),
            const SizedBox(height: 2),
            Text(
              label,
              style: theme.textTheme.bodySmall?.copyWith(
                color: colorScheme.onSurface.withValues(alpha: 0.7),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Success/Error chart
// ---------------------------------------------------------------------------

class _SuccessErrorLineChartSection extends StatelessWidget {
  final List<({DateTime date, int success, int error})> statsData;
  final int chartDays;
  final bool loading;
  final ValueChanged<int> onFilterChanged;
  final ColorScheme colorScheme;
  final ThemeData theme;

  const _SuccessErrorLineChartSection({
    required this.statsData,
    required this.chartDays,
    required this.loading,
    required this.onFilterChanged,
    required this.colorScheme,
    required this.theme,
  });

  @override
  Widget build(BuildContext context) {
    final maxVal = statsData.isEmpty
        ? 1
        : statsData.fold<int>(
            0,
            (m, e) => (e.success + e.error) > m ? (e.success + e.error) : m,
          );
    final maxY = (maxVal + 0.5).clamp(1.0, double.infinity);
    const successColor = Color(0xFF10B981);
    const errorColor = Color(0xFFEF4444);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              'Success vs Error',
              style: theme.textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.w600,
                color: colorScheme.onSurface,
              ),
            ),
            Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                _FilterChip(
                  label: '1 Day',
                  selected: chartDays == 1,
                  onTap: () => onFilterChanged(1),
                ),
                const SizedBox(width: 8),
                _FilterChip(
                  label: '7 Days',
                  selected: chartDays == 7,
                  onTap: () => onFilterChanged(7),
                ),
                const SizedBox(width: 8),
                _FilterChip(
                  label: '30 Days',
                  selected: chartDays == 30,
                  onTap: () => onFilterChanged(30),
                ),
              ],
            ),
          ],
        ),
        const SizedBox(height: 12),
        Card(
          elevation: 0,
          color: colorScheme.surfaceContainerHighest.withValues(alpha: 0.5),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
            side: BorderSide(color: colorScheme.outline.withValues(alpha: 0.1)),
          ),
          child: Padding(
            padding: const EdgeInsets.fromLTRB(16, 20, 16, 16),
            child: loading
                ? const SizedBox(
                    height: 220,
                    child: Center(child: CircularProgressIndicator()),
                  )
                : statsData.isEmpty
                    ? const SizedBox(
                        height: 220,
                        child: Center(child: Text('No data yet')),
                      )
                    : Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              _LegendDot(color: successColor),
                              const SizedBox(width: 4),
                              Text(
                                'Success',
                                style: theme.textTheme.labelSmall?.copyWith(
                                  color: colorScheme.onSurface.withValues(alpha: 0.8),
                                ),
                              ),
                              const SizedBox(width: 16),
                              _LegendDot(color: errorColor),
                              const SizedBox(width: 4),
                              Text(
                                'Error',
                                style: theme.textTheme.labelSmall?.copyWith(
                                  color: colorScheme.onSurface.withValues(alpha: 0.8),
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 12),
                          SizedBox(
                            height: 200,
                            child: LineChart(
                              LineChartData(
                                minX: 0,
                                maxX: (statsData.length - 1).toDouble(),
                                minY: 0,
                                maxY: maxY,
                                lineBarsData: [
                                  LineChartBarData(
                                    spots: statsData.asMap().entries.map((e) {
                                      return FlSpot(e.key.toDouble(), e.value.success.toDouble());
                                    }).toList(),
                                    isCurved: true,
                                    color: successColor,
                                    barWidth: 2.5,
                                    isStrokeCapRound: true,
                                    dotData: const FlDotData(show: true),
                                    belowBarData: BarAreaData(show: false),
                                  ),
                                  LineChartBarData(
                                    spots: statsData.asMap().entries.map((e) {
                                      return FlSpot(e.key.toDouble(), e.value.error.toDouble());
                                    }).toList(),
                                    isCurved: true,
                                    color: errorColor,
                                    barWidth: 2.5,
                                    isStrokeCapRound: true,
                                    dotData: const FlDotData(show: true),
                                    belowBarData: BarAreaData(show: false),
                                  ),
                                ],
                                titlesData: FlTitlesData(
                                  show: true,
                                  bottomTitles: AxisTitles(
                                    sideTitles: SideTitles(
                                      showTitles: true,
                                      reservedSize: 28,
                                      interval: chartDays == 1 ? 3 : 1,
                                      getTitlesWidget: (value, meta) {
                                        final i = value.toInt();
                                        if (i < 0 || i >= statsData.length) return const SizedBox();
                                        final d = statsData[i].date;
                                        final label = chartDays == 1
                                            ? DateFormat('H').format(d)
                                            : chartDays <= 7
                                                ? DateFormat('E').format(d)
                                                : DateFormat('d/M').format(d);
                                        return Padding(
                                          padding: const EdgeInsets.only(top: 8),
                                          child: Text(
                                            chartDays == 1 ? '${label}h' : label,
                                            style: theme.textTheme.labelSmall?.copyWith(
                                              color: colorScheme.onSurface.withValues(alpha: 0.6),
                                            ),
                                          ),
                                        );
                                      },
                                    ),
                                  ),
                                  leftTitles: AxisTitles(
                                    sideTitles: SideTitles(
                                      showTitles: true,
                                      reservedSize: 24,
                                      interval: maxY >= 5 ? (maxY / 5) : 1,
                                      getTitlesWidget: (value, meta) {
                                        return Text(
                                          value.toInt().toString(),
                                          style: theme.textTheme.labelSmall?.copyWith(
                                            color: colorScheme.onSurface.withValues(alpha: 0.6),
                                          ),
                                        );
                                      },
                                    ),
                                  ),
                                  topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                                  rightTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                                ),
                                gridData: FlGridData(
                                  show: true,
                                  drawVerticalLine: false,
                                  horizontalInterval: maxY >= 5 ? (maxY / 5) : 1,
                                  getDrawingHorizontalLine: (value) => FlLine(
                                    color: colorScheme.outline.withValues(alpha: 0.15),
                                    strokeWidth: 1,
                                  ),
                                ),
                                borderData: FlBorderData(show: false),
                                lineTouchData: LineTouchData(
                                  enabled: true,
                                  touchTooltipData: LineTouchTooltipData(
                                    getTooltipItems: (touchedSpots) {
                                      return touchedSpots.map((spot) {
                                        final i = spot.x.toInt();
                                        if (i < 0 || i >= statsData.length) return null;
                                        final d = statsData[i];
                                        final isSuccess = spot.barIndex == 0;
                                        final timeStr = chartDays == 1
                                            ? DateFormat('MMM d, HH:mm').format(d.date)
                                            : DateFormat('MMM d').format(d.date);
                                        return LineTooltipItem(
                                          '${isSuccess ? "Success" : "Error"}: ${isSuccess ? d.success : d.error}\n$timeStr',
                                          TextStyle(
                                            color: colorScheme.onSurface,
                                            fontSize: 12,
                                            fontWeight: FontWeight.w500,
                                          ),
                                        );
                                      }).whereType<LineTooltipItem>().toList();
                                    },
                                  ),
                                ),
                              ),
                            ),
                          ),
                        ],
                      ),
          ),
        ),
      ],
    );
  }
}

class _FilterChip extends StatelessWidget {
  final String label;
  final bool selected;
  final VoidCallback onTap;

  const _FilterChip({
    required this.label,
    required this.selected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(8),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
          decoration: BoxDecoration(
            color: selected
                ? colorScheme.primary.withValues(alpha: 0.15)
                : colorScheme.surfaceContainerHighest,
            borderRadius: BorderRadius.circular(8),
            border: Border.all(
              color: selected ? colorScheme.primary : colorScheme.outline.withValues(alpha: 0.2),
            ),
          ),
          child: Text(
            label,
            style: TextStyle(
              fontSize: 12,
              fontWeight: selected ? FontWeight.w600 : FontWeight.w500,
              color: selected ? colorScheme.primary : colorScheme.onSurface.withValues(alpha: 0.7),
            ),
          ),
        ),
      ),
    );
  }
}

class _LegendDot extends StatelessWidget {
  final Color color;

  const _LegendDot({required this.color});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 10,
      height: 10,
      decoration: BoxDecoration(color: color, shape: BoxShape.circle),
    );
  }
}

// ---------------------------------------------------------------------------
// Empty history card
// ---------------------------------------------------------------------------

class _EmptyHistoryCard extends StatelessWidget {
  final bool isConfigured;

  const _EmptyHistoryCard({required this.isConfigured});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return Card(
      elevation: 0,
      color: colorScheme.surfaceContainerHighest.withValues(alpha: 0.3),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          children: [
            Icon(
              Icons.history_rounded,
              size: 48,
              color: colorScheme.onSurface.withValues(alpha: 0.4),
            ),
            const SizedBox(height: 16),
            Text(
              'No rewrites yet',
              style: theme.textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.w600,
                color: colorScheme.onSurface,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              isConfigured
                  ? 'Copy text in English and it will appear here after rewriting.'
                  : 'Complete setup in Settings, then copy text to see history here.',
              textAlign: TextAlign.center,
              style: theme.textTheme.bodyMedium?.copyWith(
                color: colorScheme.onSurface.withValues(alpha: 0.6),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// History tile with undo/restore
// ---------------------------------------------------------------------------

class _HistoryTile extends StatelessWidget {
  final String original;
  final String rewritten;
  final String timeAgo;
  final String style;
  final VoidCallback onCopy;
  final VoidCallback onRestoreOriginal;

  const _HistoryTile({
    required this.original,
    required this.rewritten,
    required this.timeAgo,
    required this.style,
    required this.onCopy,
    required this.onRestoreOriginal,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    String truncate(String s, int maxLen) {
      if (s.length <= maxLen) return s;
      return '${s.substring(0, maxLen)}...';
    }

    return Card(
      margin: const EdgeInsets.fromLTRB(24, 0, 24, 12),
      elevation: 0,
      color: colorScheme.surfaceContainerHighest.withValues(alpha: 0.3),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: InkWell(
        onTap: onCopy,
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          truncate(original, 80),
                          style: theme.textTheme.bodyMedium?.copyWith(
                            color: colorScheme.onSurface.withValues(alpha: 0.8),
                          ),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          truncate(rewritten, 120),
                          style: theme.textTheme.bodyMedium?.copyWith(
                            fontWeight: FontWeight.w500,
                            color: colorScheme.onSurface,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 4),
                  Column(
                    children: [
                      IconButton(
                        onPressed: onCopy,
                        icon: const Icon(Icons.copy_rounded, size: 18),
                        tooltip: 'Copy rewritten text',
                        style: IconButton.styleFrom(
                          backgroundColor: colorScheme.primaryContainer.withValues(alpha: 0.5),
                          padding: const EdgeInsets.all(6),
                          minimumSize: const Size(32, 32),
                        ),
                      ),
                      const SizedBox(height: 4),
                      IconButton(
                        onPressed: onRestoreOriginal,
                        icon: const Icon(Icons.undo_rounded, size: 18),
                        tooltip: 'Restore original',
                        style: IconButton.styleFrom(
                          backgroundColor: colorScheme.surfaceContainerHighest,
                          padding: const EdgeInsets.all(6),
                          minimumSize: const Size(32, 32),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
              const SizedBox(height: 8),
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    decoration: BoxDecoration(
                      color: colorScheme.surfaceContainerHighest,
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Text(
                      style,
                      style: theme.textTheme.labelSmall?.copyWith(
                        color: colorScheme.onSurface.withValues(alpha: 0.7),
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Text(
                    timeAgo,
                    style: theme.textTheme.labelSmall?.copyWith(
                      color: colorScheme.onSurface.withValues(alpha: 0.5),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}
