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

  static const String colorPrimary = 'primary';
  static const String colorSecondary = 'secondary';
  static const String colorBackground = 'background';
  static const String colorSurface = 'surface';
  static const String colorUserBubble = 'userBubble';
  static const String colorAiBubble = 'aiBubble';
  static const String colorText = 'text';

  Color? getColor(String key) {
    final value = colorOverrides[key];
    return value != null ? Color(value) : null;
  }

  void setColor(String key, Color color) {
    colorOverrides[key] = color.toARGB32();
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
        colorPrimary: Colors.purple.toARGB32(),
        colorSecondary: Colors.purpleAccent.toARGB32(),
        colorBackground: Colors.white.toARGB32(),
        colorSurface: Colors.grey[100]!.toARGB32(),
        colorUserBubble: Colors.purple.toARGB32(),
        colorAiBubble: Colors.grey[200]!.toARGB32(),
        colorText: Colors.black87.toARGB32(),
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
        colorPrimary: Colors.purpleAccent.toARGB32(),
        colorSecondary: Colors.purple.toARGB32(),
        colorBackground: const Color(0xFF121212).toARGB32(),
        colorSurface: const Color(0xFF1E1E1E).toARGB32(),
        colorUserBubble: Colors.purpleAccent.toARGB32(),
        colorAiBubble: const Color(0xFF2D2D2D).toARGB32(),
        colorText: Colors.white.toARGB32(),
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
        colorPrimary: Colors.pink.toARGB32(),
        colorSecondary: Colors.pinkAccent.toARGB32(),
        colorBackground: const Color(0xFFFFF0F5).toARGB32(),
        colorSurface: const Color(0xFFFFE4E9).toARGB32(),
        colorUserBubble: Colors.pink.toARGB32(),
        colorAiBubble: const Color(0xFFFFD6E0).toARGB32(),
        colorText: Colors.black87.toARGB32(),
      },
    );
  }

  @override
  String toString() {
    return 'ThemePreset(id: $id, name: $name, isDarkMode: $isDarkMode)';
  }
}
