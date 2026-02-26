// ============================================================================
// ============================================================================
// ============================================================================

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

class MessageActionIcons extends StatelessWidget {
  final String messageContent;
  final int messageIndex;
  final VoidCallback onEdit;
  final VoidCallback onDelete;
  final bool showEdit;

  const MessageActionIcons({
    super.key,
    required this.messageContent,
    required this.messageIndex,
    required this.onEdit,
    required this.onDelete,
    this.showEdit = true,
  });

  Future<void> _copyToClipboard(BuildContext context) async {
    await Clipboard.setData(ClipboardData(text: messageContent));
    
    if (context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('$messageIndex번 메시지를 클립보드에 복사했습니다.'),
          duration: const Duration(seconds: 2),
          behavior: SnackBarBehavior.floating,
        ),
      );
    }
  }

  Future<void> _showDeleteConfirmDialog(BuildContext context) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('메시지 삭제'),
        content: Text('$messageIndex번 메시지를 정말 삭제하시겠습니까?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('취소'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            style: TextButton.styleFrom(foregroundColor: Colors.red),
            child: const Text('삭제'),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      onDelete();
    }
  }

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          '#$messageIndex',
          style: TextStyle(
            fontSize: 11,
            color: Colors.grey[500],
          ),
        ),
        const SizedBox(width: 8),

        if (showEdit)
          _ActionIconButton(
            icon: Icons.edit_outlined,
            tooltip: '수정',
            onPressed: onEdit,
          ),

        _ActionIconButton(
          icon: Icons.delete_outline,
          tooltip: '삭제',
          onPressed: () => _showDeleteConfirmDialog(context),
          color: Colors.red[400],
        ),

        _ActionIconButton(
          icon: Icons.copy_outlined,
          tooltip: '복사',
          onPressed: () => _copyToClipboard(context),
        ),
      ],
    );
  }
}

class _ActionIconButton extends StatelessWidget {
  final IconData icon;
  final String tooltip;
  final VoidCallback onPressed;
  final Color? color;

  const _ActionIconButton({
    required this.icon,
    required this.tooltip,
    required this.onPressed,
    this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Tooltip(
      message: tooltip,
      child: InkWell(
        onTap: onPressed,
        borderRadius: BorderRadius.circular(4),
        child: Padding(
          padding: const EdgeInsets.all(4),
          child: Icon(
            icon,
            size: 16,
            color: color ?? Colors.grey[600],
          ),
        ),
      ),
    );
  }
}

class MessageEditDialog extends StatefulWidget {
  final String initialContent;
  final int messageIndex;

  const MessageEditDialog({
    super.key,
    required this.initialContent,
    required this.messageIndex,
  });

  static Future<String?> show(
    BuildContext context, {
    required String initialContent,
    required int messageIndex,
  }) async {
    return showDialog<String>(
      context: context,
      builder: (context) => MessageEditDialog(
        initialContent: initialContent,
        messageIndex: messageIndex,
      ),
    );
  }

  @override
  State<MessageEditDialog> createState() => _MessageEditDialogState();
}

class _MessageEditDialogState extends State<MessageEditDialog> {
  late TextEditingController _controller;

  @override
  void initState() {
    super.initState();
    _controller = TextEditingController(text: widget.initialContent);
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text('${widget.messageIndex}번 메시지 수정'),
      content: SizedBox(
        width: double.maxFinite,
        child: TextField(
          controller: _controller,
          maxLines: 10,
          decoration: const InputDecoration(
            hintText: '메시지 내용을 입력하세요...',
            border: OutlineInputBorder(),
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('취소'),
        ),
        ElevatedButton(
          onPressed: () => Navigator.pop(context, _controller.text),
          child: const Text('저장'),
        ),
      ],
    );
  }
}
