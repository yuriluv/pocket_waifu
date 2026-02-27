import 'package:uuid/uuid.dart';

class PromptBlock {
  static const String typePrompt = 'prompt';
  static const String typePastMemory = 'pastmemory';
  static const String typeInput = 'input';

  final String id;
  String type;
  String title;
  bool isActive;
  String content;
  String range;
  String userHeader;
  String charHeader;
  int order;

  PromptBlock({
    String? id,
    required this.type,
    required this.title,
    this.isActive = true,
    this.content = '',
    this.range = '1',
    this.userHeader = 'user',
    this.charHeader = 'char',
    this.order = 0,
  }) : id = id ?? const Uuid().v4();

  PromptBlock copyWith({
    String? id,
    String? type,
    String? title,
    bool? isActive,
    String? content,
    String? range,
    String? userHeader,
    String? charHeader,
    int? order,
  }) {
    return PromptBlock(
      id: id ?? this.id,
      type: type ?? this.type,
      title: title ?? this.title,
      isActive: isActive ?? this.isActive,
      content: content ?? this.content,
      range: range ?? this.range,
      userHeader: userHeader ?? this.userHeader,
      charHeader: charHeader ?? this.charHeader,
      order: order ?? this.order,
    );
  }

  PromptBlock clone() {
    return copyWith(id: const Uuid().v4());
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'type': type,
      'title': title,
      'isActive': isActive,
      'content': content,
      'range': range,
      'userHeader': userHeader,
      'charHeader': charHeader,
      'order': order,
    };
  }

  Map<String, dynamic> toExternalMap() {
    final map = <String, dynamic>{
      'type': type,
      'title': title,
      'isActive': isActive,
    };

    if (type == typePrompt) {
      map['content'] = content;
    } else if (type == typePastMemory) {
      map['range'] = range;
      map['userHeader'] = userHeader;
      map['charHeader'] = charHeader;
    }

    return map;
  }

  factory PromptBlock.fromMap(Map<String, dynamic> map) {
    return PromptBlock(
      id: map['id'],
      type: map['type'] ?? typePrompt,
      title: map['title'] ?? '',
      isActive: map['isActive'] ?? true,
      content: map['content'] ?? '',
      range: map['range']?.toString() ?? '1',
      userHeader: map['userHeader'] ?? 'user',
      charHeader: map['charHeader'] ?? 'char',
      order: map['order'] ?? 0,
    );
  }

  static PromptBlock prompt({
    String? id,
    String title = 'Prompt',
    String content = '',
    bool isActive = true,
    int order = 0,
  }) {
    return PromptBlock(
      id: id,
      type: typePrompt,
      title: title,
      content: content,
      isActive: isActive,
      order: order,
    );
  }

  static PromptBlock pastMemory({
    String? id,
    String title = 'Past Memory',
    String range = '10',
    String userHeader = 'user',
    String charHeader = 'char',
    bool isActive = true,
    int order = 0,
  }) {
    return PromptBlock(
      id: id,
      type: typePastMemory,
      title: title,
      range: range,
      userHeader: userHeader,
      charHeader: charHeader,
      isActive: isActive,
      order: order,
    );
  }

  static PromptBlock input({
    String? id,
    String title = 'Input',
    bool isActive = true,
    int order = 0,
  }) {
    return PromptBlock(
      id: id,
      type: typeInput,
      title: title,
      isActive: isActive,
      order: order,
    );
  }

  static bool isRecognizedType(String type) {
    return type == typePrompt || type == typePastMemory || type == typeInput;
  }

  @override
  String toString() {
    return 'PromptBlock(id: $id, type: $type, title: $title, active: $isActive, order: $order)';
  }
}
