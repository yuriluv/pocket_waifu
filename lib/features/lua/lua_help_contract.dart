class LuaHelpContract {
  const LuaHelpContract._();

  static const List<String> runtimeRules = [
    'The primary contract is real Lua runtime execution.',
    'Legacy compatibility mode may still run older scripts, but new scripts should target the real runtime path.',
    'Use normal Lua syntax and explicit host functions instead of pseudo-Lua helper patterns for new scripts.',
  ];

  static const List<String> hostFunctionCalls = [
    'overlay.move({ x = 120, y = 240, op = "set", durationMs = 150 })',
    'overlay.emotion({ name = "Reilla_happy" })',
    'overlay.wait({ ms = 300 })',
    'live2d.param({ id = "ParamAngleX", value = 15, op = "set", durationMs = 200 })',
    'live2d.motion({ name = "Idle/0" })',
    'live2d.expression({ name = "smile" })',
    'live2d.emotion({ name = "happy" })',
    'live2d.wait({ ms = 300 })',
    'live2d.preset({ name = "idle", durationMs = 200 })',
    'live2d.reset({ durationMs = 200 })',
  ];

  static const List<String> authoringRules = [
    'Prefer one host call per logical action and pass typed table arguments.',
    'Use standard Lua string functions such as string.gmatch and string.gsub when parsing text.',
    'Treat host functions as the boundary for side effects; keep parsing logic in Lua and runtime effects in host calls.',
  ];

  static const List<String> workingExamples = [
    'for emotion in text:gmatch("<emotion%s+name=\"([^\"]+)\"%s*/?>") do overlay.emotion({ name = emotion }) end',
    'text = text:gsub("<move%s+x=\"([^\"]+)\"%s+y=\"([^\"]+)\"%s*/?>", function(x, y) overlay.move({ x = tonumber(x), y = tonumber(y) }) return "" end)',
  ];

  static const List<String> antiExamples = [
    'pwf.dispatchKeep(text, pattern, functionName, payloadTemplate)  -- legacy compatibility only, not the primary model for new scripts',
    'pwf.emit(text, functionName, payload)  -- legacy compatibility only',
    '<emotion name="happy"/> should not rely on hidden system parsing; your Lua should parse it and call overlay.emotion(...) or live2d.emotion(...) explicitly',
  ];

  static const List<String> legacyCompatibilityRules = [
    'Older scripts may still run in legacy compatibility mode.',
    'Legacy helper semantics are retained only for migration and should not be used as the main authoring target for new scripts.',
  ];

  static String get commandHelpFallbackSummary =>
      '• ${runtimeRules[0]}\n'
      '• ${runtimeRules[1]}\n'
      '• Working example: `${workingExamples[0]}`\n'
      '• Host functions: `${hostFunctionCalls[0]}`, `${hostFunctionCalls[1]}`, `${hostFunctionCalls[4]}`\n'
      '• ${legacyCompatibilityRules[1]}';

  static String get promptPreviewFallbackSection =>
      '[Real Lua runtime]\n'
      '- ${runtimeRules[0]}\n'
      '- ${runtimeRules[1]}\n'
      '- ${runtimeRules[2]}\n\n'
      '[Host functions]\n'
      '${hostFunctionCalls.join('\n')}\n\n'
      '[Authoring rules]\n'
      '- ${authoringRules[0]}\n'
      '- ${authoringRules[1]}\n'
      '- ${authoringRules[2]}\n\n'
      '[Working examples]\n'
      '- ${workingExamples[0]}\n'
      '- ${workingExamples[1]}\n\n'
      '[Legacy compatibility]\n'
      '- ${legacyCompatibilityRules[0]}\n'
      '- ${legacyCompatibilityRules[1]}\n\n'
      '[Anti-examples]\n'
      '- ${antiExamples[0]}\n'
      '- ${antiExamples[1]}\n'
      '- ${antiExamples[2]}';
}
