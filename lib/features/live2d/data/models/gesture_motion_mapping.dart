import '../../domain/entities/interaction_event.dart';

class GestureMotionEntry {
  const GestureMotionEntry({
    required this.id,
    required this.motionGroup,
    required this.motionIndex,
    required this.enabled,
    required this.priority,
    this.expressionOverride,
  });

  final String id;
  final String motionGroup;
  final int motionIndex;
  final bool enabled;
  final int priority;
  final String? expressionOverride;

  GestureMotionEntry copyWith({
    String? id,
    String? motionGroup,
    int? motionIndex,
    bool? enabled,
    int? priority,
    String? expressionOverride,
    bool clearExpressionOverride = false,
  }) {
    return GestureMotionEntry(
      id: id ?? this.id,
      motionGroup: motionGroup ?? this.motionGroup,
      motionIndex: motionIndex ?? this.motionIndex,
      enabled: enabled ?? this.enabled,
      priority: priority ?? this.priority,
      expressionOverride: clearExpressionOverride
          ? null
          : (expressionOverride ?? this.expressionOverride),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'motionGroup': motionGroup,
      'motionIndex': motionIndex,
      'enabled': enabled,
      'priority': priority,
      if (expressionOverride != null) 'expressionOverride': expressionOverride,
    };
  }

  factory GestureMotionEntry.fromJson(Map<String, dynamic> json) {
    return GestureMotionEntry(
      id: json['id'] as String,
      motionGroup: json['motionGroup'] as String,
      motionIndex: json['motionIndex'] as int? ?? 0,
      enabled: json['enabled'] as bool? ?? true,
      priority: (json['priority'] as int? ?? 5).clamp(1, 10),
      expressionOverride: json['expressionOverride'] as String?,
    );
  }
}

class GestureMotionConfig {
  const GestureMotionConfig({
    required this.mappings,
    required this.randomPerGesture,
  });

  final Map<InteractionType, List<GestureMotionEntry>> mappings;
  final Map<InteractionType, bool> randomPerGesture;

  static const List<InteractionType> supportedGestures = <InteractionType>[
    InteractionType.tap,
    InteractionType.doubleTap,
    InteractionType.longPress,
    InteractionType.swipeLeft,
    InteractionType.swipeRight,
    InteractionType.swipeUp,
    InteractionType.swipeDown,
  ];

  factory GestureMotionConfig.defaults() {
    return GestureMotionConfig(
      mappings: {
        for (final gesture in supportedGestures) gesture: const <GestureMotionEntry>[],
      },
      randomPerGesture: {
        for (final gesture in supportedGestures) gesture: false,
      },
    );
  }

  GestureMotionConfig copyWith({
    Map<InteractionType, List<GestureMotionEntry>>? mappings,
    Map<InteractionType, bool>? randomPerGesture,
  }) {
    return GestureMotionConfig(
      mappings: mappings ?? this.mappings,
      randomPerGesture: randomPerGesture ?? this.randomPerGesture,
    );
  }

  List<GestureMotionEntry> entriesFor(InteractionType gesture) {
    return List<GestureMotionEntry>.from(mappings[gesture] ?? const <GestureMotionEntry>[]);
  }

  bool randomEnabled(InteractionType gesture) {
    return randomPerGesture[gesture] ?? false;
  }

  Map<String, dynamic> toJson() {
    return {
      'mappings': {
        for (final gesture in supportedGestures)
          gesture.name: entriesFor(gesture).map((e) => e.toJson()).toList(growable: false),
      },
      'randomPerGesture': {
        for (final gesture in supportedGestures) gesture.name: randomEnabled(gesture),
      },
    };
  }

  factory GestureMotionConfig.fromJson(Map<String, dynamic> json) {
    final defaultConfig = GestureMotionConfig.defaults();
    final rawMappings = json['mappings'];
    final rawRandomMap = json['randomPerGesture'];

    final mappings = <InteractionType, List<GestureMotionEntry>>{};
    for (final gesture in supportedGestures) {
      if (rawMappings is Map<String, dynamic>) {
        final list = rawMappings[gesture.name];
        if (list is List) {
          mappings[gesture] = list
              .whereType<Map>()
              .map((e) => GestureMotionEntry.fromJson(Map<String, dynamic>.from(e)))
              .toList(growable: false);
          continue;
        }
      }
      mappings[gesture] = defaultConfig.entriesFor(gesture);
    }

    final randomPerGesture = <InteractionType, bool>{};
    for (final gesture in supportedGestures) {
      if (rawRandomMap is Map<String, dynamic>) {
        randomPerGesture[gesture] = rawRandomMap[gesture.name] as bool? ?? false;
      } else {
        randomPerGesture[gesture] = false;
      }
    }

    return GestureMotionConfig(
      mappings: mappings,
      randomPerGesture: randomPerGesture,
    );
  }
}
