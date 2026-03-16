import 'dart:convert';
import 'dart:io';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../features/lua/models/lua_script.dart';
import '../features/lua/services/lua_scripting_service.dart';
import '../features/regex/models/regex_rule.dart';
import '../features/regex/services/regex_pipeline_service.dart';
import '../models/message.dart';
import '../models/settings.dart';
import '../services/prompt_builder.dart';
import '../providers/settings_provider.dart';
import '../utils/ui_feedback.dart';

class RegexLuaManagementScreen extends StatefulWidget {
  const RegexLuaManagementScreen({super.key});

  @override
  State<RegexLuaManagementScreen> createState() =>
      _RegexLuaManagementScreenState();
}

class _RegexLuaManagementScreenState extends State<RegexLuaManagementScreen>
    with SingleTickerProviderStateMixin {
  late final TabController _tabController;
  final _regexService = RegexPipelineService.instance;
  final _luaService = LuaScriptingService.instance;
  final _promptBuilder = PromptBuilder();
  final TextEditingController _testInputController = TextEditingController();

  List<RegexRule> _regexRules = [];
  List<LuaScript> _luaScripts = [];
  final List<String> _testChatLogs = [];
  String _testOutput = '';
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
    _load();
  }

  @override
  void dispose() {
    _tabController.dispose();
    _testInputController.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    final regex = await _regexService.getRules();
    final lua = await _luaService.getScripts();
    if (!mounted) return;
    setState(() {
      _regexRules = List<RegexRule>.from(regex)
        ..sort((a, b) => a.priority.compareTo(b.priority));
      _luaScripts = List<LuaScript>.from(lua)
        ..sort((a, b) => a.order.compareTo(b.order));
      _loading = false;
    });
  }

  Future<void> _saveRegex() async {
    await _regexService.saveRules(_regexRules);
    if (!mounted) return;
    context.showInfoSnackBar('Regex 규칙이 저장되었습니다.');
  }

  Future<void> _saveLua() async {
    await _luaService.saveScripts(_luaScripts);
    if (!mounted) return;
    context.showInfoSnackBar('Lua 스크립트가 저장되었습니다.');
  }

  @override
  Widget build(BuildContext context) {
    final settingsProvider = context.watch<SettingsProvider>();
    final settings = settingsProvider.settings;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Regex / Lua 관리'),
        bottom: TabBar(
          controller: _tabController,
          tabs: const [
            Tab(text: 'LLM 연결'),
            Tab(text: 'Regex'),
            Tab(text: 'Lua'),
          ],
        ),
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : TabBarView(
              controller: _tabController,
              children: [
                ListView(
                  padding: const EdgeInsets.all(16),
                  children: [
                    SwitchListTile(
                      title: const Text('Lua 런타임 함수 실행 사용'),
                      subtitle: const Text('Lua 훅 안에서 직접 오버레이/파라미터 동작을 실행'),
                      value: settings.live2dLuaExecutionEnabled,
                      onChanged: settingsProvider.setLive2DLuaExecutionEnabled,
                    ),
                    SwitchListTile(
                      title: const Text('모델 기능 프롬프트 주입 사용'),
                      subtitle: const Text('시스템 프롬프트에 모델 능력 정보 주입'),
                      value: settings.live2dPromptInjectionEnabled,
                      onChanged:
                          settingsProvider.setLive2DPromptInjectionEnabled,
                    ),
                    SwitchListTile(
                      title: const Text('Regex 선처리 후 Lua 실행'),
                      subtitle: const Text('해제 시 Lua를 먼저 실행한 뒤 Regex 적용'),
                      value: settings.runRegexBeforeLua,
                      onChanged: settingsProvider.setRunRegexBeforeLua,
                    ),
                    const SizedBox(height: 12),
                    TextFormField(
                      initialValue: settings.live2dSystemPromptTemplate,
                      minLines: 4,
                      maxLines: 10,
                      decoration: const InputDecoration(
                        labelText: 'Live2D 예시 프롬프트 템플릿',
                        helperText: '현재 기본 Lua 템플릿이 인식하는 Live2D 예시 형식',
                        border: OutlineInputBorder(),
                      ),
                      onChanged: settingsProvider.setLive2DSystemPromptTemplate,
                    ),
                    const SizedBox(height: 12),
                    TextFormField(
                      initialValue: settings.imageOverlaySystemPromptTemplate,
                      minLines: 4,
                      maxLines: 10,
                      decoration: const InputDecoration(
                        labelText: '이미지 오버레이 예시 프롬프트 템플릿',
                        helperText: '현재 기본 Lua 템플릿이 인식하는 Overlay 예시 형식',
                        border: OutlineInputBorder(),
                      ),
                      onChanged:
                          settingsProvider.setImageOverlaySystemPromptTemplate,
                    ),
                    const SizedBox(height: 16),
                    _buildTestChatPanel(settingsProvider),
                  ],
                ),
                _buildRegexTab(),
                _buildLuaTab(),
              ],
            ),
    );
  }

  Widget _buildRegexTab() {
    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.all(12),
          child: Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              OutlinedButton.icon(
                onPressed: () async {
                  final next = await _showRegexEditor();
                  if (next == null) return;
                  setState(() => _regexRules.add(next));
                  await _saveRegex();
                },
                icon: const Icon(Icons.add),
                label: const Text('규칙 추가'),
              ),
              OutlinedButton.icon(
                onPressed: _importRegexRules,
                icon: const Icon(Icons.upload_file),
                label: const Text('가져오기'),
              ),
              OutlinedButton.icon(
                onPressed: _exportRegexRules,
                icon: const Icon(Icons.download),
                label: const Text('내보내기'),
              ),
              OutlinedButton.icon(
                onPressed: _showRegexTestDialog,
                icon: const Icon(Icons.science),
                label: const Text('룰 테스트'),
              ),
            ],
          ),
        ),
        Expanded(
          child: _regexRules.isEmpty
              ? const Center(child: Text('저장된 Regex 규칙이 없습니다.'))
              : ListView.builder(
                  padding: const EdgeInsets.fromLTRB(12, 4, 12, 12),
                  itemCount: _regexRules.length,
                  itemBuilder: (context, index) {
                    final rule = _regexRules[index];
                    return _buildRegexRuleBlock(rule: rule, index: index);
                  },
                ),
        ),
      ],
    );
  }

  Widget _buildLuaTab() {
    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.all(12),
          child: Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              OutlinedButton.icon(
                onPressed: () async {
                  final next = await _showLuaEditor();
                  if (next == null) return;
                  setState(() => _luaScripts.add(next));
                  await _saveLua();
                },
                icon: const Icon(Icons.add),
                label: const Text('스크립트 추가'),
              ),
              OutlinedButton.icon(
                onPressed: _importLuaScripts,
                icon: const Icon(Icons.upload_file),
                label: const Text('가져오기'),
              ),
              OutlinedButton.icon(
                onPressed: _exportLuaScripts,
                icon: const Icon(Icons.download),
                label: const Text('내보내기'),
              ),
              OutlinedButton.icon(
                onPressed: () {
                  setState(_luaService.clearLogs);
                },
                icon: const Icon(Icons.clear_all),
                label: const Text('로그 지우기'),
              ),
            ],
          ),
        ),
        Expanded(
          child: _luaScripts.isEmpty
              ? const Center(child: Text('저장된 Lua 스크립트가 없습니다.'))
              : ListView.builder(
                  padding: const EdgeInsets.fromLTRB(12, 4, 12, 12),
                  itemCount: _luaScripts.length,
                  itemBuilder: (context, index) {
                    final script = _luaScripts[index];
                    return _buildLuaScriptBlock(script: script, index: index);
                  },
                ),
        ),
        ExpansionTile(
          title: const Text('스크립트 로그'),
          subtitle: Text('${_luaService.logs.length} entries'),
          children: [
            SizedBox(
              height: 180,
              child: ListView.builder(
                itemCount: _luaService.logs.length,
                itemBuilder: (context, index) {
                  return ListTile(
                    dense: true,
                    title: Text(
                      _luaService.logs[index],
                      style: const TextStyle(fontSize: 12),
                    ),
                  );
                },
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildRegexRuleBlock({required RegexRule rule, required int index}) {
    final titleStyle = Theme.of(context).textTheme.titleMedium;
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Padding(
              padding: const EdgeInsets.only(top: 2),
              child: Icon(
                rule.isEnabled ? Icons.rule : Icons.rule_outlined,
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    rule.name,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: titleStyle,
                  ),
                  const SizedBox(height: 6),
                  Wrap(
                    spacing: 4,
                    runSpacing: 4,
                    children: [
                      IconButton(
                        tooltip: '위로 이동',
                        onPressed: index > 0
                            ? () async {
                                setState(() {
                                  final current = _regexRules[index];
                                  _regexRules[index] = _regexRules[index - 1];
                                  _regexRules[index - 1] = current;
                                  _reindexRegexPriority();
                                });
                                await _saveRegex();
                              }
                            : null,
                        icon: const Icon(Icons.arrow_upward),
                      ),
                      IconButton(
                        tooltip: '아래로 이동',
                        onPressed: index < _regexRules.length - 1
                            ? () async {
                                setState(() {
                                  final current = _regexRules[index];
                                  _regexRules[index] = _regexRules[index + 1];
                                  _regexRules[index + 1] = current;
                                  _reindexRegexPriority();
                                });
                                await _saveRegex();
                              }
                            : null,
                        icon: const Icon(Icons.arrow_downward),
                      ),
                      IconButton(
                        tooltip: '편집',
                        onPressed: () async {
                          final edited = await _showRegexEditor(existing: rule);
                          if (edited == null) return;
                          setState(() => _regexRules[index] = edited);
                          await _saveRegex();
                        },
                        icon: const Icon(Icons.edit),
                      ),
                      IconButton(
                        tooltip: '삭제',
                        onPressed: () async {
                          setState(() => _regexRules.removeAt(index));
                          _reindexRegexPriority();
                          await _saveRegex();
                        },
                        icon: const Icon(Icons.delete_outline),
                      ),
                      Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const Text('활성'),
                          Switch(
                            value: rule.isEnabled,
                            onChanged: (value) async {
                              setState(() {
                                _regexRules[index] = rule.copyWith(
                                  isEnabled: value,
                                );
                              });
                              await _saveRegex();
                            },
                          ),
                        ],
                      ),
                    ],
                  ),
                  const SizedBox(height: 6),
                  Text(
                    '${rule.type.name} · p=${rule.priority} · ${rule.scope.name}',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 2),
                  Text(
                    '/${rule.pattern}/ -> ${rule.replacement}',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: Theme.of(context).textTheme.bodySmall,
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildLuaScriptBlock({required LuaScript script, required int index}) {
    final titleStyle = Theme.of(context).textTheme.titleMedium;
    final firstLine = script.content.split('\n').firstWhere(
      (line) => line.trim().isNotEmpty,
      orElse: () => '(빈 스크립트)',
    );

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Padding(
              padding: const EdgeInsets.only(top: 2),
              child: Icon(
                script.isEnabled
                    ? Icons.description
                    : Icons.description_outlined,
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    script.name,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: titleStyle,
                  ),
                  const SizedBox(height: 6),
                  Wrap(
                    spacing: 4,
                    runSpacing: 4,
                    children: [
                      IconButton(
                        tooltip: '위로 이동',
                        onPressed: index > 0
                            ? () async {
                                setState(() {
                                  final current = _luaScripts[index];
                                  _luaScripts[index] = _luaScripts[index - 1];
                                  _luaScripts[index - 1] = current;
                                  _reindexLuaOrder();
                                });
                                await _saveLua();
                              }
                            : null,
                        icon: const Icon(Icons.arrow_upward),
                      ),
                      IconButton(
                        tooltip: '아래로 이동',
                        onPressed: index < _luaScripts.length - 1
                            ? () async {
                                setState(() {
                                  final current = _luaScripts[index];
                                  _luaScripts[index] = _luaScripts[index + 1];
                                  _luaScripts[index + 1] = current;
                                  _reindexLuaOrder();
                                });
                                await _saveLua();
                              }
                            : null,
                        icon: const Icon(Icons.arrow_downward),
                      ),
                      IconButton(
                        tooltip: '편집',
                        onPressed: () async {
                          final edited = await _showLuaEditor(existing: script);
                          if (edited == null) return;
                          setState(() => _luaScripts[index] = edited);
                          await _saveLua();
                        },
                        icon: const Icon(Icons.edit),
                      ),
                      IconButton(
                        tooltip: '삭제',
                        onPressed: () async {
                          setState(() => _luaScripts.removeAt(index));
                          _reindexLuaOrder();
                          await _saveLua();
                        },
                        icon: const Icon(Icons.delete_outline),
                      ),
                      Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const Text('활성'),
                          Switch(
                            value: script.isEnabled,
                            onChanged: (value) async {
                              setState(() {
                                _luaScripts[index] = script.copyWith(
                                  isEnabled: value,
                                );
                              });
                              await _saveLua();
                            },
                          ),
                        ],
                      ),
                    ],
                  ),
                  const SizedBox(height: 6),
                  Text(
                    '${script.scope.name} · order=${script.order}',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 2),
                  Text(
                    firstLine,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: Theme.of(context).textTheme.bodySmall,
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildTestChatPanel(SettingsProvider settingsProvider) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('테스트 채팅', style: Theme.of(context).textTheme.titleMedium),
            const SizedBox(height: 6),
            const Text(
              '@user: 유저 입력 파이프라인/LLM 전송 프롬프트 출력\n'
              '@char: 캐릭터 출력 파이프라인/Lua·Regex 처리 결과 출력',
            ),
            const SizedBox(height: 10),
            TextField(
              controller: _testInputController,
              minLines: 2,
              maxLines: 5,
              decoration: const InputDecoration(
                border: OutlineInputBorder(),
                hintText:
                    '@user 안녕 / @char <live2d><emotion name="happy"/></live2d> 반가워! / [img_emotion:name=happy]',
              ),
            ),
            const SizedBox(height: 8),
            Row(
              children: [
                FilledButton.icon(
                  onPressed: () => _runTestChat(settingsProvider),
                  icon: const Icon(Icons.play_arrow),
                  label: const Text('실행'),
                ),
                const SizedBox(width: 8),
                OutlinedButton.icon(
                  onPressed: () {
                    setState(() {
                      _testChatLogs.clear();
                      _testOutput = '';
                    });
                  },
                  icon: const Icon(Icons.clear_all),
                  label: const Text('로그 지우기'),
                ),
              ],
            ),
            const SizedBox(height: 10),
            Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text('테스트 결과'),
                      const SizedBox(height: 6),
                      Container(
                        width: double.infinity,
                        padding: const EdgeInsets.all(10),
                        decoration: BoxDecoration(
                          border: Border.all(
                            color: Theme.of(context).colorScheme.outlineVariant,
                          ),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: SelectableText(
                          _testOutput.isEmpty ? '(결과 없음)' : _testOutput,
                          style: const TextStyle(fontSize: 12),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text('테스트 채팅 로그'),
                      const SizedBox(height: 6),
                      Container(
                        height: 180,
                        decoration: BoxDecoration(
                          border: Border.all(
                            color: Theme.of(context).colorScheme.outlineVariant,
                          ),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: _testChatLogs.isEmpty
                            ? const Center(child: Text('(로그 없음)'))
                            : ListView.builder(
                                itemCount: _testChatLogs.length,
                                itemBuilder: (context, index) {
                                  return ListTile(
                                    dense: true,
                                    title: Text(
                                      _testChatLogs[index],
                                      style: const TextStyle(fontSize: 12),
                                    ),
                                  );
                                },
                              ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _runTestChat(SettingsProvider settingsProvider) async {
    final raw = _testInputController.text.trim();
    if (raw.isEmpty) {
      return;
    }

    final settings = settingsProvider.settings;
    final character = settingsProvider.character;
    final userName = settingsProvider.userName;
    const sessionId = 'regex_lua_test_session';

    if (raw.startsWith('@user')) {
      final input = raw.substring(5).trim();
      if (input.isEmpty) {
        return;
      }
      final processed = await _applyUserPipeline(
        input,
        settings: settings,
        sessionId: sessionId,
        characterId: character.id,
        characterName: character.name,
        userName: userName,
      );

      final messages = _promptBuilder.buildMessages(
        character: character,
        settings: settings,
        chatHistory: [
          Message(role: MessageRole.user, content: processed),
        ],
        userName: userName,
      );

      final promptText = messages
          .map((m) => '[${m.roleString}]\n${m.content}')
          .join('\n\n');

      setState(() {
        _testOutput = promptText;
        _appendTestLog('USER pipeline -> prompt 생성 완료');
      });
      return;
    }

    if (raw.startsWith('@char')) {
      final input = raw.substring(5).trim();
      if (input.isEmpty) {
        return;
      }

      final result = await _applyAssistantPipelineForTest(
        input,
        settings: settings,
        sessionId: sessionId,
        characterId: character.id,
        characterName: character.name,
        userName: userName,
      );

      setState(() {
        _testOutput = result;
      });
      return;
    }

    setState(() {
      _appendTestLog('입력은 @user 또는 @char로 시작해야 합니다.');
    });
  }

  Future<String> _applyUserPipeline(
    String text, {
    required AppSettings settings,
    required String sessionId,
    required String characterId,
    required String characterName,
    required String userName,
  }) async {
    var output = text;
    final luaEnabled = settings.live2dLuaExecutionEnabled;

    if (settings.runRegexBeforeLua) {
      output = await _regexService.applyUserInput(
        output,
        characterId: characterId,
        sessionId: sessionId,
      );
      if (luaEnabled) {
        output = await _luaService.onUserMessage(
          output,
          LuaHookContext(
            characterId: characterId,
            characterName: characterName,
            userName: userName,
          ),
        );
      }
    } else {
      if (luaEnabled) {
        output = await _luaService.onUserMessage(
          output,
          LuaHookContext(
            characterId: characterId,
            characterName: characterName,
            userName: userName,
          ),
        );
      }
      output = await _regexService.applyUserInput(
        output,
        characterId: characterId,
        sessionId: sessionId,
      );
    }

    return output;
  }

  Future<String> _applyAssistantPipelineForTest(
    String text, {
    required AppSettings settings,
    required String sessionId,
    required String characterId,
    required String characterName,
    required String userName,
  }) async {
    var output = text;
    final luaEnabled = settings.live2dLuaExecutionEnabled;

    if (settings.runRegexBeforeLua) {
      output = await _regexService.applyAiOutput(
        output,
        characterId: characterId,
        sessionId: sessionId,
      );
      if (luaEnabled) {
        output = await _luaService.onAssistantMessage(
          output,
          LuaHookContext(
            characterId: characterId,
            characterName: characterName,
            userName: userName,
            directiveSyntaxOwnershipEnabled: true,
            live2dLlmIntegrationEnabled: settings.live2dLlmIntegrationEnabled,
            live2dDirectiveParsingEnabled:
                settings.live2dDirectiveParsingEnabled,
            live2dShowRawDirectivesInChat:
                settings.live2dShowRawDirectivesInChat,
            llmDirectiveTarget: settings.llmDirectiveTarget,
          ),
        );
      }
    } else {
      if (luaEnabled) {
        output = await _luaService.onAssistantMessage(
          output,
          LuaHookContext(
            characterId: characterId,
            characterName: characterName,
            userName: userName,
            directiveSyntaxOwnershipEnabled: true,
            live2dLlmIntegrationEnabled: settings.live2dLlmIntegrationEnabled,
            live2dDirectiveParsingEnabled:
                settings.live2dDirectiveParsingEnabled,
            live2dShowRawDirectivesInChat:
                settings.live2dShowRawDirectivesInChat,
            llmDirectiveTarget: settings.llmDirectiveTarget,
          ),
        );
      }
      output = await _regexService.applyAiOutput(
        output,
        characterId: characterId,
        sessionId: sessionId,
      );
    }

    if (settings.runRegexBeforeLua) {
      output = await _regexService.applyDisplayOnly(
        output,
        characterId: characterId,
        sessionId: sessionId,
      );
      if (luaEnabled) {
        output = await _luaService.onDisplayRender(
          output,
          LuaHookContext(
            characterId: characterId,
            characterName: characterName,
            userName: userName,
          ),
        );
      }
    } else {
      if (luaEnabled) {
        output = await _luaService.onDisplayRender(
          output,
          LuaHookContext(
            characterId: characterId,
            characterName: characterName,
            userName: userName,
          ),
        );
      }
      output = await _regexService.applyDisplayOnly(
        output,
        characterId: characterId,
        sessionId: sessionId,
      );
    }

    _appendTestLog('CHAR pipeline 처리 완료');
    _appendTestLog('명령 실행 로그: Lua direct-dispatch 파이프라인 적용');

    return output;
  }

  void _appendTestLog(String text) {
    final line = '[${DateTime.now().toIso8601String()}] $text';
    _testChatLogs.add(line);
    if (_testChatLogs.length > 200) {
      _testChatLogs.removeAt(0);
    }
  }

  Future<void> _importRegexRules() async {
    final picked = await FilePicker.platform.pickFiles(
      type: FileType.custom,
      allowedExtensions: ['json'],
    );
    final path = picked?.files.single.path;
    if (path == null) return;

    final content = await File(path).readAsString();
    final decoded = jsonDecode(content);
    if (decoded is! List) return;

    final imported = decoded
        .whereType<Map<String, dynamic>>()
        .map(RegexRule.fromMap)
        .toList();
    setState(() {
      _regexRules = imported;
      _reindexRegexPriority();
    });
    await _saveRegex();
  }

  Future<void> _exportRegexRules() async {
    final path = await FilePicker.platform.saveFile(
      dialogTitle: 'Regex 규칙 JSON 저장',
      fileName: 'regex_rules.json',
      type: FileType.custom,
      allowedExtensions: ['json'],
    );
    if (path == null) return;

    final payload = jsonEncode(
      _regexRules.map((rule) => rule.toMap()).toList(),
    );
    await File(path).writeAsString(payload);
    if (!mounted) return;
    context.showInfoSnackBar('Regex 규칙을 내보냈습니다.');
  }

  Future<void> _showRegexTestDialog() async {
    final inputController = TextEditingController();
    String output = '';

    await showDialog<void>(
      context: context,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setLocal) {
            return AlertDialog(
              title: const Text('Regex 룰 테스트'),
              content: SizedBox(
                width: 520,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    TextField(
                      controller: inputController,
                      minLines: 3,
                      maxLines: 6,
                      decoration: const InputDecoration(
                        labelText: '입력 텍스트',
                        border: OutlineInputBorder(),
                      ),
                    ),
                    const SizedBox(height: 12),
                    Align(
                      alignment: Alignment.centerLeft,
                      child: Text(output.isEmpty ? '(결과 없음)' : output),
                    ),
                  ],
                ),
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(context),
                  child: const Text('닫기'),
                ),
                ElevatedButton(
                  onPressed: () async {
                    await _saveRegex();
                    final result = await _regexService.applyAiOutput(
                      inputController.text,
                    );
                    setLocal(() => output = result);
                  },
                  child: const Text('실행'),
                ),
              ],
            );
          },
        );
      },
    );
  }

  Future<void> _importLuaScripts() async {
    final picked = await FilePicker.platform.pickFiles(
      type: FileType.custom,
      allowedExtensions: ['json'],
    );
    final path = picked?.files.single.path;
    if (path == null) return;

    final content = await File(path).readAsString();
    final decoded = jsonDecode(content);
    if (decoded is! List) return;

    final imported = decoded
        .whereType<Map<String, dynamic>>()
        .map(LuaScript.fromMap)
        .toList();
    setState(() {
      _luaScripts = imported;
      _reindexLuaOrder();
    });
    await _saveLua();
  }

  Future<void> _exportLuaScripts() async {
    final path = await FilePicker.platform.saveFile(
      dialogTitle: 'Lua 스크립트 JSON 저장',
      fileName: 'lua_scripts.json',
      type: FileType.custom,
      allowedExtensions: ['json'],
    );
    if (path == null) return;

    final payload = jsonEncode(
      _luaScripts.map((script) => script.toMap()).toList(),
    );
    await File(path).writeAsString(payload);
    if (!mounted) return;
    context.showInfoSnackBar('Lua 스크립트를 내보냈습니다.');
  }

  void _reindexRegexPriority() {
    for (var i = 0; i < _regexRules.length; i++) {
      _regexRules[i] = _regexRules[i].copyWith(priority: i);
    }
  }

  void _reindexLuaOrder() {
    for (var i = 0; i < _luaScripts.length; i++) {
      _luaScripts[i] = _luaScripts[i].copyWith(order: i);
    }
  }

  Future<RegexRule?> _showRegexEditor({RegexRule? existing}) async {
    return Navigator.of(context).push<RegexRule>(
      MaterialPageRoute(
        builder: (_) => _RegexRuleEditorPage(
          existing: existing,
          nextPriority: _regexRules.length,
        ),
        fullscreenDialog: true,
      ),
    );
  }

  Future<LuaScript?> _showLuaEditor({LuaScript? existing}) async {
    return Navigator.of(context).push<LuaScript>(
      MaterialPageRoute(
        builder: (_) => _LuaScriptEditorPage(
          existing: existing,
          nextOrder: _luaScripts.length,
        ),
        fullscreenDialog: true,
      ),
    );
  }
}

class _RegexRuleEditorPage extends StatefulWidget {
  const _RegexRuleEditorPage({
    required this.existing,
    required this.nextPriority,
  });

  final RegexRule? existing;
  final int nextPriority;

  @override
  State<_RegexRuleEditorPage> createState() => _RegexRuleEditorPageState();
}

class _RegexRuleEditorPageState extends State<_RegexRuleEditorPage> {
  late final TextEditingController _nameController;
  late final TextEditingController _patternController;
  late final TextEditingController _replacementController;
  late final TextEditingController _characterController;
  late final TextEditingController _sessionController;

  late RegexRuleType _type;
  late RegexRuleScope _scope;
  late bool _caseInsensitive;
  late bool _multiLine;
  late bool _dotAll;

  @override
  void initState() {
    super.initState();
    final existing = widget.existing;
    _nameController = TextEditingController(text: existing?.name ?? '');
    _patternController = TextEditingController(text: existing?.pattern ?? '');
    _replacementController = TextEditingController(
      text: existing?.replacement ?? '',
    );
    _characterController = TextEditingController(
      text: existing?.associatedCharacterId ?? '',
    );
    _sessionController = TextEditingController(
      text: existing?.associatedSessionId ?? '',
    );

    _type = existing?.type ?? RegexRuleType.aiOutput;
    _scope = existing?.scope ?? RegexRuleScope.global;
    _caseInsensitive = existing?.caseInsensitive ?? false;
    _multiLine = existing?.multiLine ?? false;
    _dotAll = existing?.dotAll ?? false;
  }

  @override
  void dispose() {
    _nameController.dispose();
    _patternController.dispose();
    _replacementController.dispose();
    _characterController.dispose();
    _sessionController.dispose();
    super.dispose();
  }

  void _save() {
    final name = _nameController.text.trim();
    final pattern = _patternController.text;
    final replacement = _replacementController.text;

    if (name.isEmpty || pattern.isEmpty) {
      context.showErrorSnackBar('이름과 패턴은 필수입니다.');
      return;
    }

    Navigator.of(context).pop(
      RegexRule(
        id: widget.existing?.id,
        name: name,
        type: _type,
        pattern: pattern,
        replacement: replacement,
        caseInsensitive: _caseInsensitive,
        multiLine: _multiLine,
        dotAll: _dotAll,
        isEnabled: widget.existing?.isEnabled ?? true,
        priority: widget.existing?.priority ?? widget.nextPriority,
        scope: _scope,
        associatedCharacterId: _characterController.text.trim().isEmpty
            ? null
            : _characterController.text.trim(),
        associatedSessionId: _sessionController.text.trim().isEmpty
            ? null
            : _sessionController.text.trim(),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final title = widget.existing == null
        ? 'Regex 규칙 추가'
        : 'Regex 규칙 편집';

    return Scaffold(
      appBar: AppBar(
        title: Text(title),
        actions: [
          TextButton(
            onPressed: _save,
            child: const Text('저장'),
          ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          TextField(
            controller: _nameController,
            decoration: const InputDecoration(
              labelText: '이름',
              border: OutlineInputBorder(),
            ),
          ),
          const SizedBox(height: 12),
          DropdownButtonFormField<RegexRuleType>(
            initialValue: _type,
            decoration: const InputDecoration(
              labelText: '타입',
              border: OutlineInputBorder(),
            ),
            items: RegexRuleType.values
                .map(
                  (value) => DropdownMenuItem(
                    value: value,
                    child: Text(value.name),
                  ),
                )
                .toList(),
            onChanged: (value) {
              if (value != null) {
                setState(() => _type = value);
              }
            },
          ),
          const SizedBox(height: 12),
          DropdownButtonFormField<RegexRuleScope>(
            initialValue: _scope,
            decoration: const InputDecoration(
              labelText: '스코프',
              border: OutlineInputBorder(),
            ),
            items: RegexRuleScope.values
                .map(
                  (value) => DropdownMenuItem(
                    value: value,
                    child: Text(value.name),
                  ),
                )
                .toList(),
            onChanged: (value) {
              if (value != null) {
                setState(() => _scope = value);
              }
            },
          ),
          const SizedBox(height: 12),
          TextField(
            controller: _patternController,
            decoration: const InputDecoration(
              labelText: '패턴',
              border: OutlineInputBorder(),
            ),
          ),
          const SizedBox(height: 12),
          TextField(
            controller: _replacementController,
            decoration: const InputDecoration(
              labelText: '치환 문자열',
              border: OutlineInputBorder(),
            ),
          ),
          if (_scope == RegexRuleScope.perCharacter) ...[
            const SizedBox(height: 12),
            TextField(
              controller: _characterController,
              decoration: const InputDecoration(
                labelText: '캐릭터 ID',
                border: OutlineInputBorder(),
              ),
            ),
          ],
          if (_scope == RegexRuleScope.perSession) ...[
            const SizedBox(height: 12),
            TextField(
              controller: _sessionController,
              decoration: const InputDecoration(
                labelText: '세션 ID',
                border: OutlineInputBorder(),
              ),
            ),
          ],
          const SizedBox(height: 10),
          CheckboxListTile(
            contentPadding: EdgeInsets.zero,
            value: _caseInsensitive,
            onChanged: (value) {
              setState(() => _caseInsensitive = value ?? false);
            },
            title: const Text('CASE_INSENSITIVE'),
          ),
          CheckboxListTile(
            contentPadding: EdgeInsets.zero,
            value: _multiLine,
            onChanged: (value) {
              setState(() => _multiLine = value ?? false);
            },
            title: const Text('MULTILINE'),
          ),
          CheckboxListTile(
            contentPadding: EdgeInsets.zero,
            value: _dotAll,
            onChanged: (value) {
              setState(() => _dotAll = value ?? false);
            },
            title: const Text('DOT_ALL'),
          ),
          const SizedBox(height: 12),
          FilledButton(
            onPressed: _save,
            child: const Text('저장'),
          ),
        ],
      ),
    );
  }
}

class _LuaScriptEditorPage extends StatefulWidget {
  const _LuaScriptEditorPage({
    required this.existing,
    required this.nextOrder,
  });

  final LuaScript? existing;
  final int nextOrder;

  @override
  State<_LuaScriptEditorPage> createState() => _LuaScriptEditorPageState();
}

class _LuaScriptEditorPageState extends State<_LuaScriptEditorPage> {
  late final TextEditingController _nameController;
  late final TextEditingController _contentController;
  late final TextEditingController _characterController;
  late LuaScriptScope _scope;

  @override
  void initState() {
    super.initState();
    final existing = widget.existing;
    _nameController = TextEditingController(text: existing?.name ?? '');
    _contentController = TextEditingController(text: existing?.content ?? '');
    _characterController = TextEditingController(
      text: existing?.characterId ?? '',
    );
    _scope = existing?.scope ?? LuaScriptScope.global;
  }

  @override
  void dispose() {
    _nameController.dispose();
    _contentController.dispose();
    _characterController.dispose();
    super.dispose();
  }

  void _save() {
    final name = _nameController.text.trim();
    final content = _contentController.text;

    if (name.isEmpty || content.trim().isEmpty) {
      context.showErrorSnackBar('이름과 스크립트 내용은 필수입니다.');
      return;
    }

    Navigator.of(context).pop(
      LuaScript(
        id: widget.existing?.id,
        name: name,
        content: content,
        isEnabled: widget.existing?.isEnabled ?? true,
        order: widget.existing?.order ?? widget.nextOrder,
        scope: _scope,
        characterId: _characterController.text.trim().isEmpty
            ? null
            : _characterController.text.trim(),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final title = widget.existing == null
        ? 'Lua 스크립트 추가'
        : 'Lua 스크립트 편집';

    return Scaffold(
      appBar: AppBar(
        title: Text(title),
        actions: [
          TextButton(
            onPressed: _save,
            child: const Text('저장'),
          ),
        ],
      ),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            TextField(
              controller: _nameController,
              decoration: const InputDecoration(
                labelText: '이름',
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 12),
            DropdownButtonFormField<LuaScriptScope>(
              initialValue: _scope,
              decoration: const InputDecoration(
                labelText: '스코프',
                border: OutlineInputBorder(),
              ),
              items: LuaScriptScope.values
                  .map(
                    (value) => DropdownMenuItem(
                      value: value,
                      child: Text(value.name),
                    ),
                  )
                  .toList(),
              onChanged: (value) {
                if (value != null) {
                  setState(() => _scope = value);
                }
              },
            ),
            if (_scope == LuaScriptScope.perCharacter) ...[
              const SizedBox(height: 12),
              TextField(
                controller: _characterController,
                decoration: const InputDecoration(
                  labelText: '캐릭터 ID',
                  border: OutlineInputBorder(),
                ),
              ),
            ],
            const SizedBox(height: 12),
            Expanded(
              child: TextField(
                controller: _contentController,
                expands: true,
                maxLines: null,
                minLines: null,
                textAlignVertical: TextAlignVertical.top,
                decoration: const InputDecoration(
                  labelText: '스크립트 내용',
                  alignLabelWithHint: true,
                  border: OutlineInputBorder(),
                ),
              ),
            ),
            const SizedBox(height: 12),
            SizedBox(
              width: double.infinity,
              child: FilledButton(
                onPressed: _save,
                child: const Text('저장'),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
