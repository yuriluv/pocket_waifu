class NotificationSettings {
  final bool notificationsEnabled;
  // Deprecated: persistent notification mode has been removed.
  final bool persistentEnabled;
  final bool outputAsNewNotification;
  final String? promptPresetId;
  final String? apiPresetId;

  const NotificationSettings({
    this.notificationsEnabled = false,
    this.persistentEnabled = false,
    this.outputAsNewNotification = true,
    this.promptPresetId = 'current',
    this.apiPresetId,
  });

  NotificationSettings copyWith({
    bool? notificationsEnabled,
    bool? persistentEnabled,
    bool? outputAsNewNotification,
    String? promptPresetId,
    String? apiPresetId,
    bool clearPromptPreset = false,
    bool clearApiPreset = false,
  }) {
    return NotificationSettings(
      notificationsEnabled: notificationsEnabled ?? this.notificationsEnabled,
      persistentEnabled: persistentEnabled ?? this.persistentEnabled,
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
      'persistentEnabled': persistentEnabled,
      'outputAsNewNotification': outputAsNewNotification,
      'promptPresetId': promptPresetId,
      'apiPresetId': apiPresetId,
    };
  }

  factory NotificationSettings.fromMap(Map<String, dynamic> map) {
    return NotificationSettings(
      notificationsEnabled: map['notificationsEnabled'] ?? false,
      persistentEnabled: map['persistentEnabled'] ?? true,
      outputAsNewNotification: map['outputAsNewNotification'] ?? true,
      promptPresetId: map['promptPresetId'],
      apiPresetId: map['apiPresetId'],
    );
  }
}
