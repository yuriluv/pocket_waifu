class ProactiveResponseSettings {
  static const String defaultScheduleText =
      'base=30m\n'
      'deviation=10\n'
      'overlayon=-20m\n'
      'screenlandscape=+20m\n'
      'screenoff=inf';

  final bool enabled;
  final String scheduleText;
  final String? promptPresetId;
  final String? apiPresetId;

  const ProactiveResponseSettings({
    this.enabled = false,
    this.scheduleText = defaultScheduleText,
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
    final rawScheduleText = map['scheduleText'];
    final resolvedScheduleText =
        rawScheduleText is String && rawScheduleText.trim().isNotEmpty
        ? rawScheduleText
        : defaultScheduleText;

    return ProactiveResponseSettings(
      enabled: map['enabled'] ?? false,
      scheduleText: resolvedScheduleText,
      promptPresetId: map['promptPresetId'],
      apiPresetId: map['apiPresetId'],
    );
  }
}
