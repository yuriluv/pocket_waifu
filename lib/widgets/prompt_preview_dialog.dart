// ============================================================================
// 프롬프트 미리보기 다이얼로그 (Prompt Preview Dialog)
// ============================================================================
// 현재 프롬프트 블록들이 조합된 최종 프롬프트를 미리보는 다이얼로그입니다.
// 실제 API에 전송되는 프롬프트를 확인하고 복사할 수 있습니다.
// ============================================================================

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

/// 프롬프트 미리보기 다이얼로그
class PromptPreviewDialog extends StatelessWidget {
  final String promptText;   // 미리볼 프롬프트 텍스트

  const PromptPreviewDialog({
    super.key,
    required this.promptText,
  });

  /// 다이얼로그를 표시합니다
  static Future<void> show(BuildContext context, String promptText) {
    return showDialog(
      context: context,
      builder: (context) => PromptPreviewDialog(promptText: promptText),
    );
  }

  /// 프롬프트를 클립보드에 복사합니다
  Future<void> _copyToClipboard(BuildContext context) async {
    await Clipboard.setData(ClipboardData(text: promptText));
    
    if (context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('프롬프트가 클립보드에 복사되었습니다.'),
          duration: Duration(seconds: 2),
          behavior: SnackBarBehavior.floating,
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    // 프롬프트 통계 계산
    final int charCount = promptText.length;
    final int wordCount = promptText.split(RegExp(r'\s+')).length;
    final int lineCount = promptText.split('\n').length;
    // 대략적인 토큰 수 추정 (영어 기준 4자 = 1토큰, 한글 기준 2자 = 1토큰)
    final int estimatedTokens = (charCount / 2.5).round();

    return Dialog(
      child: Container(
        width: MediaQuery.of(context).size.width * 0.9,
        height: MediaQuery.of(context).size.height * 0.8,
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // === 헤더 ===
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text(
                  '📄 전체 프롬프트 미리보기',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                IconButton(
                  icon: const Icon(Icons.close),
                  onPressed: () => Navigator.pop(context),
                ),
              ],
            ),

            // === 통계 정보 ===
            Container(
              padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 12),
              decoration: BoxDecoration(
                color: Colors.grey[100],
                borderRadius: BorderRadius.circular(8),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceAround,
                children: [
                  _StatItem(label: '글자', value: '$charCount'),
                  _StatItem(label: '단어', value: '$wordCount'),
                  _StatItem(label: '줄', value: '$lineCount'),
                  _StatItem(label: '토큰(추정)', value: '~$estimatedTokens'),
                ],
              ),
            ),

            const SizedBox(height: 12),

            // === 프롬프트 내용 ===
            Expanded(
              child: Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.grey[50],
                  border: Border.all(color: Colors.grey[300]!),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: SingleChildScrollView(
                  child: SelectableText(
                    promptText.isEmpty ? '(프롬프트가 비어있습니다)' : promptText,
                    style: TextStyle(
                      fontFamily: 'monospace',
                      fontSize: 13,
                      color: promptText.isEmpty ? Colors.grey : Colors.black87,
                      height: 1.5,
                    ),
                  ),
                ),
              ),
            ),

            const SizedBox(height: 12),

            // === 하단 버튼 ===
            Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                OutlinedButton.icon(
                  onPressed: () => _copyToClipboard(context),
                  icon: const Icon(Icons.copy, size: 18),
                  label: const Text('복사'),
                ),
                const SizedBox(width: 8),
                ElevatedButton(
                  onPressed: () => Navigator.pop(context),
                  child: const Text('닫기'),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

/// 통계 아이템 위젯
class _StatItem extends StatelessWidget {
  final String label;
  final String value;

  const _StatItem({
    required this.label,
    required this.value,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          value,
          style: const TextStyle(
            fontWeight: FontWeight.bold,
            fontSize: 16,
          ),
        ),
        Text(
          label,
          style: TextStyle(
            color: Colors.grey[600],
            fontSize: 12,
          ),
        ),
      ],
    );
  }
}

/// 도움말 다이얼로그 (명령어 목록)
class CommandHelpDialog extends StatelessWidget {
  const CommandHelpDialog({super.key});

  static Future<void> show(BuildContext context) {
    return showDialog(
      context: context,
      builder: (context) => const CommandHelpDialog(),
    );
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Row(
        children: [
          Icon(Icons.help_outline),
          SizedBox(width: 8),
          Text('명령어 도움말'),
        ],
      ),
      content: SingleChildScrollView(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            _CommandItem(
              command: '/del n',
              description: 'n번째 메시지 삭제',
              example: '/del 3',
            ),
            _CommandItem(
              command: '/del n~m',
              description: 'n~m번째 메시지 범위 삭제',
              example: '/del 1~5',
            ),
            _CommandItem(
              command: '/send 내용',
              description: 'API 호출 없이 메시지 기록만 추가',
              example: '/send 테스트 메시지',
            ),
            _CommandItem(
              command: '/edit n 내용',
              description: 'n번째 메시지 수정',
              example: '/edit 2 수정된 내용',
            ),
            _CommandItem(
              command: '/copy n',
              description: 'n번째 메시지 클립보드 복사',
              example: '/copy 3',
            ),
            _CommandItem(
              command: '/clear',
              description: '현재 대화 전체 삭제',
              example: '/clear',
            ),
            _CommandItem(
              command: '/export',
              description: '현재 대화 JSON 내보내기',
              example: '/export',
            ),
            _CommandItem(
              command: '/help',
              description: '이 도움말 표시',
              example: '/help',
            ),
            const SizedBox(height: 12),
            Text(
              '💡 메시지 번호는 1부터 시작합니다.',
              style: TextStyle(
                color: Colors.grey[600],
                fontSize: 12,
                fontStyle: FontStyle.italic,
              ),
            ),
          ],
        ),
      ),
      actions: [
        ElevatedButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('확인'),
        ),
      ],
    );
  }
}

/// 명령어 아이템 위젯
class _CommandItem extends StatelessWidget {
  final String command;
  final String description;
  final String example;

  const _CommandItem({
    required this.command,
    required this.description,
    required this.example,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                decoration: BoxDecoration(
                  color: Theme.of(context).colorScheme.primaryContainer,
                  borderRadius: BorderRadius.circular(4),
                ),
                child: Text(
                  command,
                  style: TextStyle(
                    fontFamily: 'monospace',
                    fontWeight: FontWeight.bold,
                    color: Theme.of(context).colorScheme.primary,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 4),
          Text(description),
          Text(
            '예: $example',
            style: TextStyle(
              color: Colors.grey[500],
              fontSize: 12,
            ),
          ),
        ],
      ),
    );
  }
}
