class Live2DEmotionPreset {
  const Live2DEmotionPreset({
    required this.name,
    this.params = const {},
    this.expressionId,
    this.motionGroup,
    this.motionIndex,
    this.transitionDurationMs = 200,
  });

  final String name;
  final Map<String, double> params;
  final String? expressionId;
  final String? motionGroup;
  final int? motionIndex;
  final int transitionDurationMs;

  Map<String, dynamic> toMap() {
    return {
      'name': name,
      'params': params,
      'expressionId': expressionId,
      'motionGroup': motionGroup,
      'motionIndex': motionIndex,
      'transitionDurationMs': transitionDurationMs,
    };
  }

  factory Live2DEmotionPreset.fromMap(Map<String, dynamic> map) {
    return Live2DEmotionPreset(
      name: map['name'] as String? ?? 'neutral',
      params: (map['params'] as Map<String, dynamic>? ?? const {}).map(
        (key, value) => MapEntry(key, (value as num).toDouble()),
      ),
      expressionId: map['expressionId'] as String?,
      motionGroup: map['motionGroup'] as String?,
      motionIndex: map['motionIndex'] as int?,
      transitionDurationMs: map['transitionDurationMs'] as int? ?? 200,
    );
  }
}
