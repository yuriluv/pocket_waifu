class AutoMotionConfig {
  const AutoMotionConfig({
    required this.enabled,
    required this.motionGroup,
    required this.intervalSeconds,
    required this.randomMode,
    required this.autoExpressionChange,
    required this.expressionSelection,
    required this.cubismEyeBlinkEnabled,
    required this.eyeBlinkIntervalSeconds,
    required this.cubismBreathEnabled,
    required this.breathCycleSeconds,
    required this.breathWeight,
    required this.lookAtEnabled,
    required this.physicsEnabled,
    required this.physicsFps,
    required this.physicsDelayScale,
    required this.physicsMobilityScale,
  });

  final bool enabled;
  final String? motionGroup;
  final int intervalSeconds;
  final bool randomMode;
  final bool autoExpressionChange;
  final String? expressionSelection;
  final bool cubismEyeBlinkEnabled;
  final double eyeBlinkIntervalSeconds;
  final bool cubismBreathEnabled;
  final double breathCycleSeconds;
  final double breathWeight;
  final bool lookAtEnabled;
  final bool physicsEnabled;
  final int physicsFps;
  final double physicsDelayScale;
  final double physicsMobilityScale;

  factory AutoMotionConfig.defaults() {
    return const AutoMotionConfig(
      enabled: false,
      motionGroup: null,
      intervalSeconds: 10,
      randomMode: true,
      autoExpressionChange: false,
      expressionSelection: null,
      cubismEyeBlinkEnabled: true,
      eyeBlinkIntervalSeconds: 3.0,
      cubismBreathEnabled: true,
      breathCycleSeconds: 3.2,
      breathWeight: 1.0,
      lookAtEnabled: true,
      physicsEnabled: true,
      physicsFps: 30,
      physicsDelayScale: 1.0,
      physicsMobilityScale: 1.0,
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
    bool? cubismEyeBlinkEnabled,
    double? eyeBlinkIntervalSeconds,
    bool? cubismBreathEnabled,
    double? breathCycleSeconds,
    double? breathWeight,
    bool? lookAtEnabled,
    bool? physicsEnabled,
    int? physicsFps,
    double? physicsDelayScale,
    double? physicsMobilityScale,
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
      cubismEyeBlinkEnabled: cubismEyeBlinkEnabled ?? this.cubismEyeBlinkEnabled,
      eyeBlinkIntervalSeconds:
          eyeBlinkIntervalSeconds ?? this.eyeBlinkIntervalSeconds,
      cubismBreathEnabled: cubismBreathEnabled ?? this.cubismBreathEnabled,
      breathCycleSeconds: breathCycleSeconds ?? this.breathCycleSeconds,
      breathWeight: breathWeight ?? this.breathWeight,
      lookAtEnabled: lookAtEnabled ?? this.lookAtEnabled,
      physicsEnabled: physicsEnabled ?? this.physicsEnabled,
      physicsFps: physicsFps ?? this.physicsFps,
      physicsDelayScale: physicsDelayScale ?? this.physicsDelayScale,
      physicsMobilityScale: physicsMobilityScale ?? this.physicsMobilityScale,
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
      'cubismEyeBlinkEnabled': cubismEyeBlinkEnabled,
      'eyeBlinkIntervalSeconds': eyeBlinkIntervalSeconds,
      'cubismBreathEnabled': cubismBreathEnabled,
      'breathCycleSeconds': breathCycleSeconds,
      'breathWeight': breathWeight,
      'lookAtEnabled': lookAtEnabled,
      'physicsEnabled': physicsEnabled,
      'physicsFps': physicsFps,
      'physicsDelayScale': physicsDelayScale,
      'physicsMobilityScale': physicsMobilityScale,
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
      cubismEyeBlinkEnabled: json['cubismEyeBlinkEnabled'] as bool? ?? true,
      eyeBlinkIntervalSeconds: ((json['eyeBlinkIntervalSeconds'] as num?)
                  ?.toDouble() ??
              3.0)
          .clamp(0.5, 12.0),
      cubismBreathEnabled: json['cubismBreathEnabled'] as bool? ?? true,
      breathCycleSeconds: ((json['breathCycleSeconds'] as num?)?.toDouble() ??
              3.2)
          .clamp(1.0, 12.0),
      breathWeight: ((json['breathWeight'] as num?)?.toDouble() ?? 1.0)
          .clamp(0.0, 2.0),
      lookAtEnabled: json['lookAtEnabled'] as bool? ?? true,
      physicsEnabled: json['physicsEnabled'] as bool? ?? true,
      physicsFps: (json['physicsFps'] as int? ?? 30).clamp(1, 120),
      physicsDelayScale: ((json['physicsDelayScale'] as num?)?.toDouble() ??
              1.0)
          .clamp(0.1, 3.0),
      physicsMobilityScale:
          ((json['physicsMobilityScale'] as num?)?.toDouble() ?? 1.0)
              .clamp(0.1, 3.0),
    );
  }
}
