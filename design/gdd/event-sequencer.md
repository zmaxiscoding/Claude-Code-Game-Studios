# Event Sequencer

> **Status**: Designed
> **Author**: User (Creative Director) + Claude Code Game Studios
> **Last Updated**: 2026-03-28
> **Implements Pillar**: Tension over action, Strong first 3 minutes

## Overview

The Event Sequencer is a linear, deterministic, one-shot beat runner for the 5–10 minute vertical slice of 03:17. It owns a simple ordered list of authored beats and advances through them from beginning to end. Each beat defines: a completion condition, one or more actions to dispatch, and an optional delay before the next beat becomes `ACTIVE`. Beats fire once, in order, and do not repeat, rewind, branch, or evaluate in parallel.

The sequencer's job is to tell other systems when to act. It calls `corridor_manager.authorize_switch(target_state)` and `revoke_authorization()` to control corridor transformations, dispatches audio stingers, unlocks puzzle progression, reacts to trigger-driven slice events, and fires the ending beat. It does not own corridor logic, audio logic, interaction handling, puzzle rules, or narrative systems — it only coordinates their timing.

There is no branching, no dialogue framework, no save/load orchestration, no cutscene system, and no generic timeline editor. This is a minimal beat coordinator built only for the first vertical slice. If future scope demands a more complex progression system, this sequencer should be replaced or heavily refactored rather than gradually expanded into a bloated framework.

## Player Fantasy

**The feeling:** "The building is not attacking me. It is noticing me."

The player should feel like they are moving through a place that quietly responds to their presence. They are not following objectives, clearing tasks, or triggering obvious scripted moments. Instead, the world seems to answer them indirectly: a corridor changes after they leave it, a sound appears where silence should be, a door that meant nothing now feels important, and a familiar detail becomes wrong enough to demand attention.

The emotional progression is simple and deliberate:
- First, the player trusts the space.
- Then, that trust starts to erode through small but undeniable changes.
- Then, the building feels increasingly deliberate, as if it is arranging moments around the player rather than simply existing.
- Finally, the experience resolves in a controlled final beat that feels earned, not abrupt.

The sequencer succeeds when the player attributes the pacing to the building's personality and presence, not to an underlying script.

## Detailed Design

### Core Rules

**Rule 1: Beats are an ordered, flat array.**
The sequencer holds a single array of beat definitions. Beats are evaluated in index order. There are no parallel tracks, no nested sequences, and no conditional branches. Beat 0 must complete before Beat 1 becomes active.

**Rule 2: Each beat fires exactly once.**
When a beat's condition is satisfied and its actions have dispatched, the beat is marked `DONE` and never re-evaluated. There is no repeat, loop, or rewind mechanism.

**Rule 3: Only one beat is active at a time.**
The sequencer maintains a single `current_beat_index`. The active beat is the only one whose condition is checked. All prior beats are `DONE`. All subsequent beats are `PENDING`. A beat transitions from `PENDING` to `ACTIVE` when it is the current beat and no delay timer from the previous beat is running.

**Rule 4: Each beat has exactly one completion condition.**
A beat defines one condition, not a compound of multiple conditions. No AND/OR logic. If a moment requires multiple prerequisites, either split it into sequential beats or have the owning system emit a single composite signal when all prerequisites are met. The sequencer never evaluates compound conditions itself.

**Rule 5: A beat has three parts: condition, actions, and optional delay.**

| Part | Required | Description |
|------|----------|-------------|
| `condition` | Yes | The single event that completes this beat. Types: `on_trigger_entered(trigger_name)`, `on_corridor_state_changed(target_state)`, `on_interaction(target_name)`, `immediate` (completes on the frame the beat becomes active), `on_signal(source, signal_name)`. |
| `actions` | Yes | What the sequencer dispatches when the condition is satisfied. One or more of: `authorize_switch(target_state)`, `revoke_authorization()`, `play_stinger(audio_id)`, `unlock_gate(gate_name)`, `emit_event(event_name)`. Actions are called synchronously, in array order, within a single frame. The sequencer does not wait for completion callbacks — if a downstream system needs to report back, a later beat listens for that system's signal explicitly. |
| `delay_before_next` | No | Seconds to wait after this beat completes before the next beat becomes active. Default: `0.0` (immediate advance). Used to pace moments — e.g., let a stinger ring out before the next beat arms. |

**Beat lifecycle:** Condition satisfied → actions dispatch in array order within the same frame → beat marked `DONE` → if `delay_before_next > 0`, delay timer begins and `current_beat_index` advances but the next beat remains `PENDING` until the timer expires → when the delay ends (or immediately if `0.0`), the next beat becomes `ACTIVE` and its condition begins evaluation.

**Rule 6: The sequencer is signal-driven, not frame-polled.**
When a beat becomes `ACTIVE`, the sequencer connects to the Godot signal that corresponds to its condition type (e.g., `body_entered` for trigger conditions, `corridor_state_changed` for corridor conditions). When the beat completes, the sequencer disconnects from that signal. The exception is `immediate`: it does not connect to any signal and resolves on the same frame the beat becomes active. The only per-frame work is ticking the delay timer when one is running. The sequencer does not iterate over triggers, poll node states, or scan for changes.

**Rule 7: The sequencer dispatches — it does not execute.**
`authorize_switch()` calls the corridor manager. `play_stinger()` calls the audio manager. `unlock_gate()` calls the puzzle controller. The sequencer holds references to these systems and calls their public APIs. It does not contain corridor logic, audio logic, or puzzle logic. Ownership boundaries are strict: the sequencer decides *when*, the target system decides *how*.

**Rule 8: The sequencer does not own trigger zones.**
Trigger zones are scene-placed `Area3D` nodes owned by the Trigger Zone System. The sequencer references them by node path or name to connect signals. It never creates, moves, or destroys triggers.

**Rule 9: Beat definitions are hardcoded for MVP.**
The initial implementation defines beats as a typed array in `_ready()`. No external data files, no JSON parsing, no resource loader. If the beat list grows unwieldy (>20 beats), migrate to a Resource array — but not before.

### States and Transitions

The Event Sequencer is intentionally small. It does not model branching progression, rollback, parallel tracks, or recovery flows. For the vertical slice, it only needs to know whether it has not started yet, is waiting for the active beat to complete, is holding an authored delay, or has finished the sequence.

#### Sequencer Runtime States

| State | Meaning |
|-------|---------|
| `NOT_STARTED` | The beat list exists, but the sequence has not begun. No beat is active. No signals are connected. |
| `AWAITING_CONDITION` | One beat is `ACTIVE`. Its single completion condition is armed. For signal-driven beats, the sequencer is connected to exactly one relevant signal source. |
| `DELAY` | The current beat has completed and is `DONE`, but the next beat has not started yet because `delay_before_next` is counting down. No beat is active during this state. |
| `COMPLETED` | All beats are `DONE`. No signals remain connected, no delay is running, and the sequence will not dispatch any further actions. |

#### Beat States

Each authored beat exists in one of three simple states:

| Beat State | Meaning |
|-----------|---------|
| `PENDING` | The beat has not started yet. Its condition is not armed. |
| `ACTIVE` | This is the current beat. Its single condition is armed or, for `immediate`, resolving on activation. |
| `DONE` | The beat has already completed and will never run again. |

The sequencer owns one `current_beat_index`. At any time:
- All beats before `current_beat_index` are `DONE`
- Exactly one beat is `ACTIVE` while the sequencer is in `AWAITING_CONDITION`
- All beats after `current_beat_index` are `PENDING`
- During `DELAY`, there is no `ACTIVE` beat; the next beat remains `PENDING` until the timer expires

#### Transition Table

| From | To | Condition |
|------|----|-----------|
| `NOT_STARTED` | `AWAITING_CONDITION` | Sequence begins. `current_beat_index` is set to `0` and Beat 0 becomes `ACTIVE`. |
| `AWAITING_CONDITION` | `AWAITING_CONDITION` | The active beat's condition is satisfied, its actions dispatch, it becomes `DONE`, and the next beat exists with `delay_before_next = 0.0`. The sequencer advances immediately in the same frame. |
| `AWAITING_CONDITION` | `DELAY` | The active beat's condition is satisfied, its actions dispatch, it becomes `DONE`, and `delay_before_next > 0.0`. |
| `AWAITING_CONDITION` | `COMPLETED` | The final beat completes. Its actions dispatch, it becomes `DONE`, and the sequence ends. |
| `DELAY` | `AWAITING_CONDITION` | The delay timer reaches `0.0` and the next beat becomes `ACTIVE`. |
| `NOT_STARTED` | `COMPLETED` | The beat list is empty. This is a valid but unintended debug scenario and should log a warning in debug builds. |

#### Activation and Cleanup Rules

When a beat becomes `ACTIVE`, the sequencer arms only that beat's condition.
For signal-driven conditions, this means connecting to exactly one relevant Godot signal.
For `immediate`, no signal connection is made; the beat resolves on the same frame it becomes active.

When a beat leaves `ACTIVE`, the sequencer disconnects any temporary signal connection before advancing. This prevents duplicate completion, stale listeners, and cross-beat leakage.

The sequencer never waits on action completion callbacks in MVP. It only waits on:
- the active beat's condition
- or the authored delay timer between beats

#### Final-Beat Rule

`delay_before_next` has meaning only when another beat exists after the current one.
If the final beat defines a delay, that delay is ignored in MVP and may log a debug warning, because there is no next beat to pace.

#### Explicit Non-States

The sequencer does not have internal `PAUSED`, `FAILED`, `REWINDING`, or `BRANCHING` states in MVP.

- Engine pause is external to the sequencer
- Missing references or invalid beat definitions are implementation/debug issues, not new runtime modes
- If future scope requires recovery, rollback, or branching progression, that should be treated as a new system or a major refactor rather than layered onto this one

### Interactions with Other Systems

#### Ownership Boundary

The Event Sequencer owns progression timing and beat coordination only. It does not own corridor state logic, audio playback, puzzle rules, player movement, or interaction handling. It tells other systems *when* to act by calling their public APIs or emitting signals. It never reaches into their internals.

#### Upstream (systems that feed into the Event Sequencer)

| System | Interface | Data Flow |
|--------|-----------|-----------|
| **Trigger Zone System** | `body_entered(body)` signal from scene-placed `Area3D` nodes | The sequencer connects to a trigger's signal when a beat with `on_trigger_entered` becomes `ACTIVE`. The trigger zone does not know the sequencer exists. |
| **Corridor Transformation System** | `corridor_state_changed(old_state, new_state)` signal | The sequencer connects to this signal when a beat with `on_corridor_state_changed` becomes `ACTIVE`. Used to confirm a transformation actually occurred before advancing. |
| **Interaction System** | `interacted(target_name)` signal (or equivalent) | The sequencer connects when a beat with `on_interaction` becomes `ACTIVE`. Used for puzzle progression gates. |

#### Downstream (systems the Event Sequencer dispatches to)

| System | Interface | Data Flow |
|--------|-----------|-----------|
| **Corridor Transformation System** | `authorize_switch(target_state)`, `revoke_authorization()` | The sequencer calls these to control when the corridor is allowed to transform. The sequencer does not inspect corridor internals or decide corridor-local execution — it only calls public APIs and may listen to public signals. |
| **Audio Manager** | `play_stinger(audio_id)` (or equivalent public method) | The sequencer triggers one-shot audio events at authored moments. It does not control ambient layers, mix levels, or crossfades — those are Audio Manager's domain. |
| **Simple Puzzle Controller** | `unlock_gate(gate_name)` (or equivalent) | The sequencer unlocks progression gates when the player reaches the correct beat. The puzzle controller owns what "unlocked" means. |

#### Signals Emitted by the Sequencer

| Signal | When | Listeners |
|--------|------|-----------|
| `beat_completed(beat_index: int)` | After a beat's actions dispatch and it becomes `DONE` | Debug overlay, Slice Flow Controller, any system that needs to react to progression milestones |
| `sequence_completed()` | After the final beat completes | Slice Flow Controller (triggers ending flow) |

The sequencer does not emit signals for beat activation or delay start/end. Those are internal state, not public events.

#### Revocation Policy

The sequencer is responsible for ensuring that corridor authorization does not persist beyond its intended context. Authorization is scoped to an authored traversal window — a span of one or more sequential beats that together represent a single intended corridor interaction opportunity.

A typical pattern: Beat N dispatches `authorize_switch(STATE_B)`. Beat N+1 waits for `on_corridor_state_changed(STATE_B)` to confirm the transformation occurred. The authorization remains valid across both beats because they belong to the same traversal window.

The sequencer revokes authorization in three cases:

1. **Authored window boundary:** When the sequence advances past the last beat in an authored traversal window, the sequencer calls `revoke_authorization()`. Which beats belong to which window is an authoring decision — the beat list encodes this, not runtime logic. For MVP, the boundary is represented explicitly: the beat at the end of a traversal window includes `revoke_authorization()` in its actions list, or a dedicated cleanup beat follows the window. The sequencer does not infer window boundaries automatically.
2. **Sequence completion:** When the sequence enters `COMPLETED`, the sequencer calls `revoke_authorization()` unconditionally as a cleanup step. This is safe even if no authorization is currently pending — `revoke_authorization()` is a no-op through the corridor manager's public API when nothing is pending.
3. **Explicit authored revocation:** Any beat may include `revoke_authorization()` as one of its actions — e.g., to cancel a still-pending authorization because the player took an unexpected path or pacing requires it.

The sequencer never allows authorization to persist indefinitely across unrelated traversal loops. This aligns with the Corridor Transformation System's design: authorization is scoped to the current intended traversal window or script step, and the sequencer is the system responsible for enforcing that scope.

The sequencer does not inspect corridor internals to determine whether authorization was consumed. It manages authorization lifetime based on authored beat structure and its own progression state, using only the corridor system's public `authorize_switch()` and `revoke_authorization()` APIs.

## Formulas

This system is deterministic and event-driven. It contains no gameplay formulas, scaling curves, or procedural generation algorithms.

The only numeric behavior is the delay countdown between beats:

```
remaining = max(0.0, remaining - delta)
```

When `remaining` reaches `0.0`, the next beat becomes `ACTIVE`. This is a standard timer tick with no tunable curve or scaling factor. The authored `delay_before_next` value is used directly. When verifying delay duration, allow a tolerance of one physics frame rather than expecting exact equality, consistent with AC-7.

## Edge Cases

| # | Edge Case | Resolution |
|---|-----------|------------|
| 1 | **Beat condition is satisfied on the same frame the beat becomes `ACTIVE`.** | Valid. The beat completes immediately — actions dispatch, beat becomes `DONE`, and the sequencer advances (or begins delay) within the same frame. This is the normal behavior for `immediate` conditions and is also possible for signal-driven conditions if the signal fires during activation. |
| 2 | **Multiple `immediate` beats in a row with `delay_before_next = 0.0`.** | All resolve in the same frame, in order. Each beat activates, dispatches its actions, and becomes `DONE` before the next activates. This is valid and useful for grouping multiple dispatch actions that should happen at the same progression point without combining them into one beat. |
| 3 | **The player satisfies a future beat's condition before that beat is `ACTIVE`.** | No effect. Only the active beat's condition is armed. The sequencer does not listen to signals for `PENDING` beats. If the player later re-satisfies the condition when the beat is `ACTIVE`, it completes normally. If the condition cannot be re-satisfied (one-time event), the beat will stall — this is an authoring error, not a runtime failure. |
| 4 | **A trigger zone referenced by a beat does not exist in the scene.** | The sequencer cannot connect to the signal. The beat stalls permanently. In debug builds, log a warning identifying the missing trigger name and beat index. This is an authoring/integration error — the sequencer does not create fallback triggers or skip the beat automatically. |
| 5 | **A downstream system referenced by a beat action is not connected (null reference).** | The action call fails. In debug builds, log a warning identifying the missing system and beat index. The sequencer still marks the beat `DONE` and advances — actions are fire-and-forget dispatches, not gated on downstream acknowledgment. This should only occur during incremental development, not in the shipped slice. |
| 6 | **`authorize_switch()` is dispatched but the player never completes the corridor traversal, and the next beat waits for `on_corridor_state_changed`.** | The sequencer stalls on the confirmation beat, which is correct — the sequence cannot advance until the corridor actually transforms. If this becomes a problem during playtesting, it is a pacing/authoring issue (the authorization window is too demanding), not a sequencer bug. |
| 7 | **The sequencer dispatches `revoke_authorization()` when no authorization is pending.** | No-op. The corridor manager's public API treats this as a harmless call. No error, no warning. This is expected at sequence completion and at authored window boundaries where the corridor may have already consumed the authorization. |
| 8 | **Engine pause occurs while a delay timer is running.** | The delay timer runs in `_physics_process()`. When the engine is paused, physics processing stops, so the timer freezes. On resume, the timer continues from where it left off. No special handling required — this is standard Godot behavior. If the sequencer's `process_mode` is set to `PROCESS_MODE_INHERIT` (default), pause works correctly without sequencer-specific code. |
| 9 | **Engine pause occurs while a beat condition is armed.** | The signal connection persists through pause. When the engine resumes and the source system processes again, the signal can still fire and complete the beat normally. No cleanup or re-arming needed. |
| 10 | **`debug_skip_to_beat` targets an index beyond the last valid beat index.** | If the target index is `>= beat_count`, the sequencer marks all beats `DONE` without dispatching any actions and transitions directly to `COMPLETED`. Log a warning in debug builds identifying the out-of-range index and the actual beat count. |
| 11 | **Two sequencer instances exist in the scene simultaneously.** | Not supported. The authored slice uses exactly one sequencer. If a second is accidentally added, both will independently connect to shared trigger zones and dispatch to shared systems, causing duplicate actions and unpredictable progression. This is an authoring error — the sequencer does not detect or prevent it in MVP. |
| 12 | **A beat's action list is empty.** | Valid but unusual. The beat's condition completes, no actions dispatch, the beat becomes `DONE`, and the sequencer advances. This could be used as a pure gate — "wait for the player to reach this trigger before anything else happens." Log a debug note, not a warning. |

## Dependencies

This section describes dependencies for the authored vertical slice of 03:17 — the intended 5–10 minute experience. A separate note at the end covers the bare runtime sequencer for debugging and incremental development.

### Vertical Slice Dependencies (required for the authored sequence to function as designed)

| Dependency | Direction | Interface | What Breaks Without It |
|-----------|-----------|-----------|----------------------|
| **Trigger Zone System** | Upstream | `body_entered(body)` signals from scene-placed `Area3D` nodes | Trigger-driven beats cannot arm. The authored slice relies on spatial triggers for pacing — without them, progression stalls at the first `on_trigger_entered` beat. |
| **Corridor Transformation System** | Upstream + downstream public API | `authorize_switch()`, `revoke_authorization()` (downstream), `corridor_state_changed` signal (upstream) | The core mechanic of the slice. Corridor authorization, state-change confirmation, and first-B-entry timing are part of the required authored sequence. Without this system, the slice cannot deliver its intended experience. |
| **Interaction System** | Upstream | `interacted(target_name)` signal | The authored slice includes interaction-gated beats (apartment number hook, puzzle progression). Without interaction signals, those beats stall. |
| **Simple Puzzle Controller** | Downstream | `unlock_gate(gate_name)` | The authored slice includes a puzzle progression gate. Without a receiver for `unlock_gate()`, the gate never opens and the slice cannot reach its ending. |
| **Audio Manager** | Downstream | `play_stinger(audio_id)` | The authored slice includes a first-B-entry stinger and other timed audio beats that are integral to the intended horror experience. Without the audio manager, the sequencer's logical progression still advances, but the atmospheric impact that defines the slice's emotional arc is lost. |
| **Authored Beat List** | Internal | Hardcoded array in `_ready()` | No beats to run — sequencer transitions immediately to `COMPLETED`. |

### Downstream Listeners (enhanced by, but slice functions without)

| Dependency | Direction | Interface | What Degrades Without It |
|-----------|-----------|-----------|------------------------|
| **Debug Overlay** | Downstream | Listens to `beat_completed` signal | No visible beat progression feedback — debugging is harder but runtime is unaffected |
| **Slice Flow Controller** | Downstream | Listens to `sequence_completed()` signal | Ending flow doesn't trigger automatically — but sequencer itself completes normally |

### No Dependencies On (explicit exclusions)

| System | Why Not |
|--------|---------|
| Save/Load | Session-based play. Sequencer state is not persisted. |
| UI/HUD | No UI reflects beat progression. Sequencer is invisible to the player. |
| AI/Enemy System | No enemies exist. |
| Inventory | No items involved in beat progression. |
| Narrative/Dialogue | No dialogue system. Environmental storytelling only. |
| Door System | Doors are downstream of Interaction System, not the sequencer. The sequencer may indirectly affect doors via corridor state or puzzle gates, but has no direct door dependency. |
| Player Controller | The sequencer does not read player position, velocity, or input. It reacts to trigger zone signals, which abstract away player controller internals. |

### Note: Bare Runtime Sequencer

In isolation — without any target systems connected — the sequencer can still run beats with `immediate` conditions and advance through delays. This is useful for early development and debugging when downstream systems are stubbed or not yet implemented. Signal-driven beats will stall if their source system is missing. This is expected incremental-development behavior, not a supported runtime configuration for the shipped slice. The vertical slice must ship with all systems in the table above connected and functional.

## Tuning Knobs

### Runtime-Adjustable (exported vars in GDScript)

| Knob | Type | Default | Safe Range | Notes |
|------|------|---------|------------|-------|
| `debug_log_enabled` | bool | `true` (debug) / `false` (release) | N/A | Controls console output for beat activation, completion, and dispatch. No gameplay effect. |
| `auto_start` | bool | `true` | N/A | Integration flag. Whether the sequencer begins automatically on `_ready()` or waits for an explicit `start()` call. Default `true` for the slice; `false` is useful when another system (Slice Flow Controller) needs to control startup timing. |
| `debug_skip_to_beat` | int | `-1` (disabled) | `-1` to `beat_count - 1` | **Unsafe debug-only utility.** Skips all beats before the target index, marking them `DONE` without dispatching their actions. This leaves the world in an invalid state — corridor authorization, audio, and puzzle gates will not reflect the skipped beats. Use only for targeted testing of specific late-sequence beats, not as a substitute for real progression. Must be unavailable in release builds. |

### Authored Content Knobs (adjusted in the beat list, not code)

| Knob | Where | Guidance |
|------|-------|---------|
| **Beat count** | Beat array length | The authored slice targets 8–15 beats. Fewer than 5 means the pacing is too sparse to create escalation. More than 20 means the sequence is over-scoped for MVP — consider whether beats can be collapsed. |
| **Delay durations** | `delay_before_next` per beat | Keep delays short (0.5–3.0s). Delays exist to let a moment breathe — a stinger ringing out, a corridor change settling — not to create dead time. If a delay exceeds 5s, the player is probably waiting with nothing to do. |
| **Authorization placement** | Which beats call `authorize_switch()` | At least 2 traversals in State A before the first authorization (per Corridor GDD). Don't authorize on every traversal — hold patterns build tension. |
| **Authorization window length** | Number of beats an authorization stays valid across | Most corridor authorization windows should span only 1–2 beats (e.g., one beat authorizes, the next confirms via `on_corridor_state_changed`). If an authorization stays valid across 3+ beats, it becomes harder to reason about and risks leaking into unrelated progression context. Keep windows short and explicitly bounded with a revocation action or cleanup beat at the end. |
| **Revocation placement** | Which beats call `revoke_authorization()` | Place at authored window boundaries. Every `authorize_switch()` should have a corresponding revocation path — either the corridor consumes it, an explicit beat revokes it, or sequence completion cleans it up. |
| **Stinger timing** | Which beats call `play_stinger()` | The first-B-entry stinger is the highest-value audio moment. Don't stack stingers on consecutive beats — space them so each one registers. |
| **Condition type mix** | Which condition types appear in the beat list | Use the smallest mix of condition types that serves the authored slice. `on_trigger_entered` and `on_corridor_state_changed` will cover most beats. Add `on_interaction`, `immediate`, or `on_signal` only when a specific authored moment requires them — do not introduce condition types for variety alone. |

## Visual/Audio Requirements

The Event Sequencer has no player-facing visual or audio presentation of its own. It is invisible to the player. It does not render UI, display progress indicators, play sounds, or emit particles.

All player-facing audiovisual moments are owned by the systems the sequencer dispatches to: the Corridor Transformation System controls visual state changes, the Audio Manager plays stingers and ambient layers, and the Slice Flow Controller handles screen fades. The sequencer only decides when those systems act.

## Acceptance Criteria

### Critical (must pass before vertical slice is considered functional)

| # | Criterion | How to Verify |
|---|-----------|---------------|
| AC-1 | Beats advance in authored order. Beat 0 completes before Beat 1 becomes `ACTIVE`. No beat is skipped or evaluated out of order. | Run the full sequence. Log each beat activation and completion. Verify strictly ascending order with no gaps. |
| AC-2 | Each beat fires exactly once. Completing a beat and re-satisfying its condition does not re-trigger it. | Complete a trigger-based beat. Walk back through the same trigger. Verify no second dispatch and no second `beat_completed` signal. |
| AC-3 | Only one beat is `ACTIVE` at a time. During `DELAY`, no beat is `ACTIVE`. | Log beat states each frame during a delay. Verify the completed beat is `DONE`, the next beat is `PENDING`, and no beat is `ACTIVE` until the delay expires. |
| AC-4 | `authorize_switch()` dispatches to the corridor manager with the correct target state and the corridor system acknowledges it through observable behavior: the corridor manager's debug log confirms the authorization was received, or the corridor subsequently transforms to the expected state when traversal conditions are met. | Run a beat that authorizes `STATE_B`. Verify the corridor manager's debug log shows the authorization, or complete the traversal and verify the corridor transforms to `STATE_B`. |
| AC-5 | Corridor authorization does not survive past its authored window or past sequence completion. After the last beat of a traversal window completes (or the sequence enters `COMPLETED`), no unconsumed authorization remains that could cause an unintended corridor transformation. | Run the full sequence with debug logging. Verify: (a) authorizations that are consumed by the corridor during their window are fine. (b) Authorizations still pending when their window ends are revoked. (c) No authorization is pending after the sequence enters `COMPLETED`. |
| AC-6 | `beat_completed` signal fires once per beat with the correct `beat_index`. `sequence_completed` fires once after the final beat. | Connect test listeners. Run the full sequence. Verify signal count and arguments. |
| AC-7 | `delay_before_next` holds the sequencer in `DELAY` for the authored duration (within one physics frame tolerance) before the next beat becomes `ACTIVE`. | Set a beat with `delay_before_next = 2.0`. Log timestamps at beat completion and next beat activation. Verify the gap is within one physics frame of 2.0s. |

### Important (must pass before playtesting)

| # | Criterion | How to Verify |
|---|-----------|---------------|
| AC-8 | Signal-driven conditions connect on activation and disconnect on completion. No stale signal connections remain after a beat completes. | Run 3+ beats with different condition types. After each, verify the previous beat's signal source has no remaining sequencer connections (debug log or `is_connected()` check). |
| AC-9 | `immediate` conditions resolve on the same frame the beat becomes `ACTIVE`, without connecting to any signal. | Create a beat with `immediate` condition. Log the frame number at activation and completion. Verify same frame. Verify no signal connections made. |
| AC-10 | The authored corridor authorization → confirmation pattern works end-to-end: Beat N authorizes `STATE_B`, Beat N+1 waits for `on_corridor_state_changed(STATE_B)`, corridor transforms on traversal, Beat N+1 completes. | Run the authorization/confirmation pair. Walk the corridor traversal. Verify the sequencer advances only after the corridor emits `corridor_state_changed`. |
| AC-11 | The sequencer calls `revoke_authorization()` on sequence completion even if no authorization is pending. This is a no-op through the corridor manager's API and produces no error or warning. | Complete the sequence with no pending authorization. Verify no error logged and corridor manager state is unchanged. |
| AC-12 | At any given time, the sequencer holds at most one temporary signal connection (the active beat's condition). No prior beat's connections persist alongside the current beat's connection. | Run 5+ sequential signal-driven beats. After each activation, count the sequencer's outgoing signal connections. Verify exactly one temporary connection exists (or zero during `DELAY` and `COMPLETED`). |

### Nice-to-Have (verify before release, not blocking for slice)

| # | Criterion | How to Verify |
|---|-----------|---------------|
| AC-13 | Empty beat list transitions to `COMPLETED` immediately and logs a debug warning. | Initialize the sequencer with an empty array. Verify it reaches `COMPLETED` on the first frame with a warning logged. |
| AC-14 | `debug_skip_to_beat` marks skipped beats as `DONE` without dispatching their actions. The target beat becomes `ACTIVE` and evaluates normally. This is an unsafe debug utility — the world will be in an invalid state for skipped beats. | Set `debug_skip_to_beat = 5`. Verify beats 0–4 are `DONE` with no action dispatches logged. Verify beat 5 activates and its condition arms correctly. |
| AC-15 | `debug_skip_to_beat` is unavailable in release builds. | Build in release mode. Verify the knob has no effect or is absent. |
| AC-16 | Final beat's `delay_before_next` is ignored and logs a debug warning. | Set a delay on the last beat. Verify the sequencer transitions to `COMPLETED` immediately after the beat's actions dispatch, with a warning logged. |

## Open Questions

None for MVP.

### Deferred Future Questions

These are not current blockers. Address them as new decisions if they become relevant during or after implementation:

- Whether to migrate from hardcoded beats to a Resource array (Rule 9 provides the threshold: >20 beats)
- Whether `on_signal` is needed as a condition type (defer until a concrete authored need arises)
- Whether the sequencer needs a public `start()` / `stop()` API beyond `auto_start` (defer until Slice Flow Controller is designed)
