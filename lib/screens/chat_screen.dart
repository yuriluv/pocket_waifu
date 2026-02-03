// ============================================================================
// 채팅 화면 (Chat Screen) v1.5
// ============================================================================
// 이 파일은 메인 채팅 화면 UI를 담당합니다.
// 메시지 목록과 입력창을 표시하고, 사용자 입력을 처리합니다.
// v1.5: 드로어 메뉴, 명령어 파서, 메시지 액션 아이콘 통합
// ============================================================================

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';

import '../models/message.dart';
import '../providers/chat_provider.dart';
import '../providers/settings_provider.dart';
import '../providers/chat_session_provider.dart';
import '../services/command_parser.dart';
import '../widgets/prompt_preview_dialog.dart';
import 'menu_drawer.dart';
import 'settings_screen.dart';

/// 채팅 화면 위젯
class ChatScreen extends StatefulWidget {
  const ChatScreen({super.key});

  @override
  State<ChatScreen> createState() => _ChatScreenState();
}

class _ChatScreenState extends State<ChatScreen> {
  // 텍스트 입력 컨트롤러 - 입력창의 텍스트를 관리합니다
  final TextEditingController _textController = TextEditingController();
  
  // 스크롤 컨트롤러 - 메시지 목록의 스크롤을 관리합니다
  final ScrollController _scrollController = ScrollController();

  @override
  void dispose() {
    // 위젯이 제거될 때 컨트롤러들을 정리합니다
    _textController.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  /// 메시지를 보내는 함수
  void _sendMessage() {
    final String text = _textController.text.trim();
    if (text.isEmpty) return;

    // Provider에서 필요한 데이터 가져오기
    final chatProvider = context.read<ChatProvider>();
    final chatSessionProvider = context.read<ChatSessionProvider>();
    final settingsProvider = context.read<SettingsProvider>();

    // === 명령어 파싱 (v1.5) ===
    final commandResult = CommandParser.parse(text);
    if (commandResult.$1) {
      // 명령어가 감지됨
      _handleCommand(commandResult.$2!, chatProvider, chatSessionProvider);
      _textController.clear();
      return;
    }

    // 일반 메시지 전송
    chatProvider.sendMessage(
      userMessage: text,
      character: settingsProvider.character,
      settings: settingsProvider.settings,
      userName: settingsProvider.userName,
    );

    // 채팅 세션에도 메시지 추가 (v1.5)
    chatSessionProvider.addMessage(
      Message(role: MessageRole.user, content: text),
    );

    // 입력창 비우기
    _textController.clear();

    // 맨 아래로 스크롤
    _scrollToBottom();
  }

  /// 명령어 처리 (v1.5)
  void _handleCommand(
    CommandResult command,
    ChatProvider chatProvider,
    ChatSessionProvider chatSessionProvider,
  ) {
    final settingsProvider = context.read<SettingsProvider>();

    switch (command.command) {
      case 'del':
        // 단일 삭제
        if (command.index != null && command.endIndex == null) {
          final idx = command.index! - 1; // 1-based → 0-based
          if (idx >= 0 && idx < chatProvider.messages.length) {
            chatProvider.deleteMessage(chatProvider.messages[idx].id);
            chatSessionProvider.deleteMessageAt(idx);
            _showSnackBar('${command.index}번 메시지를 삭제했습니다.');
          } else {
            _showSnackBar('잘못된 메시지 번호입니다.', isError: true);
          }
        }
        // 범위 삭제
        else if (command.index != null && command.endIndex != null) {
          final start = command.index! - 1;
          final end = command.endIndex! - 1;
          if (start >= 0 && end < chatProvider.messages.length && start <= end) {
            // 역순으로 삭제 (인덱스 변경 방지)
            for (int i = end; i >= start; i--) {
              chatProvider.deleteMessage(chatProvider.messages[i].id);
            }
            chatSessionProvider.deleteMessagesInRange(start, end);
            _showSnackBar('${command.index}~${command.endIndex}번 메시지를 삭제했습니다.');
          } else {
            _showSnackBar('잘못된 메시지 범위입니다.', isError: true);
          }
        }

      case 'send':
        // API 호출 없이 메시지만 추가
        if (command.content != null && command.content!.isNotEmpty) {
          chatProvider.addMessageWithoutApi(
            Message(role: MessageRole.user, content: command.content!),
          );
          chatSessionProvider.addMessage(
            Message(role: MessageRole.user, content: command.content!),
          );
          _showSnackBar('메시지가 기록에 추가되었습니다.');
          _scrollToBottom();
        }

      case 'edit':
        // 메시지 수정
        if (command.index != null && command.content != null) {
          final idx = command.index! - 1;
          if (idx >= 0 && idx < chatProvider.messages.length) {
            chatProvider.editMessage(
              chatProvider.messages[idx].id,
              command.content!,
            );
            chatSessionProvider.editMessageAt(idx, command.content!);
            _showSnackBar('${command.index}번 메시지를 수정했습니다.');
          } else {
            _showSnackBar('잘못된 메시지 번호입니다.', isError: true);
          }
        }

      case 'copy':
        // 메시지 복사
        if (command.index != null) {
          final idx = command.index! - 1;
          if (idx >= 0 && idx < chatProvider.messages.length) {
            Clipboard.setData(
              ClipboardData(text: chatProvider.messages[idx].content),
            );
            _showSnackBar('${command.index}번 메시지를 복사했습니다.');
          } else {
            _showSnackBar('잘못된 메시지 번호입니다.', isError: true);
          }
        }

      case 'clear':
        // 대화 전체 삭제
        chatProvider.initializeChat(
          character: settingsProvider.character,
          userName: settingsProvider.userName,
        );
        chatSessionProvider.clearMessages();
        _showSnackBar('대화가 초기화되었습니다.');

      case 'export':
        // 대화 내보내기
        final json = chatSessionProvider.exportCurrentSession();
        _showExportDialog(json);

      case 'help':
        // 도움말 표시
        CommandHelpDialog.show(context);
    }
  }

  /// 스낵바 표시
  void _showSnackBar(String message, {bool isError = false}) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: isError ? Colors.red : null,
        duration: const Duration(seconds: 2),
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  /// 내보내기 다이얼로그 표시
  void _showExportDialog(String json) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Row(
          children: [
            Icon(Icons.download),
            SizedBox(width: 8),
            Text('대화 내보내기'),
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
          OutlinedButton.icon(
            onPressed: () {
              Clipboard.setData(ClipboardData(text: json));
              _showSnackBar('클립보드에 복사되었습니다.');
            },
            icon: const Icon(Icons.copy, size: 18),
            label: const Text('복사'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('닫기'),
          ),
        ],
      ),
    );
  }

  /// 메시지 목록을 맨 아래로 스크롤합니다
  void _scrollToBottom() {
    // 약간의 지연을 주어 UI가 업데이트된 후 스크롤
    Future.delayed(const Duration(milliseconds: 100), () {
      if (_scrollController.hasClients) {
        _scrollController.animateTo(
          _scrollController.position.maxScrollExtent,
          duration: const Duration(milliseconds: 300),
          curve: Curves.easeOut,
        );
      }
    });
  }

  /// 새 대화를 시작합니다
  void _startNewChat() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('새 대화 시작'),
        content: const Text('현재 대화 내역이 삭제됩니다. 계속하시겠습니까?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('취소'),
          ),
          TextButton(
            onPressed: () {
              Navigator.pop(context);
              
              final chatProvider = context.read<ChatProvider>();
              final settingsProvider = context.read<SettingsProvider>();
              
              // 대화 초기화
              chatProvider.initializeChat(
                character: settingsProvider.character,
                userName: settingsProvider.userName,
              );
            },
            child: const Text('확인'),
          ),
        ],
      ),
    );
  }

  /// 마지막 AI 응답을 재생성합니다
  void _regenerateResponse() {
    final chatProvider = context.read<ChatProvider>();
    final settingsProvider = context.read<SettingsProvider>();

    chatProvider.regenerateLastResponse(
      character: settingsProvider.character,
      settings: settingsProvider.settings,
      userName: settingsProvider.userName,
    );
  }

  @override
  Widget build(BuildContext context) {
    // Provider 데이터 읽기 (Consumer 대신 watch 사용)
    final chatProvider = context.watch<ChatProvider>();
    final settingsProvider = context.watch<SettingsProvider>();
    final character = settingsProvider.character;

    return Scaffold(
      // === 드로어 메뉴 (v1.5) ===
      drawer: const MenuDrawer(),
      
      // === 앱바 ===
      appBar: AppBar(
        // 드로어 메뉴 버튼 (leading은 자동 생성됨)
        title: Text(character.name),  // 캐릭터 이름 표시
        backgroundColor: Theme.of(context).colorScheme.inversePrimary,
        actions: [
          // 새 대화 버튼
          IconButton(
            icon: const Icon(Icons.refresh),
            tooltip: '새 대화',
            onPressed: _startNewChat,
          ),
          // 설정 버튼
          IconButton(
            icon: const Icon(Icons.settings),
            tooltip: '설정',
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(builder: (context) => const SettingsScreen()),
              );
            },
          ),
        ],
      ),

      // === 메인 콘텐츠 ===
      body: Column(
        children: [
          // === 에러 메시지 배너 ===
          if (chatProvider.errorMessage != null)
            MaterialBanner(
              content: Text(
                chatProvider.errorMessage!,
                style: const TextStyle(color: Colors.white),
              ),
              backgroundColor: Colors.red,
              actions: [
                TextButton(
                  onPressed: () => chatProvider.clearError(),
                  child: const Text(
                    '닫기',
                    style: TextStyle(color: Colors.white),
                  ),
                ),
              ],
            ),

          // === 메시지 목록 ===
          Expanded(
            child: chatProvider.messages.isEmpty
                // 메시지가 없을 때 안내 표시
                ? Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(
                          Icons.chat_bubble_outline,
                          size: 64,
                          color: Colors.grey[400],
                        ),
                        const SizedBox(height: 16),
                        Text(
                          '${character.name}와(과) 대화를 시작해보세요!',
                          style: TextStyle(
                            fontSize: 16,
                            color: Colors.grey[600],
                          ),
                        ),
                        const SizedBox(height: 8),
                        ElevatedButton(
                          onPressed: () {
                            chatProvider.initializeChat(
                              character: character,
                              userName: settingsProvider.userName,
                            );
                          },
                          child: const Text('대화 시작'),
                        ),
                      ],
                    ),
                  )
                // 메시지 리스트
                : ListView.builder(
                    controller: _scrollController,
                    padding: const EdgeInsets.all(16),
                    itemCount: chatProvider.messages.length,
                    itemBuilder: (context, index) {
                      final message = chatProvider.messages[index];
                      return _MessageBubble(
                        message: message,
                        characterName: character.name,
                        userName: settingsProvider.userName,
                        onDelete: () => chatProvider.deleteMessage(message.id),
                      );
                    },
                  ),
          ),

          // === 로딩 표시 ===
          if (chatProvider.isLoading)
            Container(
              padding: const EdgeInsets.all(16),
              child: Row(
                children: [
                  const SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  ),
                  const SizedBox(width: 12),
                  Text(
                    '${character.name}이(가) 입력 중...',
                    style: TextStyle(color: Colors.grey[600]),
                  ),
                ],
              ),
            ),

          // === 재생성 버튼 (마지막 메시지가 AI일 때만) ===
          if (chatProvider.messages.isNotEmpty &&
              chatProvider.messages.last.role == MessageRole.assistant &&
              !chatProvider.isLoading)
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: Row(
                children: [
                  TextButton.icon(
                    onPressed: _regenerateResponse,
                    icon: const Icon(Icons.replay, size: 18),
                    label: const Text('응답 재생성'),
                  ),
                ],
              ),
            ),

          // === 입력창 ===
          _MessageInput(
            controller: _textController,
            onSend: _sendMessage,
            isLoading: chatProvider.isLoading,
          ),
        ],
      ),
    );
  }
}

/// 메시지 버블 위젯
/// 각 메시지를 말풍선 형태로 표시합니다
class _MessageBubble extends StatelessWidget {
  final Message message;
  final String characterName;
  final String userName;
  final VoidCallback onDelete;

  const _MessageBubble({
    required this.message,
    required this.characterName,
    required this.userName,
    required this.onDelete,
  });

  @override
  Widget build(BuildContext context) {
    // 사용자 메시지인지 AI 메시지인지에 따라 스타일 결정
    final bool isUser = message.role == MessageRole.user;
    
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Row(
        // 사용자 메시지는 오른쪽, AI 메시지는 왼쪽 정렬
        mainAxisAlignment:
            isUser ? MainAxisAlignment.end : MainAxisAlignment.start,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // AI 메시지일 때 아바타 표시
          if (!isUser) ...[
            CircleAvatar(
              backgroundColor: Colors.purple[100],
              child: Text(
                characterName[0],  // 캐릭터 이름의 첫 글자
                style: TextStyle(color: Colors.purple[800]),
              ),
            ),
            const SizedBox(width: 8),
          ],

          // 메시지 버블
          Flexible(
            child: GestureDetector(
              onLongPress: () {
                // 길게 누르면 삭제 옵션 표시
                showModalBottomSheet(
                  context: context,
                  builder: (context) => SafeArea(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        ListTile(
                          leading: const Icon(Icons.delete, color: Colors.red),
                          title: const Text('메시지 삭제'),
                          onTap: () {
                            Navigator.pop(context);
                            onDelete();
                          },
                        ),
                        ListTile(
                          leading: const Icon(Icons.copy),
                          title: const Text('복사'),
                          onTap: () {
                            Navigator.pop(context);
                            // 클립보드에 복사 (실제 구현 시 clipboard 패키지 필요)
                          },
                        ),
                      ],
                    ),
                  ),
                );
              },
              child: Container(
                constraints: BoxConstraints(
                  maxWidth: MediaQuery.of(context).size.width * 0.75,
                ),
                padding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 10,
                ),
                decoration: BoxDecoration(
                  color: isUser
                      ? Theme.of(context).colorScheme.primary
                      : Colors.grey[200],
                  borderRadius: BorderRadius.circular(20).copyWith(
                    // 말풍선 모양 - 보낸 쪽 모서리를 각지게
                    bottomRight: isUser ? const Radius.circular(4) : null,
                    bottomLeft: !isUser ? const Radius.circular(4) : null,
                  ),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // 보낸 사람 이름
                    Text(
                      isUser ? userName : characterName,
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 12,
                        color: isUser ? Colors.white70 : Colors.grey[600],
                      ),
                    ),
                    const SizedBox(height: 4),
                    // 메시지 내용
                    Text(
                      message.content,
                      style: TextStyle(
                        color: isUser ? Colors.white : Colors.black87,
                        fontSize: 15,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),

          // 사용자 메시지일 때 아바타 표시
          if (isUser) ...[
            const SizedBox(width: 8),
            CircleAvatar(
              backgroundColor: Theme.of(context).colorScheme.primary,
              child: Text(
                userName[0],  // 사용자 이름의 첫 글자
                style: const TextStyle(color: Colors.white),
              ),
            ),
          ],
        ],
      ),
    );
  }
}

/// 메시지 입력 위젯
/// 텍스트 입력창과 전송 버튼을 표시합니다
class _MessageInput extends StatelessWidget {
  final TextEditingController controller;
  final VoidCallback onSend;
  final bool isLoading;

  const _MessageInput({
    required this.controller,
    required this.onSend,
    required this.isLoading,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(8),
      decoration: BoxDecoration(
        color: Theme.of(context).scaffoldBackgroundColor,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 10,
            offset: const Offset(0, -2),
          ),
        ],
      ),
      child: SafeArea(
        child: Row(
          children: [
            // 텍스트 입력창
            Expanded(
              child: TextField(
                controller: controller,
                decoration: InputDecoration(
                  hintText: '메시지를 입력하세요...',
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(24),
                    borderSide: BorderSide.none,
                  ),
                  filled: true,
                  fillColor: Colors.grey[200],
                  contentPadding: const EdgeInsets.symmetric(
                    horizontal: 20,
                    vertical: 10,
                  ),
                ),
                textInputAction: TextInputAction.send,
                onSubmitted: (_) => onSend(),
                maxLines: null,  // 여러 줄 입력 가능
                keyboardType: TextInputType.multiline,
              ),
            ),
            const SizedBox(width: 8),
            // 전송 버튼
            IconButton(
              onPressed: isLoading ? null : onSend,
              icon: Icon(
                Icons.send,
                color: isLoading
                    ? Colors.grey
                    : Theme.of(context).colorScheme.primary,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
