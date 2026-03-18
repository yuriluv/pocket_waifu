import 'package:flutter_test/flutter_test.dart';

import 'package:flutter_application_1/features/lua/lua_help_contract.dart';
import 'package:flutter_application_1/models/settings.dart';
import 'package:flutter_application_1/services/command_parser.dart';
import 'package:flutter_application_1/widgets/prompt_preview_dialog.dart';

void main() {
  group('Lua help contract drift protection', () {
    test('shared help contract keeps required real Lua rules', () {
      expect(LuaHelpContract.runtimeRules, hasLength(3));
      expect(LuaHelpContract.hostFunctionCalls, hasLength(10));
      expect(LuaHelpContract.authoringRules, hasLength(3));
      expect(LuaHelpContract.workingExamples, hasLength(2));
      expect(LuaHelpContract.antiExamples, hasLength(3));
      expect(LuaHelpContract.legacyCompatibilityRules, hasLength(2));

      expect(
        LuaHelpContract.runtimeRules,
        contains('The primary contract is real Lua runtime execution.'),
      );
      expect(
        LuaHelpContract.runtimeRules,
        contains(
          'Legacy compatibility mode may still run older scripts, but new scripts should target the real runtime path.',
        ),
      );
      expect(
        LuaHelpContract.runtimeRules,
        contains(
          'Use normal Lua syntax and explicit host functions instead of pseudo-Lua helper patterns for new scripts.',
        ),
      );
      expect(
        LuaHelpContract.authoringRules,
        contains('Prefer one host call per logical action and pass typed table arguments.'),
      );
      expect(
        LuaHelpContract.workingExamples,
        contains(
          'for emotion in text:gmatch("<emotion%s+name=\"([^\"]+)\"%s*/?>") do overlay.emotion({ name = emotion }) end',
        ),
      );
      expect(
        LuaHelpContract.antiExamples,
        contains(
          'pwf.dispatchKeep(text, pattern, functionName, payloadTemplate)  -- legacy compatibility only, not the primary model for new scripts',
        ),
      );
      expect(
        LuaHelpContract.legacyCompatibilityRules,
        contains(
          'Legacy helper semantics are retained only for migration and should not be used as the main authoring target for new scripts.',
        ),
      );
    });

    test('shared help contract keeps required host function list', () {
      expect(
        LuaHelpContract.hostFunctionCalls,
        contains('overlay.move({ x = 120, y = 240, op = "set", durationMs = 150 })'),
      );
      expect(
        LuaHelpContract.hostFunctionCalls,
        contains('live2d.motion({ name = "Idle/0" })'),
      );
      expect(
        LuaHelpContract.hostFunctionCalls,
        contains('live2d.reset({ durationMs = 200 })'),
      );
    });

    test('command help and prompt preview both include shared real Lua contract', () {
      final commandHelp = CommandParser.helpText;
      final promptHelp = promptPreviewLuaHelpText;

      expect(
        commandHelp,
        contains(LuaHelpContract.commandHelpFallbackSummary),
      );
      expect(commandHelp, contains(LuaHelpContract.runtimeRules[2]));
      expect(commandHelp, contains(LuaHelpContract.authoringRules.first));
      expect(commandHelp, contains(LuaHelpContract.antiExamples.first));
      expect(
        promptHelp,
        contains(LuaHelpContract.promptPreviewFallbackSection),
      );

      expect(promptHelp, contains(LuaHelpContract.runtimeRules.first));
      expect(promptHelp, contains(LuaHelpContract.runtimeRules[1]));
      expect(promptHelp, contains(LuaHelpContract.authoringRules[1]));
      expect(promptHelp, contains(LuaHelpContract.workingExamples.first));
      expect(promptHelp, contains(LuaHelpContract.workingExamples[1]));
      expect(promptHelp, contains(LuaHelpContract.antiExamples[0]));
      expect(promptHelp, contains(LuaHelpContract.antiExamples[1]));
      expect(promptHelp, contains(LuaHelpContract.antiExamples[2]));
      expect(promptHelp, contains(LuaHelpContract.legacyCompatibilityRules.first));
      expect(promptHelp, contains(LuaHelpContract.legacyCompatibilityRules[1]));
    });

    test('default shipped prompt templates keep truthful real Lua wording', () {
      final settings = AppSettings();

      expect(
        settings.live2dSystemPromptTemplate,
        contains(LuaHelpContract.runtimeRules.first),
      );
      expect(
        settings.live2dSystemPromptTemplate,
        contains(LuaHelpContract.runtimeRules[2]),
      );
      expect(
        settings.live2dSystemPromptTemplate,
        contains(LuaHelpContract.authoringRules.first),
      );
      expect(
        settings.live2dSystemPromptTemplate,
        contains(LuaHelpContract.hostFunctionCalls[3]),
      );
      expect(
        settings.live2dSystemPromptTemplate,
        contains(LuaHelpContract.hostFunctionCalls[9]),
      );
      expect(
        settings.live2dSystemPromptTemplate,
        contains(LuaHelpContract.antiExamples[2]),
      );
      expect(
        settings.live2dSystemPromptTemplate,
        contains(LuaHelpContract.legacyCompatibilityRules[1]),
      );
      expect(
        settings.live2dSystemPromptTemplate,
        isNot(contains('Fallback note:')),
      );
      expect(
        settings.live2dSystemPromptTemplate,
        isNot(contains('Prefer helper-first scripts')),
      );

      expect(
        settings.imageOverlaySystemPromptTemplate,
        contains(LuaHelpContract.runtimeRules.first),
      );
      expect(
        settings.imageOverlaySystemPromptTemplate,
        contains(LuaHelpContract.runtimeRules[2]),
      );
      expect(
        settings.imageOverlaySystemPromptTemplate,
        contains(LuaHelpContract.authoringRules.first),
      );
      expect(
        settings.imageOverlaySystemPromptTemplate,
        contains(LuaHelpContract.hostFunctionCalls.first),
      );
      expect(
        settings.imageOverlaySystemPromptTemplate,
        contains(LuaHelpContract.hostFunctionCalls[2]),
      );
      expect(
        settings.imageOverlaySystemPromptTemplate,
        contains(LuaHelpContract.antiExamples[2]),
      );
      expect(
        settings.imageOverlaySystemPromptTemplate,
        contains(LuaHelpContract.legacyCompatibilityRules[1]),
      );
      expect(
        settings.imageOverlaySystemPromptTemplate,
        isNot(contains('Fallback note:')),
      );
      expect(
        settings.imageOverlaySystemPromptTemplate,
        isNot(contains('Prefer helper-first scripts')),
      );
    });
  });
}
