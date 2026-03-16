class SessionInteractionState {
  const SessionInteractionState({
    this.html = '',
    this.css = '',
    this.activePresetId,
  });

  final String html;
  final String css;
  final String? activePresetId;

  factory SessionInteractionState.fromMap(Map<String, dynamic>? map) {
    if (map == null) {
      return const SessionInteractionState();
    }
    return SessionInteractionState(
      html: map['html']?.toString() ?? '',
      css: map['css']?.toString() ?? '',
      activePresetId: map['activePresetId']?.toString(),
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'html': html,
      'css': css,
      'activePresetId': activePresetId,
    };
  }

  SessionInteractionState copyWith({
    String? html,
    String? css,
    String? activePresetId,
    bool clearPreset = false,
  }) {
    return SessionInteractionState(
      html: html ?? this.html,
      css: css ?? this.css,
      activePresetId: clearPreset ? null : (activePresetId ?? this.activePresetId),
    );
  }
}
