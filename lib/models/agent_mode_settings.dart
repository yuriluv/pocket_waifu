class AgentModeSettings {
  final bool enabled;
  final String? promptPresetId;
  final String? apiPresetId;
  final int triggerIntervalMinutes;
  final int maxIterations;
  final int loopTimeoutSeconds;

  const AgentModeSettings({
    this.enabled = false,
    this.promptPresetId,
    this.apiPresetId,
    this.triggerIntervalMinutes = 15,
    this.maxIterations = 5,
    this.loopTimeoutSeconds = 120,
  });

  AgentModeSettings copyWith({
    bool? enabled,
    String? promptPresetId,
    String? apiPresetId,
    int? triggerIntervalMinutes,
    int? maxIterations,
    int? loopTimeoutSeconds,
    bool clearPromptPreset = false,
    bool clearApiPreset = false,
  }) {
    return AgentModeSettings(
      enabled: enabled ?? this.enabled,
      promptPresetId: clearPromptPreset
          ? null
          : (promptPresetId ?? this.promptPresetId),
      apiPresetId: clearApiPreset ? null : (apiPresetId ?? this.apiPresetId),
      triggerIntervalMinutes: triggerIntervalMinutes ?? this.triggerIntervalMinutes,
      maxIterations: maxIterations ?? this.maxIterations,
      loopTimeoutSeconds: loopTimeoutSeconds ?? this.loopTimeoutSeconds,
    );
  }
}
