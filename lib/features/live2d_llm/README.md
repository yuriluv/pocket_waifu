# Live2D LLM Integration

## Overview
`live2d_llm` maps assistant output directives to Live2D actions (emotion/motion/parameters)
and provides queueing/processing utilities for safe runtime application.

## Main Structure
- **Directive service**: `lib/features/live2d_llm/services/live2d_directive_service.dart`
- **Command queue**: `lib/features/live2d_llm/services/live2d_command_queue.dart`
- **Models**: `lib/features/live2d_llm/models/*`

## Cross-Feature Links
- **Notification coordinator**: consumes directives from assistant output pipeline.
- **Lua/Regex transforms**: directive text may be transformed before parsing.
- **Live2D core feature**: actions are applied through live2d runtime/bridge services.

## Known Risks
- Directive parsing order matters; changing pipeline order can break behavior.
- Command bursts can cause queue/backpressure issues in complex outputs.
- Emotion/motion naming contracts must match model capabilities.

## Change Checklist
1. Validate directive parsing toggle behavior.
2. Re-test emotion/motion parameter application with representative responses.
3. Check queue behavior under rapid consecutive directives.
