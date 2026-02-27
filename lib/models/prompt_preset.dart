import 'package:uuid/uuid.dart';
import 'prompt_block.dart';

class PromptPreset {
  final String id;
  String name;
  List<PromptBlock> blocks;

  PromptPreset({
    String? id,
    required this.name,
    required this.blocks,
  }) : id = id ?? const Uuid().v4();

  PromptPreset copyWith({
    String? id,
    String? name,
    List<PromptBlock>? blocks,
  }) {
    return PromptPreset(
      id: id ?? this.id,
      name: name ?? this.name,
      blocks: blocks ?? this.blocks,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'name': name,
      'blocks': blocks.map((b) => b.toMap()).toList(),
    };
  }

  Map<String, dynamic> toExternalMap() {
    return {
      'name': name,
      'blocks': blocks.map((b) => b.toExternalMap()).toList(),
    };
  }

  factory PromptPreset.fromMap(Map<String, dynamic> map) {
    final rawBlocks = map['blocks'] as List<dynamic>? ?? [];
    return PromptPreset(
      id: map['id'],
      name: map['name'] ?? 'Preset',
      blocks: rawBlocks
          .whereType<Map<String, dynamic>>()
          .map(PromptBlock.fromMap)
          .toList(),
    );
  }
}
