// ============================================================================
// ============================================================================
// ============================================================================

import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../models/theme_preset.dart';

class ThemeProvider extends ChangeNotifier {
  static const String _presetsKey = 'theme_presets';
  static const String _activePresetIdKey = 'active_theme_preset_id';
  static const String _themeModeKey = 'theme_mode';

  List<ThemePreset> _presets = [];
  ThemePreset? _activePreset;
  ThemeMode _themeMode = ThemeMode.system;
  bool _isLoading = false;

  // === Getter ===
  List<ThemePreset> get presets => List.unmodifiable(_presets);
  ThemePreset? get activePreset => _activePreset;
  ThemeMode get themeMode => _themeMode;
  bool get isLoading => _isLoading;

  bool get isDarkMode {
    if (_activePreset != null) {
      return _activePreset!.isDarkMode;
    }
    return _themeMode == ThemeMode.dark;
  }

  ThemeProvider() {
    loadPresets();
  }

  Future<void> loadPresets() async {
    _isLoading = true;
    notifyListeners();

    try {
      final prefs = await SharedPreferences.getInstance();

      final String? presetsJson = prefs.getString(_presetsKey);
      if (presetsJson != null) {
        final List<dynamic> presetsList = jsonDecode(presetsJson);
        _presets = presetsList
            .map((json) => ThemePreset.fromMap(json))
            .toList();
      } else {
        _initializeDefaultPresets();
      }

      final String? activePresetId = prefs.getString(_activePresetIdKey);
      if (activePresetId != null) {
        try {
          _activePreset = _presets.firstWhere((p) => p.id == activePresetId);
        } catch (e) {
          _activePreset = null;
        }
      }

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

  void _initializeDefaultPresets() {
    _presets = [
      ThemePreset.defaultLight(),
      ThemePreset.defaultDark(),
      ThemePreset.pink(),
    ];
  }

  Future<void> savePresets() async {
    try {
      final prefs = await SharedPreferences.getInstance();

      final String presetsJson = jsonEncode(
        _presets.map((preset) => preset.toMap()).toList(),
      );
      await prefs.setString(_presetsKey, presetsJson);

      if (_activePreset != null) {
        await prefs.setString(_activePresetIdKey, _activePreset!.id);
      } else {
        await prefs.remove(_activePresetIdKey);
      }

      await prefs.setInt(_themeModeKey, _themeMode.index);
    } catch (e) {
      debugPrint('테마 저장 실패: $e');
    }
  }

  void savePreset(ThemePreset preset) {
    final index = _presets.indexWhere((p) => p.id == preset.id);
    if (index != -1) {
      _presets[index] = preset;
    } else {
      _presets.add(preset);
    }
    notifyListeners();
    savePresets();
  }

  void loadPreset(String id) {
    try {
      _activePreset = _presets.firstWhere((p) => p.id == id);
      notifyListeners();
      savePresets();
    } catch (e) {
      debugPrint('프리셋을 찾을 수 없습니다: $id');
    }
  }

  bool deletePreset(String id) {
    if (id.startsWith('default_') || id == 'pink_theme') {
      debugPrint('기본 프리셋은 삭제할 수 없습니다.');
      return false;
    }

    final index = _presets.indexWhere((p) => p.id == id);
    if (index != -1) {
      _presets.removeAt(index);

      if (_activePreset?.id == id) {
        _activePreset = null;
      }

      notifyListeners();
      savePresets();
      return true;
    }
    return false;
  }

  void setThemeMode(ThemeMode mode) {
    _themeMode = mode;
    notifyListeners();
    savePresets();
  }

  void clearActivePreset() {
    _activePreset = null;
    notifyListeners();
    savePresets();
  }

  /// Build a color scheme honoring preset overrides when available.
  ColorScheme getColorScheme(Brightness brightness) {
    final preset = _activePreset;
    final seedColor =
        preset?.getColor(ThemePreset.COLOR_PRIMARY) ?? Colors.purple;
    final schemeBrightness =
        preset?.isDarkMode == true ? Brightness.dark : brightness;

    var scheme = ColorScheme.fromSeed(
      seedColor: seedColor,
      brightness: schemeBrightness,
    );

    if (preset == null) {
      return scheme;
    }

    final secondary = preset.getColor(ThemePreset.COLOR_SECONDARY);
    final background = preset.getColor(ThemePreset.COLOR_BACKGROUND);
    final surface = preset.getColor(ThemePreset.COLOR_SURFACE);

    return scheme.copyWith(
      secondary: secondary ?? scheme.secondary,
      background: background ?? scheme.background,
      surface: surface ?? scheme.surface,
    );
  }

  /// Build theme data based on active presets and brightness.
  ThemeData getThemeData({required bool isDark}) {
    final brightness = isDark ? Brightness.dark : Brightness.light;
    final colorScheme = getColorScheme(brightness);

    return ThemeData(
      useMaterial3: true,
      colorScheme: colorScheme,
      scaffoldBackgroundColor: colorScheme.background,
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

  void resetToDefaults() {
    _initializeDefaultPresets();
    _activePreset = null;
    _themeMode = ThemeMode.system;
    notifyListeners();
    savePresets();
  }
}
