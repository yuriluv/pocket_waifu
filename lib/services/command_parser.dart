// ============================================================================
// 명령어 파서 (Command Parser)
// ============================================================================
// 슬래시(/) 명령어를 파싱하고 실행하는 서비스입니다.
// SillyTavern 스타일의 파워유저 기능을 제공합니다.
// ============================================================================

import 'package:flutter/services.dart';

/// 명령어 실행 결과를 담는 클래스
class CommandResult {
  final CommandType type;           // 명령어 종류
  final bool success;               // 실행 성공 여부
  final String message;             // 사용자에게 표시할 메시지
  final Map<String, dynamic> data;  // 명령어 관련 데이터

  CommandResult({
    required this.type,
    required this.success,
    required this.message,
    this.data = const {},
  });

  // === 편의 Getter (chat_screen에서 사용) ===

  /// 명령어 문자열 (del, send, edit, copy, clear, export, help)
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

  /// 단일 인덱스 (del, edit, copy에서 사용)
  int? get index => data['index'] as int?;

  /// 범위 끝 인덱스 (del 범위 삭제에서 사용)
  int? get endIndex => data['end'] as int?;

  /// 콘텐츠 (send, edit에서 사용)
  String? get content => data['content'] as String?;

  /// 범위 삭제 여부
  bool get isRange => data['isRange'] == true;
}

/// 명령어 종류 열거형
enum CommandType {
  delete,     // /del - 메시지 삭제
  send,       // /send - API 호출 없이 메시지 추가
  edit,       // /edit - 메시지 수정
  copy,       // /copy - 메시지 복사
  help,       // /help - 도움말
  clear,      // /clear - 전체 삭제
  export_,    // /export - 대화 내보내기 (export는 예약어라 _추가)
  unknown,    // 알 수 없는 명령어
}

/// 명령어 파서 클래스
/// 슬래시 명령어를 파싱하고 적절한 CommandResult를 반환합니다
class CommandParser {
  /// 입력 텍스트를 파싱합니다
  /// 
  /// 반환값: (명령어 여부, 명령어 결과 또는 null)
  /// - 명령어가 아니면: (false, null)
  /// - 명령어이면: (true, CommandResult)
  static (bool, CommandResult?) parse(String input) {
    // 슬래시로 시작하지 않으면 일반 메시지
    if (!input.startsWith('/')) {
      return (false, null);
    }

    // 공백으로 분리하여 명령어와 인자 추출
    final parts = input.split(' ');
    final command = parts[0].toLowerCase();
    final args = parts.length > 1 ? parts.sublist(1) : <String>[];

    // 명령어별 파싱
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

  /// /del 명령어 파싱
  /// 형식: /del n 또는 /del n~m
  static CommandResult _parseDel(List<String> args) {
    if (args.isEmpty) {
      return CommandResult(
        type: CommandType.delete,
        success: false,
        message: '삭제할 메시지 번호를 입력하세요. 예: /del 3 또는 /del 1~5',
      );
    }

    final arg = args[0];

    // 범위 삭제 (n~m 형식)
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

    // 단일 삭제 (n 형식)
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

  /// /send 명령어 파싱
  /// 형식: /send 메시지 내용
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

  /// /edit 명령어 파싱
  /// 형식: /edit n 새로운 내용
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

  /// /copy 명령어 파싱
  /// 형식: /copy n
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

  /// /help 명령어 - 도움말 반환
  static CommandResult _getHelp() {
    const helpText = '''
📖 **명령어 목록**

• /del n - n번째 메시지 삭제
• /del n~m - n~m번째 메시지 범위 삭제
• /send 내용 - API 호출 없이 메시지 기록만 추가
• /edit n 내용 - n번째 메시지 수정
• /copy n - n번째 메시지 클립보드 복사
• /clear - 현재 대화 전체 삭제
• /export - 현재 대화 JSON 내보내기
• /help - 이 도움말 표시

💡 메시지 번호는 1부터 시작합니다.
''';

    return CommandResult(
      type: CommandType.help,
      success: true,
      message: helpText,
    );
  }

  /// /clear 명령어 파싱
  static CommandResult _parseClear() {
    return CommandResult(
      type: CommandType.clear,
      success: true,
      message: '현재 대화를 전체 삭제합니다.',
      data: {'requireConfirm': true},
    );
  }

  /// /export 명령어 파싱
  static CommandResult _parseExport() {
    return CommandResult(
      type: CommandType.export_,
      success: true,
      message: '대화 내역을 JSON으로 내보냅니다.',
    );
  }

  /// 클립보드에 텍스트 복사 (유틸리티 함수)
  static Future<void> copyToClipboard(String text) async {
    await Clipboard.setData(ClipboardData(text: text));
  }
}
