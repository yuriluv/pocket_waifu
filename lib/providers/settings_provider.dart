// ============================================================================
// 설정 Provider (Settings Provider)
// ============================================================================
// 이 파일은 앱의 설정값을 관리하는 Provider입니다.
// Provider는 Flutter에서 상태(데이터)를 관리하고 UI에 전달하는 패턴입니다.
// 설정값이 변경되면 자동으로 UI가 업데이트됩니다.
// ============================================================================

import 'dart:convert';  // JSON 변환용
import 'package:flutter/foundation.dart';  // ChangeNotifier용
import 'package:shared_preferences/shared_preferences.dart';  // 로컬 저장소

import '../models/character.dart';
import '../models/settings.dart';

/// 설정 상태를 관리하는 Provider 클래스
/// ChangeNotifier를 상속받아 데이터 변경 시 리스너(UI)에게 알립니다
class SettingsProvider extends ChangeNotifier {
  // === 저장 키 상수 ===
  static const String _settingsKey = 'app_settings';
  static const String _characterKey = 'character';

  // === 상태 변수 ===
  AppSettings _settings = AppSettings();  // 앱 설정
  Character _character = Character.defaultCharacter();  // 현재 캐릭터
  bool _isLoading = false;  // 로딩 상태
  String _userName = 'User';  // 사용자 이름

  // === Getter (읽기 전용 속성) ===
  // 외부에서 상태를 읽을 수 있지만 직접 수정은 불가능합니다
  AppSettings get settings => _settings;
  Character get character => _character;
  bool get isLoading => _isLoading;
  String get userName => _userName;

  /// 생성자 - Provider가 생성될 때 저장된 설정을 불러옵니다
  SettingsProvider() {
    loadSettings();
  }

  /// 저장된 설정을 불러옵니다
  Future<void> loadSettings() async {
    _isLoading = true;
    notifyListeners();  // UI에 로딩 시작을 알림

    try {
      // SharedPreferences 인스턴스 가져오기
      final prefs = await SharedPreferences.getInstance();

      // 설정 불러오기
      final String? settingsJson = prefs.getString(_settingsKey);
      if (settingsJson != null) {
        final Map<String, dynamic> settingsMap = jsonDecode(settingsJson);
        _settings = AppSettings.fromMap(settingsMap);
      }

      // 캐릭터 불러오기
      final String? characterJson = prefs.getString(_characterKey);
      if (characterJson != null) {
        final Map<String, dynamic> characterMap = jsonDecode(characterJson);
        _character = Character.fromMap(characterMap);
      }

      // 사용자 이름 불러오기
      _userName = prefs.getString('user_name') ?? 'User';
    } catch (e) {
      // 에러 발생 시 기본값 사용
      debugPrint('설정 불러오기 실패: $e');
    }

    _isLoading = false;
    notifyListeners();  // UI에 로딩 완료를 알림
  }

  /// 설정을 저장합니다
  Future<void> saveSettings() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      
      // 설정 저장
      final String settingsJson = jsonEncode(_settings.toMap());
      await prefs.setString(_settingsKey, settingsJson);

      // 캐릭터 저장
      final String characterJson = jsonEncode(_character.toMap());
      await prefs.setString(_characterKey, characterJson);

      // 사용자 이름 저장
      await prefs.setString('user_name', _userName);
    } catch (e) {
      debugPrint('설정 저장 실패: $e');
    }
  }

  /// 앱 설정을 업데이트합니다
  void updateSettings(AppSettings newSettings) {
    _settings = newSettings;
    notifyListeners();  // UI 업데이트
    saveSettings();     // 저장
  }

  /// 캐릭터를 업데이트합니다
  void updateCharacter(Character newCharacter) {
    _character = newCharacter;
    notifyListeners();
    saveSettings();
  }

  /// 사용자 이름을 업데이트합니다
  void updateUserName(String name) {
    _userName = name;
    notifyListeners();
    saveSettings();
  }

  // === 개별 설정 업데이트 메서드들 ===
  // copyWith를 사용해 일부 속성만 변경합니다

  /// API 제공자 변경
  void setApiProvider(ApiProvider provider) {
    updateSettings(_settings.copyWith(apiProvider: provider));
  }

  /// OpenAI API 키 변경
  void setOpenAIApiKey(String key) {
    updateSettings(_settings.copyWith(openaiApiKey: key));
  }

  /// Anthropic API 키 변경
  void setAnthropicApiKey(String key) {
    updateSettings(_settings.copyWith(anthropicApiKey: key));
  }

  /// OpenAI 모델 변경
  void setOpenAIModel(String model) {
    updateSettings(_settings.copyWith(openaiModel: model));
  }

  /// Anthropic 모델 변경
  void setAnthropicModel(String model) {
    updateSettings(_settings.copyWith(anthropicModel: model));
  }

  /// 온도 변경
  void setTemperature(double value) {
    updateSettings(_settings.copyWith(temperature: value));
  }

  /// Top-P 변경
  void setTopP(double value) {
    updateSettings(_settings.copyWith(topP: value));
  }

  /// 최대 토큰 변경
  void setMaxTokens(int value) {
    updateSettings(_settings.copyWith(maxTokens: value));
  }

  /// 빈도 패널티 변경
  void setFrequencyPenalty(double value) {
    updateSettings(_settings.copyWith(frequencyPenalty: value));
  }

  /// 존재 패널티 변경
  void setPresencePenalty(double value) {
    updateSettings(_settings.copyWith(presencePenalty: value));
  }

  /// 시스템 프롬프트 변경
  void setSystemPrompt(String prompt) {
    updateSettings(_settings.copyWith(systemPrompt: prompt));
  }

  /// 탈옥 프롬프트 변경
  void setJailbreakPrompt(String prompt) {
    updateSettings(_settings.copyWith(jailbreakPrompt: prompt));
  }

  /// 탈옥 프롬프트 사용 여부 변경
  void setUseJailbreak(bool value) {
    updateSettings(_settings.copyWith(useJailbreak: value));
  }

  // === 캐릭터 개별 속성 업데이트 ===

  /// 캐릭터 이름 변경
  void setCharacterName(String name) {
    updateCharacter(_character.copyWith(name: name));
  }

  /// 캐릭터 설명 변경
  void setCharacterDescription(String description) {
    updateCharacter(_character.copyWith(description: description));
  }

  /// 캐릭터 성격 변경
  void setCharacterPersonality(String personality) {
    updateCharacter(_character.copyWith(personality: personality));
  }

  /// 캐릭터 시나리오 변경
  void setCharacterScenario(String scenario) {
    updateCharacter(_character.copyWith(scenario: scenario));
  }

  /// 캐릭터 첫 인사말 변경
  void setCharacterFirstMessage(String firstMessage) {
    updateCharacter(_character.copyWith(firstMessage: firstMessage));
  }

  /// 캐릭터 예시 대화 변경
  void setCharacterExampleDialogue(String exampleDialogue) {
    updateCharacter(_character.copyWith(exampleDialogue: exampleDialogue));
  }

  /// 캐릭터를 기본값으로 리셋
  void resetCharacter() {
    updateCharacter(Character.defaultCharacter());
  }
}
