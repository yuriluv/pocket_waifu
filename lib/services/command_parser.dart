// ============================================================================
// ============================================================================
// ============================================================================

import 'package:flutter/services.dart';
import 'package:flutter_application_1/features/lua/lua_help_contract.dart';

class CommandResult {
  final CommandType type;
  final bool success;
  final String message;
  final Map<String, dynamic> data;

  CommandResult({
    required this.type,
    required this.success,
    required this.message,
    this.data = const {},
  });


  String get command {
    switch (type) {
      case CommandType.delete:
        return 'del';
      case CommandType.send:
        return 'send';
      case CommandType.edit:
        return 'edit';
      case CommandType.copy:
        return 'copy';
      case CommandType.clear:
        return 'clear';
      case CommandType.export_:
        return 'export';
      case CommandType.help:
        return 'help';
      case CommandType.unknown:
        return 'unknown';
    }
  }

  int? get index => data['index'] as int?;

  int? get endIndex => data['end'] as int?;

  String? get content => data['content'] as String?;

  bool get isRange => data['isRange'] == true;
}

enum CommandType {
  delete,
  send,
  edit,
  copy,
  help,
  clear,
  export_,
  unknown,
}

class CommandParser {
  static String get helpText => '''
📖 **명령어 목록**

• /del n - n번째 메시지 삭제
• /del n~m - n~m번째 메시지 범위 삭제
• /send 내용 - API 호출 없이 메시지 기록만 추가
• /edit n 내용 - n번째 메시지 수정
• /copy n - n번째 메시지 클립보드 복사
• /clear - 현재 대화 전체 삭제
• /export - 현재 대화 JSON 내보내기
• /help - 이 도움말 표시

🧩 **출하된 Real Lua 템플릿 예시 형식**

• ${LuaHelpContract.runtimeRules[2]}
• Live2D 블록: <live2d>...</live2d>
• Live2D 인라인: [param:...], [motion:...], [expression:...], [emotion:...], [wait:...], [preset:...], [reset]
• Overlay 블록: <overlay>...</overlay> 내부에서 <move .../>, <emotion .../>, <wait .../>
• Overlay 인라인: [img_move:...], [img_emotion:...]

🧠 **실제 Lua 런타임 계약**

• ${LuaHelpContract.authoringRules[0]}
• ${LuaHelpContract.antiExamples[0]}
${LuaHelpContract.commandHelpFallbackSummary}

💡 메시지 번호는 1부터 시작합니다.
''';

  /// 
  static (bool, CommandResult?) parse(String input) {
    final normalizedInput = input.trim();
    if (!normalizedInput.startsWith('/')) {
      return (false, null);
    }

    final parts = normalizedInput.split(RegExp(r'\s+'));
    final command = parts[0].toLowerCase();
    final args = parts.length > 1 ? parts.sublist(1) : <String>[];

    switch (command) {
      case '/del':
      case '/delete':
        return (true, _parseDel(args));
      
      case '/send':
        return (true, _parseSend(args));
      
      case '/edit':
        return (true, _parseEdit(args));
      
      case '/copy':
        return (true, _parseCopy(args));
      
      case '/help':
      case '/?':
        return (true, _getHelp());
      
      case '/clear':
        return (true, _parseClear());
      
      case '/export':
        return (true, _parseExport());
      
      default:
        return (true, CommandResult(
          type: CommandType.unknown,
          success: false,
          message: '알 수 없는 명령어입니다. /help로 명령어 목록을 확인하세요.',
        ));
    }
  }

  static CommandResult _parseDel(List<String> args) {
    if (args.isEmpty) {
      return CommandResult(
        type: CommandType.delete,
        success: false,
        message: '삭제할 메시지 번호를 입력하세요. 예: /del 3 또는 /del 1~5',
      );
    }

    final arg = args[0];

    if (arg.contains('~')) {
      final range = arg.split('~');
      if (range.length != 2) {
        return CommandResult(
          type: CommandType.delete,
          success: false,
          message: '잘못된 범위 형식입니다. 예: /del 1~5',
        );
      }

      final start = int.tryParse(range[0]);
      final end = int.tryParse(range[1]);

      if (start == null || end == null || start < 1 || end < start) {
        return CommandResult(
          type: CommandType.delete,
          success: false,
          message: '유효한 범위를 입력하세요. 시작은 1 이상, 끝은 시작 이상이어야 합니다.',
        );
      }

      return CommandResult(
        type: CommandType.delete,
        success: true,
        message: '$start~$end번 메시지를 삭제합니다.',
        data: {'index': start, 'end': end, 'isRange': true},
      );
    }

    final index = int.tryParse(arg);
    if (index == null || index < 1) {
      return CommandResult(
        type: CommandType.delete,
        success: false,
        message: '유효한 메시지 번호를 입력하세요 (1 이상).',
      );
    }

    return CommandResult(
      type: CommandType.delete,
      success: true,
      message: '$index번 메시지를 삭제합니다.',
      data: {'index': index, 'isRange': false},
    );
  }

  static CommandResult _parseSend(List<String> args) {
    if (args.isEmpty) {
      return CommandResult(
        type: CommandType.send,
        success: false,
        message: '전송할 메시지 내용을 입력하세요. 예: /send 테스트 메시지',
      );
    }

    final content = args.join(' ');
    return CommandResult(
      type: CommandType.send,
      success: true,
      message: 'API 호출 없이 메시지를 추가했습니다.',
      data: {'content': content},
    );
  }

  static CommandResult _parseEdit(List<String> args) {
    if (args.length < 2) {
      return CommandResult(
        type: CommandType.edit,
        success: false,
        message: '수정할 메시지 번호와 내용을 입력하세요. 예: /edit 2 수정된 내용',
      );
    }

    final index = int.tryParse(args[0]);
    if (index == null || index < 1) {
      return CommandResult(
        type: CommandType.edit,
        success: false,
        message: '유효한 메시지 번호를 입력하세요 (1 이상).',
      );
    }

    final newContent = args.sublist(1).join(' ');
    return CommandResult(
      type: CommandType.edit,
      success: true,
      message: '$index번 메시지를 수정했습니다.',
      data: {'index': index, 'content': newContent},
    );
  }

  static CommandResult _parseCopy(List<String> args) {
    if (args.isEmpty) {
      return CommandResult(
        type: CommandType.copy,
        success: false,
        message: '복사할 메시지 번호를 입력하세요. 예: /copy 3',
      );
    }

    final index = int.tryParse(args[0]);
    if (index == null || index < 1) {
      return CommandResult(
        type: CommandType.copy,
        success: false,
        message: '유효한 메시지 번호를 입력하세요 (1 이상).',
      );
    }

    return CommandResult(
      type: CommandType.copy,
      success: true,
      message: '$index번 메시지를 클립보드에 복사했습니다.',
      data: {'index': index},
    );
  }

  static CommandResult _getHelp() {
    return CommandResult(
      type: CommandType.help,
      success: true,
      message: helpText,
    );
  }

  static CommandResult _parseClear() {
    return CommandResult(
      type: CommandType.clear,
      success: true,
      message: '현재 대화를 전체 삭제합니다.',
      data: {'requireConfirm': true},
    );
  }

  static CommandResult _parseExport() {
    return CommandResult(
      type: CommandType.export_,
      success: true,
      message: '대화 내역을 JSON으로 내보냅니다.',
    );
  }

  static Future<void> copyToClipboard(String text) async {
    await Clipboard.setData(ClipboardData(text: text));
  }
}
