

# Notification Feature Addition

A notification feature that interacts with the existing AI chat functionality will be added.

---

## Prerequisite Task — Global On/Off Toggle

Add a prominently sized On/Off button at the very top of the menu to control the overall activation/deactivation of the app.

- This button governs the global running or stopped state of the app.
  - Example: When turned **On**, if the Live2D overlay is enabled it will be displayed, and if notifications are enabled they will be active. When turned **Off**, the same applies in reverse — all associated features become inactive.
- When the toggle is switched **Off**, all in-progress API calls must be **cancelled immediately**, all pending notifications must be **cleared**, and all proactive response timers must be **stopped**.
- The On/Off state must be **persisted** across app restarts (e.g., via SharedPreferences).
- For now, only the Live2D overlay and the forthcoming notification messages will be linked to this toggle. However, the implementation must be **modularized** — define a registration interface (e.g., a listener/callback contract) so that additional features can register themselves with the global toggle and be easily integrated in the future.

---

## Prerequisite Task — Character Name Setting

Add a **Character Name** display at the top of the menu. Tapping it opens an editor allowing the user to change the character name. This name is used as the character identifier in notification titles and other relevant locations throughout the app.

---

## Prerequisite Task — Prompt Block Generalization and Stabilization

### Premises

1. **Premise 1:** Remove all permanently fixed prompt blocks. Every block must be freely removable and addable.
2. **Premise 2:** The current past-message retrieval mechanism will be completely replaced.

### Specification

- Prompt blocks are saved and loaded as a **JSON structure**. Conflicts (e.g., duplicate IDs, ordering issues) must be handled automatically. Example:

```json
[
  {
    "type": "prompt",
    "title": "System",
    "content": "You are a user-friendly chatbot...",
    "isActive": true
  },
  {
    "type": "pastmemory",
    "title": "Past Memory",
    "range": "10",
    "userHeader": "user",
    "charHeader": "char",
    "isActive": true
  },
  {
    "type": "input",
    "title": "Input",
    "isActive": true
  }
]
```

- **Past Memory block** (`pastmemory`): Uses a JSON-like syntax to retrieve past messages.
  - `range`: The number of past messages to retrieve (e.g., `"10"` retrieves the 10 most recent messages). **Only positive integers (natural numbers) are accepted.** If the value is invalid (negative, non-numeric, empty, or zero), it defaults to `1`. If the stored message history contains fewer messages than the specified range, **retrieve only the available messages** without error.
  - `userHeader`: The XML tag name used to wrap user messages when constructing the prompt.
  - `charHeader`: The XML tag name used to wrap the LLM (character) messages when constructing the prompt.
  - Messages are ordered **oldest to newest** (chronological order).
  - When this block is rendered, it produces output in the form:
    ```
    <user>content</user><char>content</char><user>content</user><char>content</char>...
    ```
    for up to the specified number of messages.

- **Input block** (`input`): Represents the user's current input. It is loaded via the JSON syntax as well and has no additional parameters.

- **Recognized block types** when importing a prompt JSON into prompt blocks: `prompt`, `pastmemory`, `input`.

- **Block multiplicity:** If multiple blocks of the same type exist (e.g., two `input` blocks or two `pastmemory` blocks), **all of them must be processed and reflected** in the final output in the order they appear.

- **Field definitions** when a prompt JSON is loaded into prompt blocks:
  - `type` — Determines the block's form/behavior.
  - `title` — The display name of the block.
  - `isActive` — Whether the block is enabled or disabled.
  - All remaining fields are type-specific parameters.

- **Block UI:**
  - Every block has, at minimum, an **On/Off toggle** and a **name label**.
  - `prompt` blocks additionally provide a **text input area** for the content.
  - `pastmemory` blocks additionally provide **input fields** for `range`, `userHeader`, and `charHeader`.
  - `input` blocks have no additional input fields.
  - Blocks must support **reordering** (e.g., drag-and-drop or up/down buttons).

- **Inactive block handling:** Blocks with `isActive: false` are **completely excluded** from the API payload — they must not appear at all, not even as empty values.

- **Final payload sent to the API:** When the JSON is compiled for the API call, only the essential content of each active block is transmitted, separated by paragraph breaks. Example:

```
content
content
input
<char>content</char><user>content</user>...
content
```

- **Data migration:** When the legacy past-message retrieval system is replaced, any existing saved prompt/message data must be migrated or handled gracefully so that no user data is lost.

---

## Prompt Preview Feature

Overhaul the existing prompt preview to align with the redesigned prompt block system.

- The preview must display the final compiled output exactly as it would be sent to the API.
- For `pastmemory` blocks, **actual chat records from the currently active main session** must be fetched and displayed (not placeholders).
- For long prompts, the preview must be **scrollable**.
- Example output:

```
content
content
input
<char>content</char><user>content</user>...
content
```

---

## Prompt Preset System

### Menu → Prompt Block Editor — Feature Additions

Add a bar at the bottom of the editor that allows the user to select the currently displayed prompt block preset, along with **Save**, **Delete**, and **Add** buttons.

1. **Add:** Saves the current prompt block configuration as a new preset. The user must provide a **name** for the preset.
2. **Select:** Loads a previously saved preset into the editor.
   - **Caution:** If the current content has unsaved changes, a **popup dialog** must ask the user whether to save before switching.
3. **Save:** Saves the current changes to the active preset.
4. **Delete:** Deletes the currently active preset.
   - At least **one preset** must always exist; deletion is blocked otherwise.
   - A **confirmation popup** must warn the user before deletion proceeds.
   - **Reference handling on deletion:** If a deleted preset is currently referenced by the notification settings or proactive response settings, those references are **automatically released** and reassigned to an **arbitrary existing preset**.
5. **Rename:** A method to **rename** an existing preset must be provided.

### Additional Rules

- There is **no limit** on the number of presets.
- **Export/Import:** Presets can be **exported to** and **imported from** external JSON files.
- On first install, a sensible **default preset** should be provided.

### Menu → Prompt Preview — Feature Addition

Add a **preset selector** at the top of the Prompt Preview screen, allowing the user to choose which prompt block preset to preview.

---

## Notification Settings

Add a **Notification Settings** section to the menu. The following options are configured here:

1. **Notifications On/Off** — Toggle whether notifications are shown at all.
2. **Persistent Notification On/Off** — Toggle whether the notification is permanent (cannot be dismissed) or dismissible. *(Technically feasible via `Notification.FLAG_ONGOING_EVENT` + Foreground Service — must be implemented.)*
3. **Output as New Notification On/Off** — Toggle whether each AI output is delivered as a new notification (triggering a heads-up/popup notification). *(Technically feasible via high-priority channel + heads-up notification — must be implemented.)*
4. **Prompt Block Preset Selection** — Select which prompt block preset to use for notifications.
5. **API Preset Selection** — Select which API preset to use for notifications.

---

## Notification Technical Requirements

### Persistent Notification

Implement a notification that **cannot be dismissed** even by the "Clear All" action. This is achieved using `Notification.FLAG_ONGOING_EVENT` combined with a **Foreground Service**.

- A **Foreground Service** must be implemented with proper lifecycle management.
- A dedicated **notification channel** must be created with appropriate name, importance level, sound, and vibration settings.
- The `foregroundServiceType` must be specified appropriately in the manifest.
- On **app force-stop or kill**: the persistent notification is naturally removed by the system. Upon next app launch, if the global toggle is On and notifications are enabled, the notification and service must be **automatically restored**.

### Output as New Notification

When enabled, each AI output is delivered as a **new heads-up (popup) notification** using a high-priority notification channel. This can be toggled On/Off independently.

### Android 13+ Notification Permission

On Android 13 (API 33) and above, the `POST_NOTIFICATIONS` runtime permission is required. A **permission request flow** must be implemented — prompt the user for permission when notifications are first enabled, and guide them to settings if denied.

---

## Notification Message Format

- On the latest Android versions, the notification must be **persistent** — it must not be cleared by the "Clear All" action.
- **Character name** displayed in the notification title is sourced from the **Character Name setting** in the menu.
- For **long AI responses**, the notification must display the **full message** (use an expandable/big-text style notification).
- Similar to KakaoTalk's notification style, the notification must include:
  - A **button UI** below the message content.
  - A **"Reply"** label/button. When tapped, an **inline input field** appears allowing the user to compose and send a reply. The input field must include a **Cancel** button at the end.
  - Next to the Reply button, a **"Touch-Through"** button. Tapping this button automatically **toggles the touch-through mode** of the Live2D overlay (swap).
- **Loading feedback:** After the user sends a reply, a loading indicator or "Responding..." message must be shown in the notification while awaiting the AI response.
- **API failure handling:** If the API call fails after a reply is sent, an **error message** must be displayed in the notification in place of the normal AI output.

### Layout Mockup

#### i) Default State

```
======== Character Name ========
                        Message
================================
      Reply          | Touch-Through
```

#### ii) Reply Activated

```
======== Character Name ========
                        Message
================================
 __________Input Field__________(Cancel)
```

---

## Notification–AI Chat Integration — Reply Transmission

### Notification-Dedicated Prompt — Preset Selection

In the Notification Settings menu, add the ability to **select** one of the registered prompt block presets for use with the notification feature.

### Notification-Dedicated API Preset Selection

In the Notification Settings menu, add the ability to **select** one of the registered API presets for use with the notification feature.

### Notification-Dedicated Prompt — Detailed Behavior

- **Chat Session:** The chat session is **not** separated. The notification feature operates on the **currently active main session** within the app.
  - If **no active main session** exists (e.g., first launch, session deleted), the notification reply feature must be **disabled** or display a message prompting the user to create/select a session in the app.
- **Input (Reply):** The user's reply entered via the notification input field serves as the input.
- **Output:** The AI's response is delivered as a **notification**.
- **Main session synchronization:** All messages sent via notification reply and all AI responses received are **reflected in the main session's chat history** within the app.

### Thread Safety — Concurrent Access

When a notification reply, in-app chat input, and/or proactive response attempt to access the same session simultaneously, a **serialization mechanism** (e.g., queue, mutex) must be used to prevent race conditions and ensure message ordering integrity.

---

# Proactive Response Feature Addition

A feature where the AI automatically responds at set time intervals via the notification system.

---

## Proactive Response Settings

Add a **Proactive Response Settings** section to the menu. The following options are configured here:

### 1. Proactive Response Condition Configuration

Opens a **popup window** displaying conditions in a **plain-text (TXT) format**. The user can **view, edit, and save** the conditions directly. The system parses the text **line by line** and recognizes each setting accordingly.

#### Grammar Definition

Each line follows the format:

```
<condition>=<duration_min>~<duration_max>
```

or, to disable:

```
<condition>=0
```

**Formal grammar (regex-like):**

```
LINE        := CONDITION '=' VALUE
CONDITION   := 'overlayon' | 'overlayoff' | 'screenlandscape' | 'screenoff'
VALUE       := '0' | DURATION '~' DURATION
DURATION    := TIMEPART+
TIMEPART    := [0-9]+ UNIT
UNIT        := 'h' | 'm' | 's'
```

- **No spaces** are allowed within a line.
- Supported time units: `h` (hours), `m` (minutes), `s` (seconds). The `d` (days) unit is **not supported**.
- `0` means the condition is **disabled**.
- `DURATION` represents a random interval between `duration_min` and `duration_max`. Example: `3m30s~5m` means a random interval between 3 minutes 30 seconds and 5 minutes.
- **Minimum interval:** The resolved minimum interval must be **greater than 10 seconds**. If the user specifies a minimum interval of 10 seconds or less, an **error popup** must be displayed and the value must be rejected.
- **Invalid format handling:** If a line does not conform to the grammar, an **error message** must be shown to the user specifying which line is malformed, and the invalid entry must not be saved.

**Example:**

```
overlayon=3m30s~5m
overlayoff=1h20m~3h
screenlandscape=0
screenoff=0
```

*(Interpretation: When overlay is on, proactively respond at a random interval between 3 minutes 30 seconds and 5 minutes. When overlay is off, respond between 1 hour 20 minutes and 3 hours. Screen-landscape-based and screen-off-based triggering are disabled.)*

### 2. API Preset Selection

Select which API preset to use for proactive responses.

### 3. Proactive Response–Dedicated Prompt Selection

Add the ability to **select** one of the registered prompt block presets for use with the proactive response feature.

---

## Proactive Response Environment Conditions

The following environment states can each have **independently configured** proactive response conditions. When multiple conditions are satisfied simultaneously, the **condition listed lower** in the configuration text takes **higher priority**.

Additionally, `screenoff` is treated as the **highest priority** condition regardless of its position in the text. The full priority order (from lowest to highest) when conditions overlap:

1. `overlayon` (lowest priority)
2. `overlayoff`
3. `screenlandscape`
4. `screenoff` (highest priority — always overrides all others)
5. *(Additional conditions to be added in the future)*

---

## Proactive Response — Input Block Handling

In the proactive response context, there is no user input. If the selected prompt preset contains an `input` block, it must be **silently ignored** (skipped) — no error is raised, and the block simply does not appear in the compiled prompt.

---

## Proactive Response — Timer Behavior

- The random-interval timer **resets after each proactive response** is successfully generated and delivered.
- If the user sends a reply (via notification) while a proactive response API call is **in progress**, the in-progress API call must be **forcefully terminated/cancelled**. The timer then continues from where it was (it is **not** reset by user replies — only by completed proactive responses).

---

## Proactive Response — Result Handling

- Proactive response results are delivered as a **notification**.
- All proactive responses are also **reflected in the main session's chat history** within the app.
- **API failure handling:** If the API call fails, an **error message** is displayed in the notification in place of the AI output.

---

## Proactive Response — Background and Screen-Off Behavior

- When the screen is off, proactive response behavior is governed by the `screenoff` environment condition.
- When the app is in the background (screen on, app not in foreground), the proactive response timer continues to run as long as the Foreground Service is active.
- **Battery/Doze considerations:** The Foreground Service keeps the app alive; however, implementation should be mindful of battery consumption. Under Android Doze mode, alarms and timers may be deferred — use `setExactAndAllowWhileIdle()` or equivalent mechanisms if precise timing is required.

---

## Common Specifications

### Required Permissions

The following permissions must be declared and, where applicable, requested at runtime:

| Permission | Purpose |
|---|---|
| `POST_NOTIFICATIONS` (API 33+) | Displaying notifications |
| `FOREGROUND_SERVICE` | Maintaining persistent notification and proactive response timers |
| `SYSTEM_ALERT_WINDOW` | Live2D overlay display |
| Additional permissions as needed | To be determined during development |

### Error Handling Strategy

- **API call failure:** Display an error message in the notification (for notification/proactive response flows) or in the chat UI (for in-app chat).
- **Network offline:** If the device is offline when a reply or proactive response is triggered, display an error notification and **do not retry automatically**.
- **JSON parsing failure:** If a prompt preset JSON fails to parse, display an error message to the user and **do not load** the malformed preset. The previously active preset remains unchanged.

### Offline Behavior

When the device has no network connectivity:

- Notification reply attempts display an **error in the notification**.
- Proactive response timer continues to run, but API calls that fail due to no connectivity result in an **error notification**. The timer resets normally after the failed attempt.

### Implementation Priority

The recommended implementation order based on dependency:

1. **Global On/Off Toggle** (foundation for all features)
2. **Character Name Setting** (needed by notifications)
3. **Prompt Block Generalization & Stabilization** (foundation for presets)
4. **Prompt Preset System** (needed by notifications and proactive response)
5. **Prompt Preview Update** (depends on new block system)
6. **Notification Settings & Notification Message Implementation** (depends on presets, character name)
7. **Notification–AI Chat Integration** (depends on notification infrastructure)
8. **Proactive Response Feature** (depends on notifications, presets, Foreground Service)