import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:flutter_application_1/features/live2d/data/models/display_preset.dart';
import 'package:flutter_application_1/features/live2d/data/models/live2d_settings.dart';
import 'package:flutter_application_1/models/api_config.dart';
import 'package:flutter_application_1/models/prompt_block.dart';
import 'package:flutter_application_1/models/settings.dart';
import 'package:flutter_application_1/providers/settings_provider.dart';
import 'package:flutter_application_1/providers/prompt_block_provider.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('Live2DSettings persistence', () {
    test('save/load roundtrip preserves core fields', () async {
      SharedPreferences.setMockInitialValues({});

      final settings = Live2DSettings(
        isEnabled: true,
        dataFolderPath: '/tmp/live2d',
        selectedModelId: 'model-1',
        selectedModelPath: '/tmp/live2d/model.model3.json',
        scale: 1.4,
        positionX: 0.25,
        positionY: 0.75,
        opacity: 0.9,
        touchThroughEnabled: false,
        touchThroughAlpha: 40,
        overlayWidth: 512,
        overlayHeight: 640,
        editModeEnabled: true,
        characterPinned: true,
        relativeCharacterScale: 1.1,
        characterOffsetX: 10.5,
        characterOffsetY: -6.0,
        characterRotation: 45,
      );

      final saved = await settings.save();
      expect(saved, isTrue);

      final loaded = await Live2DSettings.load();
      expect(loaded.isEnabled, isTrue);
      expect(loaded.dataFolderPath, '/tmp/live2d');
      expect(loaded.selectedModelId, 'model-1');
      expect(loaded.selectedModelPath, '/tmp/live2d/model.model3.json');
      expect(loaded.scale, 1.4);
      expect(loaded.positionX, 0.25);
      expect(loaded.positionY, 0.75);
      expect(loaded.opacity, 0.9);
      expect(loaded.touchThroughEnabled, isFalse);
      expect(loaded.touchThroughAlpha, 40);
      expect(loaded.overlayWidth, 512);
      expect(loaded.overlayHeight, 640);
      expect(loaded.editModeEnabled, isTrue);
      expect(loaded.characterPinned, isTrue);
      expect(loaded.relativeCharacterScale, 1.1);
      expect(loaded.characterOffsetX, 10.5);
      expect(loaded.characterOffsetY, -6.0);
      expect(loaded.characterRotation, 45);
    });

    test('copyWith clamps values to expected bounds', () {
      const settings = Live2DSettings();

      final updated = settings.copyWith(
        scale: 9.0,
        positionX: -2.0,
        positionY: 3.0,
        opacity: -1.0,
        touchThroughAlpha: 500,
        relativeCharacterScale: 9.0,
        characterRotation: 725,
      );

      expect(updated.scale, 2.0);
      expect(updated.positionX, 0.0);
      expect(updated.positionY, 1.0);
      expect(updated.opacity, 0.0);
      expect(updated.touchThroughAlpha, 100);
      expect(updated.relativeCharacterScale, 3.0);
      expect(updated.characterRotation, 5);
    });
  });

  group('DisplayPreset persistence', () {
    test('save/load roundtrip preserves presets', () async {
      SharedPreferences.setMockInitialValues({});

      final presets = [
        DisplayPreset(
          id: 'preset-1',
          name: 'Primary',
          relativeCharacterScale: 1.2,
          characterOffsetX: 4.0,
          characterOffsetY: -3.0,
          characterRotation: 15,
          overlayWidth: 420,
          overlayHeight: 600,
          positionX: 0.1,
          positionY: 0.9,
          scale: 1.3,
          linkedModelFolder: '/tmp/models',
          linkedModelId: 'model-1',
        ),
      ];

      final saved = await DisplayPresetManager.saveAll(presets);
      expect(saved, isTrue);

      final loaded = await DisplayPresetManager.loadAll();
      expect(loaded, hasLength(1));
      expect(loaded.first.id, 'preset-1');
      expect(loaded.first.name, 'Primary');
      expect(loaded.first.overlayWidth, 420);
      expect(loaded.first.overlayHeight, 600);
      expect(loaded.first.linkedModelId, 'model-1');
    });
  });

  group('Prompt block migration', () {
    test('legacy blocks migrate into a single preset', () async {
      final legacyBlocks = [
        {
          'type': 'past_memory',
          'name': 'Past',
          'order': 0,
          'isEnabled': false,
        },
        {
          'type': 'user_input',
          'name': 'Input',
          'order': 1,
          'isEnabled': true,
        },
        {
          'type': 'prompt',
          'name': 'System',
          'content': 'System prompt',
          'order': 2,
          'isEnabled': true,
        },
      ];

      SharedPreferences.setMockInitialValues({
        'prompt_blocks': jsonEncode(legacyBlocks),
        'past_message_count': 7,
      });

      final provider = PromptBlockProvider();
      await provider.loadPresets();

      expect(provider.presets, hasLength(1));
      final preset = provider.presets.first;
      expect(preset.blocks, hasLength(3));
      expect(preset.blocks[0].type, PromptBlock.typePastMemory);
      expect(preset.blocks[0].range, '7');
      expect(preset.blocks[0].isActive, isFalse);
      expect(preset.blocks[1].type, PromptBlock.typeInput);
      expect(preset.blocks[2].type, PromptBlock.typePrompt);
      expect(preset.blocks[2].content, 'System prompt');
    });
  });

  group('API preset parameter migration', () {
    test('global generation params are migrated into non-Codex presets once', () async {
      final appSettings = AppSettings(
        temperature: 0.33,
        topP: 0.44,
        maxTokens: 777,
        frequencyPenalty: 0.55,
        presencePenalty: 0.66,
      );
      final apiConfigs = [
        ApiConfig.openaiDefault().copyWith(
          id: 'openai-1',
          additionalParams: {'temperature': 0.11},
        ),
        ApiConfig.codexOAuth(
          oauthAccountId: 'oauth-1',
          modelName: 'gpt-5.3-codex',
          name: 'Codex',
        ).copyWith(
          additionalParams: {
            'temperature': 1.0,
            'top_p': 0.2,
            'max_output_tokens': 999,
            'reasoning': {'effort': 'low'},
          },
        ),
      ];

      SharedPreferences.setMockInitialValues({
        'app_settings': jsonEncode(appSettings.toMap()),
        'api_configs': jsonEncode(apiConfigs.map((config) => config.toMap()).toList()),
      });

      final provider = SettingsProvider();
      await Future<void>.delayed(const Duration(milliseconds: 50));

      final openai = provider.apiConfigs.firstWhere((config) => config.id == 'openai-1');
      expect(openai.additionalParams['temperature'], 0.11);
      expect(openai.additionalParams['top_p'], 0.44);
      expect(openai.additionalParams['max_output_tokens'], 777);
      expect(openai.additionalParams['frequency_penalty'], 0.55);
      expect(openai.additionalParams['presence_penalty'], 0.66);

      final codex = provider.apiConfigs.firstWhere((config) => config.name == 'Codex');
      expect(codex.additionalParams.containsKey('temperature'), isFalse);
      expect(codex.additionalParams.containsKey('top_p'), isFalse);
      expect(codex.additionalParams.containsKey('max_output_tokens'), isFalse);
      expect(codex.additionalParams['reasoning'], {'effort': 'low'});
    });
  });
}
