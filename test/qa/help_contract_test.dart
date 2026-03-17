import 'package:flutter_test/flutter_test.dart';

import 'package:flutter_application_1/features/lua/lua_help_contract.dart';
import 'package:flutter_application_1/models/settings.dart';
import 'package:flutter_application_1/services/command_parser.dart';
import 'package:flutter_application_1/widgets/prompt_preview_dialog.dart';

void main() {
  group('Lua help contract drift protection', () {
    test('shared help contract keeps required fallback rules', () {
      expect(LuaHelpContract.fallbackSafeSubsetRules, isNotEmpty);
      expect(LuaHelpContract.fallbackLimitRules, hasLength(3));
      expect(LuaHelpContract.fallbackAuthoringRules, hasLength(2));
      expect(LuaHelpContract.fallbackHelperCalls, hasLength(9));
      expect(LuaHelpContract.fallbackWorkingExamples, hasLength(1));
      expect(LuaHelpContract.fallbackAntiExamples, hasLength(5));

      expect(
        LuaHelpContract.fallbackSafeSubsetRules.single,
        'The supported safe subset is pwf.* helper calls plus simple return and assignment statements.',
      );
      expect(
        LuaHelpContract.fallbackLimitRules,
        contains('The current fallback engine does not implement general Lua.'),
      );
      expect(
        LuaHelpContract.fallbackLimitRules,
        contains(
          'General Lua forms such as text:match(...), if ... then ... end, and "a" .. b may not behave as expected in fallback mode.',
        ),
      );
      expect(
        LuaHelpContract.fallbackLimitRules,
        contains('Use those forms only when native Lua availability is verifiably true at runtime.'),
      );
      expect(
        LuaHelpContract.fallbackAuthoringRules,
        contains('Fallback patterns use Dart RegExp semantics, not Lua pattern semantics.'),
      );
      expect(
        LuaHelpContract.fallbackWorkingExamples.single,
        'return pwf.dispatchKeep(text, [[\[img_emotion:([^\]]+)\]]], "overlay.emotion", "name=\$1")',
      );
      expect(
        LuaHelpContract.fallbackAntiExamples,
        contains('text:match("#alarm")'),
      );
      expect(
        LuaHelpContract.fallbackAntiExamples,
        contains('if text:match("#alarm") then return text end'),
      );
      expect(
        LuaHelpContract.fallbackAntiExamples,
        contains('return "prefix:" .. text'),
      );
      expect(
        LuaHelpContract.fallbackAntiExamples,
        contains(
          'return pwf.dispatchKeep(text, [[\[img_emotion:([^\]]+)\]]], "overlay.emotion", "name=" .. text)',
        ),
      );
    });

    test('shared help contract keeps required helper list', () {
      expect(
        LuaHelpContract.fallbackHelperCalls,
        contains('pwf.dispatch(text, pattern, functionName, payloadTemplate)'),
      );
      expect(
        LuaHelpContract.fallbackHelperCalls,
        contains(
          'pwf.dispatchKeep(text, pattern, functionName, payloadTemplate)',
        ),
      );
      expect(
        LuaHelpContract.fallbackHelperCalls,
        contains('pwf.emit(text, functionName, payload)  -- execute immediately and keep text'),
      );
    });

    test('command help and prompt preview both include shared fallback contract', () {
      final commandHelp = CommandParser.helpText;
      final promptHelp = promptPreviewLuaHelpText;

      expect(
        commandHelp,
        contains(LuaHelpContract.commandHelpFallbackSummary),
      );
      expect(commandHelp, contains(LuaHelpContract.fallbackAuthoringRules.first));
      expect(commandHelp, contains(LuaHelpContract.fallbackWorkingExamples.single));
      expect(commandHelp, contains(LuaHelpContract.fallbackAntiExamples.first));
      expect(
        promptHelp,
        contains(LuaHelpContract.promptPreviewFallbackSection),
      );

      expect(commandHelp, contains(LuaHelpContract.fallbackSafeSubsetRules.single));
      expect(promptHelp, contains(LuaHelpContract.fallbackSafeSubsetRules.single));
      expect(commandHelp, contains(LuaHelpContract.fallbackLimitRules.first));
      expect(promptHelp, contains(LuaHelpContract.fallbackLimitRules.first));
      expect(promptHelp, contains(LuaHelpContract.fallbackAuthoringRules.first));
      expect(promptHelp, contains(LuaHelpContract.fallbackWorkingExamples.single));
      expect(promptHelp, contains(LuaHelpContract.fallbackAntiExamples[0]));
      expect(promptHelp, contains(LuaHelpContract.fallbackAntiExamples[1]));
      expect(promptHelp, contains(LuaHelpContract.fallbackAntiExamples[2]));
      expect(promptHelp, contains(LuaHelpContract.fallbackAntiExamples[3]));
      expect(promptHelp, contains(LuaHelpContract.fallbackAntiExamples[4]));
    });

    test('default shipped prompt templates keep truthful fallback wording', () {
      const settings = AppSettings();

      expect(
        settings.live2dSystemPromptTemplate,
        contains(LuaHelpContract.fallbackLimitRules.first),
      );
      expect(
        settings.live2dSystemPromptTemplate,
        contains(LuaHelpContract.fallbackAuthoringRules.first),
      );
      expect(
        settings.live2dSystemPromptTemplate,
        contains(LuaHelpContract.fallbackHelperCalls[7]),
      );
      expect(
        settings.live2dSystemPromptTemplate,
        contains(LuaHelpContract.fallbackHelperCalls[8]),
      );

      expect(
        settings.imageOverlaySystemPromptTemplate,
        contains(LuaHelpContract.fallbackLimitRules.first),
      );
      expect(
        settings.imageOverlaySystemPromptTemplate,
        contains(LuaHelpContract.fallbackAuthoringRules.first),
      );
    });
  });
}
