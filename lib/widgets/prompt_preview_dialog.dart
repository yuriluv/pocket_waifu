// ============================================================================
// ============================================================================
// ============================================================================

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import '../providers/chat_provider.dart';
import '../providers/prompt_block_provider.dart';
import '../models/message.dart';

class PromptPreviewDialog extends StatefulWidget {
  final String promptText;

  const PromptPreviewDialog({super.key, required this.promptText});

  static Future<void> show(BuildContext context, String promptText) {
    return showDialog(
      context: context,
      builder: (context) => PromptPreviewDialog(promptText: promptText),
    );
  }

  static Future<void> showWithRealPrompt(BuildContext context) {
    return showDialog(
      context: context,
      builder: (context) => const _RealPromptPreviewDialog(),
    );
  }

  @override
  State<PromptPreviewDialog> createState() => _PromptPreviewDialogState();
}

class _PromptPreviewDialogState extends State<PromptPreviewDialog> {
  Future<void> _copyToClipboard(BuildContext context) async {
    await Clipboard.setData(ClipboardData(text: widget.promptText));

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
    final int charCount = widget.promptText.length;
    final int wordCount = widget.promptText.split(RegExp(r'\s+')).length;
    final int lineCount = widget.promptText.split('\n').length;
    final int estimatedTokens = (charCount / 2.5).round();

    return Dialog(
      child: Container(
        width: MediaQuery.of(context).size.width * 0.9,
        height: MediaQuery.of(context).size.height * 0.8,
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Expanded(
                  child: Text(
                    '📄 프롬프트 블록 미리보기',
                    style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                IconButton(
                  icon: const Icon(Icons.close),
                  onPressed: () => Navigator.pop(context),
                ),
              ],
            ),

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
                    widget.promptText.isEmpty
                        ? '(프롬프트가 비어있습니다)'
                        : widget.promptText,
                    style: TextStyle(
                      fontFamily: 'monospace',
                      fontSize: 13,
                      color: widget.promptText.isEmpty
                          ? Colors.grey
                          : Colors.black87,
                      height: 1.5,
                    ),
                  ),
                ),
              ),
            ),

            const SizedBox(height: 12),

            Wrap(
              alignment: WrapAlignment.end,
              spacing: 8,
              runSpacing: 8,
              children: [
                OutlinedButton.icon(
                  onPressed: () => _copyToClipboard(context),
                  icon: const Icon(Icons.copy, size: 18),
                  label: const Text('복사'),
                ),
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

class _RealPromptPreviewDialog extends StatefulWidget {
  const _RealPromptPreviewDialog();

  @override
  State<_RealPromptPreviewDialog> createState() =>
      _RealPromptPreviewDialogState();
}

class _RealPromptPreviewDialogState extends State<_RealPromptPreviewDialog> {
  bool _includePastMemory = true;

  String _buildPreviewText(
    PromptBlockProvider blockProvider,
    ChatProvider chatProvider,
  ) {
    final blocks = blockProvider.blocks.where((b) => b.isEnabled).toList()
      ..sort((a, b) => a.order.compareTo(b.order));

    final StringBuffer buffer = StringBuffer();
    final pastMessages = _includePastMemory
        ? chatProvider.messages
        : <Message>[];
    final pastCount = blockProvider.pastMessageCount;

    for (final block in blocks) {
      if (block.type == 'past_memory') {
        if (_includePastMemory && pastMessages.isNotEmpty) {
          buffer.writeln('[과거 대화]');
          final recentMessages = pastMessages.length > pastCount
              ? pastMessages.sublist(pastMessages.length - pastCount)
              : pastMessages;
          for (final msg in recentMessages) {
            final role = msg.role == MessageRole.user ? 'User' : 'Assistant';
            buffer.writeln('$role: ${msg.content}');
          }
        } else {
          buffer.writeln('[과거 대화]');
          buffer.writeln('(과거 기억 미포함)');
        }
      } else if (block.type == 'user_input') {
        buffer.writeln('[사용자 입력]');
        buffer.writeln('(현재 입력 위치)');
      } else {
        if (block.content.isNotEmpty) {
          buffer.writeln(block.content);
        }
      }
      buffer.writeln();
    }

    return buffer.toString().trim();
  }

  Future<void> _copyToClipboard(String text) async {
    await Clipboard.setData(ClipboardData(text: text));
    if (mounted) {
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
    final blockProvider = context.watch<PromptBlockProvider>();
    final chatProvider = context.watch<ChatProvider>();
    final promptText = _buildPreviewText(blockProvider, chatProvider);

    final int charCount = promptText.length;
    final int estimatedTokens = (charCount / 2.5).round();
    final int messageCount = chatProvider.messages.length;

    return Dialog(
      child: Container(
        width: MediaQuery.of(context).size.width * 0.9,
        height: MediaQuery.of(context).size.height * 0.85,
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Expanded(
                  child: Text(
                    '📄 API 전송 프롬프트 미리보기',
                    style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                IconButton(
                  icon: const Icon(Icons.close),
                  onPressed: () => Navigator.pop(context),
                ),
              ],
            ),

            Container(
              padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 12),
              margin: const EdgeInsets.only(bottom: 8),
              decoration: BoxDecoration(
                color: _includePastMemory
                    ? Colors.blue.withValues(alpha: 0.1)
                    : Colors.grey[100],
                borderRadius: BorderRadius.circular(8),
                border: Border.all(
                  color: _includePastMemory ? Colors.blue : Colors.grey[300]!,
                ),
              ),
              child: Row(
                children: [
                  Icon(
                    _includePastMemory
                        ? Icons.history
                        : Icons.history_toggle_off,
                    color: _includePastMemory ? Colors.blue : Colors.grey,
                    size: 20,
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      '과거 기억 반영 ($messageCount개 메시지 중 ${blockProvider.pastMessageCount}개)',
                      style: TextStyle(
                        fontSize: 13,
                        color: _includePastMemory
                            ? Colors.blue[800]
                            : Colors.grey[600],
                      ),
                    ),
                  ),
                  Switch(
                    value: _includePastMemory,
                    onChanged: (value) {
                      setState(() => _includePastMemory = value);
                    },
                  ),
                ],
              ),
            ),

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
                  _StatItem(label: '토큰(추정)', value: '~$estimatedTokens'),
                  _StatItem(label: '메시지', value: '$messageCount'),
                ],
              ),
            ),

            const SizedBox(height: 12),

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

            Wrap(
              alignment: WrapAlignment.end,
              spacing: 8,
              runSpacing: 8,
              children: [
                OutlinedButton.icon(
                  onPressed: () => _copyToClipboard(promptText),
                  icon: const Icon(Icons.copy, size: 18),
                  label: const Text('복사'),
                ),
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

class _StatItem extends StatelessWidget {
  final String label;
  final String value;

  const _StatItem({required this.label, required this.value});

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          value,
          style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
        ),
        Text(label, style: TextStyle(color: Colors.grey[600], fontSize: 12)),
      ],
    );
  }
}

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
