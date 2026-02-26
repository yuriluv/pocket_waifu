// ============================================================================
// ============================================================================
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

class ChatScreen extends StatefulWidget {
  const ChatScreen({super.key});

  @override
  State<ChatScreen> createState() => _ChatScreenState();
}

class _ChatScreenState extends State<ChatScreen> {
  final TextEditingController _textController = TextEditingController();

  final ScrollController _scrollController = ScrollController();

  final FocusNode _inputFocusNode = FocusNode();

  bool _isInputActive = false;

  bool _isProviderLinked = false;

  String? _currentSessionId;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _linkProviders();
      _captureCurrentSessionId();
    });
  }

  void _linkProviders() {
    if (_isProviderLinked) return;

    final chatProvider = context.read<ChatProvider>();
    final chatSessionProvider = context.read<ChatSessionProvider>();

    chatProvider.setSessionProvider(chatSessionProvider);
    _isProviderLinked = true;

    debugPrint('>>> v2.0.5: Provider 연결 완료');
  }

  void _captureCurrentSessionId() {
    final chatSessionProvider = context.read<ChatSessionProvider>();
    _currentSessionId = chatSessionProvider.activeSessionId;
    debugPrint('>>> v2.0.5: 세션 ID 캡처됨: $_currentSessionId');
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
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

  void _sendMessage() {
    final String text = _textController.text.trim();
    if (text.isEmpty) return;

    final chatProvider = context.read<ChatProvider>();
    final chatSessionProvider = context.read<ChatSessionProvider>();
    final settingsProvider = context.read<SettingsProvider>();

    final sessionId = _currentSessionId ?? chatSessionProvider.activeSessionId;
    if (sessionId == null) {
      _showSnackBar('활성 세션이 없습니다.', isError: true);
      return;
    }

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

    chatProvider.sendMessage(
      userMessage: text,
      character: settingsProvider.character,
      settings: settingsProvider.settings,
      userName: settingsProvider.userName,
      apiConfig: activeApiConfig,
      targetSessionId: sessionId,
    );

    _textController.clear();
    _scrollToBottom();
  }

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

  void _regenerateResponse() {
    final chatProvider = context.read<ChatProvider>();
    final settingsProvider = context.read<SettingsProvider>();
    final chatSessionProvider = context.read<ChatSessionProvider>();

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
    if (!_isProviderLinked) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        _linkProviders();
        _captureCurrentSessionId();
      });
    }

    final chatProvider = context.watch<ChatProvider>();
    final settingsProvider = context.watch<SettingsProvider>();
    final chatSessionProvider = context.watch<ChatSessionProvider>();
    final character = settingsProvider.character;

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
        onDrawerChanged: (isOpened) {
          if (isOpened) {
            if (_inputFocusNode.hasFocus) {
              _inputFocusNode.unfocus();
              debugPrint(
                '>>> v2.0.6: Drawer opened - unfocused (isInputActive=$_isInputActive)',
              );
            }
          } else {
            if (_isInputActive) {
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

            _MessageInput(
              controller: _textController,
              focusNode: _inputFocusNode,
              onSend: _sendMessage,
              isLoading: chatProvider.isLoading,
              onTap: () {
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
    final bool isUser = message.role == MessageRole.user;

    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Row(
        mainAxisAlignment: isUser
            ? MainAxisAlignment.end
            : MainAxisAlignment.start,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (!isUser) ...[
            CircleAvatar(
              backgroundColor: Colors.purple[100],
              child: Text(
                characterName[0],
                style: TextStyle(color: Colors.purple[800]),
              ),
            ),
            const SizedBox(width: 8),
          ],

          Flexible(
            child: GestureDetector(
              onLongPress: () {
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
                    bottomRight: isUser ? const Radius.circular(4) : null,
                    bottomLeft: !isUser ? const Radius.circular(4) : null,
                  ),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      isUser ? userName : characterName,
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 12,
                        color: isUser ? Colors.white70 : Colors.grey[600],
                      ),
                    ),
                    const SizedBox(height: 4),
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

          if (isUser) ...[
            const SizedBox(width: 8),
            CircleAvatar(
              backgroundColor: Theme.of(context).colorScheme.primary,
              child: Text(
                userName[0],
                style: const TextStyle(color: Colors.white),
              ),
            ),
          ],
        ],
      ),
    );
  }
}

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
                maxLines: null,
                keyboardType: TextInputType.multiline,
              ),
            ),
            const SizedBox(width: 8),
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
