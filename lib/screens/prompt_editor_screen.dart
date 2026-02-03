// ============================================================================
// 프롬프트 편집 화면 (Prompt Editor Screen)
// ============================================================================
// SillyTavern 스타일의 프롬프트 블록 편집 화면입니다.
// 블록 추가/삭제/활성화/재배치 및 내용 편집이 가능합니다.
// ============================================================================

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/prompt_block_provider.dart';
import '../models/prompt_block.dart';
import '../widgets/prompt_preview_dialog.dart';

/// 프롬프트 블록 편집 화면
class PromptEditorScreen extends StatelessWidget {
  const PromptEditorScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('프롬프트 블록 편집'),
        actions: [
          // 미리보기 버튼
          IconButton(
            icon: const Icon(Icons.preview),
            tooltip: '미리보기',
            onPressed: () {
              final provider = Provider.of<PromptBlockProvider>(context, listen: false);
              final preview = provider.buildPreviewText();
              PromptPreviewDialog.show(context, preview);
            },
          ),
          // 블록 추가 버튼
          IconButton(
            icon: const Icon(Icons.add),
            tooltip: '블록 추가',
            onPressed: () => _showAddBlockDialog(context),
          ),
        ],
      ),
      body: Consumer<PromptBlockProvider>(
        builder: (context, provider, child) {
          if (provider.blocks.isEmpty) {
            return _EmptyBlocksPlaceholder(
              onAddBlock: () => _showAddBlockDialog(context),
            );
          }

          return Column(
            children: [
              // === 안내 문구 ===
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(12),
                color: Theme.of(context).colorScheme.primaryContainer.withValues(alpha: 0.3),
                child: Row(
                  children: [
                    Icon(
                      Icons.info_outline,
                      size: 16,
                      color: Theme.of(context).colorScheme.primary,
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        '블록을 길게 눌러 드래그하여 순서를 변경하세요. '
                        '탭하여 편집합니다.',
                        style: TextStyle(
                          fontSize: 12,
                          color: Theme.of(context).colorScheme.primary,
                        ),
                      ),
                    ),
                  ],
                ),
              ),

              // === 블록 목록 (드래그 가능) ===
              Expanded(
                child: ReorderableListView.builder(
                  padding: const EdgeInsets.all(8),
                  itemCount: provider.blocks.length,
                  onReorder: (oldIndex, newIndex) {
                    provider.reorderBlocks(oldIndex, newIndex);
                  },
                  itemBuilder: (context, index) {
                    final block = provider.blocks[index];
                    return _PromptBlockCard(
                      key: ValueKey(block.id),
                      block: block,
                      index: index,
                      onToggle: () => provider.toggleBlock(block.id),
                      onEdit: () => _showEditBlockDialog(context, block),
                      onDelete: () => _confirmDeleteBlock(context, provider, block),
                    );
                  },
                ),
              ),

              // === 하단 정보 바 ===
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.grey[100],
                  border: Border(
                    top: BorderSide(color: Colors.grey[300]!),
                  ),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      '총 ${provider.blocks.length}개 블록 '
                      '(활성: ${provider.blocks.where((b) => b.enabled).length}개)',
                      style: const TextStyle(fontSize: 12),
                    ),
                    Row(
                      children: [
                        const Text('과거 메시지 수: ', style: TextStyle(fontSize: 12)),
                        SizedBox(
                          width: 60,
                          child: TextFormField(
                            initialValue: provider.pastMessageCount.toString(),
                            keyboardType: TextInputType.number,
                            textAlign: TextAlign.center,
                            decoration: const InputDecoration(
                              isDense: true,
                              contentPadding: EdgeInsets.symmetric(
                                horizontal: 8,
                                vertical: 8,
                              ),
                              border: OutlineInputBorder(),
                            ),
                            onChanged: (value) {
                              final count = int.tryParse(value);
                              if (count != null && count >= 0) {
                                provider.setPastMessageCount(count);
                              }
                            },
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ],
          );
        },
      ),
    );
  }

  /// 블록 추가 다이얼로그
  void _showAddBlockDialog(BuildContext context) {
    showDialog(
      context: context,
      builder: (context) => const _AddBlockDialog(),
    );
  }

  /// 블록 편집 다이얼로그
  void _showEditBlockDialog(BuildContext context, PromptBlock block) {
    showDialog(
      context: context,
      builder: (context) => _EditBlockDialog(block: block),
    );
  }

  /// 블록 삭제 확인
  void _confirmDeleteBlock(
    BuildContext context,
    PromptBlockProvider provider,
    PromptBlock block,
  ) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('블록 삭제'),
        content: Text('"${block.name}" 블록을 삭제하시겠습니까?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('취소'),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.red,
              foregroundColor: Colors.white,
            ),
            onPressed: () {
              provider.removeBlock(block.id);
              Navigator.pop(context);
            },
            child: const Text('삭제'),
          ),
        ],
      ),
    );
  }
}

/// 블록 카드 위젯
class _PromptBlockCard extends StatelessWidget {
  final PromptBlock block;
  final int index;
  final VoidCallback onToggle;
  final VoidCallback onEdit;
  final VoidCallback onDelete;

  const _PromptBlockCard({
    super.key,
    required this.block,
    required this.index,
    required this.onToggle,
    required this.onEdit,
    required this.onDelete,
  });

  @override
  Widget build(BuildContext context) {
    // 블록 타입별 아이콘 및 색상
    final (IconData icon, Color color) = switch (block.type) {
      PromptBlock.TYPE_SYSTEM_PROMPT => (Icons.settings, Colors.blue),
      PromptBlock.TYPE_CHARACTER => (Icons.person, Colors.purple),
      PromptBlock.TYPE_PAST_MEMORY => (Icons.history, Colors.orange),
      PromptBlock.TYPE_USER_INPUT => (Icons.edit, Colors.green),
      _ => (Icons.text_snippet, Colors.grey),
    };

    return Card(
      margin: const EdgeInsets.symmetric(vertical: 4),
      elevation: block.enabled ? 2 : 0,
      color: block.enabled ? null : Colors.grey[100],
      child: InkWell(
        onTap: onEdit,
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Row(
            children: [
              // 드래그 핸들
              const Icon(Icons.drag_handle, color: Colors.grey),
              const SizedBox(width: 8),

              // 블록 아이콘
              Container(
                width: 40,
                height: 40,
                decoration: BoxDecoration(
                  color: color.withValues(alpha: block.enabled ? 0.2 : 0.1),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Icon(
                  icon,
                  color: block.enabled ? color : Colors.grey,
                ),
              ),
              const SizedBox(width: 12),

              // 블록 정보
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Text(
                          block.name,
                          style: TextStyle(
                            fontWeight: FontWeight.bold,
                            color: block.enabled ? null : Colors.grey,
                          ),
                        ),
                        const SizedBox(width: 8),
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 6,
                            vertical: 2,
                          ),
                          decoration: BoxDecoration(
                            color: color.withValues(alpha: 0.1),
                            borderRadius: BorderRadius.circular(4),
                          ),
                          child: Text(
                            _getTypeLabel(block.type),
                            style: TextStyle(
                              fontSize: 10,
                              color: color,
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 4),
                    Text(
                      block.content.isEmpty
                          ? '(내용 없음)'
                          : block.content.length > 50
                              ? '${block.content.substring(0, 50)}...'
                              : block.content,
                      style: TextStyle(
                        fontSize: 12,
                        color: Colors.grey[600],
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ),
              ),

              // 활성화 토글
              Switch(
                value: block.enabled,
                onChanged: (_) => onToggle(),
              ),

              // 삭제 버튼
              IconButton(
                icon: const Icon(Icons.delete_outline),
                color: Colors.red[300],
                onPressed: onDelete,
              ),
            ],
          ),
        ),
      ),
    );
  }

  String _getTypeLabel(String type) {
    return switch (type) {
      PromptBlock.TYPE_SYSTEM_PROMPT => '시스템',
      PromptBlock.TYPE_CHARACTER => '캐릭터',
      PromptBlock.TYPE_PAST_MEMORY => '과거기억',
      PromptBlock.TYPE_USER_INPUT => '입력',
      _ => type,
    };
  }
}

/// 빈 블록 플레이스홀더
class _EmptyBlocksPlaceholder extends StatelessWidget {
  final VoidCallback onAddBlock;

  const _EmptyBlocksPlaceholder({required this.onAddBlock});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.inbox_outlined,
            size: 64,
            color: Colors.grey[400],
          ),
          const SizedBox(height: 16),
          Text(
            '프롬프트 블록이 없습니다',
            style: TextStyle(
              fontSize: 18,
              color: Colors.grey[600],
            ),
          ),
          const SizedBox(height: 8),
          Text(
            '블록을 추가하여 프롬프트 구조를 정의하세요',
            style: TextStyle(
              fontSize: 14,
              color: Colors.grey[500],
            ),
          ),
          const SizedBox(height: 24),
          ElevatedButton.icon(
            onPressed: onAddBlock,
            icon: const Icon(Icons.add),
            label: const Text('블록 추가'),
          ),
        ],
      ),
    );
  }
}

/// 블록 추가 다이얼로그
class _AddBlockDialog extends StatefulWidget {
  const _AddBlockDialog();

  @override
  State<_AddBlockDialog> createState() => _AddBlockDialogState();
}

class _AddBlockDialogState extends State<_AddBlockDialog> {
  String _selectedType = PromptBlock.TYPE_SYSTEM_PROMPT;
  final _nameController = TextEditingController();
  final _contentController = TextEditingController();

  @override
  void dispose() {
    _nameController.dispose();
    _contentController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('새 블록 추가'),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // 블록 타입 선택
            const Text('블록 타입', style: TextStyle(fontWeight: FontWeight.bold)),
            const SizedBox(height: 8),
            DropdownButtonFormField<String>(
              value: _selectedType,
              decoration: const InputDecoration(
                border: OutlineInputBorder(),
                isDense: true,
              ),
              items: const [
                DropdownMenuItem(
                  value: PromptBlock.TYPE_SYSTEM_PROMPT,
                  child: Text('시스템 프롬프트'),
                ),
                DropdownMenuItem(
                  value: PromptBlock.TYPE_CHARACTER,
                  child: Text('캐릭터 정의'),
                ),
                DropdownMenuItem(
                  value: PromptBlock.TYPE_PAST_MEMORY,
                  child: Text('과거 기억'),
                ),
                DropdownMenuItem(
                  value: PromptBlock.TYPE_USER_INPUT,
                  child: Text('사용자 입력'),
                ),
              ],
              onChanged: (value) {
                if (value != null) {
                  setState(() => _selectedType = value);
                }
              },
            ),
            const SizedBox(height: 16),

            // 블록 이름
            const Text('블록 이름', style: TextStyle(fontWeight: FontWeight.bold)),
            const SizedBox(height: 8),
            TextField(
              controller: _nameController,
              decoration: InputDecoration(
                border: const OutlineInputBorder(),
                hintText: _getDefaultName(_selectedType),
                isDense: true,
              ),
            ),
            const SizedBox(height: 16),

            // 블록 내용
            const Text('내용', style: TextStyle(fontWeight: FontWeight.bold)),
            const SizedBox(height: 8),
            TextField(
              controller: _contentController,
              maxLines: 5,
              decoration: const InputDecoration(
                border: OutlineInputBorder(),
                hintText: '블록 내용을 입력하세요...',
              ),
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('취소'),
        ),
        ElevatedButton(
          onPressed: _addBlock,
          child: const Text('추가'),
        ),
      ],
    );
  }

  String _getDefaultName(String type) {
    return switch (type) {
      PromptBlock.TYPE_SYSTEM_PROMPT => '시스템 프롬프트',
      PromptBlock.TYPE_CHARACTER => '캐릭터 정의',
      PromptBlock.TYPE_PAST_MEMORY => '과거 기억',
      PromptBlock.TYPE_USER_INPUT => '사용자 입력',
      _ => '새 블록',
    };
  }

  void _addBlock() {
    final provider = Provider.of<PromptBlockProvider>(context, listen: false);
    final name = _nameController.text.trim().isEmpty
        ? _getDefaultName(_selectedType)
        : _nameController.text.trim();

    final block = PromptBlock(
      name: name,
      type: _selectedType,
      content: _contentController.text,
      order: provider.blocks.length,
    );

    provider.addBlock(block);
    Navigator.pop(context);
  }
}

/// 블록 편집 다이얼로그
class _EditBlockDialog extends StatefulWidget {
  final PromptBlock block;

  const _EditBlockDialog({required this.block});

  @override
  State<_EditBlockDialog> createState() => _EditBlockDialogState();
}

class _EditBlockDialogState extends State<_EditBlockDialog> {
  late TextEditingController _nameController;
  late TextEditingController _contentController;

  @override
  void initState() {
    super.initState();
    _nameController = TextEditingController(text: widget.block.name);
    _contentController = TextEditingController(text: widget.block.content);
  }

  @override
  void dispose() {
    _nameController.dispose();
    _contentController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Row(
        children: [
          const Icon(Icons.edit),
          const SizedBox(width: 8),
          Text('블록 편집: ${widget.block.name}'),
        ],
      ),
      content: SizedBox(
        width: MediaQuery.of(context).size.width * 0.8,
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // 블록 이름
              const Text('블록 이름', style: TextStyle(fontWeight: FontWeight.bold)),
              const SizedBox(height: 8),
              TextField(
                controller: _nameController,
                decoration: const InputDecoration(
                  border: OutlineInputBorder(),
                  isDense: true,
                ),
              ),
              const SizedBox(height: 16),

              // 블록 내용
              const Text('내용', style: TextStyle(fontWeight: FontWeight.bold)),
              const SizedBox(height: 8),
              TextField(
                controller: _contentController,
                maxLines: 10,
                decoration: const InputDecoration(
                  border: OutlineInputBorder(),
                  hintText: '블록 내용을 입력하세요...',
                ),
              ),
            ],
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('취소'),
        ),
        ElevatedButton(
          onPressed: _saveBlock,
          child: const Text('저장'),
        ),
      ],
    );
  }

  void _saveBlock() {
    final provider = Provider.of<PromptBlockProvider>(context, listen: false);

    // 이름 업데이트
    if (_nameController.text.trim() != widget.block.name) {
      provider.updateBlockName(widget.block.id, _nameController.text.trim());
    }

    // 내용 업데이트
    if (_contentController.text != widget.block.content) {
      provider.updateBlockContent(widget.block.id, _contentController.text);
    }

    Navigator.pop(context);
  }
}
