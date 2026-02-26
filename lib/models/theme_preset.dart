// ============================================================================
// ============================================================================
// ============================================================================

import 'package:flutter/material.dart';
import 'package:uuid/uuid.dart';

class ThemePreset {
  final String id;
  String name;
  String? description;
  String customCss;
  String customHtml;
  Map<String, int> colorOverrides;
  bool isDarkMode;
  bool isBuiltIn;
  DateTime createdAt;

  ThemePreset({
    String? id,
    required this.name,
    this.description,
    this.customCss = '',
    this.customHtml = '',
    Map<String, int>? colorOverrides,
    this.isDarkMode = false,
    this.isBuiltIn = false,
    DateTime? createdAt,
  })  : id = id ?? const Uuid().v4(),
        colorOverrides = colorOverrides ?? {},
        createdAt = createdAt ?? DateTime.now();

  static const String COLOR_PRIMARY = 'primary';
  static const String COLOR_SECONDARY = 'secondary';
  static const String COLOR_BACKGROUND = 'background';
  static const String COLOR_SURFACE = 'surface';
  static const String COLOR_USER_BUBBLE = 'userBubble';
  static const String COLOR_AI_BUBBLE = 'aiBubble';
  static const String COLOR_TEXT = 'text';

  Color? getColor(String key) {
    final value = colorOverrides[key];
    return value != null ? Color(value) : null;
  }

  void setColor(String key, Color color) {
    colorOverrides[key] = color.value;
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'name': name,
      'description': description,
      'customCss': customCss,
      'customHtml': customHtml,
      'colorOverrides': colorOverrides,
      'isDarkMode': isDarkMode,
      'isBuiltIn': isBuiltIn,
      'createdAt': createdAt.toIso8601String(),
    };
  }

  factory ThemePreset.fromMap(Map<String, dynamic> map) {
    return ThemePreset(
      id: map['id'],
      name: map['name'] ?? '새 테마',
      description: map['description'],
      customCss: map['customCss'] ?? '',
      customHtml: map['customHtml'] ?? '',
      colorOverrides: Map<String, int>.from(map['colorOverrides'] ?? {}),
      isDarkMode: map['isDarkMode'] ?? false,
      isBuiltIn: map['isBuiltIn'] ?? false,
      createdAt: map['createdAt'] != null 
          ? DateTime.parse(map['createdAt']) 
          : DateTime.now(),
    );
  }

  ThemePreset copyWith({
    String? id,
    String? name,
    String? description,
    String? customCss,
    String? customHtml,
    Map<String, int>? colorOverrides,
    bool? isDarkMode,
    bool? isBuiltIn,
    DateTime? createdAt,
  }) {
    return ThemePreset(
      id: id ?? this.id,
      name: name ?? this.name,
      description: description ?? this.description,
      customCss: customCss ?? this.customCss,
      customHtml: customHtml ?? this.customHtml,
      colorOverrides: colorOverrides ?? Map.from(this.colorOverrides),
      isDarkMode: isDarkMode ?? this.isDarkMode,
      isBuiltIn: isBuiltIn ?? this.isBuiltIn,
      createdAt: createdAt ?? this.createdAt,
    );
  }


  factory ThemePreset.defaultLight() {
    return ThemePreset(
      id: 'default_light',
      name: '기본 (라이트)',
      description: '기본 라이트 테마',
      isDarkMode: false,
      isBuiltIn: true,
      colorOverrides: {
        COLOR_PRIMARY: Colors.purple.value,
        COLOR_SECONDARY: Colors.purpleAccent.value,
        COLOR_BACKGROUND: Colors.white.value,
        COLOR_SURFACE: Colors.grey[100]!.value,
        COLOR_USER_BUBBLE: Colors.purple.value,
        COLOR_AI_BUBBLE: Colors.grey[200]!.value,
        COLOR_TEXT: Colors.black87.value,
      },
    );
  }

  factory ThemePreset.defaultDark() {
    return ThemePreset(
      id: 'default_dark',
      name: '기본 (다크)',
      description: '기본 다크 테마',
      isDarkMode: true,
      isBuiltIn: true,
      colorOverrides: {
        COLOR_PRIMARY: Colors.purpleAccent.value,
        COLOR_SECONDARY: Colors.purple.value,
        COLOR_BACKGROUND: const Color(0xFF121212).value,
        COLOR_SURFACE: const Color(0xFF1E1E1E).value,
        COLOR_USER_BUBBLE: Colors.purpleAccent.value,
        COLOR_AI_BUBBLE: const Color(0xFF2D2D2D).value,
        COLOR_TEXT: Colors.white.value,
      },
    );
  }

  factory ThemePreset.pink() {
    return ThemePreset(
      id: 'pink_theme',
      name: '핑크 테마',
      description: '귀여운 핑크 테마',
      isDarkMode: false,
      isBuiltIn: true,
      colorOverrides: {
        COLOR_PRIMARY: Colors.pink.value,
        COLOR_SECONDARY: Colors.pinkAccent.value,
        COLOR_BACKGROUND: const Color(0xFFFFF0F5).value,
        COLOR_SURFACE: const Color(0xFFFFE4E9).value,
        COLOR_USER_BUBBLE: Colors.pink.value,
        COLOR_AI_BUBBLE: const Color(0xFFFFD6E0).value,
        COLOR_TEXT: Colors.black87.value,
      },
    );
  }

  @override
  String toString() {
    return 'ThemePreset(id: $id, name: $name, isDarkMode: $isDarkMode)';
  }
}
