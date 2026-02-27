

## Part 1: Major Feature Development

> **General Directive:** The original instructions are intentionally high-level. All engineers and contributors are expected to independently review, interpret, and concretize every aspect of the requirements from multiple perspectives. The primary objective is to maximize completeness and quality through thorough planning before implementation.

---

### 1.1 Live2D Feature Improvements

#### 1.1.1 Current State Assessment

Currently, the Live2D subsystem supports only **overlay rendering** and **background transparency** in a stable, error-free manner. All other functionalities require significant improvement or complete reimplementation.

---

#### 1.1.2 Live2D Display Edit Mode

**Objective:** Provide a fully functional edit mode in which users can manipulate, configure, and persist all display-related properties of a Live2D model, and reliably link those configurations to specific models.

**Known Issues:**
- Saved configuration data is not properly persisted or is lost upon reload.
- Model linking (associating a saved configuration with a specific Live2D model) is unstable and frequently breaks.
- The core problem lies in correctly saving and restoring the **relationship between the transparent bounding container and the character model**, including relative size, absolute size, and position.

**Detailed Requirements:**

| # | Requirement | Description |
|---|-------------|-------------|
| 1 | **Container–Model Relative Sizing** | The system must correctly calculate and persist the ratio between the transparent bounding box (container) and the Live2D character model. When the configuration is reloaded, the character must appear at the same relative scale within the container, regardless of screen resolution or density changes. |
| 2 | **Absolute Size Persistence** | The absolute dimensions (width and height in density-independent pixels or a normalized coordinate system) of both the container and the model must be saved and accurately restored. |
| 3 | **Position Persistence** | The absolute position (x, y coordinates) of the container on the screen and the model's offset within the container must be saved. The coordinate system used (e.g., screen-relative, parent-relative) must be explicitly defined and consistently applied. |
| 4 | **Model Linking** | Each saved display configuration must be uniquely and reliably associated with a specific Live2D model file (identified by a stable key such as file path, hash, or a user-defined model ID). When a linked model is loaded, its corresponding configuration must be automatically applied. |
| 5 | **Edit Mode UI** | The edit mode must provide intuitive controls for: (a) pinch-to-zoom / scaling the model, (b) drag-to-reposition the model within the container, (c) resizing the container itself, (d) a "Save" action that persists all current values, (e) a "Reset to Default" action, and (f) a visual indicator that edit mode is active. |
| 6 | **Data Storage Format** | All configuration data must be stored in a structured, versioned format (e.g., JSON) within the app's local storage. The schema must include: `modelId`, `containerWidth`, `containerHeight`, `containerX`, `containerY`, `modelScaleX`, `modelScaleY`, `modelOffsetX`, `modelOffsetY`, `relativeScaleRatio`, and `schemaVersion`. |
| 7 | **Migration & Validation** | On load, the system must validate saved data against the current schema version and perform migrations if necessary. Corrupted or incompatible data must be handled gracefully (fallback to defaults with a user notification). |

**Acceptance Criteria:**
- A user can enter edit mode, adjust all display parameters, save, exit the app entirely, relaunch, and observe the exact same display configuration restored.
- Linking a configuration to Model A does not affect Model B.
- Switching between multiple linked models correctly applies each model's saved configuration.
- Configurations remain valid across screen rotation and different device screen sizes (using normalized coordinates).

---

#### 1.1.3 Live2D Advanced Settings

**Objective:** Ensure that automatic motion playback and parameter manipulation function correctly, including robust handling of edge cases.

**Known Issues:**
- Automatic motion triggering and parameter adjustment appear to malfunction or have no visible effect.
- Some Live2D model files may not define any motions at all, and the current implementation does not handle this case.

**Detailed Requirements:**

| # | Requirement | Description |
|---|-------------|-------------|
| 1 | **Motion Inventory Detection** | On model load, the system must parse the model's `.model3.json` (or equivalent) file and enumerate all available motion groups and individual motions. The result must be cached for performance. |
| 2 | **No-Motion Fallback** | If a model defines zero motions, the system must: (a) not crash or throw unhandled exceptions, (b) disable or hide motion-related UI controls, (c) optionally display a notice to the user ("This model does not include predefined motions"), and (d) still allow direct parameter manipulation (see below). |
| 3 | **Automatic Motion Playback** | When motions are available, the system must support: (a) idle motion looping (configurable on/off), (b) triggered motions by name or group (for integration with LLM responses, see Section 1.3), and (c) motion priority levels (idle < normal < forced) to prevent conflicts. |
| 4 | **Parameter Direct Control** | The system must expose an API (and optionally a debug/settings UI) to directly get and set any Live2D model parameter by its ID (e.g., `ParamAngleX`, `ParamEyeLOpen`). Changes must be reflected in real-time on the rendered model. |
| 5 | **Parameter Smoothing** | When parameters are set programmatically (e.g., by the LLM), transitions should be smoothed over a configurable duration (default: 200ms) to avoid jarring visual jumps. |
| 6 | **Settings Persistence** | All advanced settings (idle motion enabled/disabled, motion priority configuration, parameter smoothing duration, etc.) must be persisted per model and restored on next load. |
| 7 | **Expression Support** | If the model defines expressions (`.exp3.json`), these must also be enumerable, triggerable, and handled with the same robustness as motions (including a no-expression fallback). |

**Acceptance Criteria:**
- A model with motions correctly plays idle motions automatically when enabled.
- A model without motions loads and renders without errors; motion-related controls are appropriately disabled.
- Parameters can be set via the internal API and the model visually responds in real-time with smooth transitions.
- All settings persist across app sessions.

---

### 1.2 Lua Scripting Engine and Regex Processing Pipeline

#### 1.2.1 Objectives

1. **Primary Objective 1:** Enable rich, programmable interaction between the Live2D rendering subsystem and the LLM (Large Language Model) backend through a Lua scripting interface.
2. **Primary Objective 2:** Enable CSS-based styling with asset embedding within the main chat session view, allowing for visually rich and customizable message rendering.

> **Implementation Directive:** Focus implementation effort on features that directly serve Objectives 1 and 2. Extraneous capabilities should be deferred.

#### 1.2.2 Reference

- Lua scripting reference architecture: [https://kwaroran.github.io/docs/srp/lua/](https://kwaroran.github.io/docs/srp/lua/)
- The implementation should adapt the concepts from the above reference to the Android/Kotlin (or Java) environment, using an embeddable Lua interpreter (e.g., LuaJ, or a native Lua via JNI).

---

#### 1.2.3 Lua Scripting Engine — Detailed Requirements

| # | Requirement | Description |
|---|-------------|-------------|
| 1 | **Embedded Lua Runtime** | Integrate a Lua 5.3+ compatible interpreter into the Android application. The runtime must be sandboxed to prevent access to the device filesystem, network, or other sensitive APIs unless explicitly exposed. |
| 2 | **Script Lifecycle** | Lua scripts must support lifecycle hooks: `onLoad()` (when the script is first loaded), `onUserMessage(text)` (before user message is sent), `onAssistantMessage(text)` (after AI response is received), `onPromptBuild(promptData)` (before final prompt is sent to LLM), `onDisplayRender(text)` (before text is displayed on screen), and `onUnload()` (when script is deactivated). |
| 3 | **Live2D Bridge API** | Expose the following Lua-callable functions for Live2D control: `live2d.setParameter(paramId, value, duration)`, `live2d.getParameter(paramId)`, `live2d.playMotion(group, index, priority)`, `live2d.setExpression(expressionId)`, `live2d.getModelInfo()` (returns available parameters, motions, expressions). |
| 4 | **Chat Context API** | Expose: `chat.getHistory(n)` (retrieve last n messages), `chat.getCurrentMessage()`, `chat.setCurrentMessage(text)`, `chat.getCharacterName()`, `chat.getUserName()`. |
| 5 | **CSS/Asset Injection API** | Expose: `ui.injectCSS(cssString)`, `ui.loadAsset(assetPath)` (returns a usable reference for embedding in HTML/CSS within the chat view), `ui.setMessageHTML(html)` (render a message using custom HTML+CSS). |
| 6 | **Script Management UI** | Provide a user-facing interface to: (a) import Lua scripts from local storage, (b) enable/disable individual scripts, (c) set script execution order (priority), (d) view script logs/errors, and (e) associate scripts with specific characters or globally. |
| 7 | **Error Handling** | Lua runtime errors must be caught and displayed in a non-intrusive log viewer. Errors must never crash the host application. A timeout mechanism (configurable, default: 5 seconds) must kill runaway scripts. |
| 8 | **Security Sandbox** | The Lua environment must whitelist only approved modules and functions. File I/O, OS commands, network access, and debug library must be blocked by default. |

---

#### 1.2.4 Regex Processing Pipeline — Detailed Requirements

**Overview:** A configurable regex (regular expression) text transformation pipeline that processes text at specific stages of the message lifecycle. Each regex rule has an **In** (input text source), an **Out** (output/replacement text), and a **Type** that determines when the rule is applied.

**Regex Rule Types:**

| Type ID | Type Name | Description |
|---------|-----------|-------------|
| 1 | **User Input Modification** | Modifies the text entered by the user **before** it is transmitted to the LLM server. The original text in the chat log is replaced with the modified version. Use cases: automatic formatting, keyword expansion, shortcut commands. |
| 2 | **AI Output Modification** | Modifies the response text generated by the AI **after** generation but **before** it is rendered on screen and saved to the chat log. The modified version becomes the canonical stored version. Use cases: censorship, formatting cleanup, tag stripping. |
| 3 | **Prompt Injection Modification** | Modifies the **final assembled prompt** that is sent to the LLM. This does **not** alter the chat log or any displayed messages — it only affects what the LLM receives. Use cases: injecting system instructions, modifying context framing, adding hidden instructions. |
| 4 | **Display-Only Modification** | Modifies the text **only for display purposes** on the chat screen. The underlying stored data remains unchanged. Use cases: rendering markdown, hiding metadata tags, visual formatting, custom CSS class injection. |

**Regex Rule Data Model:**

```
RegexRule {
    id: UUID
    name: String                    // Human-readable name
    description: String             // Optional description
    type: RuleType                  // One of: USER_INPUT, AI_OUTPUT, PROMPT_INJECTION, DISPLAY_ONLY
    pattern: String                 // Regex pattern (Java/Kotlin compatible)
    replacement: String             // Replacement string (supports group references: $1, $2, etc.)
    flags: Set<RegexFlag>           // e.g., CASE_INSENSITIVE, MULTILINE, DOT_ALL
    isEnabled: Boolean              // Toggle on/off without deleting
    priority: Int                   // Execution order (lower = earlier)
    scope: Scope                    // GLOBAL, PER_CHARACTER, PER_SESSION
    associatedCharacterId: String?  // If scope is PER_CHARACTER
}
```

**Detailed Requirements:**

| # | Requirement | Description |
|---|-------------|-------------|
| 1 | **Rule CRUD** | Users must be able to create, read, update, and delete regex rules through a dedicated settings UI. |
| 2 | **Rule Testing** | Provide an inline test feature where a user can input sample text and see the regex transformation result in real-time before saving. |
| 3 | **Ordered Execution** | Multiple rules of the same type must execute in priority order. The output of one rule becomes the input of the next. |
| 4 | **Scope Control** | Rules can be global (apply to all sessions), per-character (apply only when a specific character is active), or per-session. |
| 5 | **Import/Export** | Rules must be exportable as JSON and importable, to allow sharing between users or devices. |
| 6 | **Interaction with Lua** | Lua scripts and regex rules operate in a defined order: regex rules of a given type execute first, then Lua hooks of the corresponding lifecycle stage execute. This order must be configurable. |
| 7 | **Performance** | Regex compilation must be cached. Patterns must be pre-compiled on rule save and reused. Rules that cause catastrophic backtracking must be detected and terminated with a timeout. |

---

### 1.3 Live2D–LLM Interaction Architecture

#### 1.3.1 Objective

Design and implement a system whereby the LLM can effectively control Live2D model parameters, motions, and expressions in real-time as part of its responses, leveraging the Lua scripting engine and regex pipeline established in Section 1.2.

#### 1.3.2 Interaction Architecture Design

**Approach: Structured Inline Directives with Lua Interpretation**

The chosen architecture uses a **directive tag system** embedded within LLM responses. The LLM is instructed (via system prompt) to include structured tags in its output that encode Live2D commands. A Lua script (or regex + Lua combination) parses these tags and translates them into Live2D API calls.

**Workflow:**

```
┌─────────────────────────────────────────────────────────┐
│                    LLM Response                         │
│                                                         │
│  "Hello! *smiles warmly*                                │
│   <live2d>                                              │
│     <param id="ParamMouthOpenY" value="0.8" dur="300"/> │
│     <param id="ParamEyeLSmile" value="1.0" dur="500"/>  │
│     <motion group="Greeting" index="0"/>                │
│     <expression id="happy"/>                            │
│   </live2d>                                             │
│   How are you today?"                                   │
└──────────────────────┬──────────────────────────────────┘
                       │
                       ▼
┌──────────────────────────────────────────────────────────┐
│          Regex Pipeline (Type 2: AI Output)              │
│  • Extract <live2d>...</live2d> block                    │
│  • Pass extracted block to Lua engine                    │
│  • Remove <live2d> block from displayed text             │
└──────────────────────┬───────────────────────────────────┘
                       │
              ┌────────┴────────┐
              ▼                 ▼
┌──────────────────┐  ┌─────────────────────────┐
│  Clean Display   │  │   Lua Script Engine     │
│  Text:           │  │                         │
│  "Hello! *smiles │  │  Parse <live2d> XML     │
│   warmly*        │  │  Call live2d.setParam()  │
│   How are you    │  │  Call live2d.playMotion()│
│   today?"        │  │  Call live2d.setExpr()   │
│                  │  │                         │
└──────────────────┘  └─────────────────────────┘
```

#### 1.3.3 Detailed Requirements

| # | Requirement | Description |
|---|-------------|-------------|
| 1 | **Directive Tag Format** | Define a standard XML-like tag format (`<live2d>...</live2d>`) for embedding Live2D commands in LLM responses. The format must support: `<param>` (parameter setting), `<motion>` (motion triggering), and `<expression>` (expression setting) sub-elements. |
| 2 | **System Prompt Template** | Provide a configurable system prompt template that instructs the LLM on how and when to use `<live2d>` tags. The template must include: (a) the tag format specification, (b) a list of available parameters, motions, and expressions for the currently loaded model (dynamically generated), and (c) usage guidelines (e.g., "Use <live2d> tags to express emotions and actions"). |
| 3 | **Dynamic Model Capability Injection** | When building the system prompt, automatically query the loaded Live2D model's capabilities (available parameters, motions, expressions) and inject them into the prompt so the LLM knows what controls are available. |
| 4 | **Parsing Lua Script (Default)** | Ship a default Lua script that: (a) intercepts AI responses in the `onAssistantMessage` hook, (b) parses `<live2d>` blocks using pattern matching, (c) calls the appropriate Live2D Bridge API functions, and (d) returns the cleaned text (with `<live2d>` blocks removed) for display. |
| 5 | **Sequential Command Execution** | Multiple `<param>`, `<motion>`, and `<expression>` directives within a single `<live2d>` block must be executable in sequence with optional delays between them (specified via a `delay` attribute in milliseconds). |
| 6 | **Emotion Preset Mapping** | Provide a configurable mapping from high-level emotion keywords (e.g., `happy`, `sad`, `angry`, `surprised`) to sets of parameter values. The LLM can use `<emotion name="happy"/>` as a shorthand instead of specifying individual parameters. Users can customize these presets per model. |
| 7 | **Fallback & Error Tolerance** | If the LLM produces malformed `<live2d>` tags, the parser must: (a) skip invalid directives without crashing, (b) log the error for debugging, and (c) still display the text portion of the response normally. If a referenced parameter, motion, or expression does not exist on the current model, the directive must be silently ignored with a log entry. |
| 8 | **Streaming Response Support** | If the LLM response is streamed (token by token), the parser must buffer and detect `<live2d>` blocks correctly, executing commands only when a complete block is received. Partial tags must not be displayed to the user. |
| 9 | **Bidirectional Interaction (Advanced)** | Optionally support the reverse direction: Live2D events (e.g., user tapping the model, a motion completing) can inject context into the next LLM prompt via Lua scripts. For example, `live2d.onTap(region)` could trigger a Lua callback that appends "[User poked the character's head]" to the next user message. |
| 10 | **User Control & Privacy** | All Live2D–LLM interaction features must be toggle-able by the user. Users must be able to: (a) disable Live2D directive parsing entirely, (b) disable system prompt injection of model capabilities, (c) view and edit the system prompt template. |

#### 1.3.4 Emotion Preset Schema (Example)

```json
{
  "presets": {
    "happy": {
      "params": {
        "ParamEyeLSmile": 1.0,
        "ParamEyeRSmile": 1.0,
        "ParamMouthForm": 1.0,
        "ParamBrowLY": 0.3,
        "ParamBrowRY": 0.3
      },
      "expression": "f01",
      "motion": { "group": "Idle", "index": 1 },
      "transitionDuration": 500
    },
    "sad": {
      "params": {
        "ParamEyeLOpen": 0.6,
        "ParamEyeROpen": 0.6,
        "ParamMouthForm": -0.5,
        "ParamBrowLY": -0.5,
        "ParamBrowRY": -0.5
      },
      "expression": "f02",
      "motion": null,
      "transitionDuration": 800
    }
  }
}
```

#### 1.3.5 System Prompt Injection Template (Example)

```
[Live2D Integration]
You are controlling a Live2D character model. You may embed <live2d> blocks in your responses to animate the character.

Available commands:
- <param id="[PARAM_ID]" value="[0.0-1.0]" dur="[ms]"/> — Set a model parameter.
- <motion group="[GROUP]" index="[INDEX]"/> — Play a motion.
- <expression id="[EXPR_ID]"/> — Set an expression.
- <emotion name="[PRESET_NAME]"/> — Apply an emotion preset.

Available parameters for current model:
{{DYNAMIC_PARAM_LIST}}

Available motions:
{{DYNAMIC_MOTION_LIST}}

Available expressions:
{{DYNAMIC_EXPRESSION_LIST}}

Available emotion presets: happy, sad, angry, surprised, neutral

Guidelines:
- Use <live2d> blocks to reflect the character's emotions and actions naturally.
- Place the <live2d> block at any point in your response.
- Do not reference <live2d> tags in the visible dialogue text.
```

---

## Part 2: Baseline Operational Tasks

> **Execution Condition:** The tasks in Part 2 shall only commence **after all tasks in Part 1 have been fully completed, tested, and verified.**
>
> **Round-Level Enforcement Addendum (2026-02-27):**
> 1. Until Part 1 completion is proven by evidence, **Part 2 implementation code changes are prohibited**.
> 2. Allowed while Part 1 is incomplete: Part 2 preparation documents, instrumentation plans, and quality/ops checklists.
> 3. During Part 1 execution, work must be split as `Planning/Ops -> Implementation -> QA` with **at least three agents running in parallel**.
> 4. Review bottlenecks are triaged in a **30-minute SLA** cycle and immediately reassigned when blocked.
> 5. Any failed task must run `RCA -> fix -> rerun` (max 2 retries), then escalate with blocker owner and ETA.
> 6. Every cycle must audit: code reflection status, validation completion, and `main` push omission; missing items must create automatic follow-up tasks.

---

### 2.1 Stabilization and Optimization

**Objective:** Conduct a comprehensive, multi-pass review of the entire codebase to identify and resolve stability issues, performance bottlenecks, and architectural deficiencies.

**Detailed Requirements:**

| # | Requirement | Description |
|---|-------------|-------------|
| 1 | **Full Codebase Audit** | Review every module, class, and function for: null-safety violations, memory leaks (especially in Live2D rendering and Lua runtime), unhandled exceptions, thread-safety issues, and deprecated API usage. |
| 2 | **Performance Profiling** | Use Android Profiler (CPU, Memory, Energy) to identify: (a) excessive allocations in hot paths (e.g., rendering loop, message processing), (b) unnecessary re-compositions or re-renders in UI, (c) I/O operations on the main thread, and (d) Lua script execution overhead. |
| 3 | **Large-Scale Refactoring Authorization** | Large-scale code modifications are explicitly authorized for optimization purposes. However, any such refactoring must: (a) begin with a written plan (mini-specification), (b) be executed systematically module by module, (c) maintain or improve existing test coverage, and (d) be validated against all acceptance criteria defined in Part 1. |
| 4 | **Iterative Execution** | This task is inherently iterative. Perform repeated cycles of: Profile → Identify → Plan → Refactor → Test → Validate. Continue until no critical or high-severity issues remain. |
| 5 | **Documentation** | All significant changes must be documented with: rationale, before/after metrics (where applicable), and any behavioral changes. |

---

### 2.2 Feature Supplementation and Enhancement

**Objective:** Identify gaps, incomplete implementations, and missing quality-of-life features in the current application, then design and implement improvements.

**Detailed Requirements:**

| # | Requirement | Description |
|---|-------------|-------------|
| 1 | **Gap Analysis** | Conduct a thorough analysis of the current codebase and feature set to identify: (a) features that are partially implemented or non-functional, (b) common user-facing workflows that are cumbersome or unintuitive, (c) error states that lack proper user feedback, and (d) missing features that would be expected in an application of this type. |
| 2 | **Prioritized Enhancement Backlog** | Create a prioritized list of identified enhancements, categorized by: (a) critical (blocks core functionality), (b) high (significantly improves usability), (c) medium (nice-to-have improvement), (d) low (cosmetic or minor convenience). |
| 3 | **Implementation** | Implement enhancements starting from the highest priority. Each enhancement must follow the standard process: specification → implementation → testing → integration. |
| 4 | **Regression Prevention** | Every new feature or modification must be verified not to regress existing functionality. Where automated testing is feasible, add test cases. |
