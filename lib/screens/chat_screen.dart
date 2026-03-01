// ============================================================================
// ============================================================================
// ============================================================================

import 'dart:convert';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:image_picker/image_picker.dart';
import 'package:provider/provider.dart';

import '../models/message.dart';
import '../providers/chat_provider.dart';
import '../providers/settings_provider.dart';
import '../providers/chat_session_provider.dart';
import '../providers/global_runtime_provider.dart';
import '../services/command_parser.dart';
import '../widgets/prompt_preview_dialog.dart';
import '../widgets/empty_state_view.dart';
import '../utils/ui_feedback.dart';
import '../services/proactive_response_service.dart';
import '../services/image_attachment_service.dart';
import '../features/live2d/data/models/live2d_settings.dart';
import 'menu_drawer.dart';
import 'settings_screen.dart';

class ChatScreen extends StatefulWidget {
  const ChatScreen({super.key});

  @override
  State<ChatScreen> createState() => _ChatScreenState();
}

class _ChatScreenState extends State<ChatScreen> with WidgetsBindingObserver {
  static const int _maxAttachmentsPerMessage = 4;

  final TextEditingController _textController = TextEditingController();

  final ScrollController _scrollController = ScrollController();

  final FocusNode _inputFocusNode = FocusNode();

  bool _shouldRestoreFocusAfterDrawerClose = false;

  bool _isProviderLinked = false;

  String? _currentSessionId;

  AppLifecycleState? _lastLifecycleState;

  bool _wasKeyboardVisible = false;

  List<ImageAttachment> _attachedImages = const [];

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _wasKeyboardVisible = _isKeyboardVisible();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _linkProviders();
      _captureCurrentSessionId();
      _syncProactiveEnvironment();
    });
  }

  bool _isKeyboardVisible() {
    final views = WidgetsBinding.instance.platformDispatcher.views;
    if (views.isEmpty) return false;
    return views.first.viewInsets.bottom > 0;
  }

  void _linkProviders() {
    if (_isProviderLinked) return;

    final chatProvider = context.read<ChatProvider>();
    final chatSessionProvider = context.read<ChatSessionProvider>();

    chatProvider.setSessionProvider(chatSessionProvider);
    _isProviderLinked = true;

    debugPrint('>>> v2.0.5: Provider ?곌껐 ?꾨즺');
  }

  void _captureCurrentSessionId() {
    final chatSessionProvider = context.read<ChatSessionProvider>();
    _currentSessionId = chatSessionProvider.activeSessionId;
    debugPrint('>>> v2.0.5: ?몄뀡 ID 罹≪쿂?? $_currentSessionId');
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final chatSessionProvider = context.read<ChatSessionProvider>();
    final newSessionId = chatSessionProvider.activeSessionId;
    if (newSessionId != null && newSessionId != _currentSessionId) {
      _currentSessionId = newSessionId;
      debugPrint('>>> v2.0.5: ?몄뀡 ID ?낅뜲?댄듃?? $_currentSessionId');
    }
    _syncProactiveEnvironment();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _textController.dispose();
    _scrollController.dispose();
    _inputFocusNode.dispose();
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    _lastLifecycleState = state;
    _syncProactiveEnvironment();
  }

  @override
  void didChangeMetrics() {
    super.didChangeMetrics();

    final isKeyboardVisible = _isKeyboardVisible();
    if (_wasKeyboardVisible && !isKeyboardVisible) {
      _shouldRestoreFocusAfterDrawerClose = false;
      if (_inputFocusNode.hasFocus) {
        _inputFocusNode.unfocus();
        debugPrint('>>> v2.0.7: Keyboard dismissed - input focus cleared');
      }
    }

    _wasKeyboardVisible = isKeyboardVisible;
  }

  Future<void> _syncProactiveEnvironment() async {
    if (!mounted) return;
    final proactive = context.read<ProactiveResponseService>();
    final orientation = MediaQuery.of(context).orientation;
    proactive.updateEnvironment(
      screenLandscape: orientation == Orientation.landscape,
      screenOff: _lastLifecycleState == AppLifecycleState.paused,
    );
    try {
      final settings = await Live2DSettings.load();
      proactive.updateEnvironment(overlayOn: settings.isEnabled);
    } catch (_) {}
  }

  void _sendMessage() {
    final String text = _textController.text.trim();
    if (text.isEmpty && _attachedImages.isEmpty) return;

    final chatProvider = context.read<ChatProvider>();
    final chatSessionProvider = context.read<ChatSessionProvider>();
    final settingsProvider = context.read<SettingsProvider>();

    final sessionId = _currentSessionId ?? chatSessionProvider.activeSessionId;
    if (sessionId == null) {
      context.showErrorSnackBar('?쒖꽦 ?몄뀡???놁뒿?덈떎.');
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

    debugPrint('>>> _sendMessage - ?몄뀡 ID: $sessionId');

    chatProvider.sendMessage(
      userMessage: text,
      character: settingsProvider.character,
      settings: settingsProvider.settings,
      userName: settingsProvider.userName,
      images: _attachedImages,
      apiConfig: activeApiConfig,
      targetSessionId: sessionId,
    );

    _textController.clear();
    setState(() {
      _attachedImages = const [];
    });
    _scrollToBottom();
  }

  Future<void> _attachImage() async {
    final source = await showModalBottomSheet<ImageSource>(
      context: context,
      builder: (context) {
        return SafeArea(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              ListTile(
                leading: const Icon(Icons.photo_library_outlined),
                title: const Text('Gallery'),
                onTap: () => Navigator.pop(context, ImageSource.gallery),
              ),
              ListTile(
                leading: const Icon(Icons.photo_camera_outlined),
                title: const Text('Camera'),
                onTap: () => Navigator.pop(context, ImageSource.camera),
              ),
            ],
          ),
        );
      },
    );

    if (source == null || !mounted) {
      return;
    }

    try {
      final image = await ImageAttachmentService.pickImage(source);
      if (image == null || !mounted) {
        return;
      }
      setState(() {
        if (_attachedImages.length >= _maxAttachmentsPerMessage) {
          context.showInfoSnackBar('최대 $_maxAttachmentsPerMessage장까지 첨부할 수 있습니다.');
          return;
        }
        _attachedImages = <ImageAttachment>[..._attachedImages, image];
      });
    } catch (e) {
      if (!mounted) return;
      context.showErrorSnackBar(e.toString().replaceFirst('Exception: ', ''));
    }
  }

  void _removeAttachedImage(String id) {
    setState(() {
      _attachedImages = _attachedImages.where((img) => img.id != id).toList();
    });
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
            context.showInfoSnackBar('${command.index}踰?硫붿떆吏瑜???젣?덉뒿?덈떎.');
          } else {
            context.showErrorSnackBar('?섎せ??硫붿떆吏 踰덊샇?낅땲??');
          }
        } else if (command.index != null && command.endIndex != null) {
          final start = command.index! - 1;
          final end = command.endIndex! - 1;
          if (start >= 0 && end < currentMessages.length && start <= end) {
            for (int i = end; i >= start; i--) {
              chatProvider.deleteMessage(
                currentMessages[i].id,
                targetSessionId: sessionId,
              );
            }
            context.showInfoSnackBar(
              '${command.index}~${command.endIndex}踰?硫붿떆吏瑜???젣?덉뒿?덈떎.',
            );
          } else {
            context.showErrorSnackBar('?섎せ??硫붿떆吏 踰붿쐞?낅땲??');
          }
        }
        break;

      case 'send':
        if (command.content != null && command.content!.isNotEmpty) {
          chatProvider.addMessageWithoutApi(
            Message(role: MessageRole.user, content: command.content!),
            targetSessionId: sessionId,
          );
          context.showInfoSnackBar('硫붿떆吏媛 湲곕줉??異붽??섏뿀?듬땲??');
          _scrollToBottom();
        }
        break;

      case 'edit':
        if (command.index != null && command.content != null) {
          final idx = command.index! - 1;
          if (idx >= 0 && idx < currentMessages.length) {
            chatProvider.editMessage(
              currentMessages[idx].id,
              command.content!,
              targetSessionId: sessionId,
            );
            context.showInfoSnackBar('${command.index}踰?硫붿떆吏瑜??섏젙?덉뒿?덈떎.');
          } else {
            context.showErrorSnackBar('?섎せ??硫붿떆吏 踰덊샇?낅땲??');
          }
        }
        break;

      case 'copy':
        if (command.index != null) {
          final idx = command.index! - 1;
          if (idx >= 0 && idx < currentMessages.length) {
            Clipboard.setData(
              ClipboardData(text: currentMessages[idx].content),
            );
            context.showInfoSnackBar('${command.index}踰?硫붿떆吏瑜?蹂듭궗?덉뒿?덈떎.');
          } else {
            context.showErrorSnackBar('?섎せ??硫붿떆吏 踰덊샇?낅땲??');
          }
        }
        break;

      case 'clear':
        chatProvider.initializeChat(
          character: settingsProvider.character,
          userName: settingsProvider.userName,
          targetSessionId: sessionId,
        );
        context.showInfoSnackBar('??붽? 珥덇린?붾릺?덉뒿?덈떎.');
        break;

      case 'export':
        final json = chatSessionProvider.exportSession(sessionId);
        _showExportDialog(json);
        break;

      case 'help':
        CommandHelpDialog.show(context);
        break;
    }
  }

  void _showExportDialog(String json) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Row(
          children: [
            Icon(Icons.download),
            SizedBox(width: 8),
            Text('????대낫?닿린'),
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
              context.copyToClipboard(json);
            },
            icon: const Icon(Icons.copy, size: 18),
            label: const Text('蹂듭궗'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('?リ린'),
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
    final runtimeProvider = context.watch<GlobalRuntimeProvider>();
    final chatSessionProvider = context.watch<ChatSessionProvider>();
    final character = settingsProvider.character;

    final activeSessionId = chatSessionProvider.activeSessionId;
    if (activeSessionId != null && activeSessionId != _currentSessionId) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) {
          setState(() {
            _currentSessionId = activeSessionId;
          });
          debugPrint('>>> v2.0.5: ?몄뀡 蹂寃?媛먯? - $_currentSessionId');
        }
      });
    }

    return PopScope(
      canPop: true,
      onPopInvokedWithResult: (didPop, result) {
        if (_inputFocusNode.hasFocus) {
          _inputFocusNode.unfocus();
          _shouldRestoreFocusAfterDrawerClose = false;
          debugPrint('>>> v2.0.6: Back pressed - input deactivated');
        }
      },
      child: Scaffold(
        drawer: const MenuDrawer(),
        onDrawerChanged: (isOpened) {
          if (isOpened) {
            _shouldRestoreFocusAfterDrawerClose = _inputFocusNode.hasFocus;
            if (_inputFocusNode.hasFocus) {
              _inputFocusNode.unfocus();
              debugPrint(
                '>>> v2.0.6: Drawer opened - unfocused (restore=$_shouldRestoreFocusAfterDrawerClose)',
              );
            }
          } else {
            if (_shouldRestoreFocusAfterDrawerClose) {
              _shouldRestoreFocusAfterDrawerClose = false;
              Future.delayed(const Duration(milliseconds: 100), () {
                if (mounted && !_inputFocusNode.hasFocus) {
                  _inputFocusNode.requestFocus();
                  debugPrint('>>> v2.0.6: Drawer closed - focus restored');
                }
              });
            } else {
              debugPrint(
                '>>> v2.0.6: Drawer closed - focus NOT restored (restore=false)',
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
              tooltip: '?ㅼ젙',
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
                      '?リ린',
                      style: TextStyle(color: Colors.white),
                    ),
                  ),
                ],
              ),

            if (!runtimeProvider.isEnabled)
              Container(
                width: double.infinity,
                color: Colors.orange.withValues(alpha: 0.14),
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                child: const Row(
                  children: [
                    Icon(Icons.power_settings_new, size: 18),
                    SizedBox(width: 8),
                    Expanded(child: Text('Master OFF - automation paused')),
                  ],
                ),
              ),

            Expanded(
              child: chatProvider.messages.isEmpty
                  ? EmptyStateView(
                      icon: Icons.chat_bubble_outline,
                      title: '${character.name}?(怨? ??붾? ?쒖옉?대낫?몄슂!',
                      action: ElevatedButton(
                        onPressed: () {
                          chatProvider.initializeChat(
                            character: character,
                            userName: settingsProvider.userName,
                          );
                        },
                        child: const Text('????쒖옉'),
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
                          onRemoveImage: (imageId) => chatProvider
                              .removeImageFromMessage(message.id, imageId),
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
                      '${character.name}??媛) ?낅젰 以?..',
                      style: TextStyle(
                        color: Theme.of(context).colorScheme.onSurfaceVariant,
                      ),
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
              onAttachImage: _attachImage,
              attachedImages: _attachedImages,
              onRemoveImage: _removeAttachedImage,
              isLoading: chatProvider.isLoading,
              canAttachImages:
                  settingsProvider.activeApiConfig?.supportsVision ?? true,
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
  final ValueChanged<String>? onRemoveImage;

  const _MessageBubble({
    required this.message,
    required this.characterName,
    required this.userName,
    required this.onDelete,
    this.onRemoveImage,
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
                            context.copyToClipboard(message.content);
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
                      : Theme.of(context).colorScheme.surfaceContainerHigh,
                  borderRadius: BorderRadius.circular(20).copyWith(
                    bottomRight: isUser ? const Radius.circular(4) : null,
                    bottomLeft: !isUser ? const Radius.circular(4) : null,
                  ),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    if (message.images.isNotEmpty) ...[
                      Wrap(
                        spacing: 8,
                        runSpacing: 8,
                        children: message.images
                            .map((image) => _buildImageThumb(context, image))
                            .toList(growable: false),
                      ),
                      const SizedBox(height: 8),
                    ],
                    Text(
                      isUser ? userName : characterName,
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 12,
                        color: isUser
                            ? Theme.of(
                                context,
                              ).colorScheme.onPrimary.withValues(alpha: 0.8)
                            : Theme.of(context).colorScheme.onSurfaceVariant,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      message.content,
                      style: TextStyle(
                        color: isUser
                            ? Theme.of(context).colorScheme.onPrimary
                            : Theme.of(context).colorScheme.onSurface,
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

  Widget _buildImageThumb(BuildContext context, ImageAttachment image) {
    final filePath = image.thumbnailPath;
    final hasFile = filePath != null && filePath.isNotEmpty;

    return GestureDetector(
      onTap: () => _showImagePreview(context, image),
      onLongPress: onRemoveImage == null
          ? null
          : () {
              showModalBottomSheet<void>(
                context: context,
                builder: (sheetContext) => SafeArea(
                  child: ListTile(
                    leading: const Icon(Icons.delete_outline, color: Colors.red),
                    title: const Text('이미지 삭제'),
                    onTap: () {
                      Navigator.pop(sheetContext);
                      onRemoveImage!(image.id);
                    },
                  ),
                ),
              );
            },
      child: ClipRRect(
        borderRadius: BorderRadius.circular(10),
        child: hasFile
            ? Image.file(
                File(filePath),
                width: 96,
                height: 96,
                fit: BoxFit.cover,
                errorBuilder: (context, error, stackTrace) => _brokenImage(context),
              )
            : Image.memory(
                base64Decode(image.base64Data),
                width: 96,
                height: 96,
                fit: BoxFit.cover,
                frameBuilder: (context, child, frame, wasSynchronouslyLoaded) {
                  if (wasSynchronouslyLoaded || frame != null) {
                    return child;
                  }
                  return _loadingImage(context);
                },
                errorBuilder: (context, error, stackTrace) => _brokenImage(context),
              ),
      ),
    );
  }

  Widget _loadingImage(BuildContext context) {
    return Container(
      width: 96,
      height: 96,
      color: Theme.of(context).colorScheme.surfaceContainerHighest,
      alignment: Alignment.center,
      child: const SizedBox(
        width: 18,
        height: 18,
        child: CircularProgressIndicator(strokeWidth: 2),
      ),
    );
  }

  Widget _brokenImage(BuildContext context) {
    return Container(
      width: 96,
      height: 96,
      color: Theme.of(context).colorScheme.surfaceContainerHighest,
      alignment: Alignment.center,
      child: const Icon(Icons.broken_image_outlined),
    );
  }

  void _showImagePreview(BuildContext context, ImageAttachment image) {
    final filePath = image.thumbnailPath;
    final hasFile = filePath != null && filePath.isNotEmpty;

    showDialog(
      context: context,
      builder: (dialogContext) => Dialog(
        child: InteractiveViewer(
          minScale: 0.8,
          maxScale: 4,
          child: hasFile
              ? Image.file(
                  File(filePath),
                  fit: BoxFit.contain,
                  errorBuilder: (context, error, stackTrace) => const Padding(
                    padding: EdgeInsets.all(24),
                    child: Icon(Icons.broken_image_outlined, size: 48),
                  ),
                )
              : Image.memory(
                  base64Decode(image.base64Data),
                  fit: BoxFit.contain,
                  errorBuilder: (context, error, stackTrace) => const Padding(
                    padding: EdgeInsets.all(24),
                    child: Icon(Icons.broken_image_outlined, size: 48),
                  ),
                ),
        ),
      ),
    );
  }
}

class _MessageInput extends StatelessWidget {
  final TextEditingController controller;
  final FocusNode focusNode;
  final VoidCallback onSend;
  final VoidCallback onAttachImage;
  final List<ImageAttachment> attachedImages;
  final ValueChanged<String> onRemoveImage;
  final bool isLoading;
  final bool canAttachImages;

  const _MessageInput({
    required this.controller,
    required this.focusNode,
    required this.onSend,
    required this.onAttachImage,
    required this.attachedImages,
    required this.onRemoveImage,
    required this.isLoading,
    required this.canAttachImages,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(8),
      decoration: BoxDecoration(
        color: Theme.of(context).scaffoldBackgroundColor,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.05),
            blurRadius: 10,
            offset: const Offset(0, -2),
          ),
        ],
      ),
      child: SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (attachedImages.isNotEmpty)
              SizedBox(
                height: 72,
                child: ListView.separated(
                  scrollDirection: Axis.horizontal,
                  itemCount: attachedImages.length,
                  separatorBuilder: (_, separatorIndex) =>
                      const SizedBox(width: 8),
                  itemBuilder: (context, index) {
                    final image = attachedImages[index];
                    return Stack(
                      children: [
                        ClipRRect(
                          borderRadius: BorderRadius.circular(8),
                          child: Image.memory(
                            base64Decode(image.base64Data),
                            width: 72,
                            height: 72,
                            fit: BoxFit.cover,
                          ),
                        ),
                        Positioned(
                          top: -6,
                          right: -6,
                          child: IconButton(
                            visualDensity: VisualDensity.compact,
                            iconSize: 18,
                            onPressed: isLoading
                                ? null
                                : () => onRemoveImage(image.id),
                            icon: const Icon(Icons.cancel),
                          ),
                        ),
                      ],
                    );
                  },
                ),
              ),
            if (attachedImages.isNotEmpty) const SizedBox(height: 8),
            Row(
              children: [
                IconButton(
                  onPressed: isLoading || !canAttachImages ? null : onAttachImage,
                  icon: Icon(
                    Icons.attach_file,
                    color: isLoading || !canAttachImages
                        ? Colors.grey
                        : Theme.of(context).colorScheme.primary,
                  ),
                  tooltip: canAttachImages
                      ? '이미지 첨부'
                      : '현재 API 설정은 이미지 입력을 지원하지 않습니다',
                ),
                Expanded(
                  child: TextField(
                    controller: controller,
                    focusNode: focusNode,
                    decoration: InputDecoration(
                      hintText: '메시지를 입력하세요..',
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(24),
                        borderSide: BorderSide.none,
                      ),
                      filled: true,
                      fillColor: Theme.of(
                        context,
                      ).colorScheme.surfaceContainerHighest,
                      contentPadding: const EdgeInsets.symmetric(
                        horizontal: 20,
                        vertical: 10,
                      ),
                    ),
                    textInputAction: TextInputAction.send,
                    onSubmitted: (_) => onSend(),
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
          ],
        ),
      ),
    );
  }
}
