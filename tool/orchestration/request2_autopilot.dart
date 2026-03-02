import 'dart:async';
import 'dart:convert';
import 'dart:io';

enum _TaskPart {
  part1,
  part2,
}

enum _TaskStatus {
  pending,
  inProgress,
  blocked,
  done,
  failed,
}

enum _FailureCategory {
  code,
  environment,
  data,
  procedure,
  unknown,
}

class _Task {
  _Task({
    required this.id,
    required this.title,
    required this.part,
    required this.lane,
    required this.owner,
    required this.status,
    required this.priority,
    required this.updatedAt,
    List<String>? assignedAgents,
    this.retryCount = 0,
    this.blockedSince,
    this.failureReason,
    this.failureCategory,
    this.verificationPassed = false,
    this.codeMergedToMain = false,
    this.mainPushSha,
    List<String>? evidenceCommits,
  })  : assignedAgents = assignedAgents ?? <String>[],
        evidenceCommits = evidenceCommits ?? <String>[];

  final String id;
  final String title;
  final _TaskPart part;
  final String lane;
  final String owner;

  _TaskStatus status;
  int priority;
  int retryCount;
  DateTime updatedAt;
  DateTime? blockedSince;
  String? failureReason;
  _FailureCategory? failureCategory;
  bool verificationPassed;
  bool codeMergedToMain;
  String? mainPushSha;

  final List<String> assignedAgents;
  final List<String> evidenceCommits;

  bool get isPart1 => part == _TaskPart.part1;
  bool get isPart2 => part == _TaskPart.part2;
  bool get isOpen => status != _TaskStatus.done;

  bool get isActive =>
      status == _TaskStatus.inProgress || status == _TaskStatus.blocked;

  bool get isCompletionGateSatisfied {
    return status == _TaskStatus.done &&
        verificationPassed &&
        codeMergedToMain &&
        evidenceCommits.isNotEmpty;
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'title': title,
      'part': part.name,
      'lane': lane,
      'owner': owner,
      'status': status.name,
      'priority': priority,
      'retryCount': retryCount,
      'updatedAt': updatedAt.toIso8601String(),
      'blockedSince': blockedSince?.toIso8601String(),
      'failureReason': failureReason,
      'failureCategory': failureCategory?.name,
      'verificationPassed': verificationPassed,
      'codeMergedToMain': codeMergedToMain,
      'mainPushSha': mainPushSha,
      'assignedAgents': assignedAgents,
      'evidenceCommits': evidenceCommits,
    };
  }

  factory _Task.fromJson(Map<String, dynamic> json) {
    DateTime parseDate(dynamic value, DateTime fallback) {
      if (value is String) {
        final parsed = DateTime.tryParse(value);
        if (parsed != null) {
          return parsed.toUtc();
        }
      }
      return fallback;
    }

    DateTime? parseNullableDate(dynamic value) {
      if (value is String) {
        final parsed = DateTime.tryParse(value);
        return parsed?.toUtc();
      }
      return null;
    }

    _TaskPart parsePart(dynamic value) {
      if (value is String) {
        return _TaskPart.values.firstWhere(
          (entry) => entry.name == value,
          orElse: () => _TaskPart.part1,
        );
      }
      return _TaskPart.part1;
    }

    _TaskStatus parseStatus(dynamic value) {
      if (value is String) {
        return _TaskStatus.values.firstWhere(
          (entry) => entry.name == value,
          orElse: () => _TaskStatus.pending,
        );
      }
      return _TaskStatus.pending;
    }

    _FailureCategory? parseCategory(dynamic value) {
      if (value is String) {
        return _FailureCategory.values.firstWhere(
          (entry) => entry.name == value,
          orElse: () => _FailureCategory.unknown,
        );
      }
      return null;
    }

    final now = DateTime.now().toUtc();
    return _Task(
      id: (json['id'] as String?) ?? 'task-${now.millisecondsSinceEpoch}',
      title: (json['title'] as String?) ?? 'Untitled task',
      part: parsePart(json['part']),
      lane: (json['lane'] as String?) ?? 'implementation',
      owner: (json['owner'] as String?) ?? 'dev',
      status: parseStatus(json['status']),
      priority: (json['priority'] as int?) ?? 50,
      retryCount: (json['retryCount'] as int?) ?? 0,
      updatedAt: parseDate(json['updatedAt'], now),
      blockedSince: parseNullableDate(json['blockedSince']),
      failureReason: json['failureReason'] as String?,
      failureCategory: parseCategory(json['failureCategory']),
      verificationPassed: json['verificationPassed'] as bool? ?? false,
      codeMergedToMain: json['codeMergedToMain'] as bool? ?? false,
      mainPushSha: json['mainPushSha'] as String?,
      assignedAgents:
          (json['assignedAgents'] as List<dynamic>? ?? const <dynamic>[])
              .whereType<String>()
              .toList(),
      evidenceCommits:
          (json['evidenceCommits'] as List<dynamic>? ?? const <dynamic>[])
              .whereType<String>()
              .toList(),
    );
  }
}

class _AutopilotState {
  _AutopilotState({
    required this.schemaVersion,
    required this.createdAt,
    required this.tasks,
    required this.verificationCommands,
    required this.cycleHistory,
    this.lastCycleAt,
    this.part1CompletedAt,
    this.part2LoopCount = 0,
    this.nextAutoAgentIndex = 1,
  });

  final int schemaVersion;
  final DateTime createdAt;
  DateTime? lastCycleAt;
  DateTime? part1CompletedAt;
  int part2LoopCount;
  int nextAutoAgentIndex;

  final List<_Task> tasks;
  final List<String> verificationCommands;
  final List<Map<String, dynamic>> cycleHistory;

  List<_Task> get part1Tasks => tasks.where((task) => task.isPart1).toList();
  List<_Task> get part2Tasks => tasks.where((task) => task.isPart2).toList();

  bool get isPart1Complete => part1Tasks.isNotEmpty &&
      part1Tasks.every((task) => task.isCompletionGateSatisfied);

  Map<String, dynamic> toJson() {
    return {
      'schemaVersion': schemaVersion,
      'createdAt': createdAt.toIso8601String(),
      'lastCycleAt': lastCycleAt?.toIso8601String(),
      'part1CompletedAt': part1CompletedAt?.toIso8601String(),
      'part2LoopCount': part2LoopCount,
      'nextAutoAgentIndex': nextAutoAgentIndex,
      'verificationCommands': verificationCommands,
      'tasks': tasks.map((task) => task.toJson()).toList(),
      'cycleHistory': cycleHistory,
    };
  }

  factory _AutopilotState.bootstrap(DateTime now) {
    return _AutopilotState(
      schemaVersion: 1,
      createdAt: now,
      tasks: <_Task>[
        _Task(
          id: 'P1-DEV-CODEPATH',
          title: 'Part1 code path decomposition and ownership mapping',
          part: _TaskPart.part1,
          lane: 'implementation',
          owner: 'dev',
          status: _TaskStatus.inProgress,
          priority: 0,
          updatedAt: now,
          assignedAgents: <String>['dev-impl-1', 'dev-impl-2', 'dev-review-1'],
        ),
        _Task(
          id: 'P1-DEV-HOTFIX',
          title: 'Part1 bottleneck hotfix and rerun loop',
          part: _TaskPart.part1,
          lane: 'implementation',
          owner: 'dev',
          status: _TaskStatus.pending,
          priority: 1,
          updatedAt: now,
        ),
        _Task(
          id: 'P1-DEV-MAIN-GATE',
          title: 'Part1 code integration, verification, and main push gate',
          part: _TaskPart.part1,
          lane: 'operations',
          owner: 'dev',
          status: _TaskStatus.pending,
          priority: 2,
          updatedAt: now,
        ),
        _Task(
          id: 'P2-OPS-STABILIZE',
          title: 'Part2 stabilization optimization loop',
          part: _TaskPart.part2,
          lane: 'operations',
          owner: 'dev',
          status: _TaskStatus.pending,
          priority: 100,
          updatedAt: now,
        ),
        _Task(
          id: 'P2-OPS-ENHANCE',
          title: 'Part2 enhancement backlog execution loop',
          part: _TaskPart.part2,
          lane: 'operations',
          owner: 'dev',
          status: _TaskStatus.pending,
          priority: 101,
          updatedAt: now,
        ),
      ],
      verificationCommands: <String>[],
      cycleHistory: <Map<String, dynamic>>[],
    );
  }

  factory _AutopilotState.fromJson(Map<String, dynamic> json) {
    DateTime parseDate(dynamic value, DateTime fallback) {
      if (value is String) {
        final parsed = DateTime.tryParse(value);
        if (parsed != null) {
          return parsed.toUtc();
        }
      }
      return fallback;
    }

    DateTime? parseNullableDate(dynamic value) {
      if (value is String) {
        return DateTime.tryParse(value)?.toUtc();
      }
      return null;
    }

    final now = DateTime.now().toUtc();
    return _AutopilotState(
      schemaVersion: (json['schemaVersion'] as int?) ?? 1,
      createdAt: parseDate(json['createdAt'], now),
      lastCycleAt: parseNullableDate(json['lastCycleAt']),
      part1CompletedAt: parseNullableDate(json['part1CompletedAt']),
      part2LoopCount: (json['part2LoopCount'] as int?) ?? 0,
      nextAutoAgentIndex: (json['nextAutoAgentIndex'] as int?) ?? 1,
      tasks: (json['tasks'] as List<dynamic>? ?? const <dynamic>[])
          .whereType<Map>()
          .map((entry) => _Task.fromJson(Map<String, dynamic>.from(entry)))
          .toList(),
      verificationCommands:
          (json['verificationCommands'] as List<dynamic>? ?? const <dynamic>[])
              .whereType<String>()
              .toList(),
      cycleHistory: (json['cycleHistory'] as List<dynamic>? ?? const <dynamic>[])
          .whereType<Map>()
          .map((entry) => Map<String, dynamic>.from(entry))
          .toList(),
    );
  }
}

class _CycleAction {
  _CycleAction({
    required this.level,
    required this.code,
    required this.message,
    this.taskId,
  });

  final String level;
  final String code;
  final String message;
  final String? taskId;

  Map<String, dynamic> toJson() {
    return {
      'level': level,
      'code': code,
      'message': message,
      'taskId': taskId,
    };
  }
}

class _GitStatus {
  _GitStatus({
    required this.headSha,
    required this.hasOriginMain,
    required this.originMainSha,
    required this.headOnOriginMain,
    required this.workingTreeClean,
  });

  final String? headSha;
  final bool hasOriginMain;
  final String? originMainSha;
  final bool headOnOriginMain;
  final bool workingTreeClean;
}

class _CommandResult {
  _CommandResult({
    required this.exitCode,
    required this.stdout,
    required this.stderr,
  });

  final int exitCode;
  final String stdout;
  final String stderr;
}

class _CycleReport {
  _CycleReport({
    required this.timestamp,
    required this.mode,
    required this.actions,
    required this.gitStatus,
    required this.part1Open,
    required this.part2LoopCount,
    required this.activeAgentCount,
  });

  final DateTime timestamp;
  final String mode;
  final List<_CycleAction> actions;
  final _GitStatus gitStatus;
  final int part1Open;
  final int part2LoopCount;
  final int activeAgentCount;

  Map<String, dynamic> toJson() {
    return {
      'timestamp': timestamp.toIso8601String(),
      'mode': mode,
      'part1Open': part1Open,
      'part2LoopCount': part2LoopCount,
      'activeAgentCount': activeAgentCount,
      'gitStatus': {
        'headSha': gitStatus.headSha,
        'hasOriginMain': gitStatus.hasOriginMain,
        'originMainSha': gitStatus.originMainSha,
        'headOnOriginMain': gitStatus.headOnOriginMain,
        'workingTreeClean': gitStatus.workingTreeClean,
      },
      'actions': actions.map((action) => action.toJson()).toList(),
    };
  }
}

Future<void> main(List<String> args) async {
  final options = _CliOptions.parse(args);
  if (options.showHelp) {
    _printHelp();
    return;
  }

  final stateFile = File(options.statePath);
  final state = await _loadOrCreateState(stateFile);

  var cycle = 0;
  while (true) {
    cycle += 1;
    final report = await _runCycle(state);

    state.cycleHistory.add(report.toJson());
    if (state.cycleHistory.length > 120) {
      state.cycleHistory.removeRange(0, state.cycleHistory.length - 120);
    }

    await _saveState(stateFile, state);
    _printReport(report, stateFile.path, cycle);

    final shouldStop =
        options.runOnce || (options.maxCycles != null && cycle >= options.maxCycles!);
    if (shouldStop) {
      return;
    }

    await Future.delayed(Duration(minutes: options.intervalMinutes));
  }
}

Future<_AutopilotState> _loadOrCreateState(File stateFile) async {
  final now = DateTime.now().toUtc();
  if (!await stateFile.exists()) {
    final bootstrap = _AutopilotState.bootstrap(now);
    await _saveState(stateFile, bootstrap);
    return bootstrap;
  }

  final raw = await stateFile.readAsString();
  final decoded = jsonDecode(raw);
  if (decoded is! Map<String, dynamic>) {
    throw FormatException('Invalid state format: expected JSON object');
  }

  return _AutopilotState.fromJson(decoded);
}

Future<void> _saveState(File stateFile, _AutopilotState state) async {
  if (!await stateFile.parent.exists()) {
    await stateFile.parent.create(recursive: true);
  }
  final encoder = const JsonEncoder.withIndent('  ');
  await stateFile.writeAsString('${encoder.convert(state.toJson())}\n');
}

Future<_CycleReport> _runCycle(_AutopilotState state) async {
  final now = DateTime.now().toUtc();
  final actions = <_CycleAction>[];

  final part1Tasks = state.part1Tasks;
  final part1OpenTasks = part1Tasks.where((task) => task.status != _TaskStatus.done).toList();

  String mode;
  if (part1OpenTasks.isNotEmpty) {
    mode = 'PART1_PRIORITY';
    if (state.part1CompletedAt != null) {
      state.part1CompletedAt = null;
      actions.add(
        _CycleAction(
          level: 'warn',
          code: 'PART1_REOPENED',
          message: 'Part1 completion marker cleared because open tasks were detected.',
        ),
      );
    }
    _prioritizePart1(part1Tasks, state.part2Tasks, actions, now);
    _ensureMultiAgentCapacity(state, part1Tasks, actions, now);
    _escalateBlockedTasks(part1Tasks, actions, now);
  } else {
    mode = 'PART2_LOOP';
    if (state.part1CompletedAt == null) {
      state.part1CompletedAt = now;
      if (state.part2LoopCount == 0) {
        state.part2LoopCount = 1;
      }
      actions.add(
        _CycleAction(
          level: 'info',
          code: 'PART1_COMPLETE',
          message: 'Part1 completion gate reached. Part2 recurring loop activated.',
        ),
      );
    }
    _activatePart2Loop(state.part2Tasks, actions, now, state);
  }

  await _enforceEvidencePolicy(part1Tasks, actions, now);
  await _runVerificationIfNeeded(state, part1Tasks, actions, now);

  final gitStatus = await _collectGitStatus();
  _applyMainPushGate(state, part1Tasks, gitStatus, actions, now);

  state.lastCycleAt = now;

  final activeAgentCount = _collectActiveAgents(state.tasks).length;
  final part1Open = part1Tasks.where((task) => task.status != _TaskStatus.done).length;
  if (part1Open > 0 && mode != 'PART1_PRIORITY') {
    mode = 'PART1_PRIORITY';
    state.part1CompletedAt = null;
    actions.add(
      _CycleAction(
        level: 'warn',
        code: 'PART1_PRIORITY_RESTORED',
        message: 'Part1 gate reopened during validation; switched back to Part1 priority mode.',
      ),
    );
  }
  return _CycleReport(
    timestamp: now,
    mode: mode,
    actions: actions,
    gitStatus: gitStatus,
    part1Open: part1Open,
    part2LoopCount: state.part2LoopCount,
    activeAgentCount: activeAgentCount,
  );
}

void _prioritizePart1(
  List<_Task> part1Tasks,
  List<_Task> part2Tasks,
  List<_CycleAction> actions,
  DateTime now,
) {
  for (var index = 0; index < part1Tasks.length; index++) {
    final task = part1Tasks[index];
    final desiredPriority = index;
    if (task.priority != desiredPriority) {
      task.priority = desiredPriority;
      task.updatedAt = now;
      actions.add(
        _CycleAction(
          level: 'info',
          code: 'PART1_PRIORITY_PINNED',
          message: 'Pinned Part1 task priority: ${task.id} -> $desiredPriority',
          taskId: task.id,
        ),
      );
    }
  }

  for (var index = 0; index < part2Tasks.length; index++) {
    final task = part2Tasks[index];
    final desiredPriority = 100 + index;
    if (task.priority != desiredPriority) {
      task.priority = desiredPriority;
      task.updatedAt = now;
    }
  }
}

void _ensureMultiAgentCapacity(
  _AutopilotState state,
  List<_Task> part1Tasks,
  List<_CycleAction> actions,
  DateTime now,
) {
  final activeAgents = _collectActiveAgents(part1Tasks);
  const int minAgents = 2;
  const int recommendedAgents = 3;

  if (activeAgents.length < minAgents) {
    actions.add(
      _CycleAction(
        level: 'critical',
        code: 'AGENT_CAPACITY_MIN',
        message: 'Active agents below mandatory minimum ($minAgents). Auto-allocation started.',
      ),
    );
  }

  while (activeAgents.length < recommendedAgents) {
    final target = _pickAssignmentTarget(part1Tasks);
    if (target == null) {
      break;
    }

    final agent = 'auto-dev-agent-${state.nextAutoAgentIndex}';
    state.nextAutoAgentIndex += 1;
    target.assignedAgents.add(agent);
    if (target.status == _TaskStatus.pending) {
      target.status = _TaskStatus.inProgress;
    }
    target.updatedAt = now;
    activeAgents.add(agent);

    actions.add(
      _CycleAction(
        level: activeAgents.length < minAgents ? 'critical' : 'warn',
        code: 'AGENT_ASSIGNED',
        message: 'Assigned $agent to ${target.id} to satisfy concurrent multi-agent rule.',
        taskId: target.id,
      ),
    );
  }
}

Set<String> _collectActiveAgents(List<_Task> tasks) {
  final agents = <String>{};
  for (final task in tasks) {
    if (task.isActive) {
      agents.addAll(task.assignedAgents);
    }
  }
  return agents;
}

_Task? _pickAssignmentTarget(List<_Task> part1Tasks) {
  final sorted = List<_Task>.from(part1Tasks)
    ..sort((a, b) {
      final byPriority = a.priority.compareTo(b.priority);
      if (byPriority != 0) {
        return byPriority;
      }
      return a.updatedAt.compareTo(b.updatedAt);
    });

  for (final task in sorted) {
    if (task.status == _TaskStatus.pending || task.status == _TaskStatus.inProgress) {
      return task;
    }
  }

  for (final task in sorted) {
    if (task.status == _TaskStatus.blocked) {
      return task;
    }
  }

  return null;
}

void _escalateBlockedTasks(
  List<_Task> part1Tasks,
  List<_CycleAction> actions,
  DateTime now,
) {
  const escalationThreshold = Duration(minutes: 10);

  for (final task in part1Tasks) {
    if (task.status != _TaskStatus.blocked) {
      if (task.blockedSince != null) {
        task.blockedSince = null;
      }
      continue;
    }

    final blockedSince = task.blockedSince ?? now;
    task.blockedSince = blockedSince;
    final blockedDuration = now.difference(blockedSince);

    if (blockedDuration < escalationThreshold) {
      continue;
    }

    final reason = task.failureReason ?? 'blocked_timeout';
    final category = _classifyFailure(reason);

    task.failureCategory = category;
    task.retryCount += 1;
    task.status = _TaskStatus.inProgress;
    task.updatedAt = now;
    task.blockedSince = null;

    actions.add(
      _CycleAction(
        level: 'critical',
        code: 'BLOCKER_ESCALATED',
        message:
            'Escalated ${task.id} after ${blockedDuration.inMinutes}m block. category=${category.name}, retry=${task.retryCount}.',
        taskId: task.id,
      ),
    );
  }
}

void _activatePart2Loop(
  List<_Task> part2Tasks,
  List<_CycleAction> actions,
  DateTime now,
  _AutopilotState state,
) {
  if (part2Tasks.isEmpty) {
    return;
  }

  final allDone = part2Tasks.every((task) => task.status == _TaskStatus.done);
  if (allDone) {
    state.part2LoopCount += 1;
    for (final task in part2Tasks) {
      task.status = _TaskStatus.inProgress;
      task.updatedAt = now;
      task.verificationPassed = false;
      task.codeMergedToMain = false;
      task.mainPushSha = null;
    }
    actions.add(
      _CycleAction(
        level: 'info',
        code: 'PART2_LOOP_RESTART',
        message: 'Part2 loop #${state.part2LoopCount} restarted for iterative operation.',
      ),
    );
    return;
  }

  for (final task in part2Tasks) {
    if (task.status == _TaskStatus.pending) {
      task.status = _TaskStatus.inProgress;
      task.updatedAt = now;
      actions.add(
        _CycleAction(
          level: 'info',
          code: 'PART2_TASK_STARTED',
          message: 'Started ${task.id} in Part2 recurring loop.',
          taskId: task.id,
        ),
      );
    }
  }
}

Future<void> _enforceEvidencePolicy(
  List<_Task> part1Tasks,
  List<_CycleAction> actions,
  DateTime now,
) async {
  for (final task in part1Tasks) {
    if (task.status != _TaskStatus.done) {
      continue;
    }

    if (task.evidenceCommits.isEmpty) {
      task.status = _TaskStatus.inProgress;
      task.updatedAt = now;
      task.failureReason = 'missing_code_evidence';
      task.failureCategory = _FailureCategory.procedure;
      task.verificationPassed = false;
      actions.add(
        _CycleAction(
          level: 'critical',
          code: 'DOC_ONLY_GUARD',
          message: 'Task ${task.id} reopened: missing evidence commits (document-only completion blocked).',
          taskId: task.id,
        ),
      );
      continue;
    }

    var hasCodeDelta = false;
    for (final commit in task.evidenceCommits) {
      final changedFiles = await _changedFilesInCommit(commit);
      if (changedFiles.isEmpty) {
        continue;
      }

      final containsCodeChange = changedFiles.any((path) => !_isDocumentationPath(path));
      if (containsCodeChange) {
        hasCodeDelta = true;
        break;
      }
    }

    if (!hasCodeDelta) {
      task.status = _TaskStatus.inProgress;
      task.updatedAt = now;
      task.failureReason = 'docs_only_commit_detected';
      task.failureCategory = _FailureCategory.procedure;
      task.verificationPassed = false;
      actions.add(
        _CycleAction(
          level: 'critical',
          code: 'DOC_ONLY_GUARD',
          message:
              'Task ${task.id} reopened: evidence commits do not contain code changes.',
          taskId: task.id,
        ),
      );
    }
  }
}

Future<void> _runVerificationIfNeeded(
  _AutopilotState state,
  List<_Task> part1Tasks,
  List<_CycleAction> actions,
  DateTime now,
) async {
  final donePart1 = part1Tasks.where((task) => task.status == _TaskStatus.done).toList();
  if (donePart1.isEmpty) {
    return;
  }

  if (state.verificationCommands.isEmpty) {
    actions.add(
      _CycleAction(
        level: 'warn',
        code: 'VERIFY_CMD_MISSING',
        message:
            'Verification commands are empty; done Part1 tasks cannot pass completion gate.',
      ),
    );
    for (final task in donePart1) {
      task.verificationPassed = false;
      task.updatedAt = now;
    }
    return;
  }

  final failures = <String>[];
  for (final command in state.verificationCommands) {
    final result = await _runShell(command);
    if (result.exitCode != 0) {
      failures.add(command);
      actions.add(
        _CycleAction(
          level: 'critical',
          code: 'VERIFY_FAILED',
          message: 'Verification command failed: "$command"',
        ),
      );
    } else {
      actions.add(
        _CycleAction(
          level: 'info',
          code: 'VERIFY_PASSED',
          message: 'Verification command passed: "$command"',
        ),
      );
    }
  }

  final isSuccess = failures.isEmpty;
  for (final task in donePart1) {
    task.verificationPassed = isSuccess;
    task.updatedAt = now;

    if (!isSuccess) {
      task.status = _TaskStatus.inProgress;
      task.retryCount += 1;
      task.failureReason = 'verification_failed';
      task.failureCategory = _FailureCategory.code;
      actions.add(
        _CycleAction(
          level: 'critical',
          code: 'TASK_REOPEN_VERIFY',
          message: 'Task ${task.id} reopened due to failed verification commands.',
          taskId: task.id,
        ),
      );
    }
  }
}

Future<_GitStatus> _collectGitStatus() async {
  final head = await _runShell('git rev-parse HEAD');
  final headSha = head.exitCode == 0 ? head.stdout.trim() : null;

  final originMain = await _runShell('git rev-parse --verify origin/main');
  final hasOriginMain = originMain.exitCode == 0;
  final originMainSha = hasOriginMain ? originMain.stdout.trim() : null;

  var headOnOriginMain = false;
  if (headSha != null && originMainSha != null) {
    final merged = await Process.run(
      'git',
      <String>['merge-base', '--is-ancestor', headSha, originMainSha],
    );
    headOnOriginMain = merged.exitCode == 0;
  }

  final status = await _runShell('git status --porcelain');
  final workingTreeClean = status.exitCode == 0 && status.stdout.trim().isEmpty;

  return _GitStatus(
    headSha: headSha,
    hasOriginMain: hasOriginMain,
    originMainSha: originMainSha,
    headOnOriginMain: headOnOriginMain,
    workingTreeClean: workingTreeClean,
  );
}

void _applyMainPushGate(
  _AutopilotState state,
  List<_Task> part1Tasks,
  _GitStatus git,
  List<_CycleAction> actions,
  DateTime now,
) {
  final donePart1 = part1Tasks.where((task) => task.status == _TaskStatus.done).toList();
  if (donePart1.isEmpty) {
    return;
  }

  if (!git.workingTreeClean) {
    actions.add(
      _CycleAction(
        level: 'warn',
        code: 'DIRTY_WORKTREE',
        message: 'Working tree is dirty. completion gate remains open until commits are cleanly recorded.',
      ),
    );
  }

  if (!git.hasOriginMain) {
    for (final task in donePart1) {
      task.codeMergedToMain = false;
      task.mainPushSha = null;
      task.updatedAt = now;
    }
    _ensureFollowUpTask(
      state,
      id: 'FOLLOWUP-MAIN-PUSH',
      title: 'Configure/fetch origin main and confirm Part1 commits are pushed',
      now: now,
      actions: actions,
      reasonCode: 'MAIN_REF_MISSING',
      reasonMessage: 'origin/main not available. main push confirmation pending.',
    );
    return;
  }

  for (final task in donePart1) {
    task.codeMergedToMain = git.headOnOriginMain;
    task.mainPushSha = git.headOnOriginMain ? git.originMainSha : null;
    task.updatedAt = now;
  }

  if (!git.headOnOriginMain) {
    _ensureFollowUpTask(
      state,
      id: 'FOLLOWUP-MAIN-PUSH',
      title: 'Push/merge Part1 commits to main and re-run gate verification',
      now: now,
      actions: actions,
      reasonCode: 'MAIN_PUSH_PENDING',
      reasonMessage:
          'HEAD is not contained in origin/main. Follow-up created for push/merge confirmation.',
    );
  } else {
    final followUp = state.tasks.where((task) => task.id == 'FOLLOWUP-MAIN-PUSH');
    for (final task in followUp) {
      if (task.status != _TaskStatus.done) {
        task.status = _TaskStatus.done;
        task.updatedAt = now;
        task.verificationPassed = true;
        task.codeMergedToMain = true;
        task.mainPushSha = git.originMainSha;
      }
    }
    actions.add(
      _CycleAction(
        level: 'info',
        code: 'MAIN_PUSH_CONFIRMED',
        message: 'main push confirmed at ${git.originMainSha}.',
      ),
    );
  }
}

void _ensureFollowUpTask(
  _AutopilotState state, {
  required String id,
  required String title,
  required DateTime now,
  required List<_CycleAction> actions,
  required String reasonCode,
  required String reasonMessage,
}) {
  final existing = state.tasks.where((task) => task.id == id).toList();
  if (existing.isEmpty) {
    state.tasks.add(
      _Task(
        id: id,
        title: title,
        part: _TaskPart.part1,
        lane: 'operations',
        owner: 'dev',
        status: _TaskStatus.pending,
        priority: 3,
        updatedAt: now,
        assignedAgents: <String>['dev-ops-1'],
      ),
    );
    actions.add(
      _CycleAction(
        level: 'warn',
        code: reasonCode,
        message: reasonMessage,
        taskId: id,
      ),
    );
    return;
  }

  for (final task in existing) {
    if (task.status == _TaskStatus.done) {
      task.status = _TaskStatus.pending;
    }
    task.updatedAt = now;
  }

  actions.add(
    _CycleAction(
      level: 'warn',
      code: reasonCode,
      message: reasonMessage,
      taskId: id,
    ),
  );
}

_FailureCategory _classifyFailure(String reason) {
  final lowered = reason.toLowerCase();
  if (lowered.contains('null') ||
      lowered.contains('exception') ||
      lowered.contains('assert') ||
      lowered.contains('compile') ||
      lowered.contains('test')) {
    return _FailureCategory.code;
  }
  if (lowered.contains('permission') ||
      lowered.contains('timeout') ||
      lowered.contains('network') ||
      lowered.contains('sdk') ||
      lowered.contains('gradle')) {
    return _FailureCategory.environment;
  }
  if (lowered.contains('schema') ||
      lowered.contains('json') ||
      lowered.contains('parse') ||
      lowered.contains('data')) {
    return _FailureCategory.data;
  }
  if (lowered.contains('missing') ||
      lowered.contains('manual') ||
      lowered.contains('checklist') ||
      lowered.contains('docs')) {
    return _FailureCategory.procedure;
  }
  return _FailureCategory.unknown;
}

Future<List<String>> _changedFilesInCommit(String sha) async {
  final result = await Process.run(
    'git',
    <String>['show', '--pretty=format:', '--name-only', sha],
  );
  if (result.exitCode != 0) {
    return <String>[];
  }

  final output = (result.stdout as String?) ?? '';
  return output
      .split('\n')
      .map((line) => line.trim())
      .where((line) => line.isNotEmpty)
      .toList();
}

bool _isDocumentationPath(String path) {
  final normalized = path.trim().toLowerCase();
  if (normalized.startsWith('docs/')) {
    return true;
  }
  if (normalized.endsWith('.md') || normalized.endsWith('.txt')) {
    return true;
  }
  return false;
}

Future<_CommandResult> _runShell(String command) async {
  final result = await Process.run('bash', <String>['-lc', command]);
  return _CommandResult(
    exitCode: result.exitCode,
    stdout: (result.stdout as String?) ?? '',
    stderr: (result.stderr as String?) ?? '',
  );
}

void _printReport(_CycleReport report, String statePath, int cycle) {
  stdout.writeln('[request2-autopilot] cycle=$cycle ts=${report.timestamp.toIso8601String()} mode=${report.mode}');
  stdout.writeln('- state: $statePath');
  stdout.writeln('- part1_open_tasks: ${report.part1Open}');
  stdout.writeln('- active_agents: ${report.activeAgentCount}');
  stdout.writeln('- part2_loop_count: ${report.part2LoopCount}');
  stdout.writeln(
    '- git: head=${report.gitStatus.headSha ?? 'n/a'} originMain=${report.gitStatus.originMainSha ?? 'n/a'} '
    'headInMain=${report.gitStatus.headOnOriginMain} clean=${report.gitStatus.workingTreeClean}',
  );

  if (report.actions.isEmpty) {
    stdout.writeln('- actions: none');
  } else {
    stdout.writeln('- actions: ${report.actions.length}');
    for (final action in report.actions) {
      final taskSuffix = action.taskId == null ? '' : ' task=${action.taskId}';
      stdout.writeln('  [${action.level}] ${action.code}$taskSuffix :: ${action.message}');
    }
  }
}

class _CliOptions {
  _CliOptions({
    required this.statePath,
    required this.intervalMinutes,
    required this.runOnce,
    required this.maxCycles,
    required this.showHelp,
  });

  final String statePath;
  final int intervalMinutes;
  final bool runOnce;
  final int? maxCycles;
  final bool showHelp;

  static _CliOptions parse(List<String> args) {
    var statePath = '.autopilot/request2_state.json';
    var intervalMinutes = 30;
    var runOnce = false;
    int? maxCycles;
    var showHelp = false;

    for (var i = 0; i < args.length; i++) {
      final arg = args[i];
      switch (arg) {
        case '--state':
          if (i + 1 >= args.length) {
            throw ArgumentError('--state requires a file path');
          }
          statePath = args[++i];
          break;
        case '--interval-minutes':
          if (i + 1 >= args.length) {
            throw ArgumentError('--interval-minutes requires an integer value');
          }
          intervalMinutes = int.parse(args[++i]);
          if (intervalMinutes < 1) {
            throw ArgumentError('--interval-minutes must be >= 1');
          }
          break;
        case '--once':
          runOnce = true;
          break;
        case '--max-cycles':
          if (i + 1 >= args.length) {
            throw ArgumentError('--max-cycles requires an integer value');
          }
          maxCycles = int.parse(args[++i]);
          if (maxCycles < 1) {
            throw ArgumentError('--max-cycles must be >= 1');
          }
          break;
        case '--help':
        case '-h':
          showHelp = true;
          break;
        default:
          throw ArgumentError('Unknown argument: $arg');
      }
    }

    return _CliOptions(
      statePath: statePath,
      intervalMinutes: intervalMinutes,
      runOnce: runOnce,
      maxCycles: maxCycles,
      showHelp: showHelp,
    );
  }
}

void _printHelp() {
  stdout.writeln('request2_autopilot.dart');
  stdout.writeln('Usage:');
  stdout.writeln('  dart run tool/orchestration/request2_autopilot.dart [options]');
  stdout.writeln('');
  stdout.writeln('Options:');
  stdout.writeln('  --state <path>             State file path (default: .autopilot/request2_state.json)');
  stdout.writeln('  --interval-minutes <int>   Loop interval in minutes (default: 30)');
  stdout.writeln('  --once                     Run one cycle and exit');
  stdout.writeln('  --max-cycles <int>         Stop after N cycles');
  stdout.writeln('  --help, -h                 Show help');
}
