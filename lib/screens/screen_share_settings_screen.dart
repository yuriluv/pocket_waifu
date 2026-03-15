import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../models/message.dart';
import '../models/screen_share_settings.dart';
import '../providers/global_runtime_provider.dart';
import '../providers/screen_share_provider.dart';
import '../services/adb_screen_capture_service.dart';
import '../services/unified_capture_service.dart';

const List<int> _maxResolutionOptions = <int>[720, 1024, 1080, 1440];

class ScreenShareSettingsScreen extends StatelessWidget {
  const ScreenShareSettingsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<ScreenShareProvider>();
    final globalRuntimeProvider = context.watch<GlobalRuntimeProvider>();
    final masterEnabled = globalRuntimeProvider.isEnabled;
    final settings = provider.settings;
    final selectedMaxResolution = _maxResolutionOptions.contains(
      settings.maxResolution,
    )
        ? settings.maxResolution
        : 1080;

    return Scaffold(
      appBar: AppBar(title: const Text('Screenshot Settings')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          if (!masterEnabled)
            Container(
              margin: const EdgeInsets.only(bottom: 12),
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
              decoration: BoxDecoration(
                color: Theme.of(context).colorScheme.secondaryContainer,
                borderRadius: BorderRadius.circular(10),
              ),
              child: const Text(
                'All features are paused. Toggle Master Switch to resume.',
              ),
            ),
          Column(
            children: [
                  _SectionCard(
                    title: 'Screenshot Mode',
                    child: RadioGroup<ScreenshotMode>(
                      groupValue: settings.screenshotMode,
                      onChanged: (value) {
                        if (value != null) {
                          provider.setScreenshotMode(value);
                        }
                      },
                      child: Column(
                        children: [
                          RadioListTile<ScreenshotMode>(
                            contentPadding: EdgeInsets.zero,
                            title: const Text('Type 1 - 오버레이 포함'),
                            subtitle: const Text(
                              '현재 보이는 오버레이 객체를 함께 캡처합니다.',
                            ),
                            value: ScreenshotMode.includeOverlays,
                          ),
                          RadioListTile<ScreenshotMode>(
                            contentPadding: EdgeInsets.zero,
                            title: const Text('Type 2 - 오버레이 제외'),
                            subtitle: const Text(
                              '캡처 전에 오버레이를 잠시 숨기고 화면만 캡처합니다.',
                            ),
                            value: ScreenshotMode.excludeOverlays,
                          ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 12),
                  const _ShizukuConnectionSection(),
                  const SizedBox(height: 12),
                  _SectionCard(
                    title: 'Capture Settings',
                    child: Column(
                      children: [
                        SwitchListTile(
                          contentPadding: EdgeInsets.zero,
                          title: const Text('Enable screenshot capture'),
                          value: settings.enabled,
                          onChanged: provider.setEnabled,
                        ),
                        const SizedBox(height: 8),
                        Text('Capture interval: ${settings.captureInterval}s'),
                        Slider(
                          value: settings.captureInterval.toDouble(),
                          min: 5,
                          max: 600,
                          divisions: 119,
                          label: '${settings.captureInterval}s',
                          onChanged: (value) =>
                              provider.setCaptureInterval(value.round()),
                        ),
                        SwitchListTile(
                          contentPadding: EdgeInsets.zero,
                          title: const Text('Auto capture'),
                          value: settings.autoCapture,
                          onChanged: provider.setAutoCapture,
                        ),
                        ListTile(
                          contentPadding: EdgeInsets.zero,
                          title: const Text('Image quality'),
                          trailing: DropdownButton<ImageQuality>(
                            value: settings.imageQuality,
                            onChanged: (value) {
                              if (value != null) {
                                provider.setImageQuality(value);
                              }
                            },
                            items: ImageQuality.values
                                .map(
                                  (quality) => DropdownMenuItem(
                                    value: quality,
                                    child: Text(quality.name),
                                  ),
                                )
                                .toList(),
                          ),
                        ),
                        ListTile(
                          contentPadding: EdgeInsets.zero,
                          title: const Text('Max resolution'),
                          trailing: DropdownButton<int>(
                            value: selectedMaxResolution,
                            onChanged: (value) {
                              if (value != null) {
                                provider.setMaxResolution(value);
                              }
                            },
                            items: _maxResolutionOptions
                                .map(
                                  (size) => DropdownMenuItem(
                                    value: size,
                                    child: Text('${size}px'),
                                  ),
                                )
                                .toList(),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 12),
                  _SectionCard(
                    title: 'Privacy Notice',
                    child: const Text(
                      'Screenshots use ADB via Shizuku. '
                      'Nothing is captured unless you trigger capture.',
                    ),
                  ),
                  const SizedBox(height: 12),
                  const _SectionCard(
                    title: 'Screenshot Test',
                    child: _ScreenshotTestWidget(),
                  ),
            ],
          ),
        ],
      ),
    );
  }
}

class _ShizukuConnectionSection extends StatefulWidget {
  const _ShizukuConnectionSection();

  @override
  State<_ShizukuConnectionSection> createState() =>
      _ShizukuConnectionSectionState();
}

class _ShizukuConnectionSectionState extends State<_ShizukuConnectionSection> {
  final AdbScreenCaptureService _adbService = AdbScreenCaptureService();

  Future<void> _refresh() async {
    if (!mounted) return;
    setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    return _SectionCard(
      title: 'Shizuku Connection',
      child: FutureBuilder<Map<String, dynamic>>(
        future: _adbService.getConnectionStatus(),
        builder: (context, snapshot) {
          final status = snapshot.data ?? const <String, dynamic>{};
          final installed = status['installed'] == true;
          final running = status['running'] == true;
          final permission = status['permission'] == true;

          return Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _StatusRow(label: 'Shizuku 설치됨', ok: installed),
              _StatusRow(label: 'Shizuku 실행 중', ok: running),
              _StatusRow(label: '권한 허용됨', ok: permission),
              const SizedBox(height: 8),
              if (!installed)
                FilledButton(
                  onPressed: () async {
                    final provider = context.read<ScreenShareProvider>();
                    await _adbService.openShizukuPlayStore();
                    await provider.refreshConnectionStatus();
                    await _refresh();
                  },
                  child: const Text('Shizuku 설치'),
                ),
              if (installed && !running)
                OutlinedButton(
                  onPressed: () async {
                    final provider = context.read<ScreenShareProvider>();
                    await _adbService.openShizukuApp();
                    await provider.refreshConnectionStatus();
                    await _refresh();
                  },
                  child: const Text('Shizuku를 실행해 주세요'),
                ),
              if (running && !permission)
                FilledButton(
                  onPressed: () async {
                    await context.read<ScreenShareProvider>().requestPermission();
                    await _refresh();
                  },
                  child: const Text('권한 요청'),
                ),
            ],
          );
        },
      ),
    );
  }
}

class _StatusRow extends StatelessWidget {
  const _StatusRow({required this.label, required this.ok});

  final String label;
  final bool ok;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 2),
      child: Row(
        children: [
          Text(ok ? '✅' : '❌'),
          const SizedBox(width: 8),
          Text(label),
        ],
      ),
    );
  }
}

class _ScreenshotTestWidget extends StatefulWidget {
  const _ScreenshotTestWidget();

  @override
  State<_ScreenshotTestWidget> createState() => _ScreenshotTestWidgetState();
}

class _ScreenshotTestWidgetState extends State<_ScreenshotTestWidget> {
  final UnifiedCaptureService _unifiedService = UnifiedCaptureService();

  ImageAttachment? _lastCapture;
  bool _isCapturing = false;
  String? _errorMessage;
  DateTime? _captureTime;
  int? _captureDurationMs;

  Future<void> _doTestCapture() async {
    setState(() {
      _isCapturing = true;
      _errorMessage = null;
    });
    final stopwatch = Stopwatch()..start();
    try {
      final provider = context.read<ScreenShareProvider>();
      final settings = provider.settings;
      final hasPerm = await _unifiedService.hasPermission();
      if (!hasPerm) {
        final granted = await _unifiedService.requestPermission();
        if (!granted) {
          setState(() {
            _errorMessage = 'Shizuku 권한이 필요합니다.';
          });
          return;
        }
      }

      final image = await _unifiedService.capture(settings);
      stopwatch.stop();
      setState(() {
        _lastCapture = image;
        _captureTime = DateTime.now();
        _captureDurationMs = stopwatch.elapsedMilliseconds;
        if (image == null) {
          _errorMessage = '캡처 후 이미지가 null입니다.';
        }
      });
    } catch (e) {
      stopwatch.stop();
      setState(() {
        _errorMessage = '캡처 실패: $e';
        _captureDurationMs = stopwatch.elapsedMilliseconds;
      });
    } finally {
      setState(() {
        _isCapturing = false;
      });
    }
  }

  void _showFullScreenPreview() {
    if (_lastCapture == null) return;
    showDialog<void>(
      context: context,
      builder: (_) => Dialog.fullscreen(
        child: Stack(
          children: [
            InteractiveViewer(
              child: Center(
                child: Image.memory(
                  base64Decode(_lastCapture!.base64Data),
                  fit: BoxFit.contain,
                ),
              ),
            ),
            Positioned(
              top: 16,
              right: 16,
              child: IconButton(
                icon: const Icon(Icons.close, color: Colors.white),
                onPressed: () => Navigator.pop(context),
              ),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        FilledButton.icon(
          icon: _isCapturing
              ? const SizedBox(
                  width: 16,
                  height: 16,
                  child: CircularProgressIndicator(strokeWidth: 2),
                )
              : const Icon(Icons.camera_alt),
          label: Text(_isCapturing ? '캡처 중...' : '스크린샷 테스트'),
          onPressed: _isCapturing ? null : _doTestCapture,
        ),
        const SizedBox(height: 8),
        if (_lastCapture != null || _errorMessage != null)
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: _errorMessage != null
                  ? Colors.red.withValues(alpha: 0.1)
                  : Colors.green.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (_errorMessage != null)
                  Text('❌ $_errorMessage', style: const TextStyle(color: Colors.red)),
                if (_lastCapture != null) ...[
                  const Text('✅ 캡처 성공'),
                  Text('해상도: ${_lastCapture!.width} × ${_lastCapture!.height}'),
                  Text('형식: ${_lastCapture!.mimeType}'),
                  Text(
                    '데이터 크기: ${(_lastCapture!.base64Data.length * 3 / 4 / 1024).toStringAsFixed(1)} KB',
                  ),
                ],
                if (_captureDurationMs != null) Text('소요 시간: ${_captureDurationMs}ms'),
                if (_captureTime != null)
                  Text('시각: ${_captureTime!.toIso8601String().substring(11, 19)}'),
              ],
            ),
          ),
        if (_lastCapture != null && _lastCapture!.thumbnailPath != null)
          GestureDetector(
            onTap: _showFullScreenPreview,
            child: Container(
              margin: const EdgeInsets.only(top: 8),
              constraints: const BoxConstraints(maxHeight: 200),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(8),
                child: Image.file(
                  File(_lastCapture!.thumbnailPath!),
                  fit: BoxFit.contain,
                ),
              ),
            ),
          ),
      ],
    );
  }
}

class _SectionCard extends StatelessWidget {
  final String title;
  final Widget child;

  const _SectionCard({required this.title, required this.child});

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              title,
              style: Theme.of(
                context,
              ).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w700),
            ),
            const SizedBox(height: 8),
            child,
          ],
        ),
      ),
    );
  }
}
