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
  final Map<String, ProactiveDurationRange> ranges;

  const ProactiveConfig(this.ranges);
}

class ProactiveConfigParser {
  static const Set<String> supportedKeys = {
    'overlayon',
    'overlayoff',
    'screenlandscape',
    'screenoff',
  };

  static ProactiveConfig parse(String raw) {
    final ranges = <String, ProactiveDurationRange>{};
    final lines = raw.split('\n');

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
        throw ProactiveConfigParseException(
          '라인 ${i + 1}: 최대 간격은 최소보다 커야 합니다.',
        );
      }
      ranges[key] = ProactiveDurationRange(minDuration, maxDuration);
    }

    return ProactiveConfig(ranges);
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
