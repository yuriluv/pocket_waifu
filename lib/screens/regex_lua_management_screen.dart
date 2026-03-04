import 'dart:convert';
import 'dart:io';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../features/lua/models/lua_script.dart';
import '../features/lua/services/lua_scripting_service.dart';
import '../features/regex/models/regex_rule.dart';
import '../features/regex/services/regex_pipeline_service.dart';
import '../features/live2d_llm/services/live2d_directive_service.dart';
import '../features/image_overlay/services/image_overlay_directive_service.dart';
import '../models/message.dart';
import '../models/settings.dart';
import '../services/prompt_builder.dart';
import '../providers/settings_provider.dart';

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
  final _live2dDirectiveService = Live2DDirectiveService.instance;
  final _imageDirectiveService = ImageOverlayDirectiveService.instance;
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
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(const SnackBar(content: Text('Regex 규칙이 저장되었습니다.')));
  }

  Future<void> _saveLua() async {
    await _luaService.saveScripts(_luaScripts);
    if (!mounted) return;
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(const SnackBar(content: Text('Lua 스크립트가 저장되었습니다.')));
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
                    DropdownButtonFormField<LlmDirectiveTarget>(
                      initialValue: settings.llmDirectiveTarget,
                      decoration: const InputDecoration(
                        labelText: 'LLM 연결 대상',
                        border: OutlineInputBorder(),
                      ),
                      items: const [
                        DropdownMenuItem(
                          value: LlmDirectiveTarget.live2d,
                          child: Text('Live2D'),
                        ),
                        DropdownMenuItem(
                          value: LlmDirectiveTarget.imageOverlay,
                          child: Text('이미지 오버레이'),
                        ),
                      ],
                      onChanged: (value) {
                        if (value != null) {
                          settingsProvider.setLlmDirectiveTarget(value);
                          setState(() {});
                        }
                      },
                    ),
                    const SizedBox(height: 12),
                    SwitchListTile(
                      title: const Text('지시어 파싱 사용'),
                      subtitle: Text(
                        settings.llmDirectiveTarget == LlmDirectiveTarget.live2d
                            ? 'AI 응답의 <live2d> 지시어 블록 실행'
                            : 'AI 응답의 <overlay> 지시어 블록 실행',
                      ),
                      value: settings.live2dDirectiveParsingEnabled,
                      onChanged:
                          settingsProvider.setLive2DDirectiveParsingEnabled,
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
                    if (settings.llmDirectiveTarget ==
                        LlmDirectiveTarget.live2d)
                      TextFormField(
                        initialValue: settings.live2dSystemPromptTemplate,
                        minLines: 6,
                        maxLines: 14,
                        decoration: const InputDecoration(
                          labelText: 'Live2D 시스템 프롬프트 템플릿',
                          border: OutlineInputBorder(),
                        ),
                        onChanged:
                            settingsProvider.setLive2DSystemPromptTemplate,
                      )
                    else
                      TextFormField(
                        initialValue: settings.imageOverlaySystemPromptTemplate,
                        minLines: 6,
                        maxLines: 14,
                        decoration: const InputDecoration(
                          labelText: '이미지 오버레이 시스템 프롬프트 템플릿',
                          border: OutlineInputBorder(),
                        ),
                        onChanged: settingsProvider
                            .setImageOverlaySystemPromptTemplate,
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
                  itemCount: _regexRules.length,
                  itemBuilder: (context, index) {
                    final rule = _regexRules[index];
                    return ListTile(
                      leading: Icon(
                        rule.isEnabled ? Icons.rule : Icons.rule_outlined,
                      ),
                      title: Text(rule.name),
                      subtitle: Text(
                        '${rule.type.name} · p=${rule.priority} · ${rule.scope.name}\n/${rule.pattern}/ -> ${rule.replacement}',
                      ),
                      isThreeLine: true,
                      trailing: Wrap(
                        spacing: 4,
                        children: [
                          IconButton(
                            onPressed: index > 0
                                ? () async {
                                    setState(() {
                                      final current = _regexRules[index];
                                      _regexRules[index] =
                                          _regexRules[index - 1];
                                      _regexRules[index - 1] = current;
                                      _reindexRegexPriority();
                                    });
                                    await _saveRegex();
                                  }
                                : null,
                            icon: const Icon(Icons.arrow_upward),
                          ),
                          IconButton(
                            onPressed: index < _regexRules.length - 1
                                ? () async {
                                    setState(() {
                                      final current = _regexRules[index];
                                      _regexRules[index] =
                                          _regexRules[index + 1];
                                      _regexRules[index + 1] = current;
                                      _reindexRegexPriority();
                                    });
                                    await _saveRegex();
                                  }
                                : null,
                            icon: const Icon(Icons.arrow_downward),
                          ),
                          IconButton(
                            onPressed: () async {
                              final edited = await _showRegexEditor(
                                existing: rule,
                              );
                              if (edited == null) return;
                              setState(() => _regexRules[index] = edited);
                              await _saveRegex();
                            },
                            icon: const Icon(Icons.edit),
                          ),
                          IconButton(
                            onPressed: () async {
                              setState(() => _regexRules.removeAt(index));
                              _reindexRegexPriority();
                              await _saveRegex();
                            },
                            icon: const Icon(Icons.delete_outline),
                          ),
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
                    );
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
                  itemCount: _luaScripts.length,
                  itemBuilder: (context, index) {
                    final script = _luaScripts[index];
                    return ListTile(
                      leading: Icon(
                        script.isEnabled
                            ? Icons.description
                            : Icons.description_outlined,
                      ),
                      title: Text(script.name),
                      subtitle: Text(
                        '${script.scope.name} · order=${script.order}\n${script.content.split('\n').first}',
                      ),
                      isThreeLine: true,
                      trailing: Wrap(
                        spacing: 4,
                        children: [
                          IconButton(
                            onPressed: index > 0
                                ? () async {
                                    setState(() {
                                      final current = _luaScripts[index];
                                      _luaScripts[index] =
                                          _luaScripts[index - 1];
                                      _luaScripts[index - 1] = current;
                                      _reindexLuaOrder();
                                    });
                                    await _saveLua();
                                  }
                                : null,
                            icon: const Icon(Icons.arrow_upward),
                          ),
                          IconButton(
                            onPressed: index < _luaScripts.length - 1
                                ? () async {
                                    setState(() {
                                      final current = _luaScripts[index];
                                      _luaScripts[index] =
                                          _luaScripts[index + 1];
                                      _luaScripts[index + 1] = current;
                                      _reindexLuaOrder();
                                    });
                                    await _saveLua();
                                  }
                                : null,
                            icon: const Icon(Icons.arrow_downward),
                          ),
                          IconButton(
                            onPressed: () async {
                              final edited = await _showLuaEditor(
                                existing: script,
                              );
                              if (edited == null) return;
                              setState(() => _luaScripts[index] = edited);
                              await _saveLua();
                            },
                            icon: const Icon(Icons.edit),
                          ),
                          IconButton(
                            onPressed: () async {
                              setState(() => _luaScripts.removeAt(index));
                              _reindexLuaOrder();
                              await _saveLua();
                            },
                            icon: const Icon(Icons.delete_outline),
                          ),
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
                    );
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
                hintText: '@user 안녕 / @char <overlay><emotion name="happy"/></overlay> 반가워!',
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
        _appendTestLog('USER pipeline -> prompt 생성 완료 (${settings.llmDirectiveTarget.name})');
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
          ),
        );
      }
      output = await _regexService.applyAiOutput(
        output,
        characterId: characterId,
        sessionId: sessionId,
      );
    }

    final commandErrors = <String>[];
    if (settings.live2dLlmIntegrationEnabled &&
        settings.live2dDirectiveParsingEnabled) {
      if (settings.llmDirectiveTarget == LlmDirectiveTarget.live2d) {
        final result = await _live2dDirectiveService.processAssistantOutput(
          output,
          parsingEnabled: true,
          exposeRawDirectives: settings.live2dShowRawDirectivesInChat,
        );
        output = result.cleanedText;
        commandErrors.addAll(result.errors);
      } else {
        final result = await _imageDirectiveService.processAssistantOutput(output);
        output = result.cleanedText;
        commandErrors.addAll(result.errors);
      }
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

    _appendTestLog('CHAR pipeline 처리 완료 (${settings.llmDirectiveTarget.name})');
    if (commandErrors.isNotEmpty) {
      _appendTestLog('명령 오류: ${commandErrors.join(' | ')}');
    } else {
      _appendTestLog('명령 실행 로그: 오류 없음');
    }

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
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(const SnackBar(content: Text('Regex 규칙을 내보냈습니다.')));
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
                    await _regexService.saveRules(_regexRules);
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
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(const SnackBar(content: Text('Lua 스크립트를 내보냈습니다.')));
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
    final nameController = TextEditingController(text: existing?.name ?? '');
    final patternController = TextEditingController(
      text: existing?.pattern ?? '',
    );
    final replacementController = TextEditingController(
      text: existing?.replacement ?? '',
    );
    final characterController = TextEditingController(
      text: existing?.associatedCharacterId ?? '',
    );
    final sessionController = TextEditingController(
      text: existing?.associatedSessionId ?? '',
    );

    var type = existing?.type ?? RegexRuleType.aiOutput;
    var scope = existing?.scope ?? RegexRuleScope.global;
    var caseInsensitive = existing?.caseInsensitive ?? false;
    var multiLine = existing?.multiLine ?? false;
    var dotAll = existing?.dotAll ?? false;

    return showDialog<RegexRule>(
      context: context,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setLocal) {
            return AlertDialog(
              title: Text(existing == null ? 'Regex 규칙 추가' : 'Regex 규칙 편집'),
              content: SizedBox(
                width: 520,
                child: SingleChildScrollView(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      TextField(
                        controller: nameController,
                        decoration: const InputDecoration(labelText: '이름'),
                      ),
                      DropdownButtonFormField<RegexRuleType>(
                        initialValue: type,
                        decoration: const InputDecoration(labelText: '타입'),
                        items: RegexRuleType.values
                            .map(
                              (value) => DropdownMenuItem(
                                value: value,
                                child: Text(value.name),
                              ),
                            )
                            .toList(),
                        onChanged: (value) {
                          if (value != null) setLocal(() => type = value);
                        },
                      ),
                      DropdownButtonFormField<RegexRuleScope>(
                        initialValue: scope,
                        decoration: const InputDecoration(labelText: '스코프'),
                        items: RegexRuleScope.values
                            .map(
                              (value) => DropdownMenuItem(
                                value: value,
                                child: Text(value.name),
                              ),
                            )
                            .toList(),
                        onChanged: (value) {
                          if (value != null) setLocal(() => scope = value);
                        },
                      ),
                      TextField(
                        controller: patternController,
                        decoration: const InputDecoration(labelText: '패턴'),
                      ),
                      TextField(
                        controller: replacementController,
                        decoration: const InputDecoration(labelText: '치환 문자열'),
                      ),
                      if (scope == RegexRuleScope.perCharacter)
                        TextField(
                          controller: characterController,
                          decoration: const InputDecoration(
                            labelText: '캐릭터 ID',
                          ),
                        ),
                      if (scope == RegexRuleScope.perSession)
                        TextField(
                          controller: sessionController,
                          decoration: const InputDecoration(labelText: '세션 ID'),
                        ),
                      CheckboxListTile(
                        contentPadding: EdgeInsets.zero,
                        value: caseInsensitive,
                        onChanged: (value) {
                          setLocal(() => caseInsensitive = value ?? false);
                        },
                        title: const Text('CASE_INSENSITIVE'),
                      ),
                      CheckboxListTile(
                        contentPadding: EdgeInsets.zero,
                        value: multiLine,
                        onChanged: (value) {
                          setLocal(() => multiLine = value ?? false);
                        },
                        title: const Text('MULTILINE'),
                      ),
                      CheckboxListTile(
                        contentPadding: EdgeInsets.zero,
                        value: dotAll,
                        onChanged: (value) {
                          setLocal(() => dotAll = value ?? false);
                        },
                        title: const Text('DOT_ALL'),
                      ),
                    ],
                  ),
                ),
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(context),
                  child: const Text('취소'),
                ),
                ElevatedButton(
                  onPressed: () {
                    final name = nameController.text.trim();
                    final pattern = patternController.text;
                    final replacement = replacementController.text;
                    if (name.isEmpty || pattern.isEmpty) return;
                    Navigator.pop(
                      context,
                      RegexRule(
                        id: existing?.id,
                        name: name,
                        type: type,
                        pattern: pattern,
                        replacement: replacement,
                        caseInsensitive: caseInsensitive,
                        multiLine: multiLine,
                        dotAll: dotAll,
                        isEnabled: existing?.isEnabled ?? true,
                        priority: existing?.priority ?? _regexRules.length,
                        scope: scope,
                        associatedCharacterId:
                            characterController.text.trim().isEmpty
                            ? null
                            : characterController.text.trim(),
                        associatedSessionId:
                            sessionController.text.trim().isEmpty
                            ? null
                            : sessionController.text.trim(),
                      ),
                    );
                  },
                  child: const Text('저장'),
                ),
              ],
            );
          },
        );
      },
    );
  }

  Future<LuaScript?> _showLuaEditor({LuaScript? existing}) async {
    final nameController = TextEditingController(text: existing?.name ?? '');
    final contentController = TextEditingController(
      text: existing?.content ?? '',
    );
    final characterController = TextEditingController(
      text: existing?.characterId ?? '',
    );

    var scope = existing?.scope ?? LuaScriptScope.global;

    return showDialog<LuaScript>(
      context: context,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setLocal) {
            return AlertDialog(
              title: Text(existing == null ? 'Lua 스크립트 추가' : 'Lua 스크립트 편집'),
              content: SizedBox(
                width: 560,
                child: SingleChildScrollView(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      TextField(
                        controller: nameController,
                        decoration: const InputDecoration(labelText: '이름'),
                      ),
                      DropdownButtonFormField<LuaScriptScope>(
                        initialValue: scope,
                        decoration: const InputDecoration(labelText: '스코프'),
                        items: LuaScriptScope.values
                            .map(
                              (value) => DropdownMenuItem(
                                value: value,
                                child: Text(value.name),
                              ),
                            )
                            .toList(),
                        onChanged: (value) {
                          if (value != null) setLocal(() => scope = value);
                        },
                      ),
                      if (scope == LuaScriptScope.perCharacter)
                        TextField(
                          controller: characterController,
                          decoration: const InputDecoration(
                            labelText: '캐릭터 ID',
                          ),
                        ),
                      TextField(
                        controller: contentController,
                        minLines: 8,
                        maxLines: 20,
                        decoration: const InputDecoration(
                          labelText: '스크립트 내용',
                          border: OutlineInputBorder(),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(context),
                  child: const Text('취소'),
                ),
                ElevatedButton(
                  onPressed: () {
                    final name = nameController.text.trim();
                    final content = contentController.text;
                    if (name.isEmpty || content.trim().isEmpty) return;

                    Navigator.pop(
                      context,
                      LuaScript(
                        id: existing?.id,
                        name: name,
                        content: content,
                        isEnabled: existing?.isEnabled ?? true,
                        order: existing?.order ?? _luaScripts.length,
                        scope: scope,
                        characterId: characterController.text.trim().isEmpty
                            ? null
                            : characterController.text.trim(),
                      ),
                    );
                  },
                  child: const Text('저장'),
                ),
              ],
            );
          },
        );
      },
    );
  }
}
