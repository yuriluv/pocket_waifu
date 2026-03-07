# Regex Feature

## Overview
`regex` contains configurable rule pipelines that transform user input, assistant output,
and display-only text.

## Main Structure
- **Rule model**: `lib/features/regex/models/regex_rule.dart`
- **Pipeline service**: `lib/features/regex/services/regex_pipeline_service.dart`

## Cross-Feature Links
- **Chat provider**: applies user/assistant transformations.
- **Notification coordinator**: applies transformations in notification-driven flows.
- **Lua pipeline**: output depends on whether regex runs before or after Lua hooks.

## Known Risks
- Incorrect regex rules can unintentionally strip or mutate critical content.
- Rule ordering and priority directly affect deterministic behavior.
- Divergence between chat and notification paths can create inconsistent outputs.

## Change Checklist
1. Verify rule priority/order behavior after modifications.
2. Test user input, assistant output, and display-only pipelines.
3. Confirm parity between chat and notification orchestration paths.
