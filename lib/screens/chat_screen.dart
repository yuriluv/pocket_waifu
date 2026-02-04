// ============================================================================
// 채팅 화면 (Chat Screen) v2.0.5
// ============================================================================
// 이 파일은 메인 채팅 화면 UI를 담당합니다.
// 메시지 목록과 입력창을 표시하고, 사용자 입력을 처리합니다.
// v2.0.5: 세션 ID 캡처 패턴 - 화면 생성 시 세션 ID 고정
// ============================================================================

import 'package:flutter/foundation.dart';
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
  // 텍스트 입력 컨트롤러
  final TextEditingController _textController = TextEditingController();

  // 스크롤 컨트롤러
  final ScrollController _scrollController = ScrollController();

  // v2.0.6: 입력 필드 포커스 노드
  final FocusNode _inputFocusNode = FocusNode();

  // v2.0.6: 입력 필드 활성화 상태 (사용자가 명시적으로 활성화했는지 추적)
  // - true: 사용자가 입력 필드를 탭하여 활성화함
  // - false: 사용자가 뒤로가기로 키보드를 닫음
  // - 메뉴에서 복귀할 때 이 값을 기준으로 포커스 복원 여부 결정
  bool _isInputActive = false;

  // Provider 연결 완료 여부
  bool _isProviderLinked = false;

  // v2.0.5: 현재 화면이 표시하는 세션 ID (메시지 전송 시 사용)
  String? _currentSessionId;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _linkProviders();
      _captureCurrentSessionId();
    });
  }

  /// ChatProvider와 ChatSessionProvider 연결
  void _linkProviders() {
    if (_isProviderLinked) return;

    final chatProvider = context.read<ChatProvider>();
    final chatSessionProvider = context.read<ChatSessionProvider>();

    chatProvider.setSessionProvider(chatSessionProvider);
    _isProviderLinked = true;

    debugPrint('>>> v2.0.5: Provider 연결 완료');
  }

  /// v2.0.5: 현재 활성 세션 ID 캡처
  void _captureCurrentSessionId() {
    final chatSessionProvider = context.read<ChatSessionProvider>();
    _currentSessionId = chatSessionProvider.activeSessionId;
    debugPrint('>>> v2.0.5: 세션 ID 캡처됨: $_currentSessionId');
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    // 세션 변경 시 ID 업데이트 (드로어에서 세션 전환 시)
    final chatSessionProvider = context.read<ChatSessionProvider>();
    final newSessionId = chatSessionProvider.activeSessionId;
    if (newSessionId != null && newSessionId != _currentSessionId) {
      _currentSessionId = newSessionId;
      debugPrint('>>> v2.0.5: 세션 ID 업데이트됨: $_currentSessionId');
    }
  }

  @override
  void dispose() {
    _textController.dispose();
    _scrollController.dispose();
    _inputFocusNode.dispose();
    super.dispose();
  }

  /// 메시지를 보내는 함수
  void _sendMessage() {
    final String text = _textController.text.trim();
    if (text.isEmpty) return;

    final chatProvider = context.read<ChatProvider>();
    final chatSessionProvider = context.read<ChatSessionProvider>();
    final settingsProvider = context.read<SettingsProvider>();

    // v2.0.5: 현재 화면의 세션 ID 캡처 (메시지 전송 시점에 고정)
    final sessionId = _currentSessionId ?? chatSessionProvider.activeSessionId;
    if (sessionId == null) {
      _showSnackBar('활성 세션이 없습니다.', isError: true);
      return;
    }

    // === 명령어 파싱 ===
    final commandResult = CommandParser.parse(text);
    if (commandResult.$1) {
      _handleCommand(
        commandResult.$2!,
        chatProvider,
        chatSessionProvider,
        sessionId,
      );
      _textController.clear();
      return;
    }

    final activeApiConfig = settingsProvider.activeApiConfig;

    debugPrint('>>> _sendMessage - 세션 ID: $sessionId');

    // v2.0.5: 세션 ID를 명시적으로 전달
    chatProvider.sendMessage(
      userMessage: text,
      character: settingsProvider.character,
      settings: settingsProvider.settings,
      userName: settingsProvider.userName,
      apiConfig: activeApiConfig,
      targetSessionId: sessionId, // 🔒 세션 ID 전달
    );

    _textController.clear();
    _scrollToBottom();
  }

  /// 명령어 처리
  /// v2.0.5: 세션 ID를 명시적으로 전달
  void _handleCommand(
    CommandResult command,
    ChatProvider chatProvider,
    ChatSessionProvider chatSessionProvider,
    String sessionId,
  ) {
    final settingsProvider = context.read<SettingsProvider>();
    final currentMessages = chatProvider.getMessagesFor(sessionId);

    switch (command.command) {
      case 'del':
        // 단일 삭제
        if (command.index != null && command.endIndex == null) {
          final idx = command.index! - 1;
          if (idx >= 0 && idx < currentMessages.length) {
            chatProvider.deleteMessage(
              currentMessages[idx].id,
              targetSessionId: sessionId,
            );
            _showSnackBar('${command.index}번 메시지를 삭제했습니다.');
          } else {
            _showSnackBar('잘못된 메시지 번호입니다.', isError: true);
          }
        }
        // 범위 삭제
        else if (command.index != null && command.endIndex != null) {
          final start = command.index! - 1;
          final end = command.endIndex! - 1;
          if (start >= 0 && end < currentMessages.length && start <= end) {
            for (int i = end; i >= start; i--) {
              chatProvider.deleteMessage(
                currentMessages[i].id,
                targetSessionId: sessionId,
              );
            }
            _showSnackBar('${command.index}~${command.endIndex}번 메시지를 삭제했습니다.');
          } else {
            _showSnackBar('잘못된 메시지 범위입니다.', isError: true);
          }
        }

      case 'send':
        if (command.content != null && command.content!.isNotEmpty) {
          chatProvider.addMessageWithoutApi(
            Message(role: MessageRole.user, content: command.content!),
            targetSessionId: sessionId,
          );
          _showSnackBar('메시지가 기록에 추가되었습니다.');
          _scrollToBottom();
        }

      case 'edit':
        if (command.index != null && command.content != null) {
          final idx = command.index! - 1;
          if (idx >= 0 && idx < currentMessages.length) {
            chatProvider.editMessage(
              currentMessages[idx].id,
              command.content!,
              targetSessionId: sessionId,
            );
            _showSnackBar('${command.index}번 메시지를 수정했습니다.');
          } else {
            _showSnackBar('잘못된 메시지 번호입니다.', isError: true);
          }
        }

      case 'copy':
        if (command.index != null) {
          final idx = command.index! - 1;
          if (idx >= 0 && idx < currentMessages.length) {
            Clipboard.setData(
              ClipboardData(text: currentMessages[idx].content),
            );
            _showSnackBar('${command.index}번 메시지를 복사했습니다.');
          } else {
            _showSnackBar('잘못된 메시지 번호입니다.', isError: true);
          }
        }

      case 'clear':
        chatProvider.initializeChat(
          character: settingsProvider.character,
          userName: settingsProvider.userName,
          targetSessionId: sessionId,
        );
        _showSnackBar('대화가 초기화되었습니다.');

      case 'export':
        final json = chatSessionProvider.exportSession(sessionId);
        _showExportDialog(json);

      case 'help':
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
          children: [Icon(Icons.download), SizedBox(width: 8), Text('대화 내보내기')],
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

  /// 마지막 AI 응답을 재생성합니다
  void _regenerateResponse() {
    final chatProvider = context.read<ChatProvider>();
    final settingsProvider = context.read<SettingsProvider>();
    final chatSessionProvider = context.read<ChatSessionProvider>();

    // v2.0.5: 세션 ID 전달
    final sessionId = _currentSessionId ?? chatSessionProvider.activeSessionId;

    chatProvider.regenerateLastResponse(
      character: settingsProvider.character,
      settings: settingsProvider.settings,
      userName: settingsProvider.userName,
      apiConfig: settingsProvider.activeApiConfig,
      targetSessionId: sessionId,
    );
  }

  @override
  Widget build(BuildContext context) {
    // Provider 연결 (최초 1회)
    if (!_isProviderLinked) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        _linkProviders();
        _captureCurrentSessionId();
      });
    }

    // Provider 데이터 읽기
    final chatProvider = context.watch<ChatProvider>();
    final settingsProvider = context.watch<SettingsProvider>();
    final chatSessionProvider = context.watch<ChatSessionProvider>();
    final character = settingsProvider.character;

    // v2.0.5: 세션 변경 감지 및 ID 업데이트
    final activeSessionId = chatSessionProvider.activeSessionId;
    if (activeSessionId != null && activeSessionId != _currentSessionId) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) {
          setState(() {
            _currentSessionId = activeSessionId;
          });
          debugPrint('>>> v2.0.5: 세션 변경 감지 - $_currentSessionId');
        }
      });
    }

    return PopScope(
      canPop: true,
      onPopInvokedWithResult: (didPop, result) {
        // v2.0.6: 뒤로가기 시 입력 필드가 포커스되어 있으면 비활성화
        if (_inputFocusNode.hasFocus) {
          _inputFocusNode.unfocus();
          setState(() {
            _isInputActive = false;
          });
          debugPrint('>>> v2.0.6: Back pressed - input deactivated');
        }
      },
      child: Scaffold(
        drawer: const MenuDrawer(),
        // v2.0.6: 드로어 열림/닫힘 시 포커스 관리
        onDrawerChanged: (isOpened) {
          if (isOpened) {
            // 드로어가 열릴 때: 항상 포커스 해제 (isInputActive는 유지)
            if (_inputFocusNode.hasFocus) {
              _inputFocusNode.unfocus();
              debugPrint(
                '>>> v2.0.6: Drawer opened - unfocused (isInputActive=$_isInputActive)',
              );
            }
          } else {
            // 드로어가 닫힐 때: isInputActive가 true일 때만 포커스 복원
            if (_isInputActive) {
              // 약간의 딜레이 후 포커스 복원 (드로어 애니메이션 완료 대기)
              Future.delayed(const Duration(milliseconds: 100), () {
                if (mounted && _isInputActive) {
                  _inputFocusNode.requestFocus();
                  debugPrint('>>> v2.0.6: Drawer closed - focus restored');
                }
              });
            } else {
              debugPrint(
                '>>> v2.0.6: Drawer closed - focus NOT restored (isInputActive=false)',
              );
            }
          }
        },

        appBar: AppBar(
          title: Text(character.name),
          backgroundColor: Theme.of(context).colorScheme.inversePrimary,
          actions: [
            IconButton(
              icon: const Icon(Icons.settings),
              tooltip: '설정',
              onPressed: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (context) => const SettingsScreen(),
                  ),
                );
              },
            ),
          ],
        ),

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
                          onDelete: () =>
                              chatProvider.deleteMessage(message.id),
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
              focusNode: _inputFocusNode,
              onSend: _sendMessage,
              isLoading: chatProvider.isLoading,
              onTap: () {
                // v2.0.6: 사용자가 입력 필드를 탭했을 때 활성화
                if (!_isInputActive) {
                  setState(() {
                    _isInputActive = true;
                  });
                  debugPrint('>>> v2.0.6: Input tapped - isInputActive=true');
                }
              },
            ),
          ],
        ),
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
        mainAxisAlignment: isUser
            ? MainAxisAlignment.end
            : MainAxisAlignment.start,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // AI 메시지일 때 아바타 표시
          if (!isUser) ...[
            CircleAvatar(
              backgroundColor: Colors.purple[100],
              child: Text(
                characterName[0], // 캐릭터 이름의 첫 글자
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
                userName[0], // 사용자 이름의 첫 글자
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
/// v2.0.6: 포커스 노드와 탭 콜백 추가
class _MessageInput extends StatelessWidget {
  final TextEditingController controller;
  final FocusNode focusNode;
  final VoidCallback onSend;
  final bool isLoading;
  final VoidCallback? onTap;

  const _MessageInput({
    required this.controller,
    required this.focusNode,
    required this.onSend,
    required this.isLoading,
    this.onTap,
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
                focusNode: focusNode,
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
                onTap: onTap,
                maxLines: null, // 여러 줄 입력 가능
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
