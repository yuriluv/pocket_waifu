class NotificationSettings {
  final bool notificationsEnabled;
  final bool outputAsNewNotification;
  final String? promptPresetId;
  final String? apiPresetId;

  const NotificationSettings({
    this.notificationsEnabled = false,
    this.outputAsNewNotification = true,
    this.promptPresetId = 'current',
    this.apiPresetId,
  });

  NotificationSettings copyWith({
    bool? notificationsEnabled,
    bool? outputAsNewNotification,
    String? promptPresetId,
    String? apiPresetId,
    bool clearPromptPreset = false,
    bool clearApiPreset = false,
  }) {
    return NotificationSettings(
      notificationsEnabled: notificationsEnabled ?? this.notificationsEnabled,
      outputAsNewNotification:
          outputAsNewNotification ?? this.outputAsNewNotification,
      promptPresetId: clearPromptPreset
          ? null
          : (promptPresetId ?? this.promptPresetId),
      apiPresetId: clearApiPreset ? null : (apiPresetId ?? this.apiPresetId),
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'notificationsEnabled': notificationsEnabled,
      'outputAsNewNotification': outputAsNewNotification,
      'promptPresetId': promptPresetId,
      'apiPresetId': apiPresetId,
    };
  }

  factory NotificationSettings.fromMap(Map<String, dynamic> map) {
    return NotificationSettings(
      notificationsEnabled: map['notificationsEnabled'] ?? false,
      outputAsNewNotification: map['outputAsNewNotification'] ?? true,
      promptPresetId: map['promptPresetId'],
      apiPresetId: map['apiPresetId'],
    );
  }
}
