// ============================================================================
// 로그 뷰어 위젯 (Log Viewer Widget)
// ============================================================================
// Live2D 관련 로그를 확인하는 위젯입니다.
// ============================================================================

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../data/services/live2d_log_service.dart';

/// 로그 뷰어 다이얼로그 표시
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

/// 로그 뷰어 위젯
class Live2DLogViewer extends StatefulWidget {
  const Live2DLogViewer({super.key});

  @override
  State<Live2DLogViewer> createState() => _Live2DLogViewerState();
}

class _Live2DLogViewerState extends State<Live2DLogViewer> {
  final Live2DLogService _logService = Live2DLogService();
  Live2DLogLevel _filterLevel = Live2DLogLevel.debug;
  final ScrollController _scrollController = ScrollController();

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
    if (mounted) setState(() {});
  }

  List<Live2DLogEntry> get filteredLogs {
    return _logService.getLogsAboveLevel(_filterLevel);
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final logs = filteredLogs;

    return DraggableScrollableSheet(
      initialChildSize: 0.7,
      minChildSize: 0.3,
      maxChildSize: 0.95,
      expand: false,
      builder: (context, scrollController) {
        return Column(
          children: [
            // 핸들
            Container(
              margin: const EdgeInsets.symmetric(vertical: 8),
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: theme.colorScheme.onSurfaceVariant.withOpacity(0.4),
                borderRadius: BorderRadius.circular(2),
              ),
            ),

            // 헤더
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: Row(
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
                          'Live2D 로그',
                          style: theme.textTheme.titleMedium?.copyWith(
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        Text(
                          '${logs.length}개 항목 (에러: ${_logService.errorLogs.length})',
                          style: theme.textTheme.bodySmall?.copyWith(
                            color: theme.colorScheme.onSurfaceVariant,
                          ),
                        ),
                      ],
                    ),
                  ),
                  // 필터 드롭다운
                  DropdownButton<Live2DLogLevel>(
                    value: _filterLevel,
                    underline: const SizedBox(),
                    items: Live2DLogLevel.values.map((level) {
                      return DropdownMenuItem(
                        value: level,
                        child: Text(level.name.toUpperCase()),
                      );
                    }).toList(),
                    onChanged: (value) {
                      if (value != null) {
                        setState(() => _filterLevel = value);
                      }
                    },
                  ),
                  // 복사 버튼
                  IconButton(
                    icon: const Icon(Icons.copy),
                    tooltip: '로그 복사',
                    onPressed: () {
                      final text = _logService.exportLogs();
                      Clipboard.setData(ClipboardData(text: text));
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(content: Text('로그가 클립보드에 복사되었습니다')),
                      );
                    },
                  ),
                  // 클리어 버튼
                  IconButton(
                    icon: const Icon(Icons.delete_outline),
                    tooltip: '로그 삭제',
                    onPressed: () {
                      _logService.clear();
                    },
                  ),
                ],
              ),
            ),

            const Divider(),

            // 로그 목록
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
                        ],
                      ),
                    )
                  : ListView.builder(
                      controller: scrollController,
                      itemCount: logs.length,
                      itemBuilder: (context, index) {
                        final log = logs[logs.length - 1 - index]; // 최신순
                        return _LogEntryTile(entry: log);
                      },
                    ),
            ),
          ],
        );
      },
    );
  }
}

/// 로그 항목 타일
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
        color: color.withOpacity(0.05),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: color.withOpacity(0.2)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // 헤더
          Row(
            children: [
              Text(
                entry.levelIcon,
                style: const TextStyle(fontSize: 12),
              ),
              const SizedBox(width: 4),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 1),
                decoration: BoxDecoration(
                  color: color.withOpacity(0.2),
                  borderRadius: BorderRadius.circular(4),
                ),
                child: Text(
                  entry.tag,
                  style: theme.textTheme.labelSmall?.copyWith(
                    color: color,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
              const Spacer(),
              Text(
                entry.formattedTime,
                style: theme.textTheme.labelSmall?.copyWith(
                  color: theme.colorScheme.onSurfaceVariant,
                  fontFamily: 'monospace',
                ),
              ),
            ],
          ),
          const SizedBox(height: 4),
          // 메시지
          Text(
            entry.message,
            style: theme.textTheme.bodySmall?.copyWith(
              fontWeight: FontWeight.w500,
            ),
          ),
          // 상세 정보
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
          // 에러
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
