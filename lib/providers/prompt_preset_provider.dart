import 'package:flutter/foundation.dart';
import '../models/prompt_preset_reference.dart';

class PromptPresetProvider extends ChangeNotifier {
  final List<PromptPresetReference> _presets = const [
    PromptPresetReference(id: 'current', name: '현재 프롬프트'),
  ];

  List<PromptPresetReference> get presets => List.unmodifiable(_presets);
}
