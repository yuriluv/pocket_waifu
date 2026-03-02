// ============================================================================
// ============================================================================
// ============================================================================

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/theme_provider.dart';
import '../models/theme_preset.dart';
import '../utils/ui_feedback.dart';

class ThemeEditorScreen extends StatelessWidget {
  const ThemeEditorScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('테마 설정'),
        actions: [
          IconButton(
            icon: const Icon(Icons.add),
            tooltip: '새 테마',
            onPressed: () => _showCreateThemeDialog(context),
          ),
        ],
      ),
      body: Consumer<ThemeProvider>(
        builder: (context, provider, child) {
          return ListView(
            padding: const EdgeInsets.all(16),
            children: [
              _SectionCard(
                title: '테마 모드',
                icon: Icons.brightness_6,
                child: Column(
                  children: [
                    _ThemeModeOption(
                      title: '시스템 설정 따르기',
                      subtitle: '기기의 테마 설정을 따릅니다',
                      icon: Icons.settings_suggest,
                      isSelected: provider.themeMode == ThemeMode.system,
                      onTap: () => provider.setThemeMode(ThemeMode.system),
                    ),
                    const Divider(),
                    _ThemeModeOption(
                      title: '라이트 모드',
                      subtitle: '항상 밝은 테마 사용',
                      icon: Icons.light_mode,
                      isSelected: provider.themeMode == ThemeMode.light,
                      onTap: () => provider.setThemeMode(ThemeMode.light),
                    ),
                    const Divider(),
                    _ThemeModeOption(
                      title: '다크 모드',
                      subtitle: '항상 어두운 테마 사용',
                      icon: Icons.dark_mode,
                      isSelected: provider.themeMode == ThemeMode.dark,
                      onTap: () => provider.setThemeMode(ThemeMode.dark),
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 16),

              _SectionCard(
                title: '테마 프리셋',
                icon: Icons.palette,
                child: Column(
                  children: [
                    ...provider.presets.asMap().entries.map((entry) {
                      final index = entry.key;
                      final preset = entry.value;
                      final isActive = preset.id == provider.activePreset?.id;

                      return Column(
                        children: [
                          if (index > 0) const Divider(),
                          _ThemePresetTile(
                            preset: preset,
                            isActive: isActive,
                            onSelect: () => provider.loadPreset(preset.id),
                            onEdit: preset.isBuiltIn
                                ? null
                                : () => _showEditThemeDialog(context, preset),
                            onDelete: preset.isBuiltIn
                                ? null
                                : () => _confirmDeleteTheme(
                                    context,
                                    provider,
                                    preset,
                                  ),
                          ),
                        ],
                      );
                    }),
                  ],
                ),
              ),

              const SizedBox(height: 16),

              _SectionCard(
                title: '미리보기',
                icon: Icons.preview,
                child: _ThemePreview(provider: provider),
              ),
            ],
          );
        },
      ),
    );
  }

  void _showCreateThemeDialog(BuildContext context) {
    showDialog(
      context: context,
      builder: (context) => const _CreateThemeDialog(),
    );
  }

  void _showEditThemeDialog(BuildContext context, ThemePreset preset) {
    showDialog(
      context: context,
      builder: (context) => _EditThemeDialog(preset: preset),
    );
  }

  void _confirmDeleteTheme(
    BuildContext context,
    ThemeProvider provider,
    ThemePreset preset,
  ) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('테마 삭제'),
        content: Text('"${preset.name}" 테마를 삭제하시겠습니까?'),
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
              provider.deletePreset(preset.id);
              Navigator.pop(context);
            },
            child: const Text('삭제'),
          ),
        ],
      ),
    );
  }
}

class _SectionCard extends StatelessWidget {
  final String title;
  final IconData icon;
  final Widget child;

  const _SectionCard({
    required this.title,
    required this.icon,
    required this.child,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.all(16),
            child: Row(
              children: [
                Icon(icon, color: Theme.of(context).colorScheme.primary),
                const SizedBox(width: 8),
                Text(
                  title,
                  style: const TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
          ),
          const Divider(height: 1),
          Padding(padding: const EdgeInsets.all(8), child: child),
        ],
      ),
    );
  }
}

class _ThemeModeOption extends StatelessWidget {
  final String title;
  final String subtitle;
  final IconData icon;
  final bool isSelected;
  final VoidCallback onTap;

  const _ThemeModeOption({
    required this.title,
    required this.subtitle,
    required this.icon,
    required this.isSelected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return ListTile(
      leading: Icon(
        icon,
        color: isSelected ? Theme.of(context).colorScheme.primary : null,
      ),
      title: Text(
        title,
        style: TextStyle(
          fontWeight: isSelected ? FontWeight.bold : null,
          color: isSelected ? Theme.of(context).colorScheme.primary : null,
        ),
      ),
      subtitle: Text(subtitle),
      trailing: isSelected
          ? Icon(
              Icons.check_circle,
              color: Theme.of(context).colorScheme.primary,
            )
          : null,
      onTap: onTap,
    );
  }
}

class _ThemePresetTile extends StatelessWidget {
  final ThemePreset preset;
  final bool isActive;
  final VoidCallback onSelect;
  final VoidCallback? onEdit;
  final VoidCallback? onDelete;

  const _ThemePresetTile({
    required this.preset,
    required this.isActive,
    required this.onSelect,
    this.onEdit,
    this.onDelete,
  });

  @override
  Widget build(BuildContext context) {
    final primaryColor = Color(
      preset.colorOverrides['primary'] ?? Colors.blue.toARGB32(),
    );

    return ListTile(
      leading: Container(
        width: 40,
        height: 40,
        decoration: BoxDecoration(
          color: primaryColor,
          borderRadius: BorderRadius.circular(8),
          border: isActive
              ? Border.all(
                  color: Theme.of(context).colorScheme.primary,
                  width: 2,
                )
              : null,
        ),
        child: preset.isBuiltIn
            ? const Icon(Icons.palette, color: Colors.white, size: 20)
            : const Icon(Icons.brush, color: Colors.white, size: 20),
      ),
      title: Row(
        children: [
          Flexible(
            child: Text(
              preset.name,
              style: TextStyle(fontWeight: isActive ? FontWeight.bold : null),
              overflow: TextOverflow.ellipsis,
            ),
          ),
          if (preset.isBuiltIn) ...[
            const SizedBox(width: 8),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
              decoration: BoxDecoration(
                color: Colors.grey[200],
                borderRadius: BorderRadius.circular(4),
              ),
              child: Text(
                '기본',
                style: TextStyle(fontSize: 10, color: Colors.grey[600]),
              ),
            ),
          ],
        ],
      ),
      subtitle: preset.description != null ? Text(preset.description!) : null,
      trailing: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (isActive)
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              decoration: BoxDecoration(
                color: Theme.of(context).colorScheme.primary,
                borderRadius: BorderRadius.circular(12),
              ),
              child: const Text(
                '사용 중',
                style: TextStyle(color: Colors.white, fontSize: 12),
              ),
            ),
          if (onEdit != null || onDelete != null)
            PopupMenuButton<String>(
              icon: const Icon(Icons.more_vert),
              onSelected: (value) {
                switch (value) {
                  case 'edit':
                    onEdit?.call();
                    break;
                  case 'delete':
                    onDelete?.call();
                    break;
                }
              },
              itemBuilder: (context) => [
                if (onEdit != null)
                  const PopupMenuItem(
                    value: 'edit',
                    child: Row(
                      children: [
                        Icon(Icons.edit, size: 18),
                        SizedBox(width: 8),
                        Text('편집'),
                      ],
                    ),
                  ),
                if (onDelete != null) ...[
                  const PopupMenuDivider(),
                  const PopupMenuItem(
                    value: 'delete',
                    child: Row(
                      children: [
                        Icon(Icons.delete, size: 18, color: Colors.red),
                        SizedBox(width: 8),
                        Text('삭제', style: TextStyle(color: Colors.red)),
                      ],
                    ),
                  ),
                ],
              ],
            ),
        ],
      ),
      onTap: onSelect,
    );
  }
}

class _ThemePreview extends StatelessWidget {
  final ThemeProvider provider;

  const _ThemePreview({required this.provider});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: Theme.of(context).colorScheme.outlineVariant),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _PreviewMessage(
            isUser: false,
            message: '안녕하세요! 무엇을 도와드릴까요?',
            context: context,
          ),
          const SizedBox(height: 8),
          _PreviewMessage(
            isUser: true,
            message: '테마 설정 미리보기입니다.',
            context: context,
          ),
          const SizedBox(height: 16),

          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              _ColorChip(
                label: 'Primary',
                color: Theme.of(context).colorScheme.primary,
              ),
              _ColorChip(
                label: 'Secondary',
                color: Theme.of(context).colorScheme.secondary,
              ),
              _ColorChip(
                label: 'Surface',
                color: Theme.of(context).colorScheme.surface,
              ),
              _ColorChip(
                label: 'Error',
                color: Theme.of(context).colorScheme.error,
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _PreviewMessage extends StatelessWidget {
  final bool isUser;
  final String message;
  final BuildContext context;

  const _PreviewMessage({
    required this.isUser,
    required this.message,
    required this.context,
  });

  @override
  Widget build(BuildContext context) {
    return Align(
      alignment: isUser ? Alignment.centerRight : Alignment.centerLeft,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        decoration: BoxDecoration(
          color: isUser
              ? Theme.of(context).colorScheme.primary
              : Theme.of(context).colorScheme.surfaceContainerHigh,
          borderRadius: BorderRadius.circular(12),
        ),
        child: Text(
          message,
          style: TextStyle(
            color: isUser
                ? Theme.of(context).colorScheme.onPrimary
                : Theme.of(context).colorScheme.onSurface,
          ),
        ),
      ),
    );
  }
}

class _ColorChip extends StatelessWidget {
  final String label;
  final Color color;

  const _ColorChip({required this.label, required this.color});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: color,
        borderRadius: BorderRadius.circular(4),
      ),
      child: Text(
        label,
        style: TextStyle(
          color: color.computeLuminance() > 0.5 ? Colors.black : Colors.white,
          fontSize: 12,
        ),
      ),
    );
  }
}

class _CreateThemeDialog extends StatefulWidget {
  const _CreateThemeDialog();

  @override
  State<_CreateThemeDialog> createState() => _CreateThemeDialogState();
}

class _CreateThemeDialogState extends State<_CreateThemeDialog> {
  final _nameController = TextEditingController();
  final _descController = TextEditingController();
  Color _primaryColor = Colors.blue;
  Color _secondaryColor = Colors.teal;

  @override
  void dispose() {
    _nameController.dispose();
    _descController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('새 테마 만들기'),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            TextField(
              controller: _nameController,
              decoration: const InputDecoration(
                labelText: '테마 이름',
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _descController,
              decoration: const InputDecoration(
                labelText: '설명 (선택)',
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 16),
            const Text('기본 색상', style: TextStyle(fontWeight: FontWeight.bold)),
            const SizedBox(height: 8),
            _ColorPicker(
              label: 'Primary',
              color: _primaryColor,
              onColorSelected: (color) => setState(() => _primaryColor = color),
            ),
            const SizedBox(height: 8),
            _ColorPicker(
              label: 'Secondary',
              color: _secondaryColor,
              onColorSelected: (color) =>
                  setState(() => _secondaryColor = color),
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('취소'),
        ),
        ElevatedButton(onPressed: _createTheme, child: const Text('생성')),
      ],
    );
  }

  void _createTheme() {
    if (_nameController.text.trim().isEmpty) {
      context.showErrorSnackBar('테마 이름을 입력하세요');
      return;
    }

    final provider = Provider.of<ThemeProvider>(context, listen: false);
    final preset = ThemePreset(
      name: _nameController.text.trim(),
      description: _descController.text.trim().isEmpty
          ? null
          : _descController.text.trim(),
      colorOverrides: {
        'primary': _primaryColor.toARGB32(),
        'secondary': _secondaryColor.toARGB32(),
      },
    );

    provider.savePreset(preset);
    Navigator.pop(context);
  }
}

class _EditThemeDialog extends StatefulWidget {
  final ThemePreset preset;

  const _EditThemeDialog({required this.preset});

  @override
  State<_EditThemeDialog> createState() => _EditThemeDialogState();
}

class _EditThemeDialogState extends State<_EditThemeDialog> {
  late TextEditingController _nameController;
  late TextEditingController _descController;
  late Color _primaryColor;
  late Color _secondaryColor;

  @override
  void initState() {
    super.initState();
    _nameController = TextEditingController(text: widget.preset.name);
    _descController = TextEditingController(
      text: widget.preset.description ?? '',
    );
    _primaryColor = Color(
      widget.preset.colorOverrides['primary'] ?? Colors.blue.toARGB32(),
    );
    _secondaryColor = Color(
      widget.preset.colorOverrides['secondary'] ?? Colors.teal.toARGB32(),
    );
  }

  @override
  void dispose() {
    _nameController.dispose();
    _descController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text('테마 편집: ${widget.preset.name}'),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            TextField(
              controller: _nameController,
              decoration: const InputDecoration(
                labelText: '테마 이름',
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _descController,
              decoration: const InputDecoration(
                labelText: '설명 (선택)',
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 16),
            const Text('기본 색상', style: TextStyle(fontWeight: FontWeight.bold)),
            const SizedBox(height: 8),
            _ColorPicker(
              label: 'Primary',
              color: _primaryColor,
              onColorSelected: (color) => setState(() => _primaryColor = color),
            ),
            const SizedBox(height: 8),
            _ColorPicker(
              label: 'Secondary',
              color: _secondaryColor,
              onColorSelected: (color) =>
                  setState(() => _secondaryColor = color),
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('취소'),
        ),
        ElevatedButton(onPressed: _saveTheme, child: const Text('저장')),
      ],
    );
  }

  void _saveTheme() {
    if (_nameController.text.trim().isEmpty) {
      context.showErrorSnackBar('테마 이름을 입력하세요');
      return;
    }

    final provider = Provider.of<ThemeProvider>(context, listen: false);
    final updatedPreset = widget.preset.copyWith(
      name: _nameController.text.trim(),
      description: _descController.text.trim().isEmpty
          ? null
          : _descController.text.trim(),
      colorOverrides: {
        'primary': _primaryColor.toARGB32(),
        'secondary': _secondaryColor.toARGB32(),
      },
    );

    provider.savePreset(updatedPreset);
    Navigator.pop(context);
  }
}

class _ColorPicker extends StatelessWidget {
  final String label;
  final Color color;
  final ValueChanged<Color> onColorSelected;

  const _ColorPicker({
    required this.label,
    required this.color,
    required this.onColorSelected,
  });

  static const List<Color> _colors = [
    Colors.red,
    Colors.pink,
    Colors.purple,
    Colors.deepPurple,
    Colors.indigo,
    Colors.blue,
    Colors.lightBlue,
    Colors.cyan,
    Colors.teal,
    Colors.green,
    Colors.lightGreen,
    Colors.lime,
    Colors.yellow,
    Colors.amber,
    Colors.orange,
    Colors.deepOrange,
    Colors.brown,
    Colors.grey,
    Colors.blueGrey,
  ];

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Container(
              width: 24,
              height: 24,
              decoration: BoxDecoration(
                color: color,
                borderRadius: BorderRadius.circular(4),
                border: Border.all(color: Colors.grey),
              ),
            ),
            const SizedBox(width: 8),
            Text(label),
          ],
        ),
        const SizedBox(height: 8),
        Wrap(
          spacing: 4,
          runSpacing: 4,
          children: _colors.map((c) {
            return GestureDetector(
              onTap: () => onColorSelected(c),
              child: Container(
                width: 28,
                height: 28,
                decoration: BoxDecoration(
                  color: c,
                  borderRadius: BorderRadius.circular(4),
                  border: color == c
                      ? Border.all(color: Colors.black, width: 2)
                      : null,
                ),
              ),
            );
          }).toList(),
        ),
      ],
    );
  }
}
