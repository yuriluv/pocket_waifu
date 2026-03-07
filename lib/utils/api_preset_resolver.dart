import '../models/api_config.dart';

ApiConfig? resolveApiConfigByPreset({
  required List<ApiConfig> apiConfigs,
  required ApiConfig? activeApiConfig,
  required String? presetId,
}) {
  if (presetId != null) {
    for (final config in apiConfigs) {
      if (config.id == presetId) {
        return config;
      }
    }
  }
  return activeApiConfig;
}
