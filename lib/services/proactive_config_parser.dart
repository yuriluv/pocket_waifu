import 'dart:math';

class ProactiveConfigParseException implements Exception {
  ProactiveConfigParseException(this.message);
  final String message;

  @override
  String toString() => message;
}

class ProactiveDurationRange {
  final Duration min;
  final Duration max;

  const ProactiveDurationRange(this.min, this.max);

  Duration pick(Random random) {
    if (max <= min) return min;
    final diff = max.inMilliseconds - min.inMilliseconds;
    final offset = random.nextInt(diff + 1);
    return min + Duration(milliseconds: offset);
  }
}

class ProactiveConfig {
  final Duration? baseInterval;
  final int deviationPercent;
  final Map<String, Duration?> additiveAdjustments;
  final Map<String, ProactiveDurationRange> ranges;

  const ProactiveConfig.legacy(this.ranges)
    : baseInterval = null,
      deviationPercent = 0,
      additiveAdjustments = const {};

  const ProactiveConfig.additive({
    required this.baseInterval,
    required this.deviationPercent,
    required this.additiveAdjustments,
  }) : ranges = const {};

  bool get isAdditive => baseInterval != null;
}

class ProactiveConfigParser {
  static const Set<String> supportedKeys = {
    'overlayon',
    'overlayoff',
    'screenlandscape',
    'screenoff',
  };

  static ProactiveConfig parse(String raw) {
    final trimmedLines = raw
        .split('\n')
        .map((line) => line.trim())
        .where((line) => line.isNotEmpty)
        .toList();

    final hasAdditiveKey = trimmedLines.any(
      (line) => line.startsWith('base=') || line.startsWith('deviation='),
    );

    if (hasAdditiveKey) {
      return _parseAdditive(trimmedLines);
    }

    return _parseLegacy(trimmedLines);
  }

  static ProactiveConfig _parseAdditive(List<String> lines) {
    final keyToLine = <String, int>{};
    final values = <String, String>{};

    for (var i = 0; i < lines.length; i++) {
      final line = lines[i];
      if (line.contains(' ')) {
        throw ProactiveConfigParseException('라인 ${i + 1}: 공백이 포함되어 있습니다.');
      }
      final parts = line.split('=');
      if (parts.length != 2) {
        throw ProactiveConfigParseException('라인 ${i + 1}: 형식이 잘못되었습니다.');
      }
      final key = parts[0];
      final value = parts[1];
      values[key] = value;
      keyToLine[key] = i + 1;
    }

    if (!values.containsKey('base')) {
      throw ProactiveConfigParseException('base 키가 필요합니다.');
    }

    final baseLine = keyToLine['base']!;
    final base = _parseDuration(values['base']!, baseLine);
    if (base <= Duration.zero) {
      throw ProactiveConfigParseException('라인 $baseLine: base는 0보다 커야 합니다.');
    }

    var deviationPercent = 0;
    if (values.containsKey('deviation')) {
      final deviationLine = keyToLine['deviation']!;
      deviationPercent = int.tryParse(values['deviation']!) ?? -1;
      if (deviationPercent < 0 || deviationPercent > 100) {
        throw ProactiveConfigParseException(
          '라인 $deviationLine: deviation은 0~100 정수여야 합니다.',
        );
      }
    }

    final adjustments = <String, Duration?>{};
    for (final key in supportedKeys) {
      if (!values.containsKey(key)) continue;
      final line = keyToLine[key]!;
      final value = values[key]!;
      if (value == 'inf') {
        adjustments[key] = null;
        continue;
      }
      adjustments[key] = _parseSignedDuration(value, line);
    }

    var minimumPossibleMs = base.inMilliseconds;
    for (final value in adjustments.values) {
      if (value != null && value.isNegative) {
        minimumPossibleMs += value.inMilliseconds;
      }
    }
    if (minimumPossibleMs <= 0) {
      throw ProactiveConfigParseException('base에 음수 보정을 합산한 최소값은 0보다 커야 합니다.');
    }

    return ProactiveConfig.additive(
      baseInterval: base,
      deviationPercent: deviationPercent,
      additiveAdjustments: adjustments,
    );
  }

  static ProactiveConfig _parseLegacy(List<String> lines) {
    final ranges = <String, ProactiveDurationRange>{};

    for (int i = 0; i < lines.length; i++) {
      final line = lines[i].trim();
      if (line.isEmpty) continue;
      if (line.contains(' ')) {
        throw ProactiveConfigParseException('라인 ${i + 1}: 공백이 포함되어 있습니다.');
      }
      final parts = line.split('=');
      if (parts.length != 2) {
        throw ProactiveConfigParseException('라인 ${i + 1}: 형식이 잘못되었습니다.');
      }
      final key = parts[0];
      final value = parts[1];
      if (!supportedKeys.contains(key)) {
        throw ProactiveConfigParseException('라인 ${i + 1}: 지원하지 않는 키입니다.');
      }
      if (value == '0') {
        continue;
      }
      final rangeParts = value.split('~');
      if (rangeParts.length != 2) {
        throw ProactiveConfigParseException('라인 ${i + 1}: 구간 형식이 잘못되었습니다.');
      }
      final minDuration = _parseDuration(rangeParts[0], i + 1);
      final maxDuration = _parseDuration(rangeParts[1], i + 1);
      if (minDuration.inSeconds <= 10) {
        throw ProactiveConfigParseException(
          '라인 ${i + 1}: 최소 간격은 10초보다 커야 합니다.',
        );
      }
      if (maxDuration < minDuration) {
        throw ProactiveConfigParseException('라인 ${i + 1}: 최대 간격은 최소보다 커야 합니다.');
      }
      ranges[key] = ProactiveDurationRange(minDuration, maxDuration);
    }

    return ProactiveConfig.legacy(ranges);
  }

  static Duration _parseSignedDuration(String input, int line) {
    if (input.isEmpty) {
      throw ProactiveConfigParseException('라인 $line: 시간 값이 비어 있습니다.');
    }
    var sign = 1;
    var raw = input;
    if (input.startsWith('+')) {
      raw = input.substring(1);
    } else if (input.startsWith('-')) {
      raw = input.substring(1);
      sign = -1;
    }
    final value = _parseDuration(raw, line);
    return Duration(milliseconds: sign * value.inMilliseconds);
  }

  static Duration _parseDuration(String input, int line) {
    if (input.isEmpty) {
      throw ProactiveConfigParseException('라인 $line: 시간 값이 비어 있습니다.');
    }

    final matches = RegExp(r'([0-9]+)([hms])').allMatches(input);
    if (matches.isEmpty) {
      throw ProactiveConfigParseException('라인 $line: 시간 형식이 잘못되었습니다.');
    }

    int totalSeconds = 0;
    int lastIndex = 0;
    for (final match in matches) {
      if (match.start != lastIndex) {
        throw ProactiveConfigParseException('라인 $line: 시간 형식이 잘못되었습니다.');
      }
      lastIndex = match.end;
      final value = int.parse(match.group(1)!);
      final unit = match.group(2);
      switch (unit) {
        case 'h':
          totalSeconds += value * 3600;
          break;
        case 'm':
          totalSeconds += value * 60;
          break;
        case 's':
          totalSeconds += value;
          break;
      }
    }

    if (lastIndex != input.length) {
      throw ProactiveConfigParseException('라인 $line: 시간 형식이 잘못되었습니다.');
    }

    return Duration(seconds: totalSeconds);
  }
}
