import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../providers/chat_provider.dart';
import '../providers/prompt_block_provider.dart';
import '../services/prompt_builder.dart';
import '../utils/ui_feedback.dart';

class PromptPreviewScreen extends StatefulWidget {
  const PromptPreviewScreen({super.key});

  @override
  State<PromptPreviewScreen> createState() => _PromptPreviewScreenState();
}

class _PromptPreviewScreenState extends State<PromptPreviewScreen> {
  final PromptBuilder _promptBuilder = PromptBuilder();
  final TextEditingController _inputController = TextEditingController();
  String? _selectedPresetId;

  @override
  void dispose() {
    _inputController.dispose();
    super.dispose();
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final provider = context.read<PromptBlockProvider>();
    _selectedPresetId ??= provider.activePresetId ?? provider.presets.first.id;
  }

  @override
  Widget build(BuildContext context) {
    final blockProvider = context.watch<PromptBlockProvider>();
    final chatProvider = context.watch<ChatProvider>();

    if (blockProvider.isLoading || blockProvider.presets.isEmpty) {
      return Scaffold(
        appBar: AppBar(title: const Text('프롬프트 미리보기')),
        body: const Center(child: CircularProgressIndicator()),
      );
    }

    final preset = blockProvider.presets.firstWhere(
      (p) => p.id == _selectedPresetId,
      orElse: () => blockProvider.presets.first,
    );
    final blocks = preset.id == blockProvider.activePresetId
        ? blockProvider.blocks
        : preset.blocks;

    final promptText = _promptBuilder.buildFinalPrompt(
      blocks: blocks,
      pastMessages: chatProvider.messages,
      currentInput: _inputController.text.trim(),
    );

    final int charCount = promptText.length;
    final int estimatedTokens = (charCount / 2.5).round();
    final int messageCount = chatProvider.messages.length;

    return Scaffold(
      appBar: AppBar(
        title: const Text('프롬프트 미리보기'),
      ),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              DropdownButtonFormField<String>(
                value: preset.id,
                decoration: const InputDecoration(
                  labelText: '프리셋 선택',
                  border: OutlineInputBorder(),
                ),
                items: blockProvider.presets
                    .map(
                      (p) => DropdownMenuItem(
                        value: p.id,
                        child: Text(p.name),
                      ),
                    )
                    .toList(),
                onChanged: (value) {
                  if (value == null) return;
                  setState(() => _selectedPresetId = value);
                },
              ),
              const SizedBox(height: 12),
              TextField(
                controller: _inputController,
                decoration: const InputDecoration(
                  labelText: '현재 입력 (미리보기용)',
                  border: OutlineInputBorder(),
                ),
                minLines: 1,
                maxLines: 3,
                onChanged: (_) => setState(() {}),
              ),
              const SizedBox(height: 12),
              Container(
                padding:
                    const EdgeInsets.symmetric(vertical: 8, horizontal: 12),
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
                        color:
                            promptText.isEmpty ? Colors.grey : Colors.black87,
                        height: 1.5,
                      ),
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 12),
              Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  OutlinedButton.icon(
                    onPressed: () => context.copyToClipboard(
                      promptText,
                      successMessage: '프롬프트가 클립보드에 복사되었습니다.',
                    ),
                    icon: const Icon(Icons.copy, size: 18),
                    label: const Text('복사'),
                  ),
                ],
              ),
            ],
          ),
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
