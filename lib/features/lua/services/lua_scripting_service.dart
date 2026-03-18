import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../../models/settings.dart';
import '../../image_overlay/services/image_overlay_directive_service.dart';
import '../../live2d_llm/services/live2d_directive_service.dart';
import '../models/lua_script.dart';
import '../runtime/flutter_embed_lua_runtime.dart';
import '../runtime/real_lua_runtime.dart';
import 'lua_native_bridge.dart';

class LuaHookContext {
  const LuaHookContext({
    this.characterId,
    this.userName,
    this.characterName,
    this.directiveSyntaxOwnershipEnabled = false,
    this.live2dLlmIntegrationEnabled,
    this.live2dDirectiveParsingEnabled,
    this.live2dShowRawDirectivesInChat,
    this.llmDirectiveTarget,
    this.timeout = const Duration(seconds: 5),
  });

  final String? characterId;
  final String? userName;
  final String? characterName;
  final bool directiveSyntaxOwnershipEnabled;
  final bool? live2dLlmIntegrationEnabled;
  final bool? live2dDirectiveParsingEnabled;
  final bool? live2dShowRawDirectivesInChat;
  final LlmDirectiveTarget? llmDirectiveTarget;
  final Duration timeout;
}

enum _LuaExecutionStage { realRuntime, native, fallback }

class _RealLuaExecutionAttempt<T> {
  const _RealLuaExecutionAttempt({
    required this.result,
    required this.elapsed,
    required this.phase,
    required this.compatibilitySource,
    this.optInMarker,
  });

  final RealLuaResult<T> result;
  final Duration elapsed;
  final String phase;
  final String compatibilitySource;
  final String? optInMarker;
}

class _RealLuaCompatibilityDecision {
  const _RealLuaCompatibilityDecision({
    required this.shouldUseRealRuntime,
    required this.source,
    this.optInMarker,
  });

  final bool shouldUseRealRuntime;
  final String source;
  final String? optInMarker;
}

class _LuaExecutionReport {
  const _LuaExecutionReport({
    required this.scriptId,
    required this.scriptName,
    required this.hook,
    required this.stage,
    required this.elapsed,
    required this.reasonCode,
    required this.context,
  });

  final String scriptId;
  final String scriptName;
  final String hook;
  final _LuaExecutionStage stage;
  final Duration elapsed;
  final String reasonCode;
  final Map<String, Object?> context;

  String toDiagnosticLine(DateTime timestamp) {
    final scriptLabel = scriptName.trim().isEmpty ? scriptId : scriptName.trim();
    final stageLabel = switch (stage) {
      _LuaExecutionStage.realRuntime => 'real_runtime',
      _LuaExecutionStage.native => 'native',
      _LuaExecutionStage.fallback => 'fallback',
    };
    return '[${timestamp.toIso8601String()}] '
        'lua.exec script=$scriptLabel '
        'scriptId=$scriptId '
        'hook=$hook '
        'stage=$stageLabel '
        'reason=$reasonCode '
        'elapsedMs=${elapsed.inMilliseconds} '
        'context=${jsonEncode(context)}';
  }
}

class _PseudoLuaHookBody {
  const _PseudoLuaHookBody({required this.body, required this.startLine});

  final String body;
  final int startLine;
}

class _PseudoLuaGuardState {
  _PseudoLuaGuardState({required this.script, required this.hook});

  final LuaScript script;
  final String hook;
  int runtimeActionCount = 0;
  bool actionLimitLogged = false;
}

class LuaScriptingService {
  LuaScriptingService._();

  static const String _scriptsKey = 'lua_scripts_v1';
  static const int _pseudoLuaMaxRegexInputLength = 24000;
  static const int _pseudoLuaMaxRegexMatchesPerHelper = 64;
  static const int _pseudoLuaMaxRuntimeActionsPerHook = 48;
  static const int _pseudoLuaRegexSoftLimitMs = 200;
  static const List<String> _realLuaOptInMarkers = <String>[
    '-- pwf:runtime=real-lua',
    '-- pocketwaifu:runtime=real-lua',
  ];
  static final LuaScriptingService instance = LuaScriptingService._();

  List<LuaScript>? _scriptsCache;
  bool _hooksInitialized = false;
  final List<String> _logs = [];
  String _injectedCss = '';
  LuaNativeBridge _nativeBridge = LuaNativeBridge();
  RealLuaRuntime _realRuntime = FlutterEmbedLuaRuntime();
  final Live2DDirectiveService _live2dDirectiveService =
      Live2DDirectiveService.instance;
  final ImageOverlayDirectiveService _imageDirectiveService =
      ImageOverlayDirectiveService.instance;

  List<String> get logs => List.unmodifiable(_logs);
  String get injectedCss => _injectedCss;

  void clearLogs() {
    _logs.clear();
  }

  @visibleForTesting
  void setNativeBridgeForTesting(LuaNativeBridge bridge) {
    _nativeBridge = bridge;
  }

  @visibleForTesting
  void resetNativeBridgeForTesting() {
    _nativeBridge = LuaNativeBridge();
  }

  @visibleForTesting
  void setRealRuntimeForTesting(RealLuaRuntime runtime) {
    _realRuntime = runtime;
  }

  @visibleForTesting
  void resetRealRuntimeForTesting() {
    _realRuntime = FlutterEmbedLuaRuntime();
  }

  @visibleForTesting
  void setLogsForTesting(List<String> logs) {
    _logs
      ..clear()
      ..addAll(logs);
  }

  void _logLine(String line) {
    _logs.add(line);
    if (_logs.length > 200) {
      _logs.removeAt(0);
    }
  }

  void _logDiagnostic({
    required String reasonCode,
    required Map<String, Object?> context,
  }) {
    final bounded = _boundContext(context);
    final line =
        '[${DateTime.now().toIso8601String()}] '
        'lua.diag reason=$reasonCode context=${jsonEncode(bounded)}';
    _logLine(line);
  }

  void _logExecution(_LuaExecutionReport report) {
    _logLine(report.toDiagnosticLine(DateTime.now()));
  }

  void _logPseudoLuaWarning({
    required String reasonCode,
    required LuaScript script,
    required String hook,
    required int line,
    required String source,
    String? expression,
  }) {
    _logDiagnostic(
      reasonCode: reasonCode,
      context: {
        'severity': 'warning',
        'engine': 'fallback',
        'script': script.name,
        'scriptId': script.id,
        'hook': hook,
        'line': line,
        'source': source,
        if (expression != null) 'expression': expression,
      },
    );
  }

  String _unsupportedExpressionReasonCode(String expression) {
    final trimmed = expression.trim();
    if (trimmed.contains('..')) {
      return 'pseudo_unsupported_expression_concat';
    }
    if (RegExp(r'[A-Za-z_][A-Za-z0-9_]*\s*:[A-Za-z_][A-Za-z0-9_]*\s*\(')
        .hasMatch(trimmed)) {
      return 'pseudo_unsupported_expression_method_call';
    }
    if (RegExp(r'^if\b.*\bthen\b').hasMatch(trimmed)) {
      return 'pseudo_unsupported_expression_if_then';
    }
    if (RegExp(r'^pwf\.[A-Za-z_][A-Za-z0-9_]*\s*\(').hasMatch(trimmed) &&
        '('.allMatches(trimmed).length > ')'.allMatches(trimmed).length) {
      return 'pseudo_risky_multiline_helper';
    }
    return 'pseudo_unsupported_expression';
  }

  String _unsupportedStatementReasonCode(String statement) {
    final trimmed = statement.trim();
    if (RegExp(r'^if\b.*\bthen\b').hasMatch(trimmed)) {
      return 'pseudo_unsupported_statement_if_then';
    }
    if (trimmed.contains('..')) {
      return 'pseudo_unsupported_statement_concat';
    }
    if (RegExp(r'[A-Za-z_][A-Za-z0-9_]*\s*:[A-Za-z_][A-Za-z0-9_]*\s*\(')
        .hasMatch(trimmed)) {
      return 'pseudo_unsupported_statement_method_call';
    }
    if (RegExp(r'^pwf\.[A-Za-z_][A-Za-z0-9_]*\s*\(').hasMatch(trimmed) &&
        '('.allMatches(trimmed).length > ')'.allMatches(trimmed).length) {
      return 'pseudo_risky_multiline_helper';
    }
    return 'pseudo_unsupported_statement';
  }

  String _nativeReasonCode(LuaNativeBridgeStatus status) {
    return switch (status) {
      LuaNativeBridgeStatus.success => 'native_success',
      LuaNativeBridgeStatus.noResult => 'native_no_result',
      LuaNativeBridgeStatus.unavailable => 'native_unavailable',
      LuaNativeBridgeStatus.exception => 'native_exception',
    };
  }

  String _realRuntimeReasonCode(RealLuaResultStatus status) {
    return switch (status) {
      RealLuaResultStatus.success => 'real_runtime_success',
      RealLuaResultStatus.noResult => 'real_runtime_no_result',
      RealLuaResultStatus.unavailable => 'real_runtime_unavailable',
      RealLuaResultStatus.notInitialized => 'real_runtime_not_initialized',
      RealLuaResultStatus.error => 'real_runtime_error',
    };
  }

  String? _realLuaOptInMarkerForScript(LuaScript script) {
    for (final marker in _realLuaOptInMarkers) {
      if (script.content.contains(marker)) {
        return marker;
      }
    }
    return null;
  }

  _RealLuaCompatibilityDecision _realLuaCompatibilityDecision(
    LuaScript script,
  ) {
    if (script.runtimeMode == LuaScriptRuntimeMode.realRuntimeNative) {
      return const _RealLuaCompatibilityDecision(
        shouldUseRealRuntime: true,
        source: 'stored_runtime_mode',
      );
    }
    final marker = _realLuaOptInMarkerForScript(script);
    if (marker != null) {
      return _RealLuaCompatibilityDecision(
        shouldUseRealRuntime: true,
        source: 'legacy_marker_opt_in',
        optInMarker: marker,
      );
    }
    return const _RealLuaCompatibilityDecision(
      shouldUseRealRuntime: false,
      source: 'legacy_compatible_default',
    );
  }

  LuaScript _normalizeScriptForStorage(LuaScript script) {
    var runtimeMode = script.runtimeMode;
    if (runtimeMode == LuaScriptRuntimeMode.legacyCompatible &&
        _realLuaOptInMarkerForScript(script) != null) {
      runtimeMode = LuaScriptRuntimeMode.realRuntimeNative;
    }
    if (script.schemaVersion == LuaScript.currentSchemaVersion &&
        runtimeMode == script.runtimeMode) {
      return script;
    }
    return script.copyWith(
      schemaVersion: LuaScript.currentSchemaVersion,
      runtimeMode: runtimeMode,
    );
  }

  List<LuaScript> _normalizeScriptsForStorage(List<LuaScript> scripts) {
    return scripts.map(_normalizeScriptForStorage).toList(growable: false);
  }

  bool _requiresStorageWriteBack(LuaScript before, LuaScript after) {
    return before.schemaVersion != after.schemaVersion ||
        before.runtimeMode != after.runtimeMode;
  }

  RealLuaHook? _realLuaHookFromName(String hook) {
    return switch (hook) {
      'onLoad' => RealLuaHook.onLoad,
      'onUnload' => RealLuaHook.onUnload,
      'onUserMessage' => RealLuaHook.onUserMessage,
      'onAssistantMessage' => RealLuaHook.onAssistantMessage,
      'onPromptBuild' => RealLuaHook.onPromptBuild,
      'onDisplayRender' => RealLuaHook.onDisplayRender,
      _ => null,
    };
  }

  Future<_RealLuaExecutionAttempt<String>?> _runRealRuntimeTextHook(
    LuaScript script,
    String hook,
    String input,
    LuaHookContext context,
  ) async {
    final compatibilityDecision = _realLuaCompatibilityDecision(script);
    if (!compatibilityDecision.shouldUseRealRuntime) {
      return null;
    }
    final realHook = _realLuaHookFromName(hook);
    if (realHook == null) {
      return null;
    }

    final watch = Stopwatch()..start();
    final initResult = await _realRuntime.initialize();
    if (!initResult.isSuccess) {
      watch.stop();
      return _RealLuaExecutionAttempt<String>(
        result: RealLuaResult<String>(
          status: initResult.status,
          error: initResult.error,
          stackTrace: initResult.stackTrace,
          metadata: initResult.metadata,
        ),
        elapsed: watch.elapsed,
        phase: 'initialize',
        compatibilitySource: compatibilityDecision.source,
        optInMarker: compatibilityDecision.optInMarker,
      );
    }

    final executeResult = await _realRuntime.executeHookAndReturn(
      RealLuaHookInvocation(
        script: script.content,
        hook: realHook,
        input: input,
        timeout: context.timeout,
      ),
    );
    watch.stop();
    return _RealLuaExecutionAttempt<String>(
      result: executeResult,
      elapsed: watch.elapsed,
      phase: 'execute',
      compatibilitySource: compatibilityDecision.source,
      optInMarker: compatibilityDecision.optInMarker,
    );
  }

  Future<_RealLuaExecutionAttempt<void>?> _runRealRuntimeVoidHook(
    LuaScript script,
    String hook,
    LuaHookContext context,
  ) async {
    final compatibilityDecision = _realLuaCompatibilityDecision(script);
    if (!compatibilityDecision.shouldUseRealRuntime) {
      return null;
    }
    final realHook = _realLuaHookFromName(hook);
    if (realHook == null) {
      return null;
    }

    final watch = Stopwatch()..start();
    final initResult = await _realRuntime.initialize();
    if (!initResult.isSuccess) {
      watch.stop();
      return _RealLuaExecutionAttempt<void>(
        result: initResult,
        elapsed: watch.elapsed,
        phase: 'initialize',
        compatibilitySource: compatibilityDecision.source,
        optInMarker: compatibilityDecision.optInMarker,
      );
    }

    final executeResult = await _realRuntime.executeHook(
      RealLuaHookInvocation(
        script: script.content,
        hook: realHook,
        input: '',
        timeout: context.timeout,
      ),
    );
    watch.stop();
    return _RealLuaExecutionAttempt<void>(
      result: executeResult,
      elapsed: watch.elapsed,
      phase: 'execute',
      compatibilitySource: compatibilityDecision.source,
      optInMarker: compatibilityDecision.optInMarker,
    );
  }

  Map<String, Object?> _baseExecutionContext(
    LuaScript script,
    LuaHookContext context,
  ) {
    return <String, Object?>{
      'order': script.order,
      'scope': script.scope.name,
      'characterId': context.characterId,
      'timeoutMs': context.timeout.inMilliseconds,
    };
  }

  Map<String, Object?> _boundContext(Map<String, Object?> input) {
    final output = <String, Object?>{};
    final keys = input.keys.toList(growable: false)..sort();
    for (final key in keys) {
      final value = input[key];
      if (value == null) {
        continue;
      }
      if (value is String) {
        output[key] = _truncate(value, 96);
      } else {
        output[key] = value;
      }
    }
    return output;
  }

  String _truncate(String value, int maxLength) {
    if (value.length <= maxLength) {
      return value;
    }
    return '${value.substring(0, maxLength)}...';
  }

  Future<List<LuaScript>> getScripts() async {
    if (_scriptsCache != null) {
      return _scriptsCache!;
    }

    try {
      final prefs = await SharedPreferences.getInstance();
      final raw = prefs.getString(_scriptsKey);
      if (raw == null || raw.trim().isEmpty) {
        _scriptsCache = _normalizeScriptsForStorage(_defaultScripts());
        await prefs.setString(
          _scriptsKey,
          jsonEncode(_scriptsCache!.map((script) => script.toMap()).toList()),
        );
        if (!_hooksInitialized) {
          _hooksInitialized = true;
          await onLoad(const LuaHookContext());
        }
        return _scriptsCache!;
      }

      final parsed = jsonDecode(raw);
      if (parsed is! List) {
        _scriptsCache = [];
        if (!_hooksInitialized) {
          _hooksInitialized = true;
          await onLoad(const LuaHookContext());
        }
        return _scriptsCache!;
      }

      var shouldWriteBack = false;
      final loadedScripts = <LuaScript>[];
      for (final item in parsed) {
        if (item is! Map<String, dynamic>) {
          continue;
        }
        final loaded = LuaScript.fromMap(item);
        final normalized = _normalizeScriptForStorage(loaded);
        if (_requiresStorageWriteBack(loaded, normalized)) {
          shouldWriteBack = true;
        }
        loadedScripts.add(normalized);
      }
      loadedScripts.sort((a, b) => a.order.compareTo(b.order));
      _scriptsCache = loadedScripts;
      if (_scriptsCache!.isEmpty) {
        _scriptsCache = _normalizeScriptsForStorage(_defaultScripts());
        await prefs.setString(
          _scriptsKey,
          jsonEncode(_scriptsCache!.map((script) => script.toMap()).toList()),
        );
      } else if (shouldWriteBack) {
        await prefs.setString(
          _scriptsKey,
          jsonEncode(_scriptsCache!.map((script) => script.toMap()).toList()),
        );
      }
      if (!_hooksInitialized) {
        _hooksInitialized = true;
        await onLoad(const LuaHookContext());
      }
      return _scriptsCache!;
    } catch (e) {
      debugPrint('LuaScriptingService.getScripts failed: $e');
      _scriptsCache = [];
      return _scriptsCache!;
    }
  }

  Future<void> saveScripts(List<LuaScript> scripts) async {
    _scriptsCache =
        _normalizeScriptsForStorage(List<LuaScript>.from(scripts)
          ..sort((a, b) => a.order.compareTo(b.order)));
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(
      _scriptsKey,
      jsonEncode(_scriptsCache!.map((script) => script.toMap()).toList()),
    );
    _hooksInitialized = true;
    await onLoad(const LuaHookContext());
  }

  Future<void> onLoad(LuaHookContext context) async {
    await _runHookVoid('onLoad', context);
  }

  Future<void> onUnload(LuaHookContext context) async {
    await _runHookVoid('onUnload', context);
  }

  Future<String> onUserMessage(String text, LuaHookContext context) {
    return _runHook('onUserMessage', text, context);
  }

  Future<String> onAssistantMessage(String text, LuaHookContext context) {
    return _runHook('onAssistantMessage', text, context);
  }

  Future<String> onPromptBuild(String text, LuaHookContext context) {
    return _runHook('onPromptBuild', text, context);
  }

  Future<String> onDisplayRender(String text, LuaHookContext context) {
    return _runHook('onDisplayRender', text, context);
  }

  Future<String> _runHook(
    String hook,
    String input,
    LuaHookContext context,
  ) async {
    var output = input;
    final scripts = await getScripts();
    final runnable = scripts.where((script) {
      if (!script.isEnabled) {
        return false;
      }
      if (script.scope == LuaScriptScope.perCharacter &&
          script.characterId != context.characterId) {
        return false;
      }
      return true;
    }).toList()..sort((a, b) => a.order.compareTo(b.order));

    for (final script in runnable) {
      var stageInputLength = output.length;
      final realAttempt = await _runRealRuntimeTextHook(
        script,
        hook,
        output,
        context,
      );
      if (realAttempt != null) {
        final realReasonCode = _realRuntimeReasonCode(realAttempt.result.status);
        final realContext = <String, Object?>{
          ..._baseExecutionContext(script, context),
          'engine': _realRuntime.engineId,
          'phase': realAttempt.phase,
          'compatibilitySource': realAttempt.compatibilitySource,
          if (realAttempt.optInMarker != null)
            'optInMarker': realAttempt.optInMarker,
          'inputLength': stageInputLength,
          ...realAttempt.result.metadata,
        };
        if (realAttempt.result.error != null) {
          realContext['error'] = realAttempt.result.error.toString();
        }
        if (realAttempt.result.isSuccess && realAttempt.result.value != null) {
          output = realAttempt.result.value!;
          _logExecution(
            _LuaExecutionReport(
              scriptId: script.id,
              scriptName: script.name,
              hook: hook,
              stage: _LuaExecutionStage.realRuntime,
              elapsed: realAttempt.elapsed,
              reasonCode: realReasonCode,
              context: _boundContext({
                ...realContext,
                'outputLength': output.length,
              }),
            ),
          );
          continue;
        }
        _logExecution(
          _LuaExecutionReport(
            scriptId: script.id,
            scriptName: script.name,
            hook: hook,
            stage: _LuaExecutionStage.realRuntime,
            elapsed: realAttempt.elapsed,
            reasonCode: realReasonCode,
            context: _boundContext(realContext),
          ),
        );
      }

      final realReasonCodeForLegacy =
          realAttempt == null
              ? null
              : _realRuntimeReasonCode(realAttempt.result.status);
      final nativeWatch = Stopwatch()..start();
      final nativeResult = await _nativeBridge.executeHookAndReturn(
        script: script.content,
        hook: hook,
        input: output,
        timeoutMs: context.timeout.inMilliseconds,
      );
      nativeWatch.stop();

      final nativeReasonCode = _nativeReasonCode(nativeResult.status);
      final nativeContext = <String, Object?>{
        ..._baseExecutionContext(script, context),
        'inputLength': stageInputLength,
        'nativeAvailable': nativeResult.isAvailable,
        'nativeCause': nativeResult.causeLabel,
        if (realReasonCodeForLegacy != null)
          'realRuntimeCause': realReasonCodeForLegacy,
      };
      if (nativeResult.error != null) {
        nativeContext['error'] = nativeResult.error.toString();
      }

      if (nativeResult.isSuccess && nativeResult.value != null) {
        output = nativeResult.value!;
        _logExecution(
          _LuaExecutionReport(
            scriptId: script.id,
            scriptName: script.name,
            hook: hook,
            stage: _LuaExecutionStage.native,
            elapsed: nativeWatch.elapsed,
            reasonCode: nativeReasonCode,
            context: _boundContext({
              ...nativeContext,
              'outputLength': output.length,
            }),
          ),
        );
        continue;
      }

      _logExecution(
        _LuaExecutionReport(
          scriptId: script.id,
          scriptName: script.name,
          hook: hook,
          stage: _LuaExecutionStage.native,
          elapsed: nativeWatch.elapsed,
          reasonCode: nativeReasonCode,
          context: _boundContext(nativeContext),
        ),
      );

      stageInputLength = output.length;
      final fallbackWatch = Stopwatch()..start();
      try {
        output = await _executePseudoLua(
          script,
          hook,
          output,
        ).timeout(context.timeout);
        fallbackWatch.stop();
        _logExecution(
          _LuaExecutionReport(
            scriptId: script.id,
            scriptName: script.name,
            hook: hook,
            stage: _LuaExecutionStage.fallback,
            elapsed: fallbackWatch.elapsed,
            reasonCode: 'fallback_success',
            context: _boundContext({
              ..._baseExecutionContext(script, context),
              'fallbackCause': nativeReasonCode,
              'inputLength': stageInputLength,
              'outputLength': output.length,
            }),
          ),
        );
      } catch (e) {
        fallbackWatch.stop();
        _logExecution(
          _LuaExecutionReport(
            scriptId: script.id,
            scriptName: script.name,
            hook: hook,
            stage: _LuaExecutionStage.fallback,
            elapsed: fallbackWatch.elapsed,
            reasonCode: 'fallback_exception',
            context: _boundContext({
              ..._baseExecutionContext(script, context),
              'fallbackCause': nativeReasonCode,
              'inputLength': stageInputLength,
              'error': e.toString(),
            }),
          ),
        );
        debugPrint(
          'Lua script hook failed (${script.name}/$hook) '
          'stage=fallback reason=fallback_exception '
          'cause=$nativeReasonCode: $e',
        );
      }
    }

    return output;
  }

  Future<void> _executeRuntimeFunction(String name, String rawPayload) async {
    final attrs = _parseRuntimePayload(rawPayload);
    switch (name) {
      case 'live2d.param':
      case 'live2d.motion':
      case 'live2d.expression':
      case 'live2d.emotion':
      case 'live2d.wait':
      case 'live2d.preset':
      case 'live2d.reset':
        await _live2dDirectiveService.executeCommand(
          name.substring('live2d.'.length),
          attrs,
        );
        return;
      case 'overlay.move':
      case 'overlay.emotion':
      case 'overlay.wait':
        final mapped = switch (name) {
          'overlay.move' => 'move',
          'overlay.emotion' => 'emotion',
          _ => 'wait',
        };
        await _imageDirectiveService.executeCommand(mapped, attrs);
        return;
      default:
        _logDiagnostic(
          reasonCode: 'runtime_unknown_function',
          context: {'function': name},
        );
        return;
    }
  }

  Map<String, String> _parseRuntimePayload(String rawPayload) {
    final output = <String, String>{};

    final quotedRegex = RegExp(r'(\w+)\s*=\s*"([^"]*)"');
    var remainder = rawPayload;
    for (final match in quotedRegex.allMatches(rawPayload)) {
      final key = match.group(1);
      final value = match.group(2);
      if (key != null && value != null) {
        output[key] = value;
      }
      remainder = remainder.replaceFirst(match.group(0) ?? '', ' ');
    }

    for (final segment in remainder.split(',')) {
      final trimmed = segment.trim();
      if (trimmed.isEmpty) {
        continue;
      }
      if (trimmed.contains('=')) {
        final index = trimmed.indexOf('=');
        final key = trimmed.substring(0, index).trim();
        final value = trimmed.substring(index + 1).trim();
        if (key.isNotEmpty && value.isNotEmpty) {
          output[key] = value;
        }
      } else {
        final whitespaceParts = trimmed.split(RegExp(r'\s+'));
        for (final part in whitespaceParts) {
          final item = part.trim();
          if (item.isEmpty || !item.contains('=')) {
            continue;
          }
          final index = item.indexOf('=');
          final key = item.substring(0, index).trim();
          final value = item.substring(index + 1).trim();
          if (key.isNotEmpty && value.isNotEmpty) {
            output[key] = value;
          }
        }
      }
    }

    return output;
  }

  Future<void> _runHookVoid(String hook, LuaHookContext context) async {
    final scripts = await getScripts();
    final runnable = scripts.where((script) {
      if (!script.isEnabled) {
        return false;
      }
      if (script.scope == LuaScriptScope.perCharacter &&
          script.characterId != context.characterId) {
        return false;
      }
      return true;
    }).toList()..sort((a, b) => a.order.compareTo(b.order));

    for (final script in runnable) {
      final realAttempt = await _runRealRuntimeVoidHook(script, hook, context);
      if (realAttempt != null) {
        final realReasonCode = _realRuntimeReasonCode(realAttempt.result.status);
        final realContext = <String, Object?>{
          ..._baseExecutionContext(script, context),
          'engine': _realRuntime.engineId,
          'phase': realAttempt.phase,
          'compatibilitySource': realAttempt.compatibilitySource,
          if (realAttempt.optInMarker != null)
            'optInMarker': realAttempt.optInMarker,
          ...realAttempt.result.metadata,
        };
        if (realAttempt.result.error != null) {
          realContext['error'] = realAttempt.result.error.toString();
        }
        if (realAttempt.result.isSuccess) {
          _logExecution(
            _LuaExecutionReport(
              scriptId: script.id,
              scriptName: script.name,
              hook: hook,
              stage: _LuaExecutionStage.realRuntime,
              elapsed: realAttempt.elapsed,
              reasonCode: realReasonCode,
              context: _boundContext(realContext),
            ),
          );
          continue;
        }
        _logExecution(
          _LuaExecutionReport(
            scriptId: script.id,
            scriptName: script.name,
            hook: hook,
            stage: _LuaExecutionStage.realRuntime,
            elapsed: realAttempt.elapsed,
            reasonCode: realReasonCode,
            context: _boundContext(realContext),
          ),
        );
      }

      final realReasonCodeForLegacy =
          realAttempt == null
              ? null
              : _realRuntimeReasonCode(realAttempt.result.status);
      final nativeWatch = Stopwatch()..start();
      final nativeResult = await _nativeBridge.executeHook(
        script: script.content,
        hook: hook,
        input: '',
        timeoutMs: context.timeout.inMilliseconds,
      );
      nativeWatch.stop();

      final nativeReasonCode = _nativeReasonCode(nativeResult.status);
      final nativeContext = <String, Object?>{
        ..._baseExecutionContext(script, context),
        'nativeAvailable': nativeResult.isAvailable,
        'nativeCause': nativeResult.causeLabel,
        if (realReasonCodeForLegacy != null)
          'realRuntimeCause': realReasonCodeForLegacy,
      };
      if (nativeResult.error != null) {
        nativeContext['error'] = nativeResult.error.toString();
      }

      if (nativeResult.isSuccess) {
        _logExecution(
          _LuaExecutionReport(
            scriptId: script.id,
            scriptName: script.name,
            hook: hook,
            stage: _LuaExecutionStage.native,
            elapsed: nativeWatch.elapsed,
            reasonCode: nativeReasonCode,
            context: _boundContext(nativeContext),
          ),
        );
        continue;
      }

      _logExecution(
        _LuaExecutionReport(
          scriptId: script.id,
          scriptName: script.name,
          hook: hook,
          stage: _LuaExecutionStage.native,
          elapsed: nativeWatch.elapsed,
          reasonCode: nativeReasonCode,
          context: _boundContext(nativeContext),
        ),
      );

      final fallbackWatch = Stopwatch()..start();
      try {
        await _executePseudoLua(script, hook, '').timeout(context.timeout);
        fallbackWatch.stop();
        _logExecution(
          _LuaExecutionReport(
            scriptId: script.id,
            scriptName: script.name,
            hook: hook,
            stage: _LuaExecutionStage.fallback,
            elapsed: fallbackWatch.elapsed,
            reasonCode: 'fallback_success',
            context: _boundContext({
              ..._baseExecutionContext(script, context),
              'fallbackCause': nativeReasonCode,
            }),
          ),
        );
      } catch (e) {
        fallbackWatch.stop();
        _logExecution(
          _LuaExecutionReport(
            scriptId: script.id,
            scriptName: script.name,
            hook: hook,
            stage: _LuaExecutionStage.fallback,
            elapsed: fallbackWatch.elapsed,
            reasonCode: 'fallback_exception',
            context: _boundContext({
              ..._baseExecutionContext(script, context),
              'fallbackCause': nativeReasonCode,
              'error': e.toString(),
            }),
          ),
        );
        debugPrint(
          'Lua script hook failed (${script.name}/$hook) '
          'stage=fallback reason=fallback_exception '
          'cause=$nativeReasonCode: $e',
        );
      }
    }
  }

  void uiInjectCss(String cssString) {
    _injectedCss = cssString;
    _logDiagnostic(
      reasonCode: 'ui_inject_css',
      context: {'cssLength': cssString.length},
    );
  }

  Future<String?> uiLoadAsset(String assetPath) async {
    try {
      final file = File(assetPath);
      if (!await file.exists()) {
        _logDiagnostic(
          reasonCode: 'ui_load_asset_missing',
          context: {'assetPath': assetPath},
        );
        return null;
      }
      _logDiagnostic(
        reasonCode: 'ui_load_asset_loaded',
        context: {'assetPath': assetPath},
      );
      return file.uri.toString();
    } catch (e) {
      _logDiagnostic(
        reasonCode: 'ui_load_asset_failed',
        context: {'assetPath': assetPath, 'error': e.toString()},
      );
      return null;
    }
  }

  String uiSetMessageHtml(String html) {
    _logDiagnostic(
      reasonCode: 'ui_set_message_html',
      context: {'htmlLength': html.length},
    );
    return html;
  }

  Future<String> _executePseudoLua(
    LuaScript script,
    String hook,
    String input,
  ) async {
    var output = input;
    final guardState = _PseudoLuaGuardState(script: script, hook: hook);

    final lines = script.content.split('\n');
    output = _applyPseudoLuaCommentDirectives(lines, hook, output);
    final functionBody = _extractPseudoLuaFunctionBody(lines, hook);
    if (functionBody == null) {
      final declaration = _findPseudoLuaHookDeclaration(lines, hook);
      if (declaration != null) {
        _logPseudoLuaWarning(
          reasonCode: 'pseudo_missing_hook_body',
          script: script,
          hook: hook,
          line: declaration.$1,
          source: declaration.$2.trim(),
        );
      }
      return output;
    }

    final env = <String, String>{'text': output};
    final bodyLines = functionBody.body.split('\n');
    for (var i = 0; i < bodyLines.length; i++) {
      final rawLine = bodyLines[i];
      final line = rawLine.trim();
      if (line.isEmpty || line.startsWith('--')) {
        continue;
      }

      final sourceLine = functionBody.startLine + i;

      if (line.startsWith('return ')) {
        final expr = line.substring('return '.length).trim();
        final evaluated = await _evaluatePseudoLuaExpression(
          expr,
          env,
          guardState,
        );
        if (evaluated == null) {
          _logPseudoLuaWarning(
            reasonCode: _unsupportedExpressionReasonCode(expr),
            script: script,
            hook: hook,
            line: sourceLine,
            source: line,
            expression: expr,
          );
        }
        return evaluated ?? (env['text'] ?? output);
      }

      final assignment = RegExp(
        r'^(?:local\s+)?([A-Za-z_][A-Za-z0-9_]*)\s*=\s*(.+)$',
      ).firstMatch(line);
      if (assignment != null) {
        final variable = assignment.group(1)!;
        final expr = assignment.group(2)!.trim();
        final value = await _evaluatePseudoLuaExpression(expr, env, guardState);
        if (value != null) {
          env[variable] = value;
        } else {
          _logPseudoLuaWarning(
            reasonCode: _unsupportedExpressionReasonCode(expr),
            script: script,
            hook: hook,
            line: sourceLine,
            source: line,
            expression: expr,
          );
        }
        continue;
      }

      _logPseudoLuaWarning(
        reasonCode: _unsupportedStatementReasonCode(line),
        script: script,
        hook: hook,
        line: sourceLine,
        source: line,
      );
    }

    return env['text'] ?? output;
  }

  String _applyPseudoLuaCommentDirectives(
    List<String> lines,
    String hook,
    String input,
  ) {
    var output = input;

    for (final line in lines) {
      final trimmed = line.trim();
      if (!trimmed.startsWith('--')) {
        continue;
      }

      final target = '-- hook:$hook ';
      if (!trimmed.startsWith(target)) {
        continue;
      }

      final action = trimmed.substring(target.length);
      if (action.startsWith('replace:')) {
        final payload = action.substring('replace:'.length);
        final sep = payload.indexOf('=>');
        if (sep > -1) {
          final from = payload.substring(0, sep);
          final to = payload.substring(sep + 2);
          output = output.replaceAll(from, to);
        }
      } else if (action.startsWith('append:')) {
        output += action.substring('append:'.length);
      } else if (action.startsWith('prepend:')) {
        output = action.substring('prepend:'.length) + output;
      }
    }

    return output;
  }

  (int, String)? _findPseudoLuaHookDeclaration(List<String> lines, String hook) {
    final declarationRegex = RegExp(
      '^function\\s+$hook\\s*\\([^)]*\\)',
      caseSensitive: false,
    );
    for (var i = 0; i < lines.length; i++) {
      final line = lines[i].trim();
      if (declarationRegex.hasMatch(line)) {
        return (i + 1, lines[i]);
      }
    }
    return null;
  }

  _PseudoLuaHookBody? _extractPseudoLuaFunctionBody(
    List<String> lines,
    String hook,
  ) {
    final declarationRegex = RegExp(
      '^function\\s+$hook\\s*\\([^)]*\\)',
      caseSensitive: false,
    );
    var start = -1;
    for (var i = 0; i < lines.length; i++) {
      if (declarationRegex.hasMatch(lines[i].trim())) {
        start = i;
        break;
      }
    }
    if (start < 0) {
      return null;
    }

    var end = -1;
    for (var i = start + 1; i < lines.length; i++) {
      if (lines[i].trim().toLowerCase() == 'end') {
        end = i;
        break;
      }
    }
    if (end < 0) {
      return null;
    }

    final body = lines.sublist(start + 1, end).join('\n');
    return _PseudoLuaHookBody(body: body, startLine: start + 2);
  }

  Future<String?> _evaluatePseudoLuaExpression(
    String expression,
    Map<String, String> env,
    _PseudoLuaGuardState guardState,
  ) async {
    final trimmed = expression.trim();
    if (trimmed.isEmpty) {
      return '';
    }

    if (env.containsKey(trimmed)) {
      return env[trimmed];
    }

    if ((trimmed.startsWith('"') && trimmed.endsWith('"')) ||
        (trimmed.startsWith("'") && trimmed.endsWith("'"))) {
      return trimmed.substring(1, trimmed.length - 1);
    }

    if (trimmed.startsWith('[[') && trimmed.endsWith(']]')) {
      return trimmed.substring(2, trimmed.length - 2);
    }

    final callMatch = RegExp(r'^(pwf\.[A-Za-z_][A-Za-z0-9_]*)\((.*)\)$')
        .firstMatch(trimmed);
    if (callMatch == null) {
      return null;
    }

    final functionName = callMatch.group(1)!;
    final rawArgs = callMatch.group(2) ?? '';
    final parsedArgs = <String>[];
    for (final arg in _splitPseudoLuaArgs(rawArgs)) {
      parsedArgs.add(
        await _evaluatePseudoLuaExpression(arg, env, guardState) ?? '',
      );
    }

    switch (functionName) {
      case 'pwf.replace':
        if (parsedArgs.length < 3) return null;
        return parsedArgs[0].replaceAll(parsedArgs[1], parsedArgs[2]);
      case 'pwf.append':
        if (parsedArgs.length < 2) return null;
        return parsedArgs[0] + parsedArgs[1];
      case 'pwf.prepend':
        if (parsedArgs.length < 2) return null;
        return parsedArgs[1] + parsedArgs[0];
      case 'pwf.trim':
        if (parsedArgs.isEmpty) return null;
        return parsedArgs[0].trim();
      case 'pwf.call':
        if (parsedArgs.isEmpty) return null;
        final payload = parsedArgs.length > 1 ? parsedArgs[1] : '';
        await _executeRuntimeFunctionGuarded(
          guardState,
          helperName: 'pwf.call',
          functionName: parsedArgs[0],
          payload: payload,
        );
        return '';
      case 'pwf.emit':
        if (parsedArgs.length < 2) return null;
        final payload = parsedArgs.length > 2 ? parsedArgs[2] : '';
        await _executeRuntimeFunctionGuarded(
          guardState,
          helperName: 'pwf.emit',
          functionName: parsedArgs[1],
          payload: payload,
        );
        return parsedArgs[0];
      case 'pwf.dispatch':
        if (parsedArgs.length < 4) return null;
        return _pseudoLuaDispatch(
          guardState,
          parsedArgs[0],
          parsedArgs[1],
          parsedArgs[2],
          parsedArgs[3],
        );
      case 'pwf.dispatchKeep':
        if (parsedArgs.length < 4) return null;
        return _pseudoLuaDispatch(
          guardState,
          parsedArgs[0],
          parsedArgs[1],
          parsedArgs[2],
          parsedArgs[3],
          keepMatches: true,
        );
      case 'pwf.gsub':
        if (parsedArgs.length < 3) return null;
        return _pseudoLuaGsub(
          guardState,
          parsedArgs[0],
          parsedArgs[1],
          parsedArgs[2],
        );
      default:
        return null;
    }
  }

  List<String> _splitPseudoLuaArgs(String raw) {
    final args = <String>[];
    final buffer = StringBuffer();
    var index = 0;
    var inSingle = false;
    var inDouble = false;
    var longDepth = 0;

    while (index < raw.length) {
      final char = raw[index];
      final next = index + 1 < raw.length ? raw[index + 1] : '';

      if (!inSingle && !inDouble && char == '[' && next == '[') {
        longDepth++;
        buffer.write('[[');
        index += 2;
        continue;
      }
      if (longDepth > 0 && char == ']' && next == ']') {
        longDepth--;
        buffer.write(']]');
        index += 2;
        continue;
      }
      if (longDepth == 0 && !inDouble && char == "'") {
        inSingle = !inSingle;
        buffer.write(char);
        index++;
        continue;
      }
      if (longDepth == 0 && !inSingle && char == '"') {
        inDouble = !inDouble;
        buffer.write(char);
        index++;
        continue;
      }
      if (longDepth == 0 && !inSingle && !inDouble && char == ',') {
        args.add(buffer.toString().trim());
        buffer.clear();
        index++;
        continue;
      }

      buffer.write(char);
      index++;
    }

    final tail = buffer.toString().trim();
    if (tail.isNotEmpty) {
      args.add(tail);
    }
    return args;
  }

  String _pseudoLuaGsub(
    _PseudoLuaGuardState guardState,
    String input,
    String pattern,
    String replacement,
  ) {
    final regex = _buildPseudoLuaRegexOrLog(
      guardState,
      helperName: 'pwf.gsub',
      input: input,
      pattern: pattern,
    );
    if (regex == null) {
      return input;
    }

    final stopwatch = Stopwatch()..start();
    final allMatches = regex
        .allMatches(input)
        .take(_pseudoLuaMaxRegexMatchesPerHelper + 1)
        .toList(growable: false);
    final capped = allMatches.length > _pseudoLuaMaxRegexMatchesPerHelper;
    final matches = capped
        ? allMatches.take(_pseudoLuaMaxRegexMatchesPerHelper).toList(
            growable: false,
          )
        : allMatches;

    if (matches.isEmpty) {
      stopwatch.stop();
      _logPseudoLuaRegexSoftLimitIfNeeded(
        guardState,
        helperName: 'pwf.gsub',
        stopwatch: stopwatch,
        pattern: pattern,
        matchCount: 0,
      );
      return input;
    }

    final buffer = StringBuffer();
    var cursor = 0;
    for (final match in matches) {
      if (match.start < cursor) {
        continue;
      }
      buffer.write(input.substring(cursor, match.start));
      buffer.write(_expandPseudoLuaTemplate(replacement, match));
      cursor = match.end;
    }
    buffer.write(input.substring(cursor));
    final output = buffer.toString();
    stopwatch.stop();

    if (capped) {
      _logPseudoLuaGuard(
        guardState,
        reasonCode: 'pseudo_regex_guard_match_cap',
        helperName: 'pwf.gsub',
        context: {
          'pattern': pattern,
          'matchLimit': _pseudoLuaMaxRegexMatchesPerHelper,
          'processedMatches': matches.length,
          'replacementLength': replacement.length,
        },
      );
    }
    _logPseudoLuaRegexSoftLimitIfNeeded(
      guardState,
      helperName: 'pwf.gsub',
      stopwatch: stopwatch,
      pattern: pattern,
      matchCount: matches.length,
    );
    return output;
  }

  Future<String> _pseudoLuaDispatch(
    _PseudoLuaGuardState guardState,
    String input,
    String pattern,
    String functionName,
    String payloadTemplate, {
    bool keepMatches = false,
  }) async {
    final helperName = keepMatches ? 'pwf.dispatchKeep' : 'pwf.dispatch';
    final regex = _buildPseudoLuaRegexOrLog(
      guardState,
      helperName: helperName,
      input: input,
      pattern: pattern,
    );
    if (regex == null) {
      return input;
    }

    final stopwatch = Stopwatch()..start();
    final allMatches = regex
        .allMatches(input)
        .take(_pseudoLuaMaxRegexMatchesPerHelper + 1)
        .toList(growable: false);
    final cappedByMatchLimit =
        allMatches.length > _pseudoLuaMaxRegexMatchesPerHelper;
    final matches = cappedByMatchLimit
        ? allMatches.take(_pseudoLuaMaxRegexMatchesPerHelper).toList(
            growable: false,
          )
        : allMatches;

    if (cappedByMatchLimit) {
      _logPseudoLuaGuard(
        guardState,
        reasonCode: 'pseudo_regex_guard_match_cap',
        helperName: helperName,
        context: {
          'function': functionName,
          'matchLimit': _pseudoLuaMaxRegexMatchesPerHelper,
          'processedMatches': matches.length,
          'pattern': pattern,
        },
      );
    }

    var processedMatchCount = 0;
    for (final match in matches) {
      final didExecute = await _executeRuntimeFunctionGuarded(
        guardState,
        helperName: helperName,
        functionName: functionName,
        payload: _expandPseudoLuaTemplate(payloadTemplate, match),
      );
      if (!didExecute) {
        break;
      }
      processedMatchCount++;
    }
    stopwatch.stop();
    _logPseudoLuaRegexSoftLimitIfNeeded(
      guardState,
      helperName: helperName,
      stopwatch: stopwatch,
      pattern: pattern,
      matchCount: processedMatchCount,
    );

    if (keepMatches) {
      return input;
    }

    return _removePseudoLuaMatches(input, matches.take(processedMatchCount));
  }

  String _removePseudoLuaMatches(String input, Iterable<RegExpMatch> matches) {
    final buffer = StringBuffer();
    var cursor = 0;
    for (final match in matches) {
      if (match.start < cursor) {
        continue;
      }
      buffer.write(input.substring(cursor, match.start));
      cursor = match.end;
    }
    buffer.write(input.substring(cursor));
    return buffer.toString();
  }

  RegExp? _buildPseudoLuaRegexOrLog(
    _PseudoLuaGuardState guardState, {
    required String helperName,
    required String input,
    required String pattern,
  }) {
    if (input.length > _pseudoLuaMaxRegexInputLength) {
      _logPseudoLuaGuard(
        guardState,
        reasonCode: 'pseudo_regex_guard_input_too_large',
        helperName: helperName,
        context: {
          'inputLength': input.length,
          'maxInputLength': _pseudoLuaMaxRegexInputLength,
          'pattern': pattern,
        },
      );
      return null;
    }
    if (_isPotentiallyCatastrophicPseudoLuaPattern(pattern)) {
      _logPseudoLuaGuard(
        guardState,
        reasonCode: 'pseudo_regex_guard_catastrophic_pattern',
        helperName: helperName,
        context: {'pattern': pattern},
      );
      return null;
    }

    try {
      return RegExp(pattern, multiLine: true, dotAll: true);
    } catch (error) {
      _logPseudoLuaGuard(
        guardState,
        reasonCode: 'pseudo_regex_guard_invalid_pattern',
        helperName: helperName,
        context: {'pattern': pattern, 'error': error.toString()},
      );
      return null;
    }
  }

  bool _isPotentiallyCatastrophicPseudoLuaPattern(String pattern) {
    final nestedQuantifier = RegExp(r'\([^)]*[+*][^)]*\)[+*]');
    final ambiguousAlternation = RegExp(r'\((?:[^)]*\|){3,}[^)]*\)[+*]');
    return nestedQuantifier.hasMatch(pattern) ||
        ambiguousAlternation.hasMatch(pattern);
  }

  Future<bool> _executeRuntimeFunctionGuarded(
    _PseudoLuaGuardState guardState, {
    required String helperName,
    required String functionName,
    required String payload,
  }) async {
    if (guardState.runtimeActionCount >= _pseudoLuaMaxRuntimeActionsPerHook) {
      if (!guardState.actionLimitLogged) {
        guardState.actionLimitLogged = true;
        _logPseudoLuaGuard(
          guardState,
          reasonCode: 'pseudo_runtime_guard_action_cap',
          helperName: helperName,
          context: {
            'function': functionName,
            'actionLimit': _pseudoLuaMaxRuntimeActionsPerHook,
          },
        );
      }
      return false;
    }
    guardState.runtimeActionCount++;
    await _executeRuntimeFunction(functionName, payload);
    return true;
  }

  void _logPseudoLuaRegexSoftLimitIfNeeded(
    _PseudoLuaGuardState guardState, {
    required String helperName,
    required Stopwatch stopwatch,
    required String pattern,
    required int matchCount,
  }) {
    if (stopwatch.elapsedMilliseconds <= _pseudoLuaRegexSoftLimitMs) {
      return;
    }
    _logPseudoLuaGuard(
      guardState,
      reasonCode: 'pseudo_regex_guard_runtime_soft_limit',
      helperName: helperName,
      context: {
        'elapsedMs': stopwatch.elapsedMilliseconds,
        'softLimitMs': _pseudoLuaRegexSoftLimitMs,
        'matchCount': matchCount,
        'pattern': pattern,
        'note': 'soft guard only; synchronous regex cannot be preempted',
      },
    );
  }

  void _logPseudoLuaGuard(
    _PseudoLuaGuardState guardState, {
    required String reasonCode,
    required String helperName,
    required Map<String, Object?> context,
  }) {
    _logDiagnostic(
      reasonCode: reasonCode,
      context: {
        'severity': 'warning',
        'engine': 'fallback',
        'script': guardState.script.name,
        'scriptId': guardState.script.id,
        'hook': guardState.hook,
        'helper': helperName,
        'runtimeActionCount': guardState.runtimeActionCount,
        ...context,
      },
    );
  }

  String _expandPseudoLuaTemplate(String template, RegExpMatch match) {
    var output = template;
    output = output.replaceAll(r'$0', match.group(0) ?? '');
    for (var i = match.groupCount; i >= 1; i--) {
      output = output.replaceAll('\$' + i.toString(), match.group(i) ?? '');
    }
    return output;
  }

  List<LuaScript> _defaultScripts() {
    return <LuaScript>[
      LuaScript(
        name: 'default_runtime_template.lua',
        order: 0,
        scope: LuaScriptScope.global,
        runtimeMode: LuaScriptRuntimeMode.realRuntimeNative,
        content: '''-- Editable default Lua template (real runtime mode).
-- New installs seed this script with runtimeMode=realRuntimeNative.
-- Exposed host functions:
--   overlay.move({ x=..., y=..., op="set|del|mul", durationMs=... })
--   overlay.emotion({ name="happy" })
--   overlay.wait({ ms=300 })
--   live2d.param({ id="ParamAngleX", value=15, op="set|del|mul", durationMs=... })
--   live2d.motion({ group="Idle", index=0 }) or live2d.motion({ name="Idle/0" })
--   live2d.expression({ name="smile" })
--   live2d.emotion({ name="happy" })
--   live2d.wait({ ms=300 })
--   live2d.preset({ name="idle", durationMs=... })
--   live2d.reset({ durationMs=... })

local function trim(value)
  if value == nil then
    return ""
  end
  return (tostring(value):gsub("^%s+", ""):gsub("%s+$", ""))
end

local function parse_attrs(payload)
  local attrs = {}
  local raw = trim(payload)

  for key, value in raw:gmatch('(%w+)%s*=%s*"([^"]*)"') do
    attrs[key] = value
  end
  for key, value in raw:gmatch("(%w+)%s*=%s*'([^']*)'") do
    attrs[key] = value
  end
  for key, value in raw:gmatch("(%w+)%s*=%s*([^,%s]+)") do
    if attrs[key] == nil then
      attrs[key] = value
    end
  end

  return attrs, raw
end

local function parse_duration(attrs, raw)
  local value = attrs.ms or attrs.durationMs or attrs.duration or attrs.dur
  if value == nil and raw ~= nil and raw ~= "" and raw:find("=") == nil then
    value = raw
  end
  local numeric = tonumber(value)
  if numeric == nil then
    return nil
  end
  if numeric < 0 then
    return 0
  end
  return math.floor(numeric + 0.5)
end

local function dispatch_keep(text, pattern, handler)
  for payload in text:gmatch(pattern) do
    handler(payload)
  end
  return text
end

local function dispatch_remove(text, pattern, handler)
  return (text:gsub(pattern, function(payload)
    handler(payload)
    return ""
  end))
end

local function overlay_emotion_from_payload(payload)
  local attrs, raw = parse_attrs(payload)
  local emotion = trim(attrs.name or attrs.emotion or raw)
  if emotion ~= "" then
    overlay.emotion({ name = emotion })
  end
end

local function overlay_move_from_payload(payload)
  local attrs = parse_attrs(payload)
  local x = tonumber(attrs.x)
  local y = tonumber(attrs.y)
  overlay.move({
    x = x,
    y = y,
    op = attrs.op,
    durationMs = parse_duration(attrs),
  })
end

local function overlay_wait_from_payload(payload)
  local attrs, raw = parse_attrs(payload)
  local duration = parse_duration(attrs, raw)
  if duration ~= nil then
    overlay.wait({ ms = duration })
  end
end

local function live2d_param_from_payload(payload)
  local attrs = parse_attrs(payload)
  local parameter_id = attrs.id or attrs.parameterId
  local value = tonumber(attrs.value)
  if parameter_id ~= nil and parameter_id ~= "" and value ~= nil then
    live2d.param({
      id = parameter_id,
      value = value,
      op = attrs.op,
      durationMs = parse_duration(attrs),
    })
  end
end

local function live2d_motion_from_payload(payload)
  local attrs, raw = parse_attrs(payload)
  local motion_name = attrs.name
  if (motion_name == nil or motion_name == "") and raw ~= "" and raw:find("=") == nil then
    motion_name = raw
  end
  live2d.motion({
    group = attrs.group,
    index = tonumber(attrs.index),
    name = motion_name,
    priority = tonumber(attrs.priority),
  })
end

local function live2d_expression_from_payload(payload)
  local attrs, raw = parse_attrs(payload)
  local expression = trim(attrs.name or attrs.id or attrs.expression or raw)
  if expression ~= "" then
    live2d.expression({ name = expression })
  end
end

local function live2d_emotion_from_payload(payload)
  local attrs, raw = parse_attrs(payload)
  local emotion = trim(attrs.name or attrs.emotion or raw)
  if emotion ~= "" then
    live2d.emotion({ name = emotion })
  end
end

local function live2d_wait_from_payload(payload)
  local attrs, raw = parse_attrs(payload)
  local duration = parse_duration(attrs, raw)
  if duration ~= nil then
    live2d.wait({ ms = duration })
  end
end

local function live2d_preset_from_payload(payload)
  local attrs, raw = parse_attrs(payload)
  local name = trim(attrs.name or attrs.presetName or raw)
  if name ~= "" then
    live2d.preset({
      name = name,
      durationMs = parse_duration(attrs),
    })
  end
end

local function live2d_reset_from_payload(payload)
  local attrs, raw = parse_attrs(payload)
  live2d.reset({ durationMs = parse_duration(attrs, raw) })
end

function onLoad()
end

function onUserMessage(text)
  text = dispatch_keep(text, "<overlay>%s*<emotion%s+([^>]-)/>%s*</overlay>", overlay_emotion_from_payload)
  text = dispatch_keep(text, "<overlay>%s*<move%s+([^>]-)/>%s*</overlay>", overlay_move_from_payload)
  text = dispatch_keep(text, "%[img_emotion:([^%]]+)%]", overlay_emotion_from_payload)
  text = dispatch_keep(text, "%[img_move:([^%]]+)%]", overlay_move_from_payload)
  text = dispatch_keep(text, "<emotion%s+([^>]-)/>", live2d_emotion_from_payload)
  text = dispatch_keep(text, "<motion%s+([^>]-)/>", live2d_motion_from_payload)
  text = dispatch_keep(text, "%[emotion:([^%]]+)%]", live2d_emotion_from_payload)
  text = dispatch_keep(text, "%[motion:([^%]]+)%]", live2d_motion_from_payload)
  return text
end

function onPromptBuild(text)
  return text
end

function onAssistantMessage(text)
  text = dispatch_remove(text, "<overlay>%s*<move%s+([^>]-)/>%s*</overlay>", overlay_move_from_payload)
  text = dispatch_remove(text, "<overlay>%s*<emotion%s+([^>]-)/>%s*</overlay>", overlay_emotion_from_payload)
  text = dispatch_remove(text, "<overlay>%s*<wait%s+([^>]-)/>%s*</overlay>", overlay_wait_from_payload)
  text = dispatch_remove(text, "<live2d>%s*<wait%s+([^>]-)/>%s*</live2d>", live2d_wait_from_payload)

  text = dispatch_remove(text, "<param%s+([^>]-)/>", live2d_param_from_payload)
  text = dispatch_remove(text, "<motion%s+([^>]-)/>", live2d_motion_from_payload)
  text = dispatch_remove(text, "<expression%s+([^>]-)/>", live2d_expression_from_payload)
  text = dispatch_remove(text, "<emotion%s+([^>]-)/>", live2d_emotion_from_payload)
  text = dispatch_remove(text, "<wait%s+([^>]-)/>", live2d_wait_from_payload)
  text = dispatch_remove(text, "<preset%s+([^>]-)/>", live2d_preset_from_payload)
  text = dispatch_remove(text, "<reset%s*([^>]-)/>", live2d_reset_from_payload)
  text = dispatch_remove(text, "<move%s+([^>]-)/>", overlay_move_from_payload)

  text = dispatch_remove(text, "%[param:([^%]]+)%]", live2d_param_from_payload)
  text = dispatch_remove(text, "%[motion:([^%]]+)%]", live2d_motion_from_payload)
  text = dispatch_remove(text, "%[expression:([^%]]+)%]", live2d_expression_from_payload)
  text = dispatch_remove(text, "%[emotion:([^%]]+)%]", live2d_emotion_from_payload)
  text = dispatch_remove(text, "%[wait:([^%]]+)%]", live2d_wait_from_payload)
  text = dispatch_remove(text, "%[preset:([^%]]+)%]", live2d_preset_from_payload)
  text = dispatch_remove(text, "%[reset%]", function(_) live2d.reset() end)
  text = dispatch_remove(text, "%[img_move:([^%]]+)%]", overlay_move_from_payload)
  text = dispatch_remove(text, "%[img_emotion:([^%]]+)%]", overlay_emotion_from_payload)

  text = text:gsub("<live2d>", "")
  text = text:gsub("</live2d>", "")
  text = text:gsub("<overlay>", "")
  text = text:gsub("</overlay>", "")
  return text
end

function onDisplayRender(text)
  return text
end

function onUnload()
end
''',
      ),
    ];
  }
}
