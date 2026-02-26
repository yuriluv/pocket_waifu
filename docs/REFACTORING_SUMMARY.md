# Refactoring Summary

## Scope
- Removed Korean developer comments in source-level files (`lib/**`, `test/**`, `pubspec.yaml`) while keeping user-facing Korean strings unchanged.
- Refactored `ChatProvider` to reduce duplicated branching and tighten session-bound behavior.

## Structure Before
- `ChatProvider.sendMessage` mixed validation, session resolution, persistence, API request formatting, and state transitions in one flow.
- Session resolution logic was duplicated across most mutating methods.
- Regeneration logic used ad-hoc inline traversal logic.

## Structure After
- `ChatProvider` now separates concerns through focused internal helpers:
  - `_resolveSessionId(...)`
  - `_requestAssistantResponse(...)`
  - `_findLastUserMessage(...)`
  - `_createMessage(...)`
  - `_setLoading(...)`, `_setError(...)`
- Message creation path is normalized, and request flow is easier to follow/review.
- Session-capture behavior is preserved while reducing repeated code paths.

## Responsibility Split
- `ChatProvider`: request lifecycle + UI state (`isLoading`, `errorMessage`).
- `ChatSessionProvider`: message/session storage and mutation.
- `ApiService`: external API communication.
- `PromptBuilder`: model input composition.
