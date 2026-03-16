import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:webview_flutter/webview_flutter.dart';

import '../models/chat_variable_scope.dart';
import '../models/interaction_preset.dart';
import '../models/session_interaction_state.dart';

typedef InteractionVariableChanged = void Function(
  ChatVariableScope scope,
  String variableName,
  String value,
);

typedef InteractionVariableRemoved = void Function(
  ChatVariableScope scope,
  String variableName,
);

typedef InteractionVariableAliasChanged = void Function(
  ChatVariableScope scope,
  String variableName,
  String alias,
);

class InteractionDrawer extends StatefulWidget {
  const InteractionDrawer({
    super.key,
    required this.sessionId,
    required this.characterName,
    required this.interactionState,
    required this.variablesByScope,
    required this.aliasesByScope,
    required this.presets,
    required this.onHtmlChanged,
    required this.onCssChanged,
    required this.onVariableChanged,
    required this.onVariableRemoved,
    required this.onVariableAliasChanged,
    required this.onPresetApplied,
    required this.onPresetSaved,
    required this.onPresetRenamed,
    required this.onPresetDeleted,
    required this.onPresetImported,
    required this.onPresetExported,
  });

  final String sessionId;
  final String characterName;
  final SessionInteractionState interactionState;
  final Map<ChatVariableScope, Map<String, String>> variablesByScope;
  final Map<ChatVariableScope, Map<String, String>> aliasesByScope;
  final List<InteractionPreset> presets;
  final ValueChanged<String> onHtmlChanged;
  final ValueChanged<String> onCssChanged;
  final InteractionVariableChanged onVariableChanged;
  final InteractionVariableRemoved onVariableRemoved;
  final InteractionVariableAliasChanged onVariableAliasChanged;
  final ValueChanged<InteractionPreset> onPresetApplied;
  final Future<void> Function(String name, String html, String css) onPresetSaved;
  final Future<void> Function(String presetId, String newName) onPresetRenamed;
  final Future<void> Function(String presetId) onPresetDeleted;
  final Future<void> Function() onPresetImported;
  final Future<void> Function(InteractionPreset preset) onPresetExported;

  @override
  State<InteractionDrawer> createState() => _InteractionDrawerState();
}

class _InteractionDrawerState extends State<InteractionDrawer> {
  late final WebViewController _webViewController;
  final TextEditingController _htmlController = TextEditingController();
  final TextEditingController _cssController = TextEditingController();
  bool _showSettings = false;
  ChatVariableScope _activeScope = ChatVariableScope.mainChat;

  @override
  void initState() {
    super.initState();
    _htmlController.text = widget.interactionState.html;
    _cssController.text = widget.interactionState.css;
    _webViewController = WebViewController()
      ..setJavaScriptMode(JavaScriptMode.unrestricted)
      ..setBackgroundColor(Colors.white)
      ..setNavigationDelegate(
        NavigationDelegate(
          onNavigationRequest: (request) => NavigationDecision.prevent,
        ),
      )
      ..addJavaScriptChannel(
        'PocketWaifuBoard',
        onMessageReceived: (message) {
          try {
            final payload = jsonDecode(message.message) as Map<String, dynamic>;
            if (payload['type'] == 'setVariable') {
              final scope = ChatVariableScopeX.fromStorageKey(
                payload['scope']?.toString() ?? ChatVariableScope.mainChat.storageKey,
              );
              final name = payload['name']?.toString() ?? '';
              final value = payload['value']?.toString() ?? '';
              if (name.trim().isNotEmpty) {
                widget.onVariableChanged(scope, name.trim(), value);
              }
            }
          } catch (_) {}
        },
      );
    _reloadBoard();
  }

  @override
  void didUpdateWidget(covariant InteractionDrawer oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.interactionState.html != widget.interactionState.html) {
      _htmlController.text = widget.interactionState.html;
    }
    if (oldWidget.interactionState.css != widget.interactionState.css) {
      _cssController.text = widget.interactionState.css;
    }
    if (oldWidget.interactionState != widget.interactionState ||
        oldWidget.variablesByScope.toString() != widget.variablesByScope.toString()) {
      _reloadBoard();
    }
  }

  @override
  void dispose() {
    _htmlController.dispose();
    _cssController.dispose();
    super.dispose();
  }

  Future<void> _reloadBoard() async {
    final html = _buildDocument(
      widget.interactionState.html,
      widget.interactionState.css,
      widget.variablesByScope,
    );
    await _webViewController.loadHtmlString(html);
  }

  String _buildDocument(
    String html,
    String css,
    Map<ChatVariableScope, Map<String, String>> variablesByScope,
  ) {
    final serializedScopes = <String, Map<String, String>>{
      for (final scope in ChatVariableScope.values)
        scope.storageKey: Map<String, String>.from(variablesByScope[scope] ?? const <String, String>{}),
    };
    final escapedJson = jsonEncode(serializedScopes);
    final safeHtml = html.trim().isEmpty
        ? '<div class="pw-empty">No custom HTML yet.</div>'
        : html;
    return '''<!DOCTYPE html>
<html>
<head>
  <meta name="viewport" content="width=device-width, initial-scale=1.0, maximum-scale=1.0" />
  <meta http-equiv="Content-Security-Policy" content="default-src 'none'; connect-src 'none'; img-src data: blob:; style-src 'unsafe-inline'; script-src 'unsafe-inline'; font-src data:; media-src 'none'; frame-src 'none'; base-uri 'none'; form-action 'none';" />
  <style>
    :root { color-scheme: light; }
    html, body { margin: 0; padding: 0; background: #ffffff; min-height: 100%; font-family: sans-serif; }
    body { min-height: 100vh; }
    .pw-empty {
      color: #667085;
      min-height: 100vh;
      display: flex;
      align-items: center;
      justify-content: center;
      text-align: center;
      padding: 24px;
      box-sizing: border-box;
    }
    $css
  </style>
  <script>
    window.pocketWaifu = {
      scopes: $escapedJson,
      getVar: function(name, scope) {
        const targetScope = scope || 'mainChat';
        return (window.pocketWaifu.scopes[targetScope] || {})[name] ?? null;
      },
      setVar: function(name, value, scope) {
        const targetScope = scope || 'mainChat';
        if (!window.pocketWaifu.scopes[targetScope]) {
          window.pocketWaifu.scopes[targetScope] = {};
        }
        window.pocketWaifu.scopes[targetScope][name] = String(value ?? '');
        PocketWaifuBoard.postMessage(JSON.stringify({
          type: 'setVariable',
          scope: targetScope,
          name: name,
          value: String(value ?? '')
        }));
      }
    };
  </script>
</head>
<body>
  $safeHtml
</body>
</html>''';
  }

  @override
  Widget build(BuildContext context) {
    final width = MediaQuery.of(context).size.width * 0.7;
    return Drawer(
      width: width,
      child: SafeArea(
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 14, 10, 8),
              child: Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          '상호작용 탭',
                          style: Theme.of(context).textTheme.titleLarge,
                        ),
                        Text(
                          widget.characterName,
                          style: Theme.of(context).textTheme.bodySmall,
                        ),
                      ],
                    ),
                  ),
                  IconButton(
                    tooltip: _showSettings ? '보드 보기' : '설정',
                    onPressed: () => setState(() => _showSettings = !_showSettings),
                    icon: Icon(_showSettings ? Icons.dashboard_customize : Icons.settings),
                  ),
                ],
              ),
            ),
            const Divider(height: 1),
            Expanded(
              child: _showSettings ? _buildSettingsView(context) : _buildBoardView(context),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildBoardView(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(16),
      child: Container(
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(18),
          border: Border.all(color: Theme.of(context).dividerColor),
        ),
        clipBehavior: Clip.antiAlias,
        child: WebViewWidget(controller: _webViewController),
      ),
    );
  }

  Widget _buildSettingsView(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        _buildVariablesCard(context),
        const SizedBox(height: 12),
        _buildTextEditorCard(
          context,
          title: 'CSS',
          controller: _cssController,
          hintText: '보드에만 적용될 CSS를 입력하세요.',
          onSave: () async {
            widget.onCssChanged(_cssController.text);
            await _reloadBoard();
          },
        ),
        const SizedBox(height: 12),
        _buildTextEditorCard(
          context,
          title: 'HTML',
          controller: _htmlController,
          hintText: '보드 내부에 렌더링될 HTML을 입력하세요.',
          onSave: () async {
            widget.onHtmlChanged(_htmlController.text);
            await _reloadBoard();
          },
        ),
        const SizedBox(height: 12),
        _buildPresetsCard(context),
      ],
    );
  }

  Widget _buildVariablesCard(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('채팅 변수 / 값', style: Theme.of(context).textTheme.titleMedium),
            const SizedBox(height: 10),
            SegmentedButton<ChatVariableScope>(
              segments: ChatVariableScope.values
                  .map(
                    (scope) => ButtonSegment<ChatVariableScope>(
                      value: scope,
                      label: Text(scope.label),
                    ),
                  )
                  .toList(growable: false),
              selected: <ChatVariableScope>{_activeScope},
              onSelectionChanged: (selection) {
                setState(() => _activeScope = selection.first);
              },
            ),
            const SizedBox(height: 12),
            ..._buildVariableRows(context, _activeScope),
            const SizedBox(height: 8),
            Align(
              alignment: Alignment.centerLeft,
              child: OutlinedButton.icon(
                onPressed: () => _showVariableEditor(context, _activeScope),
                icon: const Icon(Icons.add),
                label: const Text('변수 추가'),
              ),
            ),
          ],
        ),
      ),
    );
  }

  List<Widget> _buildVariableRows(BuildContext context, ChatVariableScope scope) {
    final values = widget.variablesByScope[scope] ?? const <String, String>{};
    final aliases = widget.aliasesByScope[scope] ?? const <String, String>{};
    if (values.isEmpty) {
      return <Widget>[
        Text(
          '아직 등록된 변수가 없습니다.',
          style: Theme.of(context).textTheme.bodyMedium?.copyWith(color: Colors.grey[600]),
        ),
      ];
    }
    return values.entries.map((entry) {
      final displayName = aliases[entry.key]?.trim().isNotEmpty == true
          ? aliases[entry.key]!
          : entry.key;
      return ListTile(
        contentPadding: EdgeInsets.zero,
        title: Text(displayName),
        subtitle: Text(entry.key),
        trailing: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            SizedBox(
              width: 100,
              child: Text(
                entry.value,
                textAlign: TextAlign.right,
                overflow: TextOverflow.ellipsis,
              ),
            ),
            IconButton(
              onPressed: () => _showVariableEditor(
                context,
                scope,
                variableName: entry.key,
                currentValue: entry.value,
                currentAlias: aliases[entry.key] ?? '',
              ),
              icon: const Icon(Icons.edit_outlined),
            ),
            IconButton(
              onPressed: () => widget.onVariableRemoved(scope, entry.key),
              icon: const Icon(Icons.delete_outline),
            ),
          ],
        ),
      );
    }).toList(growable: false);
  }

  Widget _buildTextEditorCard(
    BuildContext context, {
    required String title,
    required TextEditingController controller,
    required String hintText,
    required Future<void> Function() onSave,
  }) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(title, style: Theme.of(context).textTheme.titleMedium),
            const SizedBox(height: 10),
            TextField(
              controller: controller,
              minLines: 6,
              maxLines: 12,
              decoration: InputDecoration(
                border: const OutlineInputBorder(),
                hintText: hintText,
              ),
              style: const TextStyle(fontFamily: 'monospace'),
            ),
            const SizedBox(height: 8),
            Align(
              alignment: Alignment.centerRight,
              child: FilledButton.icon(
                onPressed: () async {
                  await onSave();
                },
                icon: const Icon(Icons.save_outlined),
                label: const Text('저장'),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildPresetsCard(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('프리셋', style: Theme.of(context).textTheme.titleMedium),
            const SizedBox(height: 10),
            if (widget.presets.isEmpty)
              Text(
                '저장된 프리셋이 없습니다.',
                style: Theme.of(context).textTheme.bodyMedium?.copyWith(color: Colors.grey[600]),
              )
            else
              ...widget.presets.map((preset) {
                final isActive = preset.id == widget.interactionState.activePresetId;
                return ListTile(
                  contentPadding: EdgeInsets.zero,
                  title: Text(preset.name),
                  subtitle: Text(isActive ? '현재 세션에 적용됨' : 'HTML + CSS 묶음'),
                  trailing: Wrap(
                    spacing: 4,
                    children: [
                      IconButton(
                        tooltip: '적용',
                        onPressed: () async {
                          widget.onPresetApplied(preset);
                          _htmlController.text = preset.html;
                          _cssController.text = preset.css;
                          await _reloadBoard();
                        },
                        icon: const Icon(Icons.playlist_add_check_circle_outlined),
                      ),
                      IconButton(
                        tooltip: '이름 변경',
                        onPressed: () => _showPresetRenameDialog(context, preset),
                        icon: const Icon(Icons.drive_file_rename_outline),
                      ),
                      IconButton(
                        tooltip: '내보내기',
                        onPressed: () async {
                          await widget.onPresetExported(preset);
                        },
                        icon: const Icon(Icons.upload_file_outlined),
                      ),
                      IconButton(
                        tooltip: '삭제',
                        onPressed: () async {
                          await widget.onPresetDeleted(preset.id);
                        },
                        icon: const Icon(Icons.delete_outline),
                      ),
                    ],
                  ),
                );
              }),
            const SizedBox(height: 8),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                FilledButton.icon(
                  onPressed: () => _showSavePresetDialog(context),
                  icon: const Icon(Icons.save_outlined),
                  label: const Text('저장'),
                ),
                OutlinedButton.icon(
                  onPressed: () async {
                    await widget.onPresetImported();
                  },
                  icon: const Icon(Icons.download_outlined),
                  label: const Text('가져오기'),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _showVariableEditor(
    BuildContext context,
    ChatVariableScope scope, {
    String variableName = '',
    String currentValue = '',
    String currentAlias = '',
  }) async {
    final nameController = TextEditingController(text: variableName);
    final valueController = TextEditingController(text: currentValue);
    final aliasController = TextEditingController(text: currentAlias);
    await showDialog<void>(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: Text(variableName.isEmpty ? '변수 추가' : '변수 편집'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: nameController,
                decoration: const InputDecoration(labelText: '변수명'),
              ),
              const SizedBox(height: 8),
              TextField(
                controller: aliasController,
                decoration: const InputDecoration(labelText: '표시 별명'),
              ),
              const SizedBox(height: 8),
              TextField(
                controller: valueController,
                decoration: const InputDecoration(labelText: '값'),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('취소'),
            ),
            FilledButton(
              onPressed: () {
                final name = nameController.text.trim();
                if (name.isEmpty) {
                  return;
                }
                widget.onVariableChanged(scope, name, valueController.text);
                widget.onVariableAliasChanged(scope, name, aliasController.text);
                Navigator.pop(context);
              },
              child: const Text('저장'),
            ),
          ],
        );
      },
    );
  }

  Future<void> _showSavePresetDialog(BuildContext context) async {
    final controller = TextEditingController();
    await showDialog<void>(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: const Text('프리셋 저장'),
          content: TextField(
            controller: controller,
            decoration: const InputDecoration(labelText: '프리셋 이름'),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('취소'),
            ),
            FilledButton(
              onPressed: () async {
                await widget.onPresetSaved(
                  controller.text,
                  _htmlController.text,
                  _cssController.text,
                );
                if (context.mounted) {
                  Navigator.pop(context);
                }
              },
              child: const Text('저장'),
            ),
          ],
        );
      },
    );
  }

  Future<void> _showPresetRenameDialog(
    BuildContext context,
    InteractionPreset preset,
  ) async {
    final controller = TextEditingController(text: preset.name);
    await showDialog<void>(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: const Text('프리셋 이름 변경'),
          content: TextField(
            controller: controller,
            decoration: const InputDecoration(labelText: '프리셋 이름'),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('취소'),
            ),
            FilledButton(
              onPressed: () async {
                await widget.onPresetRenamed(preset.id, controller.text);
                if (context.mounted) {
                  Navigator.pop(context);
                }
              },
              child: const Text('변경'),
            ),
          ],
        );
      },
    );
  }
}
