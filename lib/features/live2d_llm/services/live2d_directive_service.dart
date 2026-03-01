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
  String _streamCommittedText = '';
  bool _parameterBoundsLoaded = false;
  final Map<String, _ParameterRange> _parameterBounds =
      <String, _ParameterRange>{};

  Future<Live2DDirectiveResult> processAssistantOutput(
    String text, {
    bool parsingEnabled = true,
    bool exposeRawDirectives = false,
  }) async {
    if (!parsingEnabled) {
      return Live2DDirectiveResult(
        cleanedText: _stripDirectivesOnly(text),
        errors: const [],
      );
    }

    final errors = <String>[];
    final luaExtracted = _extractLuaLive2DBlocks(text);
    final sourceText = luaExtracted.cleanedText;

    final regex = RegExp(r'<live2d>([\s\S]*?)</live2d>', caseSensitive: false);
    final matches = regex.allMatches(sourceText).toList();
    final inlineMatches = _inlineDirectiveRegex.allMatches(sourceText).toList();

    if (matches.isEmpty && inlineMatches.isEmpty) {
      return Live2DDirectiveResult(cleanedText: sourceText, errors: errors);
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

    final cleaned = exposeRawDirectives
        ? _renderDirectivesAsChips(sourceText)
        : sourceText.replaceAll(regex, '').replaceAll(_inlineDirectiveRegex, '').trim();
    return Live2DDirectiveResult(cleanedText: cleaned, errors: errors);
  }

  String _renderDirectivesAsChips(String text) {
    final xmlRegex = RegExp(r'<live2d>([\s\S]*?)</live2d>', caseSensitive: false);
    final withXml = text.replaceAllMapped(xmlRegex, (match) {
      final block = match.group(1) ?? '';
      final commandRegex = RegExp(
        r'<(param|motion|expression|emotion)\s+([^/>]*)/>',
      );
      final chips = <String>[];
      for (final cmd in commandRegex.allMatches(block)) {
        final tag = (cmd.group(1) ?? '').toLowerCase();
        final attrs = _parseAttributes(cmd.group(2) ?? '');
        chips.add('⟦${_formatChipTag(tag, attrs)}⟧');
      }
      return chips.join(' ');
    });

    final withInline = withXml.replaceAllMapped(_inlineDirectiveRegex, (match) {
      final tag = (match.group(1) ?? '').toLowerCase();
      final attrs = _parseInlineAttributes(match.group(2) ?? '');
      return '⟦${_formatChipTag(tag, attrs)}⟧';
    });
    return withInline.trim();
  }

  String _formatChipTag(String tag, Map<String, String> attrs) {
    switch (tag) {
      case 'motion':
        return 'motion:${attrs['name'] ?? '${attrs['group'] ?? '?'}:${attrs['index'] ?? '?'}'}';
      case 'expression':
        return 'expression:${attrs['name'] ?? attrs['id'] ?? '?'}';
      case 'emotion':
        return 'emotion:${attrs['name'] ?? '?'}';
      case 'param':
        if (attrs.containsKey('id') && attrs.containsKey('value')) {
          return 'param:${attrs['id']}=${attrs['value']}';
        }
        if (attrs.length == 1) {
          final entry = attrs.entries.first;
          return 'param:${entry.key}=${entry.value}';
        }
        return 'param:?';
      default:
        return tag;
    }
  }

  Future<Live2DDirectiveResult> pushStreamChunk(
    String chunk, {
    bool parsingEnabled = true,
  }) async {
    _streamBuffer += chunk;
    final raw = _streamBuffer;
    if (!parsingEnabled) {
      return Live2DDirectiveResult(
        cleanedText: _stripDirectivesOnly(raw),
        errors: const [],
      );
    }

    final start = raw.lastIndexOf('<live2d>');
    final end = raw.lastIndexOf('</live2d>');
    if (start != -1 && (end == -1 || end < start)) {
      return Live2DDirectiveResult(cleanedText: raw, errors: const []);
    }

    final safeInlineEnd = _findInlineSafeEnd(raw);
    if (safeInlineEnd <= 0) {
      return Live2DDirectiveResult(cleanedText: raw, errors: const []);
    }

    final consumable = raw.substring(0, safeInlineEnd);
    final remaining = raw.substring(safeInlineEnd);

    final result = await processAssistantOutput(
      consumable,
      parsingEnabled: parsingEnabled,
    );

    _streamBuffer = remaining;
    _streamCommittedText += result.cleanedText;

    return Live2DDirectiveResult(
      cleanedText: _streamCommittedText + remaining,
      errors: result.errors,
    );
  }

  int _findInlineSafeEnd(String text) {
    final lastOpen = text.lastIndexOf('[');
    final lastClose = text.lastIndexOf(']');
    if (lastOpen != -1 && lastOpen > lastClose) {
      final pendingLength = text.length - lastOpen;
      if (pendingLength > 100) {
        return text.length;
      }
      return lastOpen;
    }
    return text.length;
  }

  void resetStreamBuffer() {
    _streamBuffer = '';
    _streamCommittedText = '';
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

  String _stripDirectivesOnly(String text) {
    final luaExtracted = _extractLuaLive2DBlocks(text);
    final regex = RegExp(r'<live2d>([\s\S]*?)</live2d>', caseSensitive: false);
    return luaExtracted.cleanedText
        .replaceAll(regex, '')
        .replaceAll(_inlineDirectiveRegex, '')
        .trim();
  }

  _LuaBlockExtraction _extractLuaLive2DBlocks(String text) {
    final regex = RegExp(r'```lua-live2d\s*([\s\S]*?)```', caseSensitive: false);
    final scripts = <String>[];
    final cleaned = text.replaceAllMapped(regex, (match) {
      final script = (match.group(1) ?? '').trim();
      if (script.isNotEmpty) {
        scripts.add(script);
      }
      return '';
    });
    return _LuaBlockExtraction(cleanedText: cleaned, scripts: scripts);
  }

  Future<void> _ensureParameterBoundsLoaded() async {
    if (_parameterBoundsLoaded) {
      return;
    }
    _parameterBoundsLoaded = true;

    final modelInfo = await _bridge.getModelInfo();
    final rawParams = modelInfo['parameters'];
    if (rawParams is! List) {
      return;
    }

    for (final raw in rawParams) {
      if (raw is! Map) {
        continue;
      }
      final map = Map<String, dynamic>.from(raw);
      final id = (map['id'] ?? map['Id'])?.toString();
      final min = _toDouble(map['min'] ?? map['Min']);
      final max = _toDouble(map['max'] ?? map['Max']);
      if (id == null || id.isEmpty || min == null || max == null) {
        continue;
      }
      _parameterBounds[id] = _ParameterRange(min: min, max: max);
    }
  }

  double? _toDouble(dynamic value) {
    if (value is num) {
      return value.toDouble();
    }
    if (value is String) {
      return double.tryParse(value);
    }
    return null;
  }

  Future<void> _runParam(Map<String, String> attrs) async {
    var id = attrs['id'];
    var value = double.tryParse(attrs['value'] ?? '');

    if ((id == null || value == null) && attrs.length == 1) {
      final entry = attrs.entries.first;
      id = entry.key;
      value = double.tryParse(entry.value);
    }

    if (id == null || value == null) return;

    await _ensureParameterBoundsLoaded();
    var clamped = value;
    final range = _parameterBounds[id];
    if (range != null) {
      final bounded = value.clamp(range.min, range.max).toDouble();
      if ((bounded - value).abs() > 0.00001) {
        debugPrint(
          '[Live2DDirectiveService] Param $id out of range ($value), clamped to $bounded',
        );
      }
      clamped = bounded;
    }

    final dur = int.tryParse(attrs['dur'] ?? '') ?? 200;
    final ok = await _bridge.setParameter(id, clamped, durationMs: dur);
    if (!ok) {
      debugPrint('[Live2DDirectiveService] Unknown parameter: $id');
    }
  }

  Future<void> _runMotion(Map<String, String> attrs) async {
    var group = attrs['group'];
    var index = int.tryParse(attrs['index'] ?? '');
    final name = attrs['name'];
    if ((group == null || index == null) && name != null && name.contains('/')) {
      final split = name.split('/');
      if (split.length == 2) {
        group = split.first;
        index = int.tryParse(split.last);
      }
    }

    if (group == null || index == null) return;
    final priority = int.tryParse(attrs['priority'] ?? '') ?? 2;
    final ok = await _bridge.playMotion(group, index, priority: priority);
    if (!ok) {
      debugPrint('[Live2DDirectiveService] Motion not found: $group/$index');
    }
  }

  Future<void> _runExpression(Map<String, String> attrs) async {
    final id = attrs['id'] ?? attrs['name'];
    if (id == null || id.isEmpty) return;
    final ok = await _bridge.setExpression(id);
    if (!ok) {
      debugPrint('[Live2DDirectiveService] Expression not found: $id');
    }
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

class _ParameterRange {
  const _ParameterRange({required this.min, required this.max});

  final double min;
  final double max;
}

class _LuaBlockExtraction {
  const _LuaBlockExtraction({required this.cleanedText, required this.scripts});

  final String cleanedText;
  final List<String> scripts;
}
