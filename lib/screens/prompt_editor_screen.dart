// ============================================================================
// ============================================================================
// ============================================================================

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/prompt_block_provider.dart';
import '../models/prompt_block.dart';
import '../models/prompt_preset.dart';
import 'prompt_preview_screen.dart';
import '../utils/ui_feedback.dart';

class PromptEditorScreen extends StatelessWidget {
  const PromptEditorScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('프롬프트 블록 편집'),
        actions: [
          IconButton(
            icon: const Icon(Icons.preview),
            tooltip: '미리보기',
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (context) => const PromptPreviewScreen(),
                ),
              );
            },
          ),
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
            return Column(
              children: [
                Expanded(
                  child: _EmptyBlocksPlaceholder(
                    onAddBlock: () => _showAddBlockDialog(context),
                  ),
                ),
                _PresetBar(provider: provider),
              ],
            );
          }

          return Column(
            children: [
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(12),
                color: Theme.of(
                  context,
                ).colorScheme.primaryContainer.withValues(alpha: 0.3),
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
                      onToggle: () => provider.toggleBlock(block.id),
                      onEdit: () => _showEditBlockDialog(context, block),
                      onDuplicate: () => provider.duplicateBlock(block.id),
                      onDelete: () =>
                          _confirmDeleteBlock(context, provider, block),
                    );
                  },
                ),
              ),

              _PresetBar(provider: provider),
            ],
          );
        },
      ),
    );
  }

  void _showAddBlockDialog(BuildContext context) {
    showDialog(context: context, builder: (context) => const _AddBlockDialog());
  }

  void _showEditBlockDialog(BuildContext context, PromptBlock block) {
    showDialog(
      context: context,
      builder: (context) => _EditBlockDialog(block: block),
    );
  }

  void _confirmDeleteBlock(
    BuildContext context,
    PromptBlockProvider provider,
    PromptBlock block,
  ) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('블록 삭제'),
        content: Text('"${block.title}" 블록을 삭제하시겠습니까?'),
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

class _PromptBlockCard extends StatelessWidget {
  final PromptBlock block;
  final VoidCallback onToggle;
  final VoidCallback onEdit;
  final VoidCallback onDuplicate;
  final VoidCallback onDelete;

  const _PromptBlockCard({
    super.key,
    required this.block,
    required this.onToggle,
    required this.onEdit,
    required this.onDuplicate,
    required this.onDelete,
  });

  @override
  Widget build(BuildContext context) {
    final (IconData icon, Color color) = switch (block.type) {
      PromptBlock.typePrompt => (Icons.text_snippet, Colors.blue),
      PromptBlock.typePastMemory => (Icons.history, Colors.orange),
      PromptBlock.typeInput => (Icons.edit, Colors.green),
      _ => (Icons.text_snippet, Colors.grey),
    };

    return Card(
      margin: const EdgeInsets.symmetric(vertical: 4),
      elevation: block.isActive ? 2 : 0,
      color: block.isActive ? null : Colors.grey[100],
      child: InkWell(
        onTap: onEdit,
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Row(
            children: [
              const Icon(Icons.drag_handle, color: Colors.grey),
              const SizedBox(width: 8),

              Container(
                width: 40,
                height: 40,
                decoration: BoxDecoration(
                  color: color.withValues(alpha: block.isActive ? 0.2 : 0.1),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Icon(icon, color: block.isActive ? color : Colors.grey),
              ),
              const SizedBox(width: 12),

              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Flexible(
                          child: Text(
                            block.title,
                            style: TextStyle(
                              fontWeight: FontWeight.bold,
                              color: block.isActive ? null : Colors.grey,
                            ),
                            overflow: TextOverflow.ellipsis,
                            maxLines: 1,
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
                            style: TextStyle(fontSize: 10, color: color),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 4),
                    Text(
                      _buildSubtitle(block),
                      style: TextStyle(
                        fontSize: 12,
                        color: Colors.grey[600],
                        fontStyle: block.type == PromptBlock.typePrompt
                            ? FontStyle.normal
                            : FontStyle.italic,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ),
              ),

              Switch(value: block.isActive, onChanged: (_) => onToggle()),

              IconButton(
                icon: const Icon(Icons.copy_outlined),
                tooltip: '복제',
                onPressed: onDuplicate,
              ),

              IconButton(
                icon: const Icon(Icons.delete_outline),
                color: Colors.red[300],
                onPressed: onDelete,
                tooltip: '삭제',
              ),
            ],
          ),
        ),
      ),
    );
  }

  String _getTypeLabel(String type) {
    return switch (type) {
      PromptBlock.typePrompt => '프롬프트',
      PromptBlock.typePastMemory => '과거기억',
      PromptBlock.typeInput => '입력',
      _ => type,
    };
  }

  String _buildSubtitle(PromptBlock block) {
    if (block.type == PromptBlock.typePastMemory) {
      return 'range=${block.range}, <${block.userHeader}>, <${block.charHeader}>';
    }
    if (block.type == PromptBlock.typeInput) {
      return '(사용자 입력 위치)';
    }
    if (block.content.isEmpty) {
      return '(내용 없음)';
    }
    return block.content.length > 50
        ? '${block.content.substring(0, 50)}...'
        : block.content;
  }
}

class _EmptyBlocksPlaceholder extends StatelessWidget {
  final VoidCallback onAddBlock;

  const _EmptyBlocksPlaceholder({required this.onAddBlock});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.inbox_outlined, size: 64, color: Colors.grey[400]),
          const SizedBox(height: 16),
          Text(
            '프롬프트 블록이 없습니다',
            style: TextStyle(fontSize: 18, color: Colors.grey[600]),
          ),
          const SizedBox(height: 8),
          Text(
            '블록을 추가하여 프롬프트 구조를 정의하세요',
            style: TextStyle(fontSize: 14, color: Colors.grey[500]),
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

class _PresetBar extends StatelessWidget {
  final PromptBlockProvider provider;

  const _PresetBar({required this.provider});

  @override
  Widget build(BuildContext context) {
    final activeId = provider.activePresetId;
    final activePreset = provider.activePreset;

    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.grey[100],
        border: Border(top: BorderSide(color: Colors.grey[300]!)),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            children: [
              Expanded(
                child: DropdownButtonFormField<String>(
                  value: activeId,
                  decoration: const InputDecoration(
                    border: OutlineInputBorder(),
                    isDense: true,
                    labelText: '프리셋 선택',
                  ),
                  items: provider.presets
                      .map(
                        (preset) => DropdownMenuItem(
                          value: preset.id,
                          child: Text(preset.name),
                        ),
                      )
                      .toList(),
                  onChanged: (value) =>
                      _handlePresetSwitch(context, value, provider),
                ),
              ),
              const SizedBox(width: 8),
              PopupMenuButton<_PresetMenuAction>(
                tooltip: '프리셋 추가 옵션',
                onSelected: (action) =>
                    _handlePresetMenuAction(context, provider, action),
                itemBuilder: (context) => const [
                  PopupMenuItem(
                    value: _PresetMenuAction.rename,
                    child: Text('이름 변경'),
                  ),
                  PopupMenuItem(
                    value: _PresetMenuAction.export,
                    child: Text('내보내기'),
                  ),
                  PopupMenuItem(
                    value: _PresetMenuAction.import,
                    child: Text('가져오기'),
                  ),
                ],
              ),
            ],
          ),
          const SizedBox(height: 8),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                '총 ${provider.blocks.length}개 블록 '
                '(활성: ${provider.blocks.where((b) => b.isActive).length}개)',
                style: const TextStyle(fontSize: 12),
              ),
              Wrap(
                spacing: 8,
                children: [
                  OutlinedButton(
                    onPressed: activePreset == null
                        ? null
                        : () {
                            provider.saveActivePreset();
                            context.showInfoSnackBar('프리셋이 저장되었습니다.');
                          },
                    child: const Text('저장'),
                  ),
                  OutlinedButton(
                    onPressed: () => _showAddPresetDialog(context, provider),
                    child: const Text('추가'),
                  ),
                  OutlinedButton(
                    onPressed: activePreset == null
                        ? null
                        : () => _confirmDeletePreset(
                              context,
                              provider,
                              activePreset,
                            ),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: Colors.red,
                    ),
                    child: const Text('삭제'),
                  ),
                ],
              ),
            ],
          ),
          if (provider.hasUnsavedChanges)
            Align(
              alignment: Alignment.centerLeft,
              child: Padding(
                padding: const EdgeInsets.only(top: 6),
                child: Text(
                  '저장되지 않은 변경사항이 있습니다.',
                  style: TextStyle(fontSize: 11, color: Colors.orange[700]),
                ),
              ),
            ),
        ],
      ),
    );
  }

  Future<void> _handlePresetSwitch(
    BuildContext context,
    String? targetId,
    PromptBlockProvider provider,
  ) async {
    if (targetId == null || targetId == provider.activePresetId) return;

    if (!provider.hasUnsavedChanges) {
      provider.setActivePreset(targetId);
      return;
    }

    final action = await showDialog<_PresetSwitchAction>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('변경사항 저장'),
        content: const Text(
          '저장되지 않은 변경사항이 있습니다. 프리셋 전환 전에 저장할까요?',
        ),
        actions: [
          TextButton(
            onPressed: () =>
                Navigator.pop(context, _PresetSwitchAction.cancel),
            child: const Text('취소'),
          ),
          TextButton(
            onPressed: () =>
                Navigator.pop(context, _PresetSwitchAction.discard),
            child: const Text('저장 안 함'),
          ),
          ElevatedButton(
            onPressed: () =>
                Navigator.pop(context, _PresetSwitchAction.save),
            child: const Text('저장'),
          ),
        ],
      ),
    );

    if (action == _PresetSwitchAction.save) {
      provider.saveActivePreset();
      provider.setActivePreset(targetId);
      context.showInfoSnackBar('프리셋이 저장되고 전환되었습니다.');
    } else if (action == _PresetSwitchAction.discard) {
      provider.setActivePreset(targetId);
    }
  }

  Future<void> _showAddPresetDialog(
    BuildContext context,
    PromptBlockProvider provider,
  ) async {
    final controller = TextEditingController();
    final result = await showDialog<String>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('새 프리셋 추가'),
        content: TextField(
          controller: controller,
          decoration: const InputDecoration(
            border: OutlineInputBorder(),
            hintText: '프리셋 이름',
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('취소'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, controller.text.trim()),
            child: const Text('추가'),
          ),
        ],
      ),
    );

    if (result != null) {
      provider.addPreset(result);
      context.showInfoSnackBar('프리셋이 추가되었습니다.');
    }
  }

  Future<void> _confirmDeletePreset(
    BuildContext context,
    PromptBlockProvider provider,
    PromptPreset preset,
  ) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('프리셋 삭제'),
        content: Text('"${preset.name}" 프리셋을 삭제하시겠습니까?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('취소'),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.red,
              foregroundColor: Colors.white,
            ),
            onPressed: () => Navigator.pop(context, true),
            child: const Text('삭제'),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      final success = provider.deletePreset(preset.id);
      if (!success) {
        context.showErrorSnackBar('최소 1개의 프리셋은 유지되어야 합니다.');
      } else {
        context.showInfoSnackBar('프리셋이 삭제되었습니다.');
      }
    }
  }

  Future<void> _handlePresetMenuAction(
    BuildContext context,
    PromptBlockProvider provider,
    _PresetMenuAction action,
  ) async {
    if (action == _PresetMenuAction.rename) {
      final preset = provider.activePreset;
      if (preset == null) return;
      final controller = TextEditingController(text: preset.name);
      final name = await showDialog<String>(
        context: context,
        builder: (context) => AlertDialog(
          title: const Text('프리셋 이름 변경'),
          content: TextField(
            controller: controller,
            decoration: const InputDecoration(
              border: OutlineInputBorder(),
              hintText: '프리셋 이름',
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('취소'),
            ),
            ElevatedButton(
              onPressed: () => Navigator.pop(context, controller.text.trim()),
              child: const Text('저장'),
            ),
          ],
        ),
      );

      if (name != null) {
        provider.renamePreset(preset.id, name);
        context.showInfoSnackBar('프리셋 이름이 변경되었습니다.');
      }
    } else if (action == _PresetMenuAction.export) {
      final preset = provider.activePreset;
      if (preset == null) return;
      final (success, error) = await provider.exportPresetToFile(preset);
      if (!context.mounted) return;
      if (success) {
        context.showInfoSnackBar('프리셋을 내보냈습니다.');
      } else {
        context.showErrorSnackBar(error ?? '내보내기 실패');
      }
    } else if (action == _PresetMenuAction.import) {
      final (success, error) = await provider.importPresetFromFile();
      if (!context.mounted) return;
      if (success) {
        context.showInfoSnackBar('프리셋을 가져왔습니다.');
      } else {
        context.showErrorSnackBar(error ?? '가져오기 실패');
      }
    }
  }
}

enum _PresetSwitchAction { save, discard, cancel }

enum _PresetMenuAction { rename, export, import }

class _AddBlockDialog extends StatefulWidget {
  const _AddBlockDialog();

  @override
  State<_AddBlockDialog> createState() => _AddBlockDialogState();
}

class _AddBlockDialogState extends State<_AddBlockDialog> {
  String _selectedType = PromptBlock.typePrompt;
  final _titleController = TextEditingController();
  final _contentController = TextEditingController();
  final _rangeController = TextEditingController(text: '10');
  final _userHeaderController = TextEditingController(text: 'user');
  final _charHeaderController = TextEditingController(text: 'char');

  @override
  void dispose() {
    _titleController.dispose();
    _contentController.dispose();
    _rangeController.dispose();
    _userHeaderController.dispose();
    _charHeaderController.dispose();
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
                  value: PromptBlock.typePrompt,
                  child: Text('프롬프트'),
                ),
                DropdownMenuItem(
                  value: PromptBlock.typePastMemory,
                  child: Text('과거 기억'),
                ),
                DropdownMenuItem(
                  value: PromptBlock.typeInput,
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

            const Text('블록 이름', style: TextStyle(fontWeight: FontWeight.bold)),
            const SizedBox(height: 8),
            TextField(
              controller: _titleController,
              decoration: InputDecoration(
                border: const OutlineInputBorder(),
                hintText: _getDefaultName(_selectedType),
                isDense: true,
              ),
            ),
            const SizedBox(height: 16),

            if (_selectedType == PromptBlock.typePrompt) ...[
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

            if (_selectedType == PromptBlock.typePastMemory) ...[
              const Text('과거 메시지 범위', style: TextStyle(fontWeight: FontWeight.bold)),
              const SizedBox(height: 8),
              TextField(
                controller: _rangeController,
                keyboardType: TextInputType.number,
                decoration: const InputDecoration(
                  border: OutlineInputBorder(),
                  hintText: '예: 10',
                ),
              ),
              const SizedBox(height: 12),
              const Text('사용자 헤더', style: TextStyle(fontWeight: FontWeight.bold)),
              const SizedBox(height: 8),
              TextField(
                controller: _userHeaderController,
                decoration: const InputDecoration(
                  border: OutlineInputBorder(),
                  hintText: 'user',
                ),
              ),
              const SizedBox(height: 12),
              const Text('캐릭터 헤더', style: TextStyle(fontWeight: FontWeight.bold)),
              const SizedBox(height: 8),
              TextField(
                controller: _charHeaderController,
                decoration: const InputDecoration(
                  border: OutlineInputBorder(),
                  hintText: 'char',
                ),
              ),
            ],
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('취소'),
        ),
        ElevatedButton(onPressed: _addBlock, child: const Text('추가')),
      ],
    );
  }

  String _getDefaultName(String type) {
    return switch (type) {
      PromptBlock.typePrompt => '프롬프트',
      PromptBlock.typePastMemory => '과거 기억',
      PromptBlock.typeInput => '사용자 입력',
      _ => '새 블록',
    };
  }

  void _addBlock() {
    final provider = Provider.of<PromptBlockProvider>(context, listen: false);
    final title = _titleController.text.trim().isEmpty
        ? _getDefaultName(_selectedType)
        : _titleController.text.trim();

    PromptBlock block;
    if (_selectedType == PromptBlock.typePastMemory) {
      block = PromptBlock.pastMemory(
        title: title,
        range: _rangeController.text.trim().isEmpty
            ? '1'
            : _rangeController.text.trim(),
        userHeader: _userHeaderController.text.trim().isEmpty
            ? 'user'
            : _userHeaderController.text.trim(),
        charHeader: _charHeaderController.text.trim().isEmpty
            ? 'char'
            : _charHeaderController.text.trim(),
      );
    } else if (_selectedType == PromptBlock.typeInput) {
      block = PromptBlock.input(title: title);
    } else {
      block = PromptBlock.prompt(title: title, content: _contentController.text);
    }

    provider.addBlock(block);
    Navigator.pop(context);
  }
}

class _EditBlockDialog extends StatefulWidget {
  final PromptBlock block;

  const _EditBlockDialog({required this.block});

  @override
  State<_EditBlockDialog> createState() => _EditBlockDialogState();
}

class _EditBlockDialogState extends State<_EditBlockDialog> {
  late TextEditingController _titleController;
  late TextEditingController _contentController;
  late TextEditingController _rangeController;
  late TextEditingController _userHeaderController;
  late TextEditingController _charHeaderController;

  @override
  void initState() {
    super.initState();
    _titleController = TextEditingController(text: widget.block.title);
    _contentController = TextEditingController(text: widget.block.content);
    _rangeController = TextEditingController(text: widget.block.range);
    _userHeaderController = TextEditingController(text: widget.block.userHeader);
    _charHeaderController = TextEditingController(text: widget.block.charHeader);
  }

  @override
  void dispose() {
    _titleController.dispose();
    _contentController.dispose();
    _rangeController.dispose();
    _userHeaderController.dispose();
    _charHeaderController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Row(
        children: [
          const Icon(Icons.edit),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              '블록 편집: ${widget.block.title}',
              overflow: TextOverflow.ellipsis,
            ),
          ),
        ],
      ),
      content: SizedBox(
        width: MediaQuery.of(context).size.width * 0.8,
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                '블록 이름',
                style: TextStyle(fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 8),
              TextField(
                controller: _titleController,
                decoration: const InputDecoration(
                  border: OutlineInputBorder(),
                  isDense: true,
                ),
              ),
              const SizedBox(height: 16),

              if (widget.block.type == PromptBlock.typePrompt) ...[
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

              if (widget.block.type == PromptBlock.typePastMemory) ...[
                const Text('과거 메시지 범위', style: TextStyle(fontWeight: FontWeight.bold)),
                const SizedBox(height: 8),
                TextField(
                  controller: _rangeController,
                  keyboardType: TextInputType.number,
                  decoration: const InputDecoration(
                    border: OutlineInputBorder(),
                    hintText: '예: 10',
                  ),
                ),
                const SizedBox(height: 12),
                const Text('사용자 헤더', style: TextStyle(fontWeight: FontWeight.bold)),
                const SizedBox(height: 8),
                TextField(
                  controller: _userHeaderController,
                  decoration: const InputDecoration(
                    border: OutlineInputBorder(),
                    hintText: 'user',
                  ),
                ),
                const SizedBox(height: 12),
                const Text('캐릭터 헤더', style: TextStyle(fontWeight: FontWeight.bold)),
                const SizedBox(height: 8),
                TextField(
                  controller: _charHeaderController,
                  decoration: const InputDecoration(
                    border: OutlineInputBorder(),
                    hintText: 'char',
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('취소'),
        ),
        ElevatedButton(onPressed: _saveBlock, child: const Text('저장')),
      ],
    );
  }

  void _saveBlock() {
    final provider = Provider.of<PromptBlockProvider>(context, listen: false);

    if (_titleController.text.trim() != widget.block.title) {
      provider.updateBlockTitle(widget.block.id, _titleController.text.trim());
    }

    if (widget.block.type == PromptBlock.typePrompt &&
        _contentController.text != widget.block.content) {
      provider.updateBlockContent(widget.block.id, _contentController.text);
    }

    if (widget.block.type == PromptBlock.typePastMemory) {
      if (_rangeController.text != widget.block.range) {
        provider.updatePastMemoryRange(widget.block.id, _rangeController.text);
      }
      if (_userHeaderController.text != widget.block.userHeader ||
          _charHeaderController.text != widget.block.charHeader) {
        provider.updatePastMemoryHeaders(
          widget.block.id,
          _userHeaderController.text,
          _charHeaderController.text,
        );
      }
    }

    Navigator.pop(context);
  }
}
