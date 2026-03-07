import 'dart:async';

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../models/proactive_debug_models.dart';
import '../services/proactive_response_service.dart';

class ProactiveDebugScreen extends StatefulWidget {
  const ProactiveDebugScreen({super.key});

  @override
  State<ProactiveDebugScreen> createState() => _ProactiveDebugScreenState();
}

class _ProactiveDebugScreenState extends State<ProactiveDebugScreen> {
  Timer? _ticker;

  @override
  void initState() {
    super.initState();
    _ticker = Timer.periodic(const Duration(seconds: 1), (_) {
      if (mounted) {
        setState(() {});
      }
    });
  }

  @override
  void dispose() {
    _ticker?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final proactiveService = context.read<ProactiveResponseService>();

    return Scaffold(
      appBar: AppBar(
        title: const Text('선응답 디버그'),
        actions: [
          IconButton(
            onPressed: proactiveService.clearDebugLogs,
            icon: const Icon(Icons.delete_outline),
            tooltip: '로그 비우기',
          ),
        ],
      ),
      body: ValueListenableBuilder<ProactiveDebugSnapshot>(
        valueListenable: proactiveService.debugSnapshot,
        builder: (context, snapshot, _) {
          final logs = proactiveService.debugLogs.reversed.toList(growable: false);

          return Padding(
            padding: const EdgeInsets.all(12),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Card(
                  child: Padding(
                    padding: const EdgeInsets.all(12),
                    child: Column(
                      children: [
                        _DebugRow(label: '상태', value: snapshot.status),
                        _DebugRow(
                          label: '타이머',
                          value: snapshot.running
                              ? (snapshot.paused ? 'paused' : 'running')
                              : 'stopped',
                        ),
                        _DebugRow(
                          label: '남은 시간',
                          value: _formatRemaining(snapshot),
                        ),
                        _DebugRow(
                          label: '다음 실행',
                          value: _formatDateTime(snapshot.nextTriggerAt),
                        ),
                        _DebugRow(
                          label: '현재 주기',
                          value: snapshot.scheduledDuration == null
                              ? '-'
                              : _formatDuration(snapshot.scheduledDuration!),
                        ),
                        _DebugRow(
                          label: '요청 처리중',
                          value: snapshot.inFlight ? 'YES' : 'NO',
                        ),
                      ],
                    ),
                  ),
                ),
                Card(
                  child: Padding(
                    padding: const EdgeInsets.all(12),
                    child: Column(
                      children: [
                        _DebugRow(
                          label: 'Master',
                          value: snapshot.globalEnabled ? 'ON' : 'OFF',
                        ),
                        _DebugRow(
                          label: '알림',
                          value: snapshot.notificationsEnabled ? 'ON' : 'OFF',
                        ),
                        _DebugRow(
                          label: '선응답',
                          value: snapshot.proactiveEnabled ? 'ON' : 'OFF',
                        ),
                        _DebugRow(
                          label: '오버레이',
                          value: snapshot.overlayOn ? 'ON' : 'OFF',
                        ),
                        _DebugRow(
                          label: '가로모드',
                          value: snapshot.screenLandscape ? 'ON' : 'OFF',
                        ),
                        _DebugRow(
                          label: '화면꺼짐',
                          value: snapshot.screenOff ? 'ON' : 'OFF',
                        ),
                      ],
                    ),
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 6),
                  child: Text(
                    '최근 이벤트 (${snapshot.logCount})',
                    style: Theme.of(context).textTheme.titleMedium,
                  ),
                ),
                Expanded(
                  child: logs.isEmpty
                      ? const Center(child: Text('기록된 이벤트가 없습니다.'))
                      : ListView.separated(
                          itemCount: logs.length,
                          separatorBuilder: (_, _) => const Divider(height: 1),
                          itemBuilder: (context, index) {
                            final log = logs[index];
                            final detail = log.detail.trim();
                            final subtitle = detail.isEmpty
                                ? _formatDateTime(log.timestamp)
                                : '${_formatDateTime(log.timestamp)}  •  $detail';
                            return ListTile(
                              dense: true,
                              title: Text(log.event),
                              subtitle: Text(
                                subtitle,
                                maxLines: 2,
                                overflow: TextOverflow.ellipsis,
                              ),
                            );
                          },
                        ),
                ),
              ],
            ),
          );
        },
      ),
    );
  }

  String _formatRemaining(ProactiveDebugSnapshot snapshot) {
    if (snapshot.paused) {
      final pausedRemaining = snapshot.remainingDuration;
      if (pausedRemaining == null) {
        return 'paused';
      }
      return 'paused (${_formatDuration(pausedRemaining)})';
    }

    final nextTriggerAt = snapshot.nextTriggerAt;
    if (nextTriggerAt != null) {
      final remaining = nextTriggerAt.difference(DateTime.now());
      if (remaining.isNegative) {
        return '00:00:00';
      }
      return _formatDuration(remaining);
    }

    final fallback = snapshot.remainingDuration;
    if (fallback == null) {
      return '-';
    }
    return _formatDuration(fallback);
  }

  String _formatDuration(Duration duration) {
    final totalSeconds = duration.inSeconds;
    final hours = (totalSeconds ~/ 3600).toString().padLeft(2, '0');
    final minutes = ((totalSeconds % 3600) ~/ 60).toString().padLeft(2, '0');
    final seconds = (totalSeconds % 60).toString().padLeft(2, '0');
    return '$hours:$minutes:$seconds';
  }

  String _formatDateTime(DateTime? value) {
    if (value == null) {
      return '-';
    }
    final local = value.toLocal();
    final month = local.month.toString().padLeft(2, '0');
    final day = local.day.toString().padLeft(2, '0');
    final hour = local.hour.toString().padLeft(2, '0');
    final minute = local.minute.toString().padLeft(2, '0');
    final second = local.second.toString().padLeft(2, '0');
    return '${local.year}-$month-$day $hour:$minute:$second';
  }
}

class _DebugRow extends StatelessWidget {
  const _DebugRow({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 2),
      child: Row(
        children: [
          SizedBox(width: 96, child: Text(label)),
          Expanded(
            child: Text(
              value,
              textAlign: TextAlign.right,
            ),
          ),
        ],
      ),
    );
  }
}
