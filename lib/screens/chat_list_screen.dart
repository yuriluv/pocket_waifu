// ============================================================================
// 채팅 목록 화면 (Chat List Screen) - v2.0.4
// ============================================================================
// 모든 채팅 세션을 표시하고 관리하는 화면입니다.
// 채팅 선택, 이름 변경, 삭제 기능을 제공합니다.
// v2.0.4: ChatSessionProvider가 단일 데이터 소스 - 세션 전환만으로 자동 연동
// ============================================================================

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/chat_session_provider.dart';
import '../models/chat_session.dart';
import 'package:intl/intl.dart';

/// 채팅 목록 화면
class ChatListScreen extends StatelessWidget {
  const ChatListScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('채팅 목록'),
        actions: [
          // 새 채팅 버튼
          IconButton(
            icon: const Icon(Icons.add),
            tooltip: '새 채팅',
            onPressed: () {
              // v2.0.4: 세션 생성만 하면 ChatProvider가 자동 연동
              final provider = Provider.of<ChatSessionProvider>(
                context,
                listen: false,
              );
              provider.createNewSession();
              Navigator.pop(context);
            },
          ),
        ],
      ),
      body: Consumer<ChatSessionProvider>(
        builder: (context, provider, child) {
          if (provider.sessions.isEmpty) {
            return _EmptySessionsPlaceholder(
              onCreate: () {
                // v2.0.4: 세션 생성만 하면 ChatProvider가 자동 연동
                provider.createNewSession();
                Navigator.pop(context);
              },
            );
          }

          return ListView.builder(
            padding: const EdgeInsets.all(8),
            itemCount: provider.sessions.length,
            itemBuilder: (context, index) {
              final session = provider.sessions[index];
              final isActive = session.id == provider.activeSessionId;

              return _ChatSessionCard(
                session: session,
                isActive: isActive,
                onTap: () {
                  // v2.0.4: 세션 전환만 하면 ChatProvider가 자동 연동
                  provider.switchSession(session.id);
                  Navigator.pop(context);
                },
                onRename: () => _showRenameDialog(context, provider, session),
                onDelete: () => _confirmDelete(context, provider, session),
                onExport: () => _exportSession(context, provider, session),
              );
            },
          );
        },
      ),
    );
  }

  /// 이름 변경 다이얼로그
  void _showRenameDialog(
    BuildContext context,
    ChatSessionProvider provider,
    ChatSession session,
  ) {
    final controller = TextEditingController(text: session.name);

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('채팅 이름 변경'),
        content: TextField(
          controller: controller,
          autofocus: true,
          decoration: const InputDecoration(
            border: OutlineInputBorder(),
            labelText: '채팅 이름',
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('취소'),
          ),
          ElevatedButton(
            onPressed: () {
              if (controller.text.trim().isNotEmpty) {
                provider.renameSession(session.id, controller.text.trim());
              }
              Navigator.pop(context);
            },
            child: const Text('변경'),
          ),
        ],
      ),
    );
  }

  /// 삭제 확인 다이얼로그
  void _confirmDelete(
    BuildContext context,
    ChatSessionProvider provider,
    ChatSession session,
  ) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('채팅 삭제'),
        content: Text(
          '"${session.name}" 채팅을 삭제하시겠습니까?\n'
          '이 작업은 되돌릴 수 없습니다.',
        ),
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
              provider.deleteSession(session.id);
              Navigator.pop(context);

              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content: Text('"${session.name}" 채팅이 삭제되었습니다.'),
                  duration: const Duration(seconds: 2),
                ),
              );
            },
            child: const Text('삭제'),
          ),
        ],
      ),
    );
  }

  /// 세션 내보내기
  void _exportSession(
    BuildContext context,
    ChatSessionProvider provider,
    ChatSession session,
  ) {
    final json = provider.exportSession(session.id);

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Row(
          children: [
            const Icon(Icons.download),
            const SizedBox(width: 8),
            Text('${session.name} 내보내기'),
          ],
        ),
        content: SizedBox(
          width: double.maxFinite,
          height: 300,
          child: SingleChildScrollView(
            child: SelectableText(
              json,
              style: const TextStyle(fontFamily: 'monospace', fontSize: 12),
            ),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('닫기'),
          ),
        ],
      ),
    );
  }
}

/// 채팅 세션 카드 위젯
class _ChatSessionCard extends StatelessWidget {
  final ChatSession session;
  final bool isActive;
  final VoidCallback onTap;
  final VoidCallback onRename;
  final VoidCallback onDelete;
  final VoidCallback onExport;

  const _ChatSessionCard({
    required this.session,
    required this.isActive,
    required this.onTap,
    required this.onRename,
    required this.onDelete,
    required this.onExport,
  });

  @override
  Widget build(BuildContext context) {
    // 마지막 메시지 미리보기
    String lastMessagePreview = '새 채팅';
    if (session.messages.isNotEmpty) {
      final lastMsg = session.messages.last;
      lastMessagePreview = lastMsg.content.length > 50
          ? '${lastMsg.content.substring(0, 50)}...'
          : lastMsg.content;
    }

    // 날짜 포맷
    String dateStr;
    try {
      final dateFormat = DateFormat('MM/dd HH:mm');
      dateStr = dateFormat.format(session.updatedAt);
    } catch (e) {
      // intl 패키지 없을 때 fallback
      dateStr =
          '${session.updatedAt.month}/${session.updatedAt.day} '
          '${session.updatedAt.hour}:${session.updatedAt.minute.toString().padLeft(2, '0')}';
    }

    return Card(
      elevation: isActive ? 4 : 1,
      margin: const EdgeInsets.symmetric(vertical: 4),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: isActive
            ? BorderSide(color: Theme.of(context).colorScheme.primary, width: 2)
            : BorderSide.none,
      ),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Row(
            children: [
              // 채팅 아이콘
              Container(
                width: 48,
                height: 48,
                decoration: BoxDecoration(
                  color: isActive
                      ? Theme.of(context).colorScheme.primaryContainer
                      : Colors.grey[100],
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(
                  Icons.chat_bubble,
                  color: isActive
                      ? Theme.of(context).colorScheme.primary
                      : Colors.grey,
                ),
              ),
              const SizedBox(width: 12),

              // 채팅 정보
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            session.name,
                            style: TextStyle(
                              fontWeight: FontWeight.bold,
                              color: isActive
                                  ? Theme.of(context).colorScheme.primary
                                  : null,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                        if (isActive)
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 8,
                              vertical: 2,
                            ),
                            decoration: BoxDecoration(
                              color: Theme.of(context).colorScheme.primary,
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: const Text(
                              '현재',
                              style: TextStyle(
                                color: Colors.white,
                                fontSize: 10,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ),
                      ],
                    ),
                    const SizedBox(height: 4),
                    Text(
                      lastMessagePreview,
                      style: TextStyle(fontSize: 12, color: Colors.grey[600]),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 4),
                    Row(
                      children: [
                        Icon(
                          Icons.access_time,
                          size: 12,
                          color: Colors.grey[400],
                        ),
                        const SizedBox(width: 4),
                        Text(
                          dateStr,
                          style: TextStyle(
                            fontSize: 11,
                            color: Colors.grey[500],
                          ),
                        ),
                        const SizedBox(width: 12),
                        Icon(Icons.chat, size: 12, color: Colors.grey[400]),
                        const SizedBox(width: 4),
                        Text(
                          '${session.messages.length}개 메시지',
                          style: TextStyle(
                            fontSize: 11,
                            color: Colors.grey[500],
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),

              // 액션 메뉴
              PopupMenuButton<String>(
                icon: const Icon(Icons.more_vert),
                onSelected: (value) {
                  switch (value) {
                    case 'rename':
                      onRename();
                    case 'export':
                      onExport();
                    case 'delete':
                      onDelete();
                  }
                },
                itemBuilder: (context) => [
                  const PopupMenuItem(
                    value: 'rename',
                    child: Row(
                      children: [
                        Icon(Icons.edit, size: 18),
                        SizedBox(width: 8),
                        Text('이름 변경'),
                      ],
                    ),
                  ),
                  const PopupMenuItem(
                    value: 'export',
                    child: Row(
                      children: [
                        Icon(Icons.download, size: 18),
                        SizedBox(width: 8),
                        Text('내보내기'),
                      ],
                    ),
                  ),
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
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// 빈 세션 플레이스홀더
class _EmptySessionsPlaceholder extends StatelessWidget {
  final VoidCallback onCreate;

  const _EmptySessionsPlaceholder({required this.onCreate});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.chat_bubble_outline, size: 64, color: Colors.grey[400]),
          const SizedBox(height: 16),
          Text(
            '채팅이 없습니다',
            style: TextStyle(fontSize: 18, color: Colors.grey[600]),
          ),
          const SizedBox(height: 8),
          Text(
            '새 채팅을 시작해보세요!',
            style: TextStyle(fontSize: 14, color: Colors.grey[500]),
          ),
          const SizedBox(height: 24),
          ElevatedButton.icon(
            onPressed: onCreate,
            icon: const Icon(Icons.add),
            label: const Text('새 채팅 시작'),
          ),
        ],
      ),
    );
  }
}
