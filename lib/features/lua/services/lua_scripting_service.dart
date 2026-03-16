import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../../models/settings.dart';
import '../../image_overlay/services/image_overlay_directive_service.dart';
import '../../live2d_llm/services/live2d_directive_service.dart';
import '../models/lua_script.dart';
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

class LuaScriptingService {
  LuaScriptingService._();

  static const String _scriptsKey = 'lua_scripts_v1';
  static final LuaScriptingService instance = LuaScriptingService._();

  List<LuaScript>? _scriptsCache;
  bool _hooksInitialized = false;
  final List<String> _logs = [];
  String _injectedCss = '';
  final LuaNativeBridge _nativeBridge = LuaNativeBridge();
  final Live2DDirectiveService _live2dDirectiveService =
      Live2DDirectiveService.instance;
  final ImageOverlayDirectiveService _imageDirectiveService =
      ImageOverlayDirectiveService.instance;

  List<String> get logs => List.unmodifiable(_logs);
  String get injectedCss => _injectedCss;

  void clearLogs() {
    _logs.clear();
  }

  void _log(String message) {
    final line = '[${DateTime.now().toIso8601String()}] $message';
    _logs.add(line);
    if (_logs.length > 200) {
      _logs.removeAt(0);
    }
  }

  Future<List<LuaScript>> getScripts() async {
    if (_scriptsCache != null) {
      return _scriptsCache!;
    }

    try {
      final prefs = await SharedPreferences.getInstance();
      final raw = prefs.getString(_scriptsKey);
      if (raw == null || raw.trim().isEmpty) {
        _scriptsCache = _defaultScripts();
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

      _scriptsCache =
          parsed
              .whereType<Map<String, dynamic>>()
              .map(LuaScript.fromMap)
              .toList()
            ..sort((a, b) => a.order.compareTo(b.order));
      if (_scriptsCache!.isEmpty) {
        _scriptsCache = _defaultScripts();
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
    _scriptsCache = List<LuaScript>.from(scripts)
      ..sort((a, b) => a.order.compareTo(b.order));
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
      try {
        final native = await _nativeBridge.executeHookAndReturn(
          script: script.content,
          hook: hook,
          input: output,
          timeoutMs: context.timeout.inMilliseconds,
        );
        if (native != null) {
          output = native;
        } else {
          output = await _executePseudoLua(
            script,
            hook,
            output,
          ).timeout(context.timeout);
        }
      } catch (e) {
        final message = 'Lua script hook failed (${script.name}/$hook): $e';
        _log(message);
        debugPrint(message);
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
        _log('Unknown Lua runtime function: $name');
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
      try {
        final executed = await _nativeBridge.executeHook(
          script: script.content,
          hook: hook,
          input: '',
          timeoutMs: context.timeout.inMilliseconds,
        );
        if (!executed) {
          await _executePseudoLua(script, hook, '').timeout(context.timeout);
        }
      } catch (e) {
        final message = 'Lua script hook failed (${script.name}/$hook): $e';
        _log(message);
        debugPrint(message);
      }
    }
  }

  void uiInjectCss(String cssString) {
    _injectedCss = cssString;
    _log('ui.injectCSS called');
  }

  Future<String?> uiLoadAsset(String assetPath) async {
    try {
      final file = File(assetPath);
      if (!await file.exists()) {
        _log('ui.loadAsset missing: $assetPath');
        return null;
      }
      _log('ui.loadAsset loaded: $assetPath');
      return file.uri.toString();
    } catch (e) {
      _log('ui.loadAsset failed: $e');
      return null;
    }
  }

  String uiSetMessageHtml(String html) {
    _log('ui.setMessageHTML called');
    return html;
  }

  Future<String> _executePseudoLua(
    LuaScript script,
    String hook,
    String input,
  ) async {
    var output = input;

    final lines = script.content.split('\n');
    output = _applyPseudoLuaCommentDirectives(lines, hook, output);
    final functionBody = _extractPseudoLuaFunctionBody(script.content, hook);
    if (functionBody == null) {
      return output;
    }

    final env = <String, String>{'text': output};
    final bodyLines = functionBody.split('\n');
    for (final rawLine in bodyLines) {
      final line = rawLine.trim();
      if (line.isEmpty || line.startsWith('--')) {
        continue;
      }

      if (line.startsWith('return ')) {
        final expr = line.substring('return '.length).trim();
        return await _evaluatePseudoLuaExpression(expr, env) ??
            (env['text'] ?? output);
      }

      final assignment = RegExp(
        r'^(?:local\s+)?([A-Za-z_][A-Za-z0-9_]*)\s*=\s*(.+)$',
      ).firstMatch(line);
      if (assignment != null) {
        final variable = assignment.group(1)!;
        final expr = assignment.group(2)!.trim();
        final value = await _evaluatePseudoLuaExpression(expr, env);
        if (value != null) {
          env[variable] = value;
        }
      }
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

  String? _extractPseudoLuaFunctionBody(String script, String hook) {
    final regex = RegExp(
      'function\\s+$hook\\s*\\([^)]*\\)\\s*([\\s\\S]*?)\\nend',
      caseSensitive: false,
    );
    final match = regex.firstMatch(script);
    return match?.group(1);
  }

  Future<String?> _evaluatePseudoLuaExpression(
    String expression,
    Map<String, String> env,
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
      parsedArgs.add(await _evaluatePseudoLuaExpression(arg, env) ?? '');
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
        await _executeRuntimeFunction(parsedArgs[0], payload);
        return '';
      case 'pwf.emit':
        if (parsedArgs.length < 2) return null;
        final payload = parsedArgs.length > 2 ? parsedArgs[2] : '';
        await _executeRuntimeFunction(parsedArgs[1], payload);
        return parsedArgs[0];
      case 'pwf.dispatch':
        if (parsedArgs.length < 4) return null;
        return _pseudoLuaDispatch(
          parsedArgs[0],
          parsedArgs[1],
          parsedArgs[2],
          parsedArgs[3],
        );
      case 'pwf.dispatchKeep':
        if (parsedArgs.length < 4) return null;
        return _pseudoLuaDispatch(
          parsedArgs[0],
          parsedArgs[1],
          parsedArgs[2],
          parsedArgs[3],
          keepMatches: true,
        );
      case 'pwf.gsub':
        if (parsedArgs.length < 3) return null;
        return _pseudoLuaGsub(parsedArgs[0], parsedArgs[1], parsedArgs[2]);
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

  String _pseudoLuaGsub(String input, String pattern, String replacement) {
    final regex = RegExp(pattern, multiLine: true, dotAll: true);
    return input.replaceAllMapped(regex, (match) {
      var output = replacement;
      for (var i = match.groupCount; i >= 1; i--) {
        output = output.replaceAll('\$' + i.toString(), match.group(i) ?? '');
      }
      return output;
    });
  }

  Future<String> _pseudoLuaDispatch(
    String input,
    String pattern,
    String functionName,
    String payloadTemplate, {
    bool keepMatches = false,
  }) async {
    final regex = RegExp(pattern, multiLine: true, dotAll: true);
    final matches = regex.allMatches(input).toList(growable: false);
    for (final match in matches) {
      await _executeRuntimeFunction(
        functionName,
        _expandPseudoLuaTemplate(payloadTemplate, match),
      );
    }

    if (keepMatches) {
      return input;
    }

    return input.replaceAllMapped(regex, (_) => '');
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
        content: '''-- Editable default Lua template.
-- The app only provides runtime functions. This script decides what text means.
-- Available pseudo-Lua helpers in fallback mode:
--   pwf.gsub(text, pattern, replacement)
--   pwf.replace(text, from, to)
--   pwf.append(text, suffix)
--   pwf.prepend(text, prefix)
--   pwf.trim(text)
--   pwf.call(functionName, payload)         -> execute immediately
--   pwf.emit(text, functionName, payload)   -> execute immediately and keep text
--   pwf.dispatch(text, pattern, functionName, payloadTemplate)
--   pwf.dispatchKeep(text, pattern, functionName, payloadTemplate)
--
-- Runtime functions exposed by the system:
--   live2d.param      payload: id=...,value=...,op=set|del|mul,dur=...,delay=...
--   live2d.motion     payload: group=...,index=... OR name=Idle/0
--   live2d.expression payload: id=... OR name=...
--   live2d.emotion    payload: name=happy
--   live2d.wait       payload: ms=300
--   live2d.preset     payload: name=idle,delay=...
--   live2d.reset      payload: delay=...
--   overlay.move      payload: x=100,y=200,op=set|del|mul,delay=...
--   overlay.emotion   payload: name=happy
--   overlay.wait      payload: ms=300
--
-- Example custom syntax you can enable yourself:
-- text = pwf.dispatch(text, [[function\(emotion,\s*([^)]+)\)]], "overlay.emotion", "name=$1")

function onLoad()
end

function onUserMessage(text)
  text = pwf.dispatchKeep(text, [[<overlay>\s*<emotion\s+([^>]*?)/>\s*</overlay>]], "overlay.emotion", "$1")
  text = pwf.dispatchKeep(text, [[<overlay>\s*<move\s+([^>]*?)/>\s*</overlay>]], "overlay.move", "$1")
  text = pwf.dispatchKeep(text, [[\[img_emotion:([^\]]+)\]]], "overlay.emotion", "$1")
  text = pwf.dispatchKeep(text, [[\[img_move:([^\]]+)\]]], "overlay.move", "$1")
  text = pwf.dispatchKeep(text, [[<emotion\s+([^>]*?)/>]], "live2d.emotion", "$1")
  text = pwf.dispatchKeep(text, [[<motion\s+([^>]*?)/>]], "live2d.motion", "$1")
  text = pwf.dispatchKeep(text, [[\[emotion:([^\]]+)\]]], "live2d.emotion", "$1")
  text = pwf.dispatchKeep(text, [[\[motion:([^\]]+)\]]], "live2d.motion", "$1")
  return text
end

function onPromptBuild(text)
  return text
end

function onAssistantMessage(text)
  text = pwf.dispatch(text, [[<overlay>\s*<move\s+([^>]*?)/>\s*</overlay>]], "overlay.move", "$1")
  text = pwf.dispatch(text, [[<overlay>\s*<emotion\s+([^>]*?)/>\s*</overlay>]], "overlay.emotion", "$1")
  text = pwf.dispatch(text, [[<overlay>\s*<wait\s+([^>]*?)/>\s*</overlay>]], "overlay.wait", "$1")
  text = pwf.dispatch(text, [[<live2d>\s*<wait\s+([^>]*?)/>\s*</live2d>]], "live2d.wait", "$1")

  text = pwf.dispatch(text, [[<param\s+([^>]*?)/>]], "live2d.param", "$1")
  text = pwf.dispatch(text, [[<motion\s+([^>]*?)/>]], "live2d.motion", "$1")
  text = pwf.dispatch(text, [[<expression\s+([^>]*?)/>]], "live2d.expression", "$1")
  text = pwf.dispatch(text, [[<emotion\s+([^>]*?)/>]], "live2d.emotion", "$1")
  text = pwf.dispatch(text, [[<wait\s+([^>]*?)/>]], "live2d.wait", "$1")
  text = pwf.dispatch(text, [[<preset\s+([^>]*?)/>]], "live2d.preset", "$1")
  text = pwf.dispatch(text, [[<reset\s*([^>]*?)/>]], "live2d.reset", "$1")
  text = pwf.dispatch(text, [[<move\s+([^>]*?)/>]], "overlay.move", "$1")

  text = pwf.dispatch(text, [[\[param:([^\]]+)\]]], "live2d.param", "$1")
  text = pwf.dispatch(text, [[\[motion:([^\]]+)\]]], "live2d.motion", "$1")
  text = pwf.dispatch(text, [[\[expression:([^\]]+)\]]], "live2d.expression", "$1")
  text = pwf.dispatch(text, [[\[emotion:([^\]]+)\]]], "live2d.emotion", "$1")
  text = pwf.dispatch(text, [[\[wait:([^\]]+)\]]], "live2d.wait", "$1")
  text = pwf.dispatch(text, [[\[preset:([^\]]+)\]]], "live2d.preset", "$1")
  text = pwf.dispatch(text, [[\[reset\]]], "live2d.reset", "")
  text = pwf.dispatch(text, [[\[img_move:([^\]]+)\]]], "overlay.move", "$1")
  text = pwf.dispatch(text, [[\[img_emotion:([^\]]+)\]]], "overlay.emotion", "$1")

  text = pwf.gsub(text, [[</?live2d>]], "")
  text = pwf.gsub(text, [[</?overlay>]], "")
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
