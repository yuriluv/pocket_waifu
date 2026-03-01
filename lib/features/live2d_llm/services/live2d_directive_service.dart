import 'dart:async';

import 'package:flutter/foundation.dart';

import '../../live2d/data/services/live2d_native_bridge.dart';
import '../models/live2d_emotion_preset.dart';
import 'live2d_command_queue.dart';

class Live2DDirectiveResult {
  const Live2DDirectiveResult({
    required this.cleanedText,
    required this.errors,
  });

  final String cleanedText;
  final List<String> errors;
}

class Live2DDirectiveService {
  Live2DDirectiveService._();

  static final Live2DDirectiveService instance = Live2DDirectiveService._();

  final Live2DNativeBridge _bridge = Live2DNativeBridge();
  final Live2DCommandQueue _queue = Live2DCommandQueue.instance;

  final Map<String, Live2DEmotionPreset> _defaultEmotions = {
    'happy': const Live2DEmotionPreset(
      name: 'happy',
      params: {
        'ParamEyeLSmile': 1.0,
        'ParamEyeRSmile': 1.0,
        'ParamMouthForm': 1.0,
      },
      transitionDurationMs: 300,
    ),
    'sad': const Live2DEmotionPreset(
      name: 'sad',
      params: {
        'ParamMouthForm': -0.5,
        'ParamBrowLY': -0.4,
        'ParamBrowRY': -0.4,
      },
      transitionDurationMs: 400,
    ),
    'angry': const Live2DEmotionPreset(
      name: 'angry',
      params: {'ParamBrowLY': -0.7, 'ParamBrowRY': -0.7},
      transitionDurationMs: 200,
    ),
    'surprised': const Live2DEmotionPreset(
      name: 'surprised',
      params: {
        'ParamEyeLOpen': 1.0,
        'ParamEyeROpen': 1.0,
        'ParamMouthOpenY': 1.0,
      },
      transitionDurationMs: 150,
    ),
    'neutral': const Live2DEmotionPreset(name: 'neutral'),
  };

  String _streamBuffer = '';

  Future<Live2DDirectiveResult> processAssistantOutput(
    String text, {
    bool parsingEnabled = true,
  }) async {
    if (!parsingEnabled) {
      return Live2DDirectiveResult(cleanedText: text, errors: const []);
    }

    final errors = <String>[];
    final regex = RegExp(r'<live2d>([\s\S]*?)</live2d>', caseSensitive: false);
    final matches = regex.allMatches(text).toList();
    final inlineMatches = _inlineDirectiveRegex.allMatches(text).toList();

    if (matches.isEmpty && inlineMatches.isEmpty) {
      return Live2DDirectiveResult(cleanedText: text, errors: errors);
    }

    for (final match in matches) {
      final block = match.group(1) ?? '';
      try {
        await _queue.enqueue(() => _executeDirectiveBlock(block));
      } catch (e) {
        errors.add(e.toString());
      }
    }

    for (final match in inlineMatches) {
      final tag = (match.group(1) ?? '').toLowerCase();
      final attrs = _parseInlineAttributes(match.group(2) ?? '');
      try {
        await _queue.enqueue(() => _executeSingleDirective(tag, attrs));
      } catch (e) {
        errors.add(e.toString());
      }
    }

    final cleaned = text
        .replaceAll(regex, '')
        .replaceAll(_inlineDirectiveRegex, '')
        .trim();
    return Live2DDirectiveResult(cleanedText: cleaned, errors: errors);
  }

  Future<Live2DDirectiveResult> pushStreamChunk(
    String chunk, {
    bool parsingEnabled = true,
  }) async {
    _streamBuffer += chunk;
    final raw = _streamBuffer;
    final start = raw.lastIndexOf('<live2d>');
    final end = raw.lastIndexOf('</live2d>');

    if (!parsingEnabled || start == -1 || end == -1 || end < start) {
      return Live2DDirectiveResult(cleanedText: raw, errors: const []);
    }

    final consumable = raw.substring(0, end + '</live2d>'.length);
    final remaining = raw.substring(end + '</live2d>'.length);

    final result = await processAssistantOutput(
      consumable,
      parsingEnabled: parsingEnabled,
    );

    _streamBuffer = remaining;

    return Live2DDirectiveResult(
      cleanedText: result.cleanedText + remaining,
      errors: result.errors,
    );
  }

  void resetStreamBuffer() {
    _streamBuffer = '';
    _queue.reset();
  }

  static final RegExp _inlineDirectiveRegex = RegExp(
    r'\[(param|motion|expression|emotion):([^\]]+)\]',
    caseSensitive: false,
  );

  Future<void> _executeDirectiveBlock(String block) async {
    final commandRegex = RegExp(
      r'<(param|motion|expression|emotion)\s+([^/>]*)/>',
    );
    final matches = commandRegex.allMatches(block).toList();

    for (final match in matches) {
      final tag = match.group(1)?.toLowerCase();
      final attrs = _parseAttributes(match.group(2) ?? '');
      await _executeSingleDirective(tag, attrs);
    }
  }

  Future<void> _executeSingleDirective(
    String? tag,
    Map<String, String> attrs,
  ) async {
    final delay = int.tryParse(attrs['delay'] ?? '') ?? 0;
    if (delay > 0) {
      await Future<void>.delayed(Duration(milliseconds: delay));
    }

    switch (tag) {
      case 'param':
        await _runParam(attrs);
        break;
      case 'motion':
        await _runMotion(attrs);
        break;
      case 'expression':
        await _runExpression(attrs);
        break;
      case 'emotion':
        await _runEmotion(attrs);
        break;
      default:
        break;
    }
  }

  Map<String, String> _parseAttributes(String attrs) {
    final out = <String, String>{};
    final regex = RegExp(r'(\w+)\s*=\s*"([^"]*)"');
    for (final match in regex.allMatches(attrs)) {
      final key = match.group(1);
      final value = match.group(2);
      if (key != null && value != null) {
        out[key] = value;
      }
    }
    return out;
  }

  Map<String, String> _parseInlineAttributes(String attrs) {
    final out = <String, String>{};
    final parts = attrs.split(',');
    for (final part in parts) {
      final index = part.indexOf('=');
      if (index <= 0) {
        continue;
      }
      final key = part.substring(0, index).trim();
      final value = part.substring(index + 1).trim();
      if (key.isNotEmpty && value.isNotEmpty) {
        out[key] = value;
      }
    }

    if (out.isEmpty) {
      final first = attrs.trim();
      if (first.isNotEmpty) {
        out['name'] = first;
      }
    }
    return out;
  }

  Future<void> _runParam(Map<String, String> attrs) async {
    final id = attrs['id'];
    final value = double.tryParse(attrs['value'] ?? '');
    if (id == null || value == null) return;
    final dur = int.tryParse(attrs['dur'] ?? '') ?? 200;
    await _bridge.setParameter(id, value, durationMs: dur);
  }

  Future<void> _runMotion(Map<String, String> attrs) async {
    final group = attrs['group'];
    final index = int.tryParse(attrs['index'] ?? '');
    if (group == null || index == null) return;
    final priority = int.tryParse(attrs['priority'] ?? '') ?? 2;
    await _bridge.playMotion(group, index, priority: priority);
  }

  Future<void> _runExpression(Map<String, String> attrs) async {
    final id = attrs['id'];
    if (id == null || id.isEmpty) return;
    await _bridge.setExpression(id);
  }

  Future<void> _runEmotion(Map<String, String> attrs) async {
    final name = attrs['name']?.toLowerCase();
    if (name == null || name.isEmpty) return;

    final preset = _defaultEmotions[name];
    if (preset == null) {
      debugPrint('Unknown emotion preset: $name');
      return;
    }

    for (final entry in preset.params.entries) {
      await _bridge.setParameter(
        entry.key,
        entry.value,
        durationMs: preset.transitionDurationMs,
      );
    }

    if (preset.expressionId != null && preset.expressionId!.isNotEmpty) {
      await _bridge.setExpression(preset.expressionId!);
    }

    if (preset.motionGroup != null && preset.motionIndex != null) {
      await _bridge.playMotion(preset.motionGroup!, preset.motionIndex!);
    }
  }
}
