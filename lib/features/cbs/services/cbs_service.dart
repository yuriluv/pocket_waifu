import 'dart:convert';
import 'dart:math';

import 'package:flutter/widgets.dart';
import 'package:intl/intl.dart';

import '../../../models/api_config.dart';
import '../../../models/chat_variable_scope.dart';
import '../../../models/message.dart';
import '../../../providers/chat_session_provider.dart';

enum CbsPhase { userInput, promptBuild, assistantOutput, displayRender, system }

class CbsRenderContext {
  const CbsRenderContext({
    required this.sessionProvider,
    required this.sessionId,
    required this.scope,
    required this.phase,
    required this.characterName,
    required this.userName,
    required this.messages,
    this.currentInput = '',
    this.apiConfig,
    this.maxPromptTokens,
    this.currentMessageTimestamp,
    this.currentMessageIndex,
    this.tempVariables = const <String, String>{},
    this.localSlots = const <String, String>{},
    this.allowWrites = true,
  });

  final ChatSessionProvider sessionProvider;
  final String sessionId;
  final ChatVariableScope scope;
  final CbsPhase phase;
  final String characterName;
  final String userName;
  final List<Message> messages;
  final String currentInput;
  final ApiConfig? apiConfig;
  final int? maxPromptTokens;
  final DateTime? currentMessageTimestamp;
  final int? currentMessageIndex;
  final Map<String, String> tempVariables;
  final Map<String, String> localSlots;
  final bool allowWrites;

  CbsRenderContext copyWith({
    ChatVariableScope? scope,
    CbsPhase? phase,
    List<Message>? messages,
    String? currentInput,
    ApiConfig? apiConfig,
    int? maxPromptTokens,
    DateTime? currentMessageTimestamp,
    int? currentMessageIndex,
    Map<String, String>? tempVariables,
    Map<String, String>? localSlots,
    bool? allowWrites,
  }) {
    return CbsRenderContext(
      sessionProvider: sessionProvider,
      sessionId: sessionId,
      scope: scope ?? this.scope,
      phase: phase ?? this.phase,
      characterName: characterName,
      userName: userName,
      messages: messages ?? this.messages,
      currentInput: currentInput ?? this.currentInput,
      apiConfig: apiConfig ?? this.apiConfig,
      maxPromptTokens: maxPromptTokens ?? this.maxPromptTokens,
      currentMessageTimestamp:
          currentMessageTimestamp ?? this.currentMessageTimestamp,
      currentMessageIndex: currentMessageIndex ?? this.currentMessageIndex,
      tempVariables: tempVariables ?? this.tempVariables,
      localSlots: localSlots ?? this.localSlots,
      allowWrites: allowWrites ?? this.allowWrites,
    );
  }
}

class CbsRenderResult {
  const CbsRenderResult({
    required this.output,
    required this.tempVariables,
  });

  final String output;
  final Map<String, String> tempVariables;
}

class CbsService {
  CbsService._();

  static final CbsService instance = CbsService._();

  static const String _arraySeparator = '§';
  static final Random _random = Random();
  final Map<String, Map<ChatVariableScope, Map<String, String>>> _tempStore =
      <String, Map<ChatVariableScope, Map<String, String>>>{};

  CbsRenderResult render(String input, CbsRenderContext context) {
    if (input.isEmpty || !input.contains('{{')) {
      return CbsRenderResult(
        output: input,
        tempVariables: _cloneMap(_ensureTempVariables(context)),
      );
    }

    final tempVariables = _ensureTempVariables(context);
    final output = _renderTemplate(
      input,
      context.copyWith(tempVariables: tempVariables),
    );
    return CbsRenderResult(
      output: output,
      tempVariables: _cloneMap(tempVariables),
    );
  }

  void clearSessionTempVariables(String sessionId) {
    _tempStore.remove(sessionId);
  }

  String? getVariable(
    ChatSessionProvider sessionProvider,
    String sessionId,
    ChatVariableScope scope,
    String variableName,
  ) {
    return sessionProvider.getVariableValue(sessionId, scope, variableName);
  }

  String _renderTemplate(String input, CbsRenderContext context) {
    var output = input;
    var iterations = 0;
    while (iterations < 100 && output.contains('{{#')) {
      final next = _renderBlocks(output, context);
      if (next == output) {
        break;
      }
      output = next;
      iterations += 1;
    }

    iterations = 0;
    while (iterations < 200 && output.contains('{{')) {
      final span = _findInnermostExpression(output);
      if (span == null) {
        break;
      }
      final expression = output.substring(span.$1 + 2, span.$2).trim();
      final replacement = _evaluateExpression(expression, context);
      output = output.replaceRange(span.$1, span.$2 + 2, replacement);
      iterations += 1;
    }
    return output;
  }

  String _renderBlocks(String input, CbsRenderContext context) {
    final openIndex = input.indexOf('{{#');
    if (openIndex == -1) {
      return input;
    }
    final openEnd = input.indexOf('}}', openIndex);
    if (openEnd == -1) {
      return input;
    }

    final header = input.substring(openIndex + 3, openEnd).trim();
    final headerParts = _splitHeader(header);
    if (headerParts.isEmpty) {
      return input;
    }
    final blockName = headerParts.first.toLowerCase();

    final closeInfo = _findBlockClose(input, openIndex, blockName);
    if (closeInfo == null) {
      return input;
    }

    final bodyStart = openEnd + 2;
    final bodyEnd = closeInfo.$1;
    final closeEnd = closeInfo.$2;
    final body = input.substring(bodyStart, bodyEnd);
    final replacement = _evaluateBlock(blockName, header, body, context);

    return input.replaceRange(openIndex, closeEnd, replacement);
  }

  List<String> _splitHeader(String header) {
    final index = header.indexOf(' ');
    if (index == -1) {
      return <String>[header];
    }
    return <String>[header.substring(0, index), header.substring(index + 1)];
  }

  (int, int)? _findBlockClose(String input, int blockStart, String blockName) {
    var cursor = blockStart;
    var depth = 0;
    while (cursor < input.length) {
      final next = input.indexOf('{{', cursor);
      if (next == -1) {
        return null;
      }
      final end = input.indexOf('}}', next);
      if (end == -1) {
        return null;
      }
      final content = input.substring(next + 2, end).trim();
      if (content.startsWith('#')) {
        final nestedHeader = content.substring(1).trim();
        final nestedName = _splitHeader(nestedHeader).first.toLowerCase();
        if (nestedName == blockName) {
          depth += 1;
        }
      } else if (content.startsWith('/')) {
        final closeName = content.substring(1).trim().toLowerCase();
        if (closeName == blockName || closeName.isEmpty) {
          depth -= 1;
          if (depth == 0) {
            return (next, end + 2);
          }
        }
      }
      cursor = end + 2;
    }
    return null;
  }

  String _evaluateBlock(
    String blockName,
    String header,
    String body,
    CbsRenderContext context,
  ) {
    switch (blockName) {
      case 'when':
        return _evaluateWhenBlock(header, body, context);
      case 'each':
        return _evaluateEachBlock(header, body, context);
      default:
        return '';
    }
  }

  String _evaluateWhenBlock(
    String header,
    String body,
    CbsRenderContext context,
  ) {
    final conditionSource = header.substring('when'.length).trim();
    final condition = _renderTemplate(conditionSource, context);
    final elseIndex = _findElseIndex(body);
    final truthy = _isTruthy(condition);
    String selected;
    if (elseIndex == -1) {
      selected = truthy ? body : '';
    } else if (truthy) {
      selected = body.substring(0, elseIndex);
    } else {
      selected = body.substring(elseIndex + '{{:else}}'.length);
    }
    return _renderTemplate(_dedentBlock(selected), context);
  }

  int _findElseIndex(String body) {
    var cursor = 0;
    var depth = 0;
    while (cursor < body.length) {
      final next = body.indexOf('{{', cursor);
      if (next == -1) {
        return -1;
      }
      final end = body.indexOf('}}', next);
      if (end == -1) {
        return -1;
      }
      final content = body.substring(next + 2, end).trim();
      if (content.startsWith('#')) {
        depth += 1;
      } else if (content.startsWith('/')) {
        depth = max(0, depth - 1);
      } else if (content == ':else' && depth == 0) {
        return next;
      }
      cursor = end + 2;
    }
    return -1;
  }

  String _evaluateEachBlock(
    String header,
    String body,
    CbsRenderContext context,
  ) {
    final remainder = header.substring('each'.length).trim();
    final separatorIndex = _findTopLevelSpace(remainder);
    if (separatorIndex == -1) {
      return '';
    }
    final iterableSource = remainder.substring(0, separatorIndex).trim();
    final slotName = remainder.substring(separatorIndex + 1).trim();
    if (slotName.isEmpty) {
      return '';
    }
    final iterableValue = _renderTemplate(iterableSource, context);
    final items = _decodeArray(iterableValue);
    final rendered = StringBuffer();
    for (var index = 0; index < items.length; index++) {
      final nextSlots = Map<String, String>.from(context.localSlots)
        ..[slotName] = items[index]
        ..['index'] = index.toString();
      rendered.write(
        _renderTemplate(
          _dedentBlock(body),
          context.copyWith(localSlots: nextSlots, currentMessageIndex: index),
        ),
      );
    }
    return rendered.toString();
  }

  int _findTopLevelSpace(String input) {
    var depth = 0;
    for (var i = 0; i < input.length; i++) {
      final current = input[i];
      if (i + 1 < input.length && input.substring(i, i + 2) == '{{') {
        depth += 1;
        i += 1;
        continue;
      }
      if (i + 1 < input.length && input.substring(i, i + 2) == '}}') {
        depth = max(0, depth - 1);
        i += 1;
        continue;
      }
      if (current == ' ' && depth == 0) {
        return i;
      }
    }
    return -1;
  }

  String _dedentBlock(String input) {
    final trimmed = input.trim();
    if (trimmed.isEmpty) {
      return '';
    }
    final lines = trimmed.split('\n');
    var minIndent = 9999;
    for (final line in lines) {
      if (line.trim().isEmpty) {
        continue;
      }
      final indent = line.length - line.trimLeft().length;
      minIndent = min(minIndent, indent);
    }
    if (minIndent == 9999 || minIndent == 0) {
      return trimmed;
    }
    return lines.map((line) {
      if (line.trim().isEmpty) {
        return '';
      }
      return line.length >= minIndent ? line.substring(minIndent) : line;
    }).join('\n');
  }

  (int, int)? _findInnermostExpression(String input) {
    final starts = <int>[];
    for (var i = 0; i < input.length - 1; i++) {
      final pair = input.substring(i, i + 2);
      if (pair == '{{') {
        starts.add(i);
        i += 1;
        continue;
      }
      if (pair == '}}' && starts.isNotEmpty) {
        final start = starts.removeLast();
        if (start + 2 < input.length && input[start + 2] == '#') {
          i += 1;
          continue;
        }
        return (start, i);
      }
    }
    return null;
  }

  String _evaluateExpression(String expression, CbsRenderContext context) {
    if (expression.isEmpty) {
      return '';
    }

    if (expression.startsWith('?')) {
      return _formatDynamic(_evaluateMathExpression(expression.substring(1).trim(), context));
    }

    final normalized = expression.toLowerCase();
    switch (normalized) {
      case 'char':
        return context.characterName;
      case 'user':
        return context.userName;
      case 'past_memory':
      case 'past':
        return _buildPastMemory(context.messages);
      case 'user_input':
      case 'input':
        return context.currentInput;
      case 'history':
      case 'messages':
        return _encodeArray(context.messages.map((message) => message.content).toList());
      case 'chat_index':
        return (context.currentMessageIndex ?? _defaultChatIndex(context)).toString();
      case 'lastmessage':
        return context.messages.isEmpty ? 'null' : context.messages.last.content;
      case 'lastmessageid':
      case 'lastmessageindex':
        return context.messages.isEmpty ? '-1' : '${context.messages.length - 1}';
      case 'first_msg_index':
        return context.messages.isEmpty ? '-1' : '0';
      case 'previous_char_chat':
      case 'lastcharmessage':
        return _findPreviousMessageByRole(context.messages, MessageRole.assistant) ?? 'null';
      case 'previous_user_chat':
      case 'lastusermessage':
        return _findPreviousMessageByRole(context.messages, MessageRole.user) ?? 'null';
      case 'user_history':
        return _encodeArray(
          context.messages
              .where((message) => message.role == MessageRole.user)
              .map((message) => message.content)
              .toList(),
        );
      case 'char_history':
        return _encodeArray(
          context.messages
              .where((message) => message.role == MessageRole.assistant)
              .map((message) => message.content)
              .toList(),
        );
      case 'model':
        return context.apiConfig?.modelName ?? 'null';
      case 'axmodel':
        return 'null';
      case 'maxprompt':
        return (context.maxPromptTokens ?? 0).toString();
      case 'screen_width':
        return _screenSize().$1.toString();
      case 'screen_height':
        return _screenSize().$2.toString();
      case 'time':
        return DateFormat('HH:mm:ss').format(DateTime.now());
      case 'date':
        return DateFormat('yyyy-MM-dd').format(DateTime.now());
      case 'isotime':
        return DateFormat('HH:mm:ss').format(DateTime.now().toUtc());
      case 'isodate':
        return DateFormat('yyyy-MM-dd').format(DateTime.now().toUtc());
      case 'message_time':
        return _formatMessageTime(context.currentMessageTimestamp ?? _currentMessageTime(context), 'HH:mm:ss');
      case 'message_date':
        return _formatMessageTime(context.currentMessageTimestamp ?? _currentMessageTime(context), 'yyyy-MM-dd');
      case 'idle_duration':
        return _formatDuration(_idleDuration(context));
      case 'message_idle_duration':
        return _formatDuration(_messageIdleDuration(context));
      case 'message_unixtime_array':
        return _encodeArray(
          context.messages
              .map((message) => (message.timestamp.millisecondsSinceEpoch ~/ 1000).toString())
              .toList(),
        );
      case 'isfirstmsg':
        return _isFirstMessage(context) ? '1' : '0';
      case 'none':
      case 'blank':
        return '';
      case 'br':
      case 'newline':
        return '\n';
      case 'slot':
        return context.localSlots.values.isEmpty ? '' : context.localSlots.values.first;
    }

    final parts = _splitArgs(expression);
    final functionName = parts.first.trim().toLowerCase();
    final args = parts.skip(1).toList(growable: false);

    switch (functionName) {
      case 'time':
      case 'date':
      case 'datetimeformat':
        return _formatDateCall(args);
      case 'previous_chat_log':
        return _messageAtIndex(context.messages, _parseInt(args.firstOrNull) ?? -1);
      case 'calc':
        return _formatDynamic(_evaluateMathExpression(args.join('::'), context));
      case 'equal':
        return _boolToString((args.firstOrNull ?? '') == (args.elementAtOrNull(1) ?? ''));
      case 'not_equal':
      case 'notequal':
        return _boolToString((args.firstOrNull ?? '') != (args.elementAtOrNull(1) ?? ''));
      case 'remaind':
        return _formatDynamic((_toNum(args.firstOrNull) ?? 0) % (_toNum(args.elementAtOrNull(1)) ?? 1));
      case 'greater':
        return _boolToString((_toNum(args.firstOrNull) ?? 0) > (_toNum(args.elementAtOrNull(1)) ?? 0));
      case 'greater_equal':
      case 'greaterequal':
        return _boolToString((_toNum(args.firstOrNull) ?? 0) >= (_toNum(args.elementAtOrNull(1)) ?? 0));
      case 'less':
        return _boolToString((_toNum(args.firstOrNull) ?? 0) < (_toNum(args.elementAtOrNull(1)) ?? 0));
      case 'less_equal':
      case 'lessequal':
        return _boolToString((_toNum(args.firstOrNull) ?? 0) <= (_toNum(args.elementAtOrNull(1)) ?? 0));
      case 'and':
        return _boolToString(_isTruthy(args.firstOrNull) && _isTruthy(args.elementAtOrNull(1)));
      case 'or':
        return _boolToString(_isTruthy(args.firstOrNull) || _isTruthy(args.elementAtOrNull(1)));
      case 'not':
        return _boolToString(!_isTruthy(args.firstOrNull));
      case 'pow':
        return _formatDynamic(pow(_toNum(args.firstOrNull) ?? 0, _toNum(args.elementAtOrNull(1)) ?? 0));
      case 'floor':
        return (_toNum(args.firstOrNull) ?? 0).floor().toString();
      case 'ceil':
        return (_toNum(args.firstOrNull) ?? 0).ceil().toString();
      case 'abs':
        return _formatDynamic((_toNum(args.firstOrNull) ?? 0).abs());
      case 'round':
        return (_toNum(args.firstOrNull) ?? 0).round().toString();
      case 'min':
        return _formatDynamic(_foldNumeric(args, (a, b) => min(a, b)));
      case 'max':
        return _formatDynamic(_foldNumeric(args, (a, b) => max(a, b)));
      case 'sum':
        return _formatDynamic(_flattenNumericArgs(args).fold<num>(0, (sum, value) => sum + value));
      case 'average':
        final numbers = _flattenNumericArgs(args);
        if (numbers.isEmpty) return '0';
        return _formatDynamic(numbers.fold<num>(0, (sum, value) => sum + value) / numbers.length);
      case 'fix_number':
        return (_toNum(args.firstOrNull) ?? 0).toStringAsFixed(_parseInt(args.elementAtOrNull(1)) ?? 0);
      case 'startswith':
        return _boolToString((args.firstOrNull ?? '').startsWith(args.elementAtOrNull(1) ?? ''));
      case 'endswith':
        return _boolToString((args.firstOrNull ?? '').endsWith(args.elementAtOrNull(1) ?? ''));
      case 'contains':
        return _boolToString((args.firstOrNull ?? '').contains(args.elementAtOrNull(1) ?? ''));
      case 'lower':
        return (args.firstOrNull ?? '').toLowerCase();
      case 'upper':
        return (args.firstOrNull ?? '').toUpperCase();
      case 'capitalize':
        final value = args.firstOrNull ?? '';
        return value.isEmpty ? '' : '${value[0].toUpperCase()}${value.substring(1)}';
      case 'trim':
        return (args.firstOrNull ?? '').trim();
      case 'unicode_encode':
        return (args.firstOrNull ?? '').runes.map((code) => code.toString()).join(',');
      case 'unicode_decode':
        return (args.firstOrNull ?? '')
            .split(',')
            .map((entry) => int.tryParse(entry.trim()))
            .whereType<int>()
            .map(String.fromCharCode)
            .join();
      case 'all':
        return _boolToString(_flattenTruthArgs(args).every((value) => value));
      case 'any':
        return _boolToString(_flattenTruthArgs(args).any((value) => value));
      case 'module_enabled':
        return '0';
      case 'getvar':
        return context.sessionProvider.getVariableValue(
              context.sessionId,
              context.scope,
              args.firstOrNull?.trim() ?? '',
            ) ??
            'null';
      case 'setvar':
        if (context.allowWrites && (args.firstOrNull ?? '').trim().isNotEmpty) {
          context.sessionProvider.setVariable(
            context.sessionId,
            context.scope,
            args.first.trim(),
            args.elementAtOrNull(1) ?? 'null',
          );
        }
        return '';
      case 'addvar':
        if (context.allowWrites && (args.firstOrNull ?? '').trim().isNotEmpty) {
          context.sessionProvider.incrementVariable(
            context.sessionId,
            context.scope,
            args.first.trim(),
            _toNum(args.elementAtOrNull(1)) ?? 0,
          );
        }
        return '';
      case 'settempvar':
        if (context.allowWrites && (args.firstOrNull ?? '').trim().isNotEmpty) {
          context.tempVariables[args.first.trim()] = args.elementAtOrNull(1) ?? 'null';
        }
        return '';
      case 'gettempvar':
        return context.tempVariables[args.firstOrNull?.trim() ?? ''] ?? 'null';
      case 'getglobalvar':
        return 'null';
      case 'array':
        return _encodeArray(args);
      case 'array_length':
      case 'arraylength':
        return _decodeArray(args.firstOrNull ?? '').length.toString();
      case 'array_element':
        return _arrayElement(args.firstOrNull ?? '', _parseInt(args.elementAtOrNull(1)) ?? 0);
      case 'array_push':
        final items = _decodeArray(args.firstOrNull ?? '');
        items.add(args.elementAtOrNull(1) ?? '');
        return _encodeArray(items);
      case 'array_pop':
        final items = _decodeArray(args.firstOrNull ?? '');
        if (items.isNotEmpty) items.removeLast();
        return _encodeArray(items);
      case 'array_shift':
        final items = _decodeArray(args.firstOrNull ?? '');
        if (items.isNotEmpty) items.removeAt(0);
        return _encodeArray(items);
      case 'array_splice':
      case 'array_assert':
        final items = _decodeArray(args.firstOrNull ?? '');
        final index = (_parseInt(args.elementAtOrNull(1)) ?? items.length).clamp(0, items.length);
        items.insertAll(index, args.skip(2));
        return _encodeArray(items);
      case 'split':
        return _encodeArray((args.firstOrNull ?? '').split(args.elementAtOrNull(1) ?? ''));
      case 'join':
        return _decodeArray(args.firstOrNull ?? '').join(args.elementAtOrNull(1) ?? '');
      case 'filter':
        return _filterArray(args.firstOrNull ?? '', args.elementAtOrNull(1) ?? '');
      case 'dict':
      case 'object':
      case 'o':
      case 'd':
        return jsonEncode(_buildDict(args));
      case 'dict_element':
      case 'object_element':
        return _dictElement(args.firstOrNull ?? '', args.elementAtOrNull(1) ?? '');
      case 'dict_assert':
      case 'object_assert':
        final dict = _decodeDict(args.firstOrNull ?? '');
        if ((args.elementAtOrNull(1) ?? '').isNotEmpty) {
          dict[args[1]] = args.elementAtOrNull(2) ?? '';
        }
        return jsonEncode(dict);
      case 'slot':
        if (args.isEmpty) {
          return context.localSlots.values.isEmpty ? '' : context.localSlots.values.first;
        }
        return context.localSlots[args.first] ?? '';
      case 'random':
        return _randomPick(args);
      case 'pick':
        return _seededPick(args, context);
      case 'roll':
        return _roll(args.firstOrNull, false, context);
      case 'rollp':
        return _roll(args.firstOrNull, true, context);
      case 'spread':
        return _decodeArray(args.firstOrNull ?? '').join('::');
      case 'replace':
        return (args.firstOrNull ?? '').replaceAll(args.elementAtOrNull(1) ?? '', args.elementAtOrNull(2) ?? '');
      case 'range':
        final count = max(0, _parseInt(args.firstOrNull) ?? 0);
        return _encodeArray(List<String>.generate(count, (index) => index.toString()));
      case 'length':
        return (args.firstOrNull ?? '').length.toString();
      case 'tonumber':
        return (args.firstOrNull ?? '').replaceAll(RegExp(r'[^0-9.]'), '');
      default:
        return '{{$expression}}';
    }
  }

  String _buildPastMemory(List<Message> messages) {
    final filtered = messages.where((message) => message.role != MessageRole.system);
    return filtered.map((message) {
      final tag = message.role == MessageRole.user ? 'user' : 'char';
      return '<$tag>${message.content}</$tag>';
    }).join();
  }

  String? _findPreviousMessageByRole(List<Message> messages, MessageRole role) {
    for (var i = messages.length - 1; i >= 0; i--) {
      if (messages[i].role == role) {
        return messages[i].content;
      }
    }
    return null;
  }

  String _messageAtIndex(List<Message> messages, int index) {
    if (index < 0 || index >= messages.length) {
      return 'Out of range';
    }
    return messages[index].content;
  }

  DateTime? _currentMessageTime(CbsRenderContext context) {
    if (context.messages.isEmpty) {
      return null;
    }
    final index = context.currentMessageIndex ?? (context.messages.length - 1);
    if (index < 0 || index >= context.messages.length) {
      return null;
    }
    return context.messages[index].timestamp;
  }

  String _formatMessageTime(DateTime? timestamp, String pattern) {
    if (timestamp == null) {
      return '[Cannot get time]';
    }
    return DateFormat(pattern).format(timestamp);
  }

  Duration _idleDuration(CbsRenderContext context) {
    for (var i = context.messages.length - 1; i >= 0; i--) {
      if (context.messages[i].role == MessageRole.user) {
        return DateTime.now().difference(context.messages[i].timestamp);
      }
    }
    return Duration.zero;
  }

  Duration _messageIdleDuration(CbsRenderContext context) {
    final userMessages = context.messages
        .where((message) => message.role == MessageRole.user)
        .toList(growable: false);
    if (userMessages.length < 2) {
      return Duration.zero;
    }
    return userMessages.last.timestamp.difference(userMessages[userMessages.length - 2].timestamp);
  }

  bool _isFirstMessage(CbsRenderContext context) {
    final userOrAssistant = context.messages
        .where((message) => message.role != MessageRole.system)
        .length;
    return userOrAssistant <= 1;
  }

  int _defaultChatIndex(CbsRenderContext context) {
    if (context.messages.isEmpty) {
      return -1;
    }
    return max(-1, context.messages.length - 2);
  }

  String _formatDateCall(List<String> args) {
    if (args.isEmpty) {
      return DateFormat('HH:mm:ss').format(DateTime.now());
    }
    final pattern = _normalizeDatePattern(args.first);
    final rawTimestamp = _toNum(args.length >= 2 ? args[1] : null);
    final target = rawTimestamp == null
        ? DateTime.now()
        : DateTime.fromMillisecondsSinceEpoch(
            rawTimestamp.abs() > 1000000000000
                ? rawTimestamp.round()
                : (rawTimestamp * 1000).round(),
          );
    return DateFormat(pattern).format(target);
  }

  String _normalizeDatePattern(String input) {
    return input
        .replaceAll('YYYY', 'yyyy')
        .replaceAll('YY', 'yy')
        .replaceAll('DDDD', 'DDD')
        .replaceAll('DD', 'dd')
        .replaceAll('HH', 'HH')
        .replaceAll('hh', 'hh')
        .replaceAll('mm', 'mm')
        .replaceAll('ss', 'ss')
        .replaceAll('A', 'a');
  }

  dynamic _evaluateMathExpression(String expression, CbsRenderContext context) {
    final parser = _MathExpressionParser(
      expression,
      variableResolver: (name) {
        return _toNum(
              context.sessionProvider.getVariableValue(
                context.sessionId,
                context.scope,
                name,
              ),
            ) ??
            0;
      },
    );
    return parser.parse();
  }

  List<String> _splitArgs(String expression) {
    final out = <String>[];
    var buffer = StringBuffer();
    var depth = 0;
    for (var i = 0; i < expression.length; i++) {
      final current = expression[i];
      if (i + 1 < expression.length && expression.substring(i, i + 2) == '::') {
        if (depth == 0) {
          out.add(buffer.toString());
          buffer = StringBuffer();
          i += 1;
          continue;
        }
      }
      if (i + 1 < expression.length && expression.substring(i, i + 2) == '{{') {
        depth += 1;
      } else if (i + 1 < expression.length && expression.substring(i, i + 2) == '}}') {
        depth = max(0, depth - 1);
      }
      buffer.write(current);
    }
    out.add(buffer.toString());
    return out.map((entry) => entry.trim()).toList(growable: false);
  }

  Map<String, String> _buildDict(List<String> args) {
    final out = <String, String>{};
    for (final arg in args) {
      final index = arg.indexOf('=');
      if (index == -1) {
        continue;
      }
      final key = arg.substring(0, index).trim();
      if (key.isEmpty) {
        continue;
      }
      out[key] = arg.substring(index + 1).trim();
    }
    return out;
  }

  String _dictElement(String source, String key) {
    final dict = _decodeDict(source);
    return dict[key] ?? 'null';
  }

  Map<String, String> _decodeDict(String source) {
    try {
      final decoded = jsonDecode(source);
      if (decoded is Map) {
        return decoded.map((key, value) => MapEntry(key.toString(), value?.toString() ?? ''));
      }
    } catch (_) {}
    return <String, String>{};
  }

  String _encodeArray(List<String> items) => items.join(_arraySeparator);

  List<String> _decodeArray(String source) {
    if (source.isEmpty) {
      return <String>[];
    }
    if (!source.contains(_arraySeparator)) {
      return <String>[source];
    }
    return source.split(_arraySeparator);
  }

  String _arrayElement(String source, int index) {
    final items = _decodeArray(source);
    if (items.isEmpty) {
      return 'null';
    }
    final resolvedIndex = index < 0 ? items.length + index : index;
    if (resolvedIndex < 0 || resolvedIndex >= items.length) {
      return 'null';
    }
    return items[resolvedIndex];
  }

  String _filterArray(String source, String mode) {
    var items = _decodeArray(source);
    final normalized = mode.toLowerCase();
    if (normalized == 'nonempty' || normalized == 'all') {
      items = items.where((item) => item.trim().isNotEmpty).toList(growable: false);
    }
    if (normalized == 'unique' || normalized == 'all') {
      items = items.toSet().toList(growable: false);
    }
    return _encodeArray(items);
  }

  String _randomPick(List<String> args) {
    final items = args.isEmpty ? <String>['${_random.nextDouble()}'] : args;
    return items[_random.nextInt(items.length)];
  }

  String _seededPick(List<String> args, CbsRenderContext context) {
    if (args.isEmpty) {
      return '0';
    }
    final seed = Object.hash(context.sessionId, context.currentInput, args.join('|'));
    final random = Random(seed);
    return args[random.nextInt(args.length)];
  }

  String _roll(String? rawLimit, bool seeded, CbsRenderContext context) {
    final normalized = (rawLimit ?? '1').trim().toLowerCase();
    final limit = int.tryParse(normalized.startsWith('d') ? normalized.substring(1) : normalized) ?? 1;
    final random = seeded ? Random(Object.hash(context.sessionId, context.currentInput, rawLimit)) : _random;
    return (random.nextInt(max(1, limit)) + 1).toString();
  }

  List<num> _flattenNumericArgs(List<String> args) {
    if (args.length == 1 && args.first.contains(_arraySeparator)) {
      return _decodeArray(args.first).map((entry) => _toNum(entry) ?? 0).toList(growable: false);
    }
    return args.map((entry) => _toNum(entry) ?? 0).toList(growable: false);
  }

  num _foldNumeric(List<String> args, num Function(num, num) combine) {
    final numbers = _flattenNumericArgs(args);
    if (numbers.isEmpty) {
      return 0;
    }
    return numbers.skip(1).fold<num>(numbers.first, combine);
  }

  List<bool> _flattenTruthArgs(List<String> args) {
    if (args.length == 1 && args.first.contains(_arraySeparator)) {
      return _decodeArray(args.first).map(_isTruthy).toList(growable: false);
    }
    return args.map(_isTruthy).toList(growable: false);
  }

  bool _isTruthy(Object? value) {
    final raw = value?.toString().trim().toLowerCase() ?? '';
    return raw.isNotEmpty && raw != '0' && raw != 'false' && raw != 'null';
  }

  String _boolToString(bool value) => value ? '1' : '0';

  num? _toNum(Object? value) {
    if (value == null) {
      return null;
    }
    if (value is num) {
      return value;
    }
    return num.tryParse(value.toString().trim());
  }

  int? _parseInt(Object? value) {
    if (value == null) {
      return null;
    }
    return int.tryParse(value.toString().trim());
  }

  String _formatDuration(Duration duration) {
    final hours = duration.inHours.toString().padLeft(2, '0');
    final minutes = (duration.inMinutes % 60).toString().padLeft(2, '0');
    final seconds = (duration.inSeconds % 60).toString().padLeft(2, '0');
    return '$hours:$minutes:$seconds';
  }

  String _formatDynamic(Object? value) {
    if (value == null) {
      return 'null';
    }
    if (value is int) {
      return value.toString();
    }
    if (value is double) {
      if (value == value.roundToDouble()) {
        return value.toInt().toString();
      }
      return value.toString();
    }
    return value.toString();
  }

  (int, int) _screenSize() {
    final view = WidgetsBinding.instance.platformDispatcher.views.isEmpty
        ? null
        : WidgetsBinding.instance.platformDispatcher.views.first;
    if (view == null) {
      return (0, 0);
    }
    return (
      (view.physicalSize.width / view.devicePixelRatio).round(),
      (view.physicalSize.height / view.devicePixelRatio).round(),
    );
  }

  Map<String, String> _ensureTempVariables(CbsRenderContext context) {
    final sessionStore = _tempStore.putIfAbsent(
      context.sessionId,
      () => <ChatVariableScope, Map<String, String>>{},
    );
    return sessionStore.putIfAbsent(context.scope, () => <String, String>{});
  }

  Map<String, String> _cloneMap(Map<String, String> source) {
    return Map<String, String>.from(source);
  }
}

class _MathExpressionParser {
  _MathExpressionParser(this.source, {required this.variableResolver});

  final String source;
  final num Function(String name) variableResolver;
  int _index = 0;

  num parse() {
    final value = _parseOr();
    _skipSpaces();
    return value;
  }

  num _parseOr() {
    var value = _parseAnd();
    while (true) {
      _skipSpaces();
      if (_match('||') || _match('|')) {
        final right = _parseAnd();
        value = (_truthy(value) || _truthy(right)) ? 1 : 0;
        continue;
      }
      return value;
    }
  }

  num _parseAnd() {
    var value = _parseEquality();
    while (true) {
      _skipSpaces();
      if (_match('&&') || _match('&')) {
        final right = _parseEquality();
        value = (_truthy(value) && _truthy(right)) ? 1 : 0;
        continue;
      }
      return value;
    }
  }

  num _parseEquality() {
    var value = _parseComparison();
    while (true) {
      _skipSpaces();
      if (_match('==') || _match('=')) {
        final right = _parseComparison();
        value = value == right ? 1 : 0;
        continue;
      }
      if (_match('!=')) {
        final right = _parseComparison();
        value = value != right ? 1 : 0;
        continue;
      }
      return value;
    }
  }

  num _parseComparison() {
    var value = _parseTerm();
    while (true) {
      _skipSpaces();
      if (_match('>=')) {
        final right = _parseTerm();
        value = value >= right ? 1 : 0;
        continue;
      }
      if (_match('<=')) {
        final right = _parseTerm();
        value = value <= right ? 1 : 0;
        continue;
      }
      if (_match('>')) {
        final right = _parseTerm();
        value = value > right ? 1 : 0;
        continue;
      }
      if (_match('<')) {
        final right = _parseTerm();
        value = value < right ? 1 : 0;
        continue;
      }
      return value;
    }
  }

  num _parseTerm() {
    var value = _parseFactor();
    while (true) {
      _skipSpaces();
      if (_match('+')) {
        value += _parseFactor();
        continue;
      }
      if (_match('-')) {
        value -= _parseFactor();
        continue;
      }
      return value;
    }
  }

  num _parseFactor() {
    var value = _parseUnary();
    while (true) {
      _skipSpaces();
      if (_match('*')) {
        value *= _parseUnary();
        continue;
      }
      if (_match('/')) {
        value /= _parseUnary();
        continue;
      }
      if (_match('%')) {
        value %= _parseUnary();
        continue;
      }
      return value;
    }
  }

  num _parseUnary() {
    _skipSpaces();
    if (_match('!')) {
      return _truthy(_parseUnary()) ? 0 : 1;
    }
    if (_match('-')) {
      return -_parseUnary();
    }
    return _parsePower();
  }

  num _parsePower() {
    var value = _parsePrimary();
    _skipSpaces();
    if (_match('^')) {
      value = pow(value, _parseUnary()).toDouble();
    }
    return value;
  }

  num _parsePrimary() {
    _skipSpaces();
    if (_match('(')) {
      final value = _parseOr();
      _match(')');
      return value;
    }
    if (_match(r'$')) {
      final name = _readWhile(RegExp(r'[A-Za-z0-9_]'));
      return variableResolver(name);
    }
    final number = _readWhile(RegExp(r'[0-9.]'));
    return num.tryParse(number) ?? 0;
  }

  bool _match(String token) {
    if (source.startsWith(token, _index)) {
      _index += token.length;
      return true;
    }
    return false;
  }

  String _readWhile(RegExp pattern) {
    final buffer = StringBuffer();
    while (_index < source.length && pattern.hasMatch(source[_index])) {
      buffer.write(source[_index]);
      _index += 1;
    }
    return buffer.toString();
  }

  void _skipSpaces() {
    while (_index < source.length && source[_index].trim().isEmpty) {
      _index += 1;
    }
  }

  bool _truthy(num value) => value != 0;
}

extension<T> on List<T> {
  T? get firstOrNull => isEmpty ? null : first;
  T? elementAtOrNull(int index) => (index < 0 || index >= length) ? null : this[index];
}
