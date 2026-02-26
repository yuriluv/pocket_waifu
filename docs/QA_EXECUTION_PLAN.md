# QA Execution Plan - Korean Comment Policy and Regression Gates

## Scope

- Add an automated policy gate that detects Korean text in comments and string literals.
- Enforce **zero Korean comments** as a hard gate.
- Add a whitelist mechanism for approved paths/literals.
- Add regression contracts for core user-facing behaviors affected by modular refactors.

## Subtasks (Quality Team)

1. Implement a static policy checker:
   - Rule A: detect Hangul in comment lines and block comments.
   - Rule B: detect Hangul in string literal lines (report by default, hard-fail in strict mode).
   - Inputs: repository source files.
   - Output: violation report with file/line and category.
2. Add whitelist support:
   - Path regex list.
   - Literal regex list.
   - Keep defaults minimal and auditable.
3. Add regression/contract tests:
   - Command parser behavior contracts.
   - Prompt builder output/ordering contracts.
   - Core model serialization contracts.
4. Define QA evidence checkpoints for PR validation:
   - Korean comments report = 0.
   - Lint/type/build/test commands pass.
   - Regression suite passes before and after refactor.

## Commands (CI/Local)

```bash
dart run tool/qa/check_korean_policy.dart
dart run tool/qa/check_korean_policy.dart --strict-strings
flutter analyze
flutter test test/qa
flutter test
```

## Checkpoint Policy

- **Required for merge**
  - `dart run tool/qa/check_korean_policy.dart`
  - `flutter analyze`
  - `flutter test test/qa`
- **Recommended hardening**
  - `dart run tool/qa/check_korean_policy.dart --strict-strings`
  - `flutter test`

## Notes

- The checker is heuristic-based for multi-language source trees and should be tuned through whitelist updates when legitimate localized text is introduced.
- The regression suite is intentionally focused on stable contracts rather than UI snapshots to reduce flakiness.
