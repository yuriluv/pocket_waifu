import 'dart:convert';
import 'dart:io';

const Set<String> _failureCategories = {
  'code',
  'environment',
  'data',
  'procedure',
};

const List<String> _requiredEvidenceKeys = [
  'executionLog',
  'testReport',
  'mainPush',
  'codeDiff',
  'followUpTask',
];

void main(List<String> args) {
  final strictAgentRecommendation = args.contains('--strict-agents');
  String? inputPath;
  for (final arg in args) {
    if (!arg.startsWith('--')) {
      inputPath = arg;
      break;
    }
  }

  if (inputPath == null) {
    stderr.writeln(
      'Usage: dart run tool/qa/check_request2_autopilot.dart <status.json> [--strict-agents]',
    );
    exit(64);
  }

  final inputFile = File(inputPath);
  if (!inputFile.existsSync()) {
    stderr.writeln('Input file not found: $inputPath');
    exit(66);
  }

  final rawContent = inputFile.readAsStringSync();
  final dynamic decoded;
  try {
    decoded = jsonDecode(rawContent);
  } catch (error) {
    stderr.writeln('Invalid JSON: $error');
    exit(65);
  }

  if (decoded is! Map<String, dynamic>) {
    stderr.writeln('Top-level JSON must be an object.');
    exit(65);
  }

  final result = validateAutopilotStatus(
    decoded,
    strictAgentRecommendation: strictAgentRecommendation,
  );

  stdout.writeln('Request2 autopilot QA gate report');
  stdout.writeln('- errors: ${result.errors.length}');
  stdout.writeln('- warnings: ${result.warnings.length}');

  for (final error in result.errors) {
    stdout.writeln('  [error] $error');
  }
  for (final warning in result.warnings) {
    stdout.writeln('  [warn] $warning');
  }

  if (result.errors.isNotEmpty) {
    stderr.writeln('QA gate failed.');
    exit(1);
  }
}

ValidationResult validateAutopilotStatus(
  Map<String, dynamic> payload, {
  bool strictAgentRecommendation = false,
}) {
  final errors = <String>[];
  final warnings = <String>[];

  final cycle = _asMap(payload['cycle']);
  final part1 = _asMap(payload['part1']);
  final part2 = _asMap(payload['part2']);
  final agents = _asMap(payload['agents']);
  final evidence = _asMap(payload['evidence']);

  if (cycle == null) {
    errors.add('Missing cycle object.');
  }
  if (part1 == null) {
    errors.add('Missing part1 object.');
  }
  if (part2 == null) {
    errors.add('Missing part2 object.');
  }
  if (agents == null) {
    errors.add('Missing agents object.');
  }
  if (evidence == null) {
    errors.add('Missing evidence object.');
  }

  final cycleStartedAt = _parseDateTime(cycle?['startedAt'], 'cycle.startedAt', errors);
  final cycleCheckedAt = _parseDateTime(cycle?['checkedAt'], 'cycle.checkedAt', errors);
  if (cycleStartedAt != null &&
      cycleCheckedAt != null &&
      cycleCheckedAt.isBefore(cycleStartedAt)) {
    errors.add('cycle.checkedAt must be after or equal to cycle.startedAt.');
  }

  final activeCount = _asInt(agents?['activeCount']);
  if (activeCount == null) {
    errors.add('agents.activeCount must be an integer.');
  } else {
    if (activeCount < 2) {
      errors.add('At least 2 agents must be active in parallel.');
    }
    if (activeCount < 3) {
      final message = '3+ agents are recommended; current activeCount=$activeCount.';
      if (strictAgentRecommendation) {
        errors.add(message);
      } else {
        warnings.add(message);
      }
    }
  }

  final part1Status = _asString(part1?['status']);
  if (part1Status == null || part1Status.isEmpty) {
    errors.add('part1.status is required.');
  } else {
    final isPart1Completed = part1Status.toLowerCase() == 'completed';
    if (!isPart1Completed) {
      final priority = _asString(part1?['priority'])?.toLowerCase();
      if (priority != 'highest') {
        errors.add('Part1 incomplete state requires part1.priority to be highest.');
      }
    } else {
      final loopActive = part2?['loopActive'];
      if (loopActive != true) {
        errors.add('Part1 completed state requires part2.loopActive=true.');
      }
    }
  }

  final gate = _asMap(part1?['gate']);
  if (gate == null) {
    errors.add('part1.gate is required for automated judgment.');
  } else {
    final functionalPass = gate['functionalPass'] == true;
    final regressionFailures = _asInt(gate['regressionFailures']);
    final rerunSuccessStreak = _asInt(gate['rerunSuccessStreak']);

    if (regressionFailures == null) {
      errors.add('part1.gate.regressionFailures must be an integer.');
    }
    if (rerunSuccessStreak == null) {
      errors.add('part1.gate.rerunSuccessStreak must be an integer.');
    }

    final gatePassed =
        functionalPass &&
        (regressionFailures != null && regressionFailures == 0) &&
        (rerunSuccessStreak != null && rerunSuccessStreak >= 2);

    final reportedGatePassed = gate['passed'];
    if (reportedGatePassed is bool && reportedGatePassed != gatePassed) {
      errors.add(
        'part1.gate.passed does not match computed gate result (expected $gatePassed).',
      );
    }

    if (part1Status?.toLowerCase() == 'completed' && !gatePassed) {
      errors.add(
        'Part1 cannot be completed unless gate conditions pass (functionalPass=true, regressionFailures=0, rerunSuccessStreak>=2).',
      );
    }
  }

  final failures = _asList(payload['failures']);
  if (failures == null) {
    errors.add('failures must be a list.');
  } else {
    for (var i = 0; i < failures.length; i++) {
      final failure = _asMap(failures[i]);
      if (failure == null) {
        errors.add('failures[$i] must be an object.');
        continue;
      }

      final category = _asString(failure['category'])?.toLowerCase();
      if (category == null || !_failureCategories.contains(category)) {
        errors.add('failures[$i].category must be one of: ${_failureCategories.join(', ')}.');
      }

      final detectedAt = _parseDateTime(
        failure['detectedAt'],
        'failures[$i].detectedAt',
        errors,
      );
      final reproCapturedAt = _parseDateTime(
        failure['reproCapturedAt'],
        'failures[$i].reproCapturedAt',
        errors,
      );
      if (detectedAt != null && reproCapturedAt != null) {
        final delay = reproCapturedAt.difference(detectedAt).inMinutes;
        if (delay < 0) {
          errors.add('failures[$i].reproCapturedAt must not be earlier than detectedAt.');
        } else if (delay > 10) {
          errors.add('failures[$i] reproduction log capture exceeded 10 minutes.');
        }
      }
    }
  }

  if (evidence != null) {
    for (final key in _requiredEvidenceKeys) {
      final value = _asString(evidence[key]);
      if (value == null || value.isEmpty) {
        errors.add('evidence.$key is required and must be a non-empty string.');
      }
    }

    final mainPushBranch = _asString(evidence['mainPushBranch'])?.toLowerCase();
    if (mainPushBranch != 'main') {
      errors.add('evidence.mainPushBranch must be main.');
    }

    final mainPushCommit = _asString(evidence['mainPushCommit']);
    if (mainPushCommit == null || !RegExp(r'^[0-9a-fA-F]{7,40}$').hasMatch(mainPushCommit)) {
      errors.add('evidence.mainPushCommit must be a valid git SHA (7-40 hex chars).');
    }
  }

  final codeChanges = _asList(payload['codeChanges']);
  if (codeChanges == null || codeChanges.isEmpty) {
    errors.add('codeChanges must include at least one code artifact (document-only completion forbidden).');
  } else {
    var hasNonDocChange = false;
    for (var i = 0; i < codeChanges.length; i++) {
      final item = _asMap(codeChanges[i]);
      if (item == null) {
        errors.add('codeChanges[$i] must be an object.');
        continue;
      }

      final path = _asString(item['path']);
      final commit = _asString(item['commit']);
      if (path == null || path.isEmpty) {
        errors.add('codeChanges[$i].path is required.');
      }
      if (commit == null || commit.isEmpty) {
        errors.add('codeChanges[$i].commit is required.');
      }
      if (path != null && !path.startsWith('docs/')) {
        hasNonDocChange = true;
      }
    }

    if (!hasNonDocChange) {
      errors.add('codeChanges cannot be docs-only. Include test/automation/script changes.');
    }
  }

  return ValidationResult(errors: errors, warnings: warnings);
}

DateTime? _parseDateTime(dynamic value, String fieldName, List<String> errors) {
  if (value is! String || value.isEmpty) {
    errors.add('$fieldName must be an ISO-8601 string.');
    return null;
  }

  final parsed = DateTime.tryParse(value);
  if (parsed == null) {
    errors.add('$fieldName must be a valid ISO-8601 timestamp.');
    return null;
  }
  return parsed;
}

Map<String, dynamic>? _asMap(dynamic value) {
  if (value is Map<String, dynamic>) {
    return value;
  }
  return null;
}

List<dynamic>? _asList(dynamic value) {
  if (value is List<dynamic>) {
    return value;
  }
  return null;
}

String? _asString(dynamic value) {
  if (value is String) {
    return value.trim();
  }
  return null;
}

int? _asInt(dynamic value) {
  if (value is int) {
    return value;
  }
  if (value is num) {
    return value.toInt();
  }
  return null;
}

class ValidationResult {
  final List<String> errors;
  final List<String> warnings;

  const ValidationResult({required this.errors, required this.warnings});
}
