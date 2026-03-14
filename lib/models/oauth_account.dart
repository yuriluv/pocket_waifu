import 'package:uuid/uuid.dart';

enum OAuthAccountProvider { codex, geminiGca }

extension OAuthAccountProviderX on OAuthAccountProvider {
  String get displayName => switch (this) {
    OAuthAccountProvider.codex => 'Codex',
    OAuthAccountProvider.geminiGca => 'Gemini CLI (GCA)',
  };

  String get shortName => switch (this) {
    OAuthAccountProvider.codex => 'codex',
    OAuthAccountProvider.geminiGca => 'gemini',
  };
}

class OAuthAccount {
  OAuthAccount({
    String? id,
    required this.provider,
    required this.label,
    required this.accessToken,
    this.refreshToken,
    this.expiresAt,
    this.email,
    this.displayName,
    this.idToken,
    this.cloudProjectId,
    this.oauthClientId,
    this.oauthClientSecret,
    this.organizationId,
    this.projectId,
    this.planType,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) : id = id ?? const Uuid().v4(),
       createdAt = createdAt ?? DateTime.now(),
       updatedAt = updatedAt ?? DateTime.now();

  final String id;
  final OAuthAccountProvider provider;
  final String label;
  final String accessToken;
  final String? refreshToken;
  final DateTime? expiresAt;
  final String? email;
  final String? displayName;
  final String? idToken;
  final String? cloudProjectId;
  final String? oauthClientId;
  final String? oauthClientSecret;
  final String? organizationId;
  final String? projectId;
  final String? planType;
  final DateTime createdAt;
  final DateTime updatedAt;

  bool get hasRefreshToken =>
      refreshToken != null && refreshToken!.trim().isNotEmpty;

  bool get isExpiringSoon {
    final expiry = expiresAt;
    if (expiry == null) {
      return false;
    }
    return DateTime.now().add(const Duration(minutes: 5)).isAfter(expiry);
  }

  String get displayLabel {
    if (label.trim().isNotEmpty) {
      return label.trim();
    }
    if (email != null && email!.trim().isNotEmpty) {
      return email!.trim();
    }
    if (displayName != null && displayName!.trim().isNotEmpty) {
      return displayName!.trim();
    }
    return provider.displayName;
  }

  OAuthAccount copyWith({
    String? id,
    OAuthAccountProvider? provider,
    String? label,
    String? accessToken,
    String? refreshToken,
    DateTime? expiresAt,
    String? email,
    String? displayName,
    String? idToken,
    String? cloudProjectId,
    String? oauthClientId,
    String? oauthClientSecret,
    String? organizationId,
    String? projectId,
    String? planType,
    DateTime? createdAt,
    DateTime? updatedAt,
    bool clearRefreshToken = false,
    bool clearExpiresAt = false,
    bool clearEmail = false,
    bool clearDisplayName = false,
    bool clearIdToken = false,
    bool clearCloudProjectId = false,
    bool clearOAuthClientId = false,
    bool clearOAuthClientSecret = false,
    bool clearOrganizationId = false,
    bool clearProjectId = false,
    bool clearPlanType = false,
  }) {
    return OAuthAccount(
      id: id ?? this.id,
      provider: provider ?? this.provider,
      label: label ?? this.label,
      accessToken: accessToken ?? this.accessToken,
      refreshToken: clearRefreshToken ? null : (refreshToken ?? this.refreshToken),
      expiresAt: clearExpiresAt ? null : (expiresAt ?? this.expiresAt),
      email: clearEmail ? null : (email ?? this.email),
      displayName: clearDisplayName ? null : (displayName ?? this.displayName),
      idToken: clearIdToken ? null : (idToken ?? this.idToken),
      cloudProjectId: clearCloudProjectId
          ? null
          : (cloudProjectId ?? this.cloudProjectId),
      oauthClientId: clearOAuthClientId
          ? null
          : (oauthClientId ?? this.oauthClientId),
      oauthClientSecret: clearOAuthClientSecret
          ? null
          : (oauthClientSecret ?? this.oauthClientSecret),
      organizationId: clearOrganizationId
          ? null
          : (organizationId ?? this.organizationId),
      projectId: clearProjectId ? null : (projectId ?? this.projectId),
      planType: clearPlanType ? null : (planType ?? this.planType),
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? DateTime.now(),
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'provider': provider.name,
      'label': label,
      'accessToken': accessToken,
      'refreshToken': refreshToken,
      'expiresAt': expiresAt?.toIso8601String(),
      'email': email,
      'displayName': displayName,
      'idToken': idToken,
      'cloudProjectId': cloudProjectId,
      'oauthClientId': oauthClientId,
      'oauthClientSecret': oauthClientSecret,
      'organizationId': organizationId,
      'projectId': projectId,
      'planType': planType,
      'createdAt': createdAt.toIso8601String(),
      'updatedAt': updatedAt.toIso8601String(),
    };
  }

  factory OAuthAccount.fromMap(Map<String, dynamic> map) {
    return OAuthAccount(
      id: map['id'] as String?,
      provider: switch (map['provider']) {
        'geminiGca' => OAuthAccountProvider.geminiGca,
        _ => OAuthAccountProvider.codex,
      },
      label: map['label'] as String? ?? '',
      accessToken: map['accessToken'] as String? ?? '',
      refreshToken: map['refreshToken'] as String?,
      expiresAt: _parseDateTime(map['expiresAt']),
      email: map['email'] as String?,
      displayName: map['displayName'] as String?,
      idToken: map['idToken'] as String?,
      cloudProjectId: map['cloudProjectId'] as String?,
      oauthClientId: map['oauthClientId'] as String?,
      oauthClientSecret: map['oauthClientSecret'] as String?,
      organizationId: map['organizationId'] as String?,
      projectId: map['projectId'] as String?,
      planType: map['planType'] as String?,
      createdAt: _parseDateTime(map['createdAt']) ?? DateTime.now(),
      updatedAt: _parseDateTime(map['updatedAt']) ?? DateTime.now(),
    );
  }

  static DateTime? _parseDateTime(Object? value) {
    if (value is! String || value.trim().isEmpty) {
      return null;
    }
    return DateTime.tryParse(value);
  }
}
