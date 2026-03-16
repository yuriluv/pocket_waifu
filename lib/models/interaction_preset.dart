import 'package:uuid/uuid.dart';

class InteractionPreset {
  InteractionPreset({
    String? id,
    required this.name,
    this.html = '',
    this.css = '',
  }) : id = id ?? const Uuid().v4();

  final String id;
  final String name;
  final String html;
  final String css;

  InteractionPreset copyWith({
    String? id,
    String? name,
    String? html,
    String? css,
  }) {
    return InteractionPreset(
      id: id ?? this.id,
      name: name ?? this.name,
      html: html ?? this.html,
      css: css ?? this.css,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'name': name,
      'html': html,
      'css': css,
    };
  }

  factory InteractionPreset.fromMap(Map<String, dynamic> map) {
    return InteractionPreset(
      id: map['id']?.toString(),
      name: map['name']?.toString() ?? 'Preset',
      html: map['html']?.toString() ?? '',
      css: map['css']?.toString() ?? '',
    );
  }
}
