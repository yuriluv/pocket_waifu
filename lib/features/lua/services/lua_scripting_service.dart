import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../models/lua_script.dart';
import 'lua_native_bridge.dart';

class LuaHookContext {
  const LuaHookContext({
    this.characterId,
    this.userName,
    this.characterName,
    this.timeout = const Duration(seconds: 5),
  });

  final String? characterId;
  final String? userName;
  final String? characterName;
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
    // Placeholder execution model for lifecycle compatibility.
    // Recognized directives in script.content:
    //   -- hook:onUserMessage replace:foo=>bar
    //   -- hook:onAssistantMessage append:...text...
    final lines = script.content.split('\n');
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

  List<LuaScript> _defaultScripts() {
    return <LuaScript>[
      LuaScript(
        name: 'live2d_hooks_template.lua',
        order: 0,
        scope: LuaScriptScope.global,
        content: '''-- Editable Live2D hook template.
-- Keep or customize these hooks from the Regex/Lua management screen.

function onLoad()
end

function onUserMessage(text)
  return text
end

function onPromptBuild(text)
  return text
end

function onAssistantMessage(text)
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
