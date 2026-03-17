class LuaHelpContract {
  const LuaHelpContract._();

  static const List<String> fallbackHelperCalls = [
    'pwf.gsub(text, pattern, replacement)',
    'pwf.replace(text, from, to)',
    'pwf.append(text, suffix)',
    'pwf.prepend(text, prefix)',
    'pwf.trim(text)',
    'pwf.call(functionName, payload)        -- execute immediately',
    'pwf.emit(text, functionName, payload)  -- execute immediately and keep text',
    'pwf.dispatch(text, pattern, functionName, payloadTemplate)',
    'pwf.dispatchKeep(text, pattern, functionName, payloadTemplate)',
  ];

  static const List<String> fallbackSafeSubsetRules = [
    'The supported safe subset is pwf.* helper calls plus simple return and assignment statements.',
  ];

  static const List<String> fallbackAuthoringRules = [
    'Fallback patterns use Dart RegExp semantics, not Lua pattern semantics.',
    'Prefer one helper call per line; multiline helper invocations are unsupported and nested helper forms are harder to diagnose.',
  ];

  static const List<String> fallbackWorkingExamples = [
    'return pwf.dispatchKeep(text, [[\[img_emotion:([^\]]+)\]]], "overlay.emotion", "name=\$1")',
  ];

  static const List<String> fallbackAntiExamples = [
    'text:match("#alarm")',
    'if text:match("#alarm") then return text end',
    'return "prefix:" .. text',
    'return pwf.dispatchKeep(text, [[\[img_emotion:([^\]]+)\]]], "overlay.emotion", "name=" .. text)',
    'return pwf.dispatchKeep(\n  text,\n  r"#alarm\\(([^)]*)\\)",\n  "alarm_keep",\n  "{\\"label\\":\\"\$1\\"}"\n)',
  ];

  static const List<String> fallbackLimitRules = [
    'The current fallback engine does not implement general Lua.',
    'General Lua forms such as text:match(...), if ... then ... end, and "a" .. b may not behave as expected in fallback mode.',
    'Use those forms only when native Lua availability is verifiably true at runtime.',
  ];

  static String get commandHelpFallbackSummary =>
      '• In fallback mode, helper-first scripts using `pwf.dispatch`, `pwf.dispatchKeep`, and `pwf.emit` are the safest option.\n'
      '• ${fallbackAuthoringRules[0]}\n'
      '• Working example: `${fallbackWorkingExamples[0]}`\n'
      '• Avoid examples like `${fallbackAntiExamples[0]}` and `${fallbackAntiExamples[4]}` in fallback mode.\n'
      '• ${fallbackSafeSubsetRules.first}\n'
      '• ${fallbackLimitRules.first}';

  static String get promptPreviewFallbackSection =>
      '[Fallback helpers]\n'
      '${fallbackHelperCalls.join('\n')}\n\n'
      '[Fallback authoring rules]\n'
      '- ${fallbackAuthoringRules[0]}\n'
      '- ${fallbackAuthoringRules[1]}\n\n'
      '[Fallback working example]\n'
      '- ${fallbackWorkingExamples[0]}\n\n'
      '[Fallback anti-examples]\n'
      '- ${fallbackAntiExamples[0]}\n'
      '- ${fallbackAntiExamples[1]}\n'
      '- ${fallbackAntiExamples[2]}\n'
      '- ${fallbackAntiExamples[3]}\n'
      '- ${fallbackAntiExamples[4]}\n\n'
      '[Fallback limits]\n'
      '- ${fallbackLimitRules[0]}\n'
      '- ${fallbackSafeSubsetRules[0]}\n'
      '- ${fallbackLimitRules[1]}\n'
      '- ${fallbackLimitRules[2]}';
}
