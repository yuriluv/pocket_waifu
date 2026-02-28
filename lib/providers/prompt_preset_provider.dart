import 'package:flutter/foundation.dart';
import '../models/prompt_preset_reference.dart';
import '../models/prompt_preset.dart';

class PromptPresetProvider extends ChangeNotifier {
  List<PromptPresetReference> _presets = const [
    PromptPresetReference(id: 'current', name: '현재 프롬프트'),
  ];

  List<PromptPresetReference> get presets => List.unmodifiable(_presets);

  void syncFromPromptPresets(List<PromptPreset> presets) {
    final mapped = presets
        .map(
          (preset) => PromptPresetReference(id: preset.id, name: preset.name),
        )
        .toList();
    final next = mapped.isEmpty
        ? const [PromptPresetReference(id: 'current', name: '현재 프롬프트')]
        : mapped;

    if (_equals(_presets, next)) {
      return;
    }

    _presets = next;
    notifyListeners();
  }

  bool _equals(List<PromptPresetReference> a, List<PromptPresetReference> b) {
    if (a.length != b.length) return false;
    for (var i = 0; i < a.length; i++) {
      if (a[i].id != b[i].id || a[i].name != b[i].name) {
        return false;
      }
    }
    return true;
  }
}
