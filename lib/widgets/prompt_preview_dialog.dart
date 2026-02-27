import 'package:flutter/material.dart';

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
              '메시지 번호는 1부터 시작합니다.',
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
            style: TextStyle(color: Colors.grey[500], fontSize: 12),
          ),
        ],
      ),
    );
  }
}
