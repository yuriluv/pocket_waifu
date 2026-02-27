# Newcastle Proactive Condition Parser and Priority Spec (2026-02-27)

## Purpose

Define implementation-ready requirements for:

- Proactive TXT condition parser (grammar + validation)
- Condition priority resolution (`screenoff` always highest)
- Timer reset/cancel behavior
- User-facing error handling for malformed lines

This document operationalizes the proactive sections in `docs/Newcastle.md` and closes ambiguity before coding.

## Scope

In scope:

- Parsing and validating condition text entered in the Proactive Response popup
- Choosing one active proactive condition when multiple environment states are true
- Timer lifecycle rules across success, failure, cancellation, and feature toggle changes
- Error message contract (line-specific feedback)

Out of scope:

- UI visual design details of popup components
- Notification channel creation details
- API model selection and prompt preset persistence details

## Condition Definitions

Supported conditions:

1. `overlayon`
2. `overlayoff`
3. `screenlandscape`
4. `screenoff`

`screenoff` always overrides other active conditions.

## TXT Grammar and Parsing Rules

### Grammar

Each non-empty line must match one of:

- `<condition>=0`
- `<condition>=<durationMin>~<durationMax>`

Formal grammar:

```
LINE        := CONDITION '=' VALUE
CONDITION   := 'overlayon' | 'overlayoff' | 'screenlandscape' | 'screenoff'
VALUE       := '0' | DURATION '~' DURATION
DURATION    := TIMEPART+
TIMEPART    := [0-9]+ UNIT
UNIT        := 'h' | 'm' | 's'
```

### Normalization

- Newlines: support both LF and CRLF
- Leading/trailing whitespace around each line: trimmed before validation
- Internal spaces in a line: not allowed (for example `overlayon = 3m~5m` is invalid)
- Empty lines: ignored

### Duration Semantics

- Convert each `DURATION` to total seconds
- Unit `d` is invalid
- `durationMinSeconds` must be `> 10`
- `durationMaxSeconds` must be `>= durationMinSeconds`
- `0` means disabled condition and no timer is scheduled for that condition

### Duplicate Condition Policy

Duplicate condition keys in the same TXT payload are invalid and block save.

Rationale: avoids hidden override behavior and keeps user intent explicit.

## Validation Contract

Validation runs for all lines before save. If any error exists, save fails atomically.

Error payload contract:

- `lineNumber` (1-based)
- `lineText`
- `code`
- `message`

Standard error codes:

- `unknown_condition`
- `missing_equal`
- `invalid_value`
- `invalid_duration_format`
- `unsupported_unit`
- `min_interval_too_short`
- `max_less_than_min`
- `duplicate_condition`

UI behavior:

- Show popup error with first invalid line immediately
- Keep editor content unchanged
- Do not persist partial configuration

## Parsed Model Contract

Parser output (conceptual):

- `Map<ConditionType, ConditionSchedule>`
- `ConditionSchedule.disabled` or `ConditionSchedule.range(minSec, maxSec)`

Persistence format is implementation-defined but must preserve disabled vs range explicitly.

## Environment-to-Condition Activation

At runtime, active condition candidates are derived from environment snapshot:

- `overlayon`: overlay visible and screen on
- `overlayoff`: overlay not visible and screen on
- `screenlandscape`: screen on and orientation is landscape
- `screenoff`: screen off

Only configured and enabled conditions can be selected.

## Priority Resolution Engine

Priority order from low to high:

1. `overlayon`
2. `overlayoff`
3. `screenlandscape`
4. `screenoff`

Resolution algorithm:

1. Build active candidate list from environment snapshot.
2. Remove candidates that are disabled or not configured.
3. If `screenoff` is present, select `screenoff` immediately.
4. Otherwise select highest priority candidate by fixed order above.
5. If no candidate exists, proactive timer is unscheduled.

Note: This fixed priority supersedes text line position and is authoritative.

## Timer Lifecycle Rules

### Core Behavior

- On timer arm, sample random delay in `[minSec, maxSec]` (inclusive).
- On proactive API success: reset timer (sample new delay).
- On proactive API failure (including offline): reset timer (sample new delay).

### Cancellation and Continuation Rules

- User reply while proactive API call is in progress:
  - cancel in-flight proactive request immediately
  - do not reset timer
  - continue from remaining timer duration
- Global proactive toggle OFF:
  - cancel in-flight proactive request
  - cancel timer
  - clear pending proactive notifications
- Global proactive toggle ON:
  - resolve active condition
  - arm new timer if a valid condition exists

### Environment Change Rules

If selected condition changes due to environment transition (for example screen on -> screen off):

- cancel current timer
- resolve new active condition by priority
- arm fresh timer for the new condition

Rationale: condition-specific intervals should apply immediately when context changes.

## Runtime State Machine (Reference)

States:

- `idle` (no active timer)
- `armed` (countdown running)
- `firing` (API request in flight)
- `disabled` (global toggle off)

Key transitions:

- `disabled -> armed` on toggle ON with valid active condition
- `armed -> firing` on timeout reached
- `firing -> armed` on success/failure (reset)
- `firing -> armed` on user-reply cancellation (continue remaining)
- `any -> disabled` on toggle OFF

## Acceptance Criteria

1. Any malformed line shows exact failing line number and save is rejected.
2. Any minimum duration `<= 10s` is rejected with clear error.
3. `screenoff` wins whenever screen is off and configured.
4. User reply during proactive in-flight request cancels request without timer reset.
5. Success and failure both reset proactive timer.
6. No partial-save state is possible when at least one line is invalid.

## QA Scenario Matrix (Minimum)

1. Valid config with all four conditions -> parse success.
2. Unknown key (`overlay_on`) -> line error.
3. Format error (`overlayon3m~5m`) -> line error.
4. Unsupported unit (`1d`) -> line error.
5. `overlayon=10s~20s` -> rejected (`min_interval_too_short`).
6. Duplicate `overlayon` line -> rejected (`duplicate_condition`).
7. Overlap case (`screenoff` + others true) -> `screenoff` selected.
8. In-flight proactive call canceled by user reply -> no timer reset.
9. API failure/offline -> error notification and timer reset.

## Implementation Notes for Dev Handoff

- Keep parser and validator pure and deterministic (no IO side effects).
- Return typed failures rather than throwing for expected validation errors.
- Keep timer orchestration single-owner (one scheduler component) to prevent dual timers.
- Ensure cancellation token/source is shared between proactive firing flow and notification reply flow.
