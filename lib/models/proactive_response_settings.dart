class ProactiveResponseSettings {
  final bool enabled;
  final String scheduleText;
  final String? promptPresetId;
  final String? apiPresetId;

  const ProactiveResponseSettings({
    this.enabled = false,
    this.scheduleText =
        'base=30m\n'
        'deviation=10\n'
        'overlayon=-20m\n'
        'screenlandscape=+20m\n'
        'screenoff=inf',
    this.promptPresetId = 'current',
    this.apiPresetId,
  });

  ProactiveResponseSettings copyWith({
    bool? enabled,
    String? scheduleText,
    String? promptPresetId,
    String? apiPresetId,
    bool clearPromptPreset = false,
    bool clearApiPreset = false,
  }) {
    return ProactiveResponseSettings(
      enabled: enabled ?? this.enabled,
      scheduleText: scheduleText ?? this.scheduleText,
      promptPresetId: clearPromptPreset
          ? null
          : (promptPresetId ?? this.promptPresetId),
      apiPresetId: clearApiPreset ? null : (apiPresetId ?? this.apiPresetId),
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'enabled': enabled,
      'scheduleText': scheduleText,
      'promptPresetId': promptPresetId,
      'apiPresetId': apiPresetId,
    };
  }

  factory ProactiveResponseSettings.fromMap(Map<String, dynamic> map) {
    return ProactiveResponseSettings(
      enabled: map['enabled'] ?? false,
      scheduleText: map['scheduleText'] ?? '',
      promptPresetId: map['promptPresetId'],
      apiPresetId: map['apiPresetId'],
    );
  }
}
