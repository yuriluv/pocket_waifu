// ============================================================================
// ============================================================================
// ============================================================================

import 'package:flutter/material.dart';
import '../../data/services/live2d_native_bridge.dart';
import '../../data/services/interaction_config_service.dart';

class AutoBehaviorSettings {
  final bool eyeBlinkEnabled;
  final bool breathingEnabled;
  final bool lookAtEnabled;
  final double eyeBlinkInterval;
  final double breathingSpeed;
  final double lookAtSensitivity; // 0.0 ~ 1.0

  const AutoBehaviorSettings({
    this.eyeBlinkEnabled = true,
    this.breathingEnabled = true,
    this.lookAtEnabled = true,
    this.eyeBlinkInterval = 3.0,
    this.breathingSpeed = 1.0,
    this.lookAtSensitivity = 0.5,
  });

  AutoBehaviorSettings copyWith({
    bool? eyeBlinkEnabled,
    bool? breathingEnabled,
    bool? lookAtEnabled,
    double? eyeBlinkInterval,
    double? breathingSpeed,
    double? lookAtSensitivity,
  }) {
    return AutoBehaviorSettings(
      eyeBlinkEnabled: eyeBlinkEnabled ?? this.eyeBlinkEnabled,
      breathingEnabled: breathingEnabled ?? this.breathingEnabled,
      lookAtEnabled: lookAtEnabled ?? this.lookAtEnabled,
      eyeBlinkInterval: eyeBlinkInterval ?? this.eyeBlinkInterval,
      breathingSpeed: breathingSpeed ?? this.breathingSpeed,
      lookAtSensitivity: lookAtSensitivity ?? this.lookAtSensitivity,
    );
  }

  Map<String, dynamic> toJson() => {
    'eyeBlinkEnabled': eyeBlinkEnabled,
    'breathingEnabled': breathingEnabled,
    'lookAtEnabled': lookAtEnabled,
    'eyeBlinkInterval': eyeBlinkInterval,
    'breathingSpeed': breathingSpeed,
    'lookAtSensitivity': lookAtSensitivity,
  };

  factory AutoBehaviorSettings.fromJson(Map<String, dynamic> json) {
    return AutoBehaviorSettings(
      eyeBlinkEnabled: json['eyeBlinkEnabled'] as bool? ?? true,
      breathingEnabled: json['breathingEnabled'] as bool? ?? true,
      lookAtEnabled: json['lookAtEnabled'] as bool? ?? true,
      eyeBlinkInterval: (json['eyeBlinkInterval'] as num?)?.toDouble() ?? 3.0,
      breathingSpeed: (json['breathingSpeed'] as num?)?.toDouble() ?? 1.0,
      lookAtSensitivity: (json['lookAtSensitivity'] as num?)?.toDouble() ?? 0.5,
    );
  }
}

class AutoBehaviorSettingsScreen extends StatefulWidget {
  const AutoBehaviorSettingsScreen({super.key});

  @override
  State<AutoBehaviorSettingsScreen> createState() => _AutoBehaviorSettingsScreenState();
}

class _AutoBehaviorSettingsScreenState extends State<AutoBehaviorSettingsScreen> {
  final Live2DNativeBridge _bridge = Live2DNativeBridge();
  final InteractionConfigService _configService = InteractionConfigService();
  
  AutoBehaviorSettings _settings = const AutoBehaviorSettings();
  bool _isLoading = true;
  bool _hasChanges = false;

  @override
  void initState() {
    super.initState();
    _loadSettings();
  }

  Future<void> _loadSettings() async {
    setState(() => _isLoading = true);
    _settings = await _configService.loadAutoBehaviorSettings();
    if (mounted) {
      setState(() => _isLoading = false);
    }
  }

  Future<void> _saveSettings() async {
    await _configService.saveAutoBehaviorSettings(_settings);
    
    await _bridge.setEyeBlink(_settings.eyeBlinkEnabled);
    await _bridge.setBreathing(_settings.breathingEnabled);
    await _bridge.setLookAt(_settings.lookAtEnabled);
    
    setState(() => _hasChanges = false);
    
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('설정이 저장되었습니다')),
      );
    }
  }

  void _updateSettings(AutoBehaviorSettings newSettings) {
    setState(() {
      _settings = newSettings;
      _hasChanges = true;
    });
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(
        title: const Text('자동 동작 설정'),
        actions: [
          if (_hasChanges)
            IconButton(
              icon: const Icon(Icons.save),
              tooltip: '저장',
              onPressed: _saveSettings,
            ),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : ListView(
              children: [
                _SectionHeader(
                  title: '눈 깜빡임',
                  icon: Icons.visibility,
                ),
                
                SwitchListTile(
                  title: const Text('자동 눈 깜빡임'),
                  subtitle: const Text('캐릭터가 자연스럽게 눈을 깜빡입니다'),
                  secondary: const Icon(Icons.remove_red_eye),
                  value: _settings.eyeBlinkEnabled,
                  onChanged: (value) {
                    _updateSettings(_settings.copyWith(eyeBlinkEnabled: value));
                  },
                ),
                
                if (_settings.eyeBlinkEnabled) ...[
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          '깜빡임 간격: ${_settings.eyeBlinkInterval.toStringAsFixed(1)}초',
                          style: theme.textTheme.bodyMedium,
                        ),
                        Slider(
                          value: _settings.eyeBlinkInterval,
                          min: 1.0,
                          max: 10.0,
                          divisions: 18,
                          label: '${_settings.eyeBlinkInterval.toStringAsFixed(1)}초',
                          onChanged: (value) {
                            _updateSettings(_settings.copyWith(eyeBlinkInterval: value));
                          },
                        ),
                      ],
                    ),
                  ),
                ],
                
                const Divider(),
                
                _SectionHeader(
                  title: '호흡',
                  icon: Icons.air,
                ),
                
                SwitchListTile(
                  title: const Text('자동 호흡'),
                  subtitle: const Text('캐릭터가 자연스럽게 숨을 쉽니다'),
                  secondary: const Icon(Icons.air),
                  value: _settings.breathingEnabled,
                  onChanged: (value) {
                    _updateSettings(_settings.copyWith(breathingEnabled: value));
                  },
                ),
                
                if (_settings.breathingEnabled) ...[
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          '호흡 속도: ${(_settings.breathingSpeed * 100).toInt()}%',
                          style: theme.textTheme.bodyMedium,
                        ),
                        Slider(
                          value: _settings.breathingSpeed,
                          min: 0.5,
                          max: 2.0,
                          divisions: 15,
                          label: '${(_settings.breathingSpeed * 100).toInt()}%',
                          onChanged: (value) {
                            _updateSettings(_settings.copyWith(breathingSpeed: value));
                          },
                        ),
                      ],
                    ),
                  ),
                ],
                
                const Divider(),
                
                _SectionHeader(
                  title: '시선 추적',
                  icon: Icons.track_changes,
                ),
                
                SwitchListTile(
                  title: const Text('시선 추적'),
                  subtitle: const Text('터치 위치를 따라 시선이 움직입니다'),
                  secondary: const Icon(Icons.remove_red_eye_outlined),
                  value: _settings.lookAtEnabled,
                  onChanged: (value) {
                    _updateSettings(_settings.copyWith(lookAtEnabled: value));
                  },
                ),
                
                if (_settings.lookAtEnabled) ...[
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          '민감도: ${(_settings.lookAtSensitivity * 100).toInt()}%',
                          style: theme.textTheme.bodyMedium,
                        ),
                        Slider(
                          value: _settings.lookAtSensitivity,
                          min: 0.1,
                          max: 1.0,
                          divisions: 9,
                          label: '${(_settings.lookAtSensitivity * 100).toInt()}%',
                          onChanged: (value) {
                            _updateSettings(_settings.copyWith(lookAtSensitivity: value));
                          },
                        ),
                      ],
                    ),
                  ),
                ],
                
                const SizedBox(height: 16),
                
                Card(
                  margin: const EdgeInsets.all(16),
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Icon(Icons.info_outline, 
                              color: theme.colorScheme.primary),
                            const SizedBox(width: 8),
                            Text('안내', 
                              style: theme.textTheme.titleMedium),
                          ],
                        ),
                        const SizedBox(height: 8),
                        const Text(
                          '• 자동 동작은 모델이 지원하는 경우에만 작동합니다.\n'
                          '• 시선 추적은 화면 터치 시 활성화됩니다.\n'
                          '• 배터리 소모를 줄이려면 불필요한 기능을 끄세요.',
                        ),
                      ],
                    ),
                  ),
                ),
                
                Padding(
                  padding: const EdgeInsets.all(16),
                  child: OutlinedButton.icon(
                    onPressed: () {
                      _updateSettings(const AutoBehaviorSettings());
                    },
                    icon: const Icon(Icons.refresh),
                    label: const Text('기본값으로 초기화'),
                  ),
                ),
                
                const SizedBox(height: 32),
              ],
            ),
    );
  }
}

// ============================================================================
// ============================================================================

class _SectionHeader extends StatelessWidget {
  final String title;
  final IconData icon;

  const _SectionHeader({
    required this.title,
    required this.icon,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
      child: Row(
        children: [
          Icon(icon, size: 20, color: theme.colorScheme.primary),
          const SizedBox(width: 8),
          Text(
            title,
            style: theme.textTheme.titleMedium?.copyWith(
              color: theme.colorScheme.primary,
              fontWeight: FontWeight.bold,
            ),
          ),
        ],
      ),
    );
  }
}
