// ============================================================================
// ============================================================================
// ============================================================================

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../data/services/live2d_log_service.dart';
import '../../../../utils/ui_feedback.dart';

void showLive2DLogViewer(BuildContext context) {
  showModalBottomSheet(
    context: context,
    isScrollControlled: true,
    useSafeArea: true,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
    ),
    builder: (context) => const Live2DLogViewer(),
  );
}

enum LogSourceFilter {
  all,
  flutter,
  native,
}

class Live2DLogViewer extends StatefulWidget {
  const Live2DLogViewer({super.key});

  @override
  State<Live2DLogViewer> createState() => _Live2DLogViewerState();
}

class _Live2DLogViewerState extends State<Live2DLogViewer> {
  final Live2DLogService _logService = Live2DLogService();
  Live2DLogLevel _filterLevel = Live2DLogLevel.debug;
  LogSourceFilter _sourceFilter = LogSourceFilter.all;
  final ScrollController _scrollController = ScrollController();
  bool _autoScroll = true;

  @override
  void initState() {
    super.initState();
    _logService.addListener(_onLogsChanged);
  }

  @override
  void dispose() {
    _logService.removeListener(_onLogsChanged);
    _scrollController.dispose();
    super.dispose();
  }

  void _onLogsChanged() {
    if (mounted) {
      setState(() {});
      if (_autoScroll && _scrollController.hasClients) {
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (_scrollController.hasClients) {
            _scrollController.jumpTo(0);
          }
        });
      }
    }
  }

  List<Live2DLogEntry> get filteredLogs {
    var logs = _logService.getLogsAboveLevel(_filterLevel);
    
    switch (_sourceFilter) {
      case LogSourceFilter.flutter:
        logs = logs.where((e) => e.source == Live2DLogSource.flutter).toList();
        break;
      case LogSourceFilter.native:
        logs = logs.where((e) => e.source == Live2DLogSource.native).toList();
        break;
      case LogSourceFilter.all:
        break;
    }
    
    return logs;
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final logs = filteredLogs;
    final stats = _logService.getStatistics();

    return DraggableScrollableSheet(
      initialChildSize: 0.7,
      minChildSize: 0.3,
      maxChildSize: 0.95,
      expand: false,
      builder: (context, scrollController) {
        return Column(
          children: [
            Container(
              margin: const EdgeInsets.symmetric(vertical: 8),
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: theme.colorScheme.onSurfaceVariant.withValues(alpha: 0.4),
                borderRadius: BorderRadius.circular(2),
              ),
            ),

            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: Column(
                children: [
                  Row(
                    children: [
                      Icon(
                        Icons.terminal,
                        color: theme.colorScheme.primary,
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Live2D 디버그 로그',
                              style: theme.textTheme.titleMedium?.copyWith(
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            Text(
                              '총 ${stats['total']}개 (Flutter: ${stats['flutter']}, Native: ${stats['native']})',
                              style: theme.textTheme.bodySmall?.copyWith(
                                color: theme.colorScheme.onSurfaceVariant,
                              ),
                            ),
                          ],
                        ),
                      ),
                      IconButton(
                        icon: Icon(
                          _autoScroll ? Icons.vertical_align_top : Icons.vertical_align_center,
                          size: 20,
                        ),
                        tooltip: _autoScroll ? '자동 스크롤 끄기' : '자동 스크롤 켜기',
                        onPressed: () => setState(() => _autoScroll = !_autoScroll),
                      ),
                      IconButton(
                        icon: const Icon(Icons.copy, size: 20),
                        tooltip: '로그 복사',
                        onPressed: () {
                          final text = _logService.exportLogs();
                          Clipboard.setData(ClipboardData(text: text));
                          context.showInfoSnackBar('로그가 클립보드에 복사되었습니다');
                        },
                      ),
                      IconButton(
                        icon: const Icon(Icons.delete_outline, size: 20),
                        tooltip: '로그 삭제',
                        onPressed: () {
                          _logService.clear();
                        },
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      _FilterChip(
                        label: '전체',
                        selected: _sourceFilter == LogSourceFilter.all,
                        onSelected: () => setState(() => _sourceFilter = LogSourceFilter.all),
                      ),
                      const SizedBox(width: 4),
                      _FilterChip(
                        label: '🐦 Flutter',
                        selected: _sourceFilter == LogSourceFilter.flutter,
                        onSelected: () => setState(() => _sourceFilter = LogSourceFilter.flutter),
                      ),
                      const SizedBox(width: 4),
                      _FilterChip(
                        label: '🤖 Native',
                        selected: _sourceFilter == LogSourceFilter.native,
                        onSelected: () => setState(() => _sourceFilter = LogSourceFilter.native),
                      ),
                      const Spacer(),
                      DropdownButton<Live2DLogLevel>(
                        value: _filterLevel,
                        underline: const SizedBox(),
                        isDense: true,
                        items: Live2DLogLevel.values.map((level) {
                          return DropdownMenuItem(
                            value: level,
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                _getLevelIcon(level),
                                const SizedBox(width: 4),
                                Text(level.name.toUpperCase(), style: const TextStyle(fontSize: 12)),
                              ],
                            ),
                          );
                        }).toList(),
                        onChanged: (value) {
                          if (value != null) {
                            setState(() => _filterLevel = value);
                          }
                        },
                      ),
                    ],
                  ),
                  const SizedBox(height: 4),
                  _StatisticsBar(stats: stats),
                ],
              ),
            ),

            const Divider(),

            Expanded(
              child: logs.isEmpty
                  ? Center(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(
                            Icons.event_note,
                            size: 48,
                            color: theme.colorScheme.onSurfaceVariant,
                          ),
                          const SizedBox(height: 16),
                          Text(
                            '로그가 없습니다',
                            style: theme.textTheme.bodyLarge?.copyWith(
                              color: theme.colorScheme.onSurfaceVariant,
                            ),
                          ),
                          const SizedBox(height: 8),
                          Text(
                            '오버레이를 시작하면 로그가 표시됩니다',
                            style: theme.textTheme.bodySmall?.copyWith(
                              color: theme.colorScheme.onSurfaceVariant,
                            ),
                          ),
                        ],
                      ),
                    )
                  : ListView.builder(
                      controller: scrollController,
                      itemCount: logs.length,
                      itemBuilder: (context, index) {
                        final log = logs[logs.length - 1 - index];
                        return _LogEntryTile(entry: log);
                      },
                    ),
            ),
          ],
        );
      },
    );
  }
  
  Widget _getLevelIcon(Live2DLogLevel level) {
    switch (level) {
      case Live2DLogLevel.debug:
        return const Text('🔍', style: TextStyle(fontSize: 12));
      case Live2DLogLevel.info:
        return const Text('ℹ️', style: TextStyle(fontSize: 12));
      case Live2DLogLevel.warning:
        return const Text('⚠️', style: TextStyle(fontSize: 12));
      case Live2DLogLevel.error:
        return const Text('❌', style: TextStyle(fontSize: 12));
    }
  }
}

class _FilterChip extends StatelessWidget {
  final String label;
  final bool selected;
  final VoidCallback onSelected;
  
  const _FilterChip({
    required this.label,
    required this.selected,
    required this.onSelected,
  });
  
  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return GestureDetector(
      onTap: onSelected,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
        decoration: BoxDecoration(
          color: selected ? theme.colorScheme.primaryContainer : Colors.transparent,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: selected ? theme.colorScheme.primary : theme.colorScheme.outline,
          ),
        ),
        child: Text(
          label,
          style: theme.textTheme.labelSmall?.copyWith(
            color: selected ? theme.colorScheme.primary : theme.colorScheme.onSurfaceVariant,
            fontWeight: selected ? FontWeight.bold : FontWeight.normal,
          ),
        ),
      ),
    );
  }
}

class _StatisticsBar extends StatelessWidget {
  final Map<String, int> stats;
  
  const _StatisticsBar({required this.stats});
  
  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final total = stats['total'] ?? 0;
    if (total == 0) return const SizedBox.shrink();
    
    final errorCount = stats['error'] ?? 0;
    final warningCount = stats['warning'] ?? 0;
    final infoCount = stats['info'] ?? 0;
    final debugCount = stats['debug'] ?? 0;
    
    return Container(
      height: 4,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(2),
        color: theme.colorScheme.surfaceContainerHighest,
      ),
      child: Row(
        children: [
          if (errorCount > 0)
            Expanded(
              flex: errorCount,
              child: Container(
                decoration: BoxDecoration(
                  color: theme.colorScheme.error,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),
          if (warningCount > 0)
            Expanded(
              flex: warningCount,
              child: Container(color: Colors.orange),
            ),
          if (infoCount > 0)
            Expanded(
              flex: infoCount,
              child: Container(color: theme.colorScheme.primary),
            ),
          if (debugCount > 0)
            Expanded(
              flex: debugCount,
              child: Container(color: theme.colorScheme.onSurfaceVariant.withValues(alpha: 0.5)),
            ),
        ],
      ),
    );
  }
}

class _LogEntryTile extends StatelessWidget {
  final Live2DLogEntry entry;

  const _LogEntryTile({required this.entry});

  Color _getColor(BuildContext context) {
    final theme = Theme.of(context);
    switch (entry.level) {
      case Live2DLogLevel.debug:
        return theme.colorScheme.onSurfaceVariant;
      case Live2DLogLevel.info:
        return theme.colorScheme.primary;
      case Live2DLogLevel.warning:
        return Colors.orange;
      case Live2DLogLevel.error:
        return theme.colorScheme.error;
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final color = _getColor(context);

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
      padding: const EdgeInsets.all(8),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.05),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: color.withValues(alpha: 0.2)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Text(
                entry.sourceIcon,
                style: const TextStyle(fontSize: 10),
              ),
              const SizedBox(width: 2),
              Text(
                entry.levelIcon,
                style: const TextStyle(fontSize: 10),
              ),
              const SizedBox(width: 4),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 1),
                decoration: BoxDecoration(
                  color: color.withValues(alpha: 0.2),
                  borderRadius: BorderRadius.circular(4),
                ),
                child: Text(
                  entry.tag,
                  style: theme.textTheme.labelSmall?.copyWith(
                    color: color,
                    fontWeight: FontWeight.bold,
                    fontSize: 10,
                  ),
                ),
              ),
              const Spacer(),
              Text(
                entry.formattedTime,
                style: theme.textTheme.labelSmall?.copyWith(
                  color: theme.colorScheme.onSurfaceVariant,
                  fontFamily: 'monospace',
                  fontSize: 10,
                ),
              ),
            ],
          ),
          const SizedBox(height: 4),
          Text(
            entry.message,
            style: theme.textTheme.bodySmall?.copyWith(
              fontWeight: FontWeight.w500,
            ),
          ),
          if (entry.details != null) ...[
            const SizedBox(height: 4),
            Text(
              entry.details!,
              style: theme.textTheme.bodySmall?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
                fontFamily: 'monospace',
                fontSize: 11,
              ),
            ),
          ],
          if (entry.error != null) ...[
            const SizedBox(height: 4),
            Container(
              padding: const EdgeInsets.all(4),
              decoration: BoxDecoration(
                color: theme.colorScheme.errorContainer,
                borderRadius: BorderRadius.circular(4),
              ),
              child: Text(
                entry.error.toString(),
                style: theme.textTheme.bodySmall?.copyWith(
                  color: theme.colorScheme.error,
                  fontFamily: 'monospace',
                  fontSize: 10,
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }
}
