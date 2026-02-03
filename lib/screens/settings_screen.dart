// ============================================================================
// 설정 화면 (Settings Screen)
// ============================================================================
// 이 파일은 앱의 설정 화면 UI를 담당합니다.
// API 키, 모델 선택, 생성 파라미터, 캐릭터 설정 등을 변경할 수 있습니다.
// ============================================================================

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../models/settings.dart';
import '../providers/settings_provider.dart';

/// 설정 화면 위젯
class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key});

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen>
    with SingleTickerProviderStateMixin {
  // 탭 컨트롤러 - API 설정 / 캐릭터 설정 / 파라미터 설정 탭
  late TabController _tabController;

  @override
  void initState() {
    super.initState();
    // 3개의 탭 생성
    _tabController = TabController(length: 3, vsync: this);
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('설정'),
        backgroundColor: Theme.of(context).colorScheme.inversePrimary,
        // 탭 바
        bottom: TabBar(
          controller: _tabController,
          tabs: const [
            Tab(icon: Icon(Icons.key), text: 'API'),
            Tab(icon: Icon(Icons.person), text: '캐릭터'),
            Tab(icon: Icon(Icons.tune), text: '파라미터'),
          ],
        ),
      ),
      body: TabBarView(
        controller: _tabController,
        children: const [
          // 각 탭의 내용
          _ApiSettingsTab(),
          _CharacterSettingsTab(),
          _ParameterSettingsTab(),
        ],
      ),
    );
  }
}

// ============================================================================
// API 설정 탭
// ============================================================================

class _ApiSettingsTab extends StatelessWidget {
  const _ApiSettingsTab();

  @override
  Widget build(BuildContext context) {
    // Provider에서 설정값 읽기
    final settingsProvider = context.watch<SettingsProvider>();
    final settings = settingsProvider.settings;

    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        // === API 제공자 선택 ===
        _SectionTitle(title: 'API 제공자'),
        const SizedBox(height: 8),
        _buildInfoText('사용할 AI API를 선택합니다.'),
        const SizedBox(height: 8),
        
        // API 제공자 드롭다운
        DropdownButtonFormField<ApiProvider>(
          value: settings.apiProvider,
          decoration: const InputDecoration(
            labelText: 'API 제공자',
            border: OutlineInputBorder(),
          ),
          items: const [
            DropdownMenuItem(
              value: ApiProvider.openai,
              child: Text('OpenAI (GPT)'),
            ),
            DropdownMenuItem(
              value: ApiProvider.anthropic,
              child: Text('Anthropic (Claude)'),
            ),
          ],
          onChanged: (value) {
            if (value != null) {
              settingsProvider.setApiProvider(value);
            }
          },
        ),

        const SizedBox(height: 24),

        // === OpenAI 설정 ===
        _SectionTitle(title: 'OpenAI 설정'),
        const SizedBox(height: 8),
        _buildInfoText('OpenAI API 키는 https://platform.openai.com에서 발급받을 수 있습니다.'),
        const SizedBox(height: 8),

        // OpenAI API 키 입력
        TextFormField(
          initialValue: settings.openaiApiKey,
          decoration: const InputDecoration(
            labelText: 'OpenAI API 키',
            hintText: 'sk-...',
            border: OutlineInputBorder(),
            prefixIcon: Icon(Icons.key),
          ),
          obscureText: true,  // 비밀번호처럼 숨김
          onChanged: settingsProvider.setOpenAIApiKey,
        ),

        const SizedBox(height: 16),

        // OpenAI 모델 선택
        DropdownButtonFormField<String>(
          value: settings.openaiModel,
          decoration: const InputDecoration(
            labelText: 'OpenAI 모델',
            border: OutlineInputBorder(),
          ),
          items: const [
            DropdownMenuItem(value: 'gpt-4o', child: Text('GPT-4o (최신, 고성능)')),
            DropdownMenuItem(value: 'gpt-4o-mini', child: Text('GPT-4o-mini (빠르고 저렴)')),
            DropdownMenuItem(value: 'gpt-4-turbo', child: Text('GPT-4 Turbo')),
            DropdownMenuItem(value: 'gpt-4', child: Text('GPT-4')),
            DropdownMenuItem(value: 'gpt-3.5-turbo', child: Text('GPT-3.5 Turbo (저렴)')),
          ],
          onChanged: (value) {
            if (value != null) {
              settingsProvider.setOpenAIModel(value);
            }
          },
        ),

        const SizedBox(height: 24),

        // === Anthropic 설정 ===
        _SectionTitle(title: 'Anthropic 설정'),
        const SizedBox(height: 8),
        _buildInfoText('Anthropic API 키는 https://console.anthropic.com에서 발급받을 수 있습니다.'),
        const SizedBox(height: 8),

        // Anthropic API 키 입력
        TextFormField(
          initialValue: settings.anthropicApiKey,
          decoration: const InputDecoration(
            labelText: 'Anthropic API 키',
            hintText: 'sk-ant-...',
            border: OutlineInputBorder(),
            prefixIcon: Icon(Icons.key),
          ),
          obscureText: true,
          onChanged: settingsProvider.setAnthropicApiKey,
        ),

        const SizedBox(height: 16),

        // Anthropic 모델 선택
        DropdownButtonFormField<String>(
          value: settings.anthropicModel,
          decoration: const InputDecoration(
            labelText: 'Anthropic 모델',
            border: OutlineInputBorder(),
          ),
          items: const [
            DropdownMenuItem(
              value: 'claude-3-5-sonnet-20241022',
              child: Text('Claude 3.5 Sonnet (추천)'),
            ),
            DropdownMenuItem(
              value: 'claude-3-opus-20240229',
              child: Text('Claude 3 Opus (최고 성능)'),
            ),
            DropdownMenuItem(
              value: 'claude-3-sonnet-20240229',
              child: Text('Claude 3 Sonnet'),
            ),
            DropdownMenuItem(
              value: 'claude-3-haiku-20240307',
              child: Text('Claude 3 Haiku (빠르고 저렴)'),
            ),
          ],
          onChanged: (value) {
            if (value != null) {
              settingsProvider.setAnthropicModel(value);
            }
          },
        ),

        const SizedBox(height: 24),

        // === 사용자 이름 설정 ===
        _SectionTitle(title: '사용자 설정'),
        const SizedBox(height: 8),
        _buildInfoText('AI가 당신을 부를 이름을 설정합니다.'),
        const SizedBox(height: 8),

        TextFormField(
          initialValue: settingsProvider.userName,
          decoration: const InputDecoration(
            labelText: '사용자 이름',
            hintText: '예: 마스터, 주인님...',
            border: OutlineInputBorder(),
            prefixIcon: Icon(Icons.person),
          ),
          onChanged: settingsProvider.updateUserName,
        ),
      ],
    );
  }

  Widget _buildInfoText(String text) {
    return Text(
      text,
      style: TextStyle(
        fontSize: 12,
        color: Colors.grey[600],
      ),
    );
  }
}

// ============================================================================
// 캐릭터 설정 탭
// ============================================================================

class _CharacterSettingsTab extends StatelessWidget {
  const _CharacterSettingsTab();

  @override
  Widget build(BuildContext context) {
    final settingsProvider = context.watch<SettingsProvider>();
    final character = settingsProvider.character;

    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        // === 캐릭터 기본 정보 ===
        _SectionTitle(title: '캐릭터 기본 정보'),
        const SizedBox(height: 8),

        // 캐릭터 이름
        TextFormField(
          initialValue: character.name,
          decoration: const InputDecoration(
            labelText: '캐릭터 이름',
            hintText: '예: 미카, 사쿠라...',
            border: OutlineInputBorder(),
          ),
          onChanged: settingsProvider.setCharacterName,
        ),

        const SizedBox(height: 16),

        // 캐릭터 설명
        TextFormField(
          initialValue: character.description,
          decoration: const InputDecoration(
            labelText: '캐릭터 설명',
            hintText: '캐릭터의 외모, 배경 등을 설명합니다...',
            border: OutlineInputBorder(),
            alignLabelWithHint: true,
          ),
          maxLines: 5,
          onChanged: settingsProvider.setCharacterDescription,
        ),

        const SizedBox(height: 16),

        // 캐릭터 성격
        TextFormField(
          initialValue: character.personality,
          decoration: const InputDecoration(
            labelText: '캐릭터 성격',
            hintText: '캐릭터의 성격 특성, 말투 등을 설명합니다...',
            border: OutlineInputBorder(),
            alignLabelWithHint: true,
          ),
          maxLines: 5,
          onChanged: settingsProvider.setCharacterPersonality,
        ),

        const SizedBox(height: 24),

        // === 시나리오 설정 ===
        _SectionTitle(title: '시나리오'),
        const SizedBox(height: 8),
        Text(
          '캐릭터와 사용자의 관계, 현재 상황 등을 설명합니다.',
          style: TextStyle(fontSize: 12, color: Colors.grey[600]),
        ),
        const SizedBox(height: 8),

        TextFormField(
          initialValue: character.scenario,
          decoration: const InputDecoration(
            labelText: '시나리오',
            hintText: '예: 당신은 미카의 주인이며...',
            border: OutlineInputBorder(),
            alignLabelWithHint: true,
          ),
          maxLines: 4,
          onChanged: settingsProvider.setCharacterScenario,
        ),

        const SizedBox(height: 24),

        // === 첫 인사말 ===
        _SectionTitle(title: '첫 인사말'),
        const SizedBox(height: 8),
        Text(
          '대화 시작 시 캐릭터가 먼저 하는 말입니다. {{user}}는 사용자 이름으로 대체됩니다.',
          style: TextStyle(fontSize: 12, color: Colors.grey[600]),
        ),
        const SizedBox(height: 8),

        TextFormField(
          initialValue: character.firstMessage,
          decoration: const InputDecoration(
            labelText: '첫 인사말',
            hintText: '안녕하세요, {{user}}님! 반가워요~',
            border: OutlineInputBorder(),
            alignLabelWithHint: true,
          ),
          maxLines: 4,
          onChanged: settingsProvider.setCharacterFirstMessage,
        ),

        const SizedBox(height: 24),

        // === 예시 대화 ===
        _SectionTitle(title: '예시 대화'),
        const SizedBox(height: 8),
        Text(
          '캐릭터의 말투와 반응 스타일을 보여주는 예시입니다.\n{{user}}: 사용자 대사\n{{char}}: 캐릭터 대사',
          style: TextStyle(fontSize: 12, color: Colors.grey[600]),
        ),
        const SizedBox(height: 8),

        TextFormField(
          initialValue: character.exampleDialogue,
          decoration: const InputDecoration(
            labelText: '예시 대화',
            hintText: '{{user}}: 안녕\n{{char}}: 안녕하세요~! 반가워요! 💕',
            border: OutlineInputBorder(),
            alignLabelWithHint: true,
          ),
          maxLines: 6,
          onChanged: settingsProvider.setCharacterExampleDialogue,
        ),

        const SizedBox(height: 24),

        // 캐릭터 초기화 버튼
        OutlinedButton.icon(
          onPressed: () {
            showDialog(
              context: context,
              builder: (context) => AlertDialog(
                title: const Text('캐릭터 초기화'),
                content: const Text('캐릭터 설정을 기본값으로 되돌립니다. 계속하시겠습니까?'),
                actions: [
                  TextButton(
                    onPressed: () => Navigator.pop(context),
                    child: const Text('취소'),
                  ),
                  TextButton(
                    onPressed: () {
                      Navigator.pop(context);
                      settingsProvider.resetCharacter();
                    },
                    child: const Text('확인'),
                  ),
                ],
              ),
            );
          },
          icon: const Icon(Icons.restart_alt),
          label: const Text('기본 캐릭터로 초기화'),
        ),
      ],
    );
  }
}

// ============================================================================
// 파라미터 설정 탭
// ============================================================================

class _ParameterSettingsTab extends StatelessWidget {
  const _ParameterSettingsTab();

  @override
  Widget build(BuildContext context) {
    final settingsProvider = context.watch<SettingsProvider>();
    final settings = settingsProvider.settings;

    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        // === 생성 파라미터 ===
        _SectionTitle(title: '생성 파라미터'),
        const SizedBox(height: 8),
        Text(
          'AI가 텍스트를 생성할 때 사용하는 설정입니다.',
          style: TextStyle(fontSize: 12, color: Colors.grey[600]),
        ),

        const SizedBox(height: 16),

        // Temperature 슬라이더
        _ParameterSlider(
          label: 'Temperature (온도)',
          value: settings.temperature,
          min: 0.0,
          max: 2.0,
          divisions: 20,
          description: '높을수록 창의적이고 다양한 응답, 낮을수록 일관적인 응답',
          onChanged: settingsProvider.setTemperature,
        ),

        const SizedBox(height: 16),

        // Top-P 슬라이더
        _ParameterSlider(
          label: 'Top-P',
          value: settings.topP,
          min: 0.0,
          max: 1.0,
          divisions: 20,
          description: '단어 선택의 다양성을 조절합니다 (보통 1.0 권장)',
          onChanged: settingsProvider.setTopP,
        ),

        const SizedBox(height: 16),

        // Max Tokens 입력
        TextFormField(
          initialValue: settings.maxTokens.toString(),
          decoration: const InputDecoration(
            labelText: 'Max Tokens (최대 토큰)',
            hintText: '1024',
            border: OutlineInputBorder(),
            helperText: 'AI 응답의 최대 길이 (1000 토큰 ≈ 한글 500자)',
          ),
          keyboardType: TextInputType.number,
          onChanged: (value) {
            final int? tokens = int.tryParse(value);
            if (tokens != null && tokens > 0) {
              settingsProvider.setMaxTokens(tokens);
            }
          },
        ),

        const SizedBox(height: 16),

        // Frequency Penalty 슬라이더
        _ParameterSlider(
          label: 'Frequency Penalty (빈도 패널티)',
          value: settings.frequencyPenalty,
          min: -2.0,
          max: 2.0,
          divisions: 40,
          description: '같은 단어의 반복을 억제합니다',
          onChanged: settingsProvider.setFrequencyPenalty,
        ),

        const SizedBox(height: 16),

        // Presence Penalty 슬라이더
        _ParameterSlider(
          label: 'Presence Penalty (존재 패널티)',
          value: settings.presencePenalty,
          min: -2.0,
          max: 2.0,
          divisions: 40,
          description: '새로운 주제로 대화를 유도합니다',
          onChanged: settingsProvider.setPresencePenalty,
        ),

        const SizedBox(height: 24),

        // === 프롬프트 설정 ===
        _SectionTitle(title: '추가 프롬프트'),
        const SizedBox(height: 8),

        // 시스템 프롬프트
        TextFormField(
          initialValue: settings.systemPrompt,
          decoration: const InputDecoration(
            labelText: '추가 시스템 프롬프트',
            hintText: 'AI에게 추가로 전달할 지시사항...',
            border: OutlineInputBorder(),
            alignLabelWithHint: true,
            helperText: '캐릭터 설정 외에 추가로 전달할 지시사항',
          ),
          maxLines: 4,
          onChanged: settingsProvider.setSystemPrompt,
        ),

        const SizedBox(height: 16),

        // 탈옥 프롬프트 사용 여부
        SwitchListTile(
          title: const Text('탈옥 프롬프트 사용'),
          subtitle: Text(
            '주의: 이 기능은 AI의 안전 제한을 우회하려는 시도입니다',
            style: TextStyle(fontSize: 12, color: Colors.grey[600]),
          ),
          value: settings.useJailbreak,
          onChanged: settingsProvider.setUseJailbreak,
        ),

        // 탈옥 프롬프트 입력
        if (settings.useJailbreak) ...[
          const SizedBox(height: 8),
          TextFormField(
            initialValue: settings.jailbreakPrompt,
            decoration: const InputDecoration(
              labelText: '탈옥 프롬프트',
              hintText: '특별 지시사항...',
              border: OutlineInputBorder(),
              alignLabelWithHint: true,
            ),
            maxLines: 4,
            onChanged: settingsProvider.setJailbreakPrompt,
          ),
        ],
      ],
    );
  }
}

// ============================================================================
// 공통 위젯
// ============================================================================

/// 섹션 제목 위젯
class _SectionTitle extends StatelessWidget {
  final String title;

  const _SectionTitle({required this.title});

  @override
  Widget build(BuildContext context) {
    return Text(
      title,
      style: const TextStyle(
        fontSize: 18,
        fontWeight: FontWeight.bold,
      ),
    );
  }
}

/// 파라미터 슬라이더 위젯
class _ParameterSlider extends StatelessWidget {
  final String label;
  final double value;
  final double min;
  final double max;
  final int divisions;
  final String description;
  final ValueChanged<double> onChanged;

  const _ParameterSlider({
    required this.label,
    required this.value,
    required this.min,
    required this.max,
    required this.divisions,
    required this.description,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // 라벨과 현재 값
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(label, style: const TextStyle(fontWeight: FontWeight.w500)),
            Text(
              value.toStringAsFixed(2),
              style: TextStyle(
                color: Theme.of(context).colorScheme.primary,
                fontWeight: FontWeight.bold,
              ),
            ),
          ],
        ),
        // 슬라이더
        Slider(
          value: value,
          min: min,
          max: max,
          divisions: divisions,
          onChanged: onChanged,
        ),
        // 설명
        Text(
          description,
          style: TextStyle(fontSize: 12, color: Colors.grey[600]),
        ),
      ],
    );
  }
}
