import 'package:flutter/material.dart';

class Live2DPipelinePrototypeScreen extends StatefulWidget {
  const Live2DPipelinePrototypeScreen({super.key});

  @override
  State<Live2DPipelinePrototypeScreen> createState() =>
      _Live2DPipelinePrototypeScreenState();
}

class _Live2DPipelinePrototypeScreenState
    extends State<Live2DPipelinePrototypeScreen> {
  bool _globalScriptEnabled = true;
  bool _runRegexBeforeLua = true;
  bool _directiveParsingEnabled = true;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return DefaultTabController(
      length: 3,
      child: Scaffold(
        appBar: AppBar(
          title: const Text('Lua/Regex 파이프라인 시안'),
          bottom: const TabBar(
            tabs: [
              Tab(text: 'Lua 스크립트'),
              Tab(text: 'Regex 규칙'),
              Tab(text: 'Live2D 지시어'),
            ],
          ),
        ),
        body: TabBarView(
          children: [
            _buildLuaTab(theme),
            _buildRegexTab(theme),
            _buildDirectiveTab(theme),
          ],
        ),
      ),
    );
  }

  Widget _buildLuaTab(ThemeData theme) {
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        SwitchListTile(
          value: _globalScriptEnabled,
          onChanged: (value) {
            setState(() => _globalScriptEnabled = value);
          },
          title: const Text('스크립트 엔진 활성화'),
          subtitle: const Text('캐릭터별/글로벌 스크립트 실행을 제어합니다'),
        ),
        Card(
          child: Column(
            children: const [
              ListTile(
                leading: Icon(Icons.description),
                title: Text('emotion_router.lua'),
                subtitle: Text('onAssistantMessage → 감정 프리셋 매핑'),
                trailing: Icon(Icons.drag_indicator),
              ),
              Divider(height: 1),
              ListTile(
                leading: Icon(Icons.description),
                title: Text('prompt_guard.lua'),
                subtitle: Text('onPromptBuild → 안전 규칙 보강'),
                trailing: Icon(Icons.drag_indicator),
              ),
            ],
          ),
        ),
        const SizedBox(height: 12),
        Card(
          child: Padding(
            padding: const EdgeInsets.all(12),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('실행 순서', style: theme.textTheme.titleSmall),
                const SizedBox(height: 8),
                SwitchListTile(
                  contentPadding: EdgeInsets.zero,
                  value: _runRegexBeforeLua,
                  onChanged: (value) {
                    setState(() => _runRegexBeforeLua = value);
                  },
                  title: const Text('Regex 먼저 실행'),
                  subtitle: Text(
                    _runRegexBeforeLua
                        ? 'regex -> lua hook 순서'
                        : 'lua hook -> regex 순서',
                  ),
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 12),
        OutlinedButton.icon(
          onPressed: () {},
          icon: const Icon(Icons.upload_file),
          label: const Text('스크립트 가져오기 (시안)'),
        ),
      ],
    );
  }

  Widget _buildRegexTab(ThemeData theme) {
    final chips = <String>[
      'USER_INPUT',
      'AI_OUTPUT',
      'PROMPT_INJECTION',
      'DISPLAY_ONLY',
    ];

    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        Text('규칙 유형', style: theme.textTheme.titleSmall),
        const SizedBox(height: 8),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: chips.map((type) => Chip(label: Text(type))).toList(),
        ),
        const SizedBox(height: 12),
        Card(
          child: Column(
            children: const [
              ListTile(
                leading: Icon(Icons.rule),
                title: Text('Strip Live2D Tags'),
                subtitle: Text(
                  'Type: AI_OUTPUT · pattern: <live2d>[\\s\\S]*?</live2d>',
                ),
                trailing: Text('P1'),
              ),
              Divider(height: 1),
              ListTile(
                leading: Icon(Icons.rule),
                title: Text('Prompt Context Booster'),
                subtitle: Text('Type: PROMPT_INJECTION · pattern: \\bhello\\b'),
                trailing: Text('P2'),
              ),
            ],
          ),
        ),
        const SizedBox(height: 12),
        Card(
          child: Padding(
            padding: const EdgeInsets.all(12),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('룰 테스트', style: theme.textTheme.titleSmall),
                const SizedBox(height: 8),
                TextField(
                  maxLines: 3,
                  decoration: InputDecoration(
                    hintText: '샘플 텍스트 입력',
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(8),
                    ),
                  ),
                ),
                const SizedBox(height: 8),
                TextField(
                  readOnly: true,
                  maxLines: 3,
                  decoration: InputDecoration(
                    hintText: '변환 결과 미리보기',
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(8),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 12),
        OutlinedButton.icon(
          onPressed: () {},
          icon: const Icon(Icons.ios_share),
          label: const Text('JSON 내보내기/가져오기 (시안)'),
        ),
      ],
    );
  }

  Widget _buildDirectiveTab(ThemeData theme) {
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        SwitchListTile(
          value: _directiveParsingEnabled,
          onChanged: (value) {
            setState(() => _directiveParsingEnabled = value);
          },
          title: const Text('Live2D 지시어 파싱 활성화'),
          subtitle: const Text('<live2d> 블록 파싱/실행 토글'),
        ),
        Card(
          child: Padding(
            padding: const EdgeInsets.all(12),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('시스템 프롬프트 템플릿', style: theme.textTheme.titleSmall),
                const SizedBox(height: 8),
                TextField(
                  maxLines: 7,
                  decoration: InputDecoration(
                    hintText: '사용 가능한 파라미터/모션/표정 정보를 포함한 템플릿',
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(8),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 12),
        Card(
          child: Padding(
            padding: const EdgeInsets.all(12),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('지시어 미리보기', style: theme.textTheme.titleSmall),
                const SizedBox(height: 8),
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: theme.colorScheme.surfaceContainerHighest,
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: const Text(
                    '<live2d>\n'
                    '  <emotion name="happy"/>\n'
                    '  <motion group="Greeting" index="0" delay="150"/>\n'
                    '</live2d>',
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  '표시 텍스트에는 지시어 블록을 숨기고, 유효 명령만 순차 실행하는 UX를 가정합니다.',
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: theme.colorScheme.onSurfaceVariant,
                  ),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }
}
