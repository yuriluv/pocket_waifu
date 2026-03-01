class AutoMotionConfig {
  const AutoMotionConfig({
    required this.enabled,
    required this.motionGroup,
    required this.intervalSeconds,
    required this.randomMode,
    required this.autoExpressionChange,
    required this.expressionSelection,
  });

  final bool enabled;
  final String? motionGroup;
  final int intervalSeconds;
  final bool randomMode;
  final bool autoExpressionChange;
  final String? expressionSelection;

  factory AutoMotionConfig.defaults() {
    return const AutoMotionConfig(
      enabled: false,
      motionGroup: null,
      intervalSeconds: 10,
      randomMode: true,
      autoExpressionChange: false,
      expressionSelection: null,
    );
  }

  AutoMotionConfig copyWith({
    bool? enabled,
    String? motionGroup,
    bool clearMotionGroup = false,
    int? intervalSeconds,
    bool? randomMode,
    bool? autoExpressionChange,
    String? expressionSelection,
    bool clearExpressionSelection = false,
  }) {
    return AutoMotionConfig(
      enabled: enabled ?? this.enabled,
      motionGroup: clearMotionGroup ? null : (motionGroup ?? this.motionGroup),
      intervalSeconds: intervalSeconds ?? this.intervalSeconds,
      randomMode: randomMode ?? this.randomMode,
      autoExpressionChange: autoExpressionChange ?? this.autoExpressionChange,
      expressionSelection: clearExpressionSelection
          ? null
          : (expressionSelection ?? this.expressionSelection),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'enabled': enabled,
      'motionGroup': motionGroup,
      'intervalSeconds': intervalSeconds,
      'randomMode': randomMode,
      'autoExpressionChange': autoExpressionChange,
      'expressionSelection': expressionSelection,
    };
  }

  factory AutoMotionConfig.fromJson(Map<String, dynamic> json) {
    return AutoMotionConfig(
      enabled: json['enabled'] as bool? ?? false,
      motionGroup: json['motionGroup'] as String?,
      intervalSeconds: (json['intervalSeconds'] as int? ?? 10).clamp(5, 120),
      randomMode: json['randomMode'] as bool? ?? true,
      autoExpressionChange: json['autoExpressionChange'] as bool? ?? false,
      expressionSelection: json['expressionSelection'] as String?,
    );
  }
}
