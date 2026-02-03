// ============================================================================
// 테마 프리셋 모델 (Theme Preset Model)
// ============================================================================
// 앱의 시각적 테마를 커스터마이징하기 위한 프리셋 모델입니다.
// CSS/HTML 커스텀 기능은 추후 구현 예정입니다.
// ============================================================================

import 'package:flutter/material.dart';
import 'package:uuid/uuid.dart';

/// 테마 프리셋 클래스
/// 앱의 시각적 스타일을 정의하는 프리셋입니다
class ThemePreset {
  final String id;            // 프리셋 고유 ID
  String name;                // 프리셋 이름 (예: "다크 모드", "핑크 테마")
  String? description;        // 프리셋 설명 (선택사항)
  String customCss;           // 커스텀 CSS (TODO: 추후 적용 로직 구현)
  String customHtml;          // 커스텀 HTML 템플릿 (TODO: 추후 적용 로직 구현)
  Map<String, int> colorOverrides;  // 색상 오버라이드 (Color 값을 int로 저장)
  bool isDarkMode;            // 다크 모드 여부
  bool isBuiltIn;             // 기본 제공 테마 여부
  DateTime createdAt;         // 생성 시간

  /// ThemePreset 생성자
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

  // === 색상 키 상수 ===
  // colorOverrides Map에서 사용할 키 값들
  static const String COLOR_PRIMARY = 'primary';           // 주요 색상
  static const String COLOR_SECONDARY = 'secondary';       // 보조 색상
  static const String COLOR_BACKGROUND = 'background';     // 배경 색상
  static const String COLOR_SURFACE = 'surface';           // 표면 색상
  static const String COLOR_USER_BUBBLE = 'userBubble';    // 사용자 메시지 버블
  static const String COLOR_AI_BUBBLE = 'aiBubble';        // AI 메시지 버블
  static const String COLOR_TEXT = 'text';                 // 텍스트 색상

  /// 특정 색상 값 가져오기
  Color? getColor(String key) {
    final value = colorOverrides[key];
    return value != null ? Color(value) : null;
  }

  /// 특정 색상 값 설정하기
  void setColor(String key, Color color) {
    colorOverrides[key] = color.value;
  }

  /// ThemePreset을 Map으로 변환 (저장용)
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

  /// Map에서 ThemePreset 생성 (불러오기용)
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

  /// 프리셋 복사본 생성
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

  // === 기본 프리셋 팩토리 메서드 ===

  /// 기본 라이트 테마 프리셋
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

  /// 기본 다크 테마 프리셋
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

  /// 핑크 테마 프리셋
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
