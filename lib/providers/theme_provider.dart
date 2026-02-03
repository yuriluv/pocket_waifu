// ============================================================================
// 테마 Provider (Theme Provider)
// ============================================================================
// 앱의 테마 프리셋을 관리하는 Provider입니다.
// 테마 저장/불러오기/전환 기능을 제공합니다.
// CSS/HTML 커스텀 적용 로직은 추후 구현 예정입니다.
// ============================================================================

import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../models/theme_preset.dart';

/// 테마 상태를 관리하는 Provider
class ThemeProvider extends ChangeNotifier {
  // === 저장 키 상수 ===
  static const String _presetsKey = 'theme_presets';
  static const String _activePresetIdKey = 'active_theme_preset_id';
  static const String _themeModeKey = 'theme_mode';

  // === 상태 변수 ===
  List<ThemePreset> _presets = [];       // 테마 프리셋 목록
  ThemePreset? _activePreset;            // 현재 활성 프리셋
  ThemeMode _themeMode = ThemeMode.system;  // 시스템/라이트/다크 모드
  bool _isLoading = false;               // 로딩 상태

  // === Getter ===
  List<ThemePreset> get presets => List.unmodifiable(_presets);
  ThemePreset? get activePreset => _activePreset;
  ThemeMode get themeMode => _themeMode;
  bool get isLoading => _isLoading;

  /// 현재 테마가 다크 모드인지 확인
  bool get isDarkMode {
    if (_activePreset != null) {
      return _activePreset!.isDarkMode;
    }
    return _themeMode == ThemeMode.dark;
  }

  /// 생성자 - 저장된 테마를 불러옵니다
  ThemeProvider() {
    loadPresets();
  }

  /// 저장된 테마 프리셋을 불러옵니다
  Future<void> loadPresets() async {
    _isLoading = true;
    notifyListeners();

    try {
      final prefs = await SharedPreferences.getInstance();

      // 프리셋 목록 불러오기
      final String? presetsJson = prefs.getString(_presetsKey);
      if (presetsJson != null) {
        final List<dynamic> presetsList = jsonDecode(presetsJson);
        _presets = presetsList
            .map((json) => ThemePreset.fromMap(json))
            .toList();
      } else {
        // 기본 프리셋 생성
        _initializeDefaultPresets();
      }

      // 활성 프리셋 불러오기
      final String? activePresetId = prefs.getString(_activePresetIdKey);
      if (activePresetId != null) {
        try {
          _activePreset = _presets.firstWhere((p) => p.id == activePresetId);
        } catch (e) {
          _activePreset = null;
        }
      }

      // 테마 모드 불러오기
      final int? themeModeIndex = prefs.getInt(_themeModeKey);
      if (themeModeIndex != null && themeModeIndex < ThemeMode.values.length) {
        _themeMode = ThemeMode.values[themeModeIndex];
      }
    } catch (e) {
      debugPrint('테마 불러오기 실패: $e');
      _initializeDefaultPresets();
    }

    _isLoading = false;
    notifyListeners();
  }

  /// 기본 프리셋을 초기화합니다
  void _initializeDefaultPresets() {
    _presets = [
      ThemePreset.defaultLight(),
      ThemePreset.defaultDark(),
      ThemePreset.pink(),
    ];
  }

  /// 테마 설정을 저장합니다
  Future<void> savePresets() async {
    try {
      final prefs = await SharedPreferences.getInstance();

      // 프리셋 목록 저장
      final String presetsJson = jsonEncode(
        _presets.map((preset) => preset.toMap()).toList(),
      );
      await prefs.setString(_presetsKey, presetsJson);

      // 활성 프리셋 ID 저장
      if (_activePreset != null) {
        await prefs.setString(_activePresetIdKey, _activePreset!.id);
      } else {
        await prefs.remove(_activePresetIdKey);
      }

      // 테마 모드 저장
      await prefs.setInt(_themeModeKey, _themeMode.index);
    } catch (e) {
      debugPrint('테마 저장 실패: $e');
    }
  }

  /// 새 프리셋을 저장합니다
  void savePreset(ThemePreset preset) {
    final index = _presets.indexWhere((p) => p.id == preset.id);
    if (index != -1) {
      // 기존 프리셋 업데이트
      _presets[index] = preset;
    } else {
      // 새 프리셋 추가
      _presets.add(preset);
    }
    notifyListeners();
    savePresets();
  }

  /// 프리셋을 불러와 활성화합니다
  void loadPreset(String id) {
    try {
      _activePreset = _presets.firstWhere((p) => p.id == id);
      notifyListeners();
      savePresets();
    } catch (e) {
      debugPrint('프리셋을 찾을 수 없습니다: $id');
    }
  }

  /// 프리셋을 삭제합니다
  bool deletePreset(String id) {
    // 기본 프리셋은 삭제 불가
    if (id.startsWith('default_') || id == 'pink_theme') {
      debugPrint('기본 프리셋은 삭제할 수 없습니다.');
      return false;
    }

    final index = _presets.indexWhere((p) => p.id == id);
    if (index != -1) {
      _presets.removeAt(index);

      // 삭제된 프리셋이 활성 프리셋이었다면 해제
      if (_activePreset?.id == id) {
        _activePreset = null;
      }

      notifyListeners();
      savePresets();
      return true;
    }
    return false;
  }

  /// 테마 모드 변경 (시스템/라이트/다크)
  void setThemeMode(ThemeMode mode) {
    _themeMode = mode;
    notifyListeners();
    savePresets();
  }

  /// 활성 프리셋 해제 (시스템 기본 테마 사용)
  void clearActivePreset() {
    _activePreset = null;
    notifyListeners();
    savePresets();
  }

  /// 현재 테마의 ColorScheme 생성
  /// TODO: 추후 CSS/HTML 커스텀 적용 로직 구현
  ColorScheme getColorScheme(Brightness brightness) {
    if (_activePreset != null) {
      final preset = _activePreset!;
      final primary = preset.getColor(ThemePreset.COLOR_PRIMARY);
      
      if (primary != null) {
        return ColorScheme.fromSeed(
          seedColor: primary,
          brightness: preset.isDarkMode ? Brightness.dark : Brightness.light,
        );
      }
    }

    // 기본 ColorScheme
    return ColorScheme.fromSeed(
      seedColor: Colors.purple,
      brightness: brightness,
    );
  }

  /// 현재 테마의 ThemeData 생성
  /// 
  /// [isDark]: 다크 모드 여부
  ThemeData getThemeData({required bool isDark}) {
    final brightness = isDark ? Brightness.dark : Brightness.light;
    final colorScheme = getColorScheme(brightness);

    return ThemeData(
      useMaterial3: true,
      colorScheme: colorScheme,
      appBarTheme: const AppBarTheme(
        centerTitle: true,
        elevation: 0,
      ),
      inputDecorationTheme: InputDecorationTheme(
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
        ),
        contentPadding: const EdgeInsets.symmetric(
          horizontal: 16,
          vertical: 12,
        ),
      ),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          padding: const EdgeInsets.symmetric(
            horizontal: 24,
            vertical: 12,
          ),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
        ),
      ),
    );
  }

  /// 모든 프리셋을 기본값으로 리셋
  void resetToDefaults() {
    _initializeDefaultPresets();
    _activePreset = null;
    _themeMode = ThemeMode.system;
    notifyListeners();
    savePresets();
  }
}
