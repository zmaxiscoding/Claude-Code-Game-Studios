# Corridor Transformation System

> **Status**: Designed
> **Author**: User (Creative Director) + Claude Code Game Studios
> **Last Updated**: 2026-03-28
> **Implements Pillar**: Atmosphere over complexity, Tension over action

## Overview

The Corridor Transformation System is the core mechanic of 03:17. It reuses one authored corridor scene and swaps it between two predefined states (State A and State B) through a hidden state manager. When the player crosses a corridor-end trigger, fully loses line of sight to the corridor, and re-enters, the system may switch to the other state without showing the transition directly. Each state changes a fixed set of authored elements — apartment numbers, light color/intensity, selected props, ambient audio layers, door availability, and a small number of interactables — while keeping the same base layout so implementation stays cheap and readable. The system is deterministic and script-driven, not procedural or random by default, and exists to create spatial unease: the player feels that a familiar place has become subtly wrong, with no UI, no explicit explanation, and no visible "mechanic" presentation.

## Player Fantasy

**The feeling:** "I know this hallway. I just walked through it. But something is different, and I don't immediately know what."

The Corridor Transformation System supports a fantasy of creeping wrongness: a familiar space quietly betrays the player's memory. The emotional target is not panic, action, or surprise for its own sake. It is the slow, mounting realization that reality is unstable enough to make the player doubt what they just saw, heard, and remembered.

The intended emotional progression is:
- First pass: recognition and baseline familiarity
- Second pass: subtle doubt
- Third pass: confirmation that specific details have changed
- Later passes: loss of trust in the space and in the player's own spatial certainty

The system succeeds when the player becomes unusually attentive to small environmental details — apartment numbers, lights, door states, props, and ambient sounds — because they no longer trust the corridor to remain consistent. The result should be vigilance, unease, and self-generated tension rather than a simple flinch response.

## Detailed Design

### Core Rules

**Rule 1: One corridor, two authored states.**
The corridor is a single Godot scene. It contains a base layout (walls, floor, ceiling, door frames) that never changes, plus two sets of authored element overrides called State A and State B. Only one state is active at any time.

**Rule 2: States are authored, not generated.**
Each state is a hand-placed configuration of changeable elements. There is no procedural generation, no randomization, and no blending between states. The active state is either A or B — never a mix.

**Rule 3: Transformation requires all three conditions (AND logic).**
A state switch is *eligible* only when all three are true simultaneously:
1. **Exit trigger**: The player has crossed a corridor-end trigger volume (leaving the corridor space)
2. **Line-of-sight break**: The player cannot see any part of the corridor interior (e.g., they have turned a corner into the stairwell or entered an apartment)
3. **Script permission**: The current game script step has flagged this traversal as a transformation point

If any condition is false, the corridor remains in its current state. The player can walk back and forth freely without triggering a change unless all three conditions align.

**Rule 4: Transformation is instant and invisible.**
When all three conditions are met, the system swaps the active element set in a single frame. There is no animation, no fade, no transition effect on the corridor itself. The player simply re-enters and the corridor is different. The invisibility of the swap *is* the horror.

**Rule 5: Transformation sequence is script-driven.**
The game script (event sequencer) dictates *when* transformations are allowed and *which* state to switch to. Example sequence:
- Traversal 1–2: State A (no change allowed — player establishes baseline)
- Traversal 3: Switch to State B (first wrongness)
- Traversal 4: Remain State B (player confirms the change)
- Traversal 5: Switch back to State A (was it always like this?)

The corridor system does not decide on its own. It only executes switches that the script has pre-authorized.

**Rule 6: Changeable elements are a fixed, authored set.**
The following element categories can differ between states:

| Element | State A Example | State B Example |
|---------|----------------|-----------------|
| Apartment numbers | 301, 302, 303, 304 | 301, 303, 302, 305 |
| Hallway light color | Warm fluorescent (3200K) | Cool fluorescent (5600K) |
| Hallway light intensity | Normal (dimmed) | Slightly brighter or one bulb out |
| Props (small) | Doormat at 302, umbrella by 304 | Doormat gone, shoes at 303 |
| Door states | 301 closed, 302 ajar | 301 ajar, 302 closed |
| Ambient sound layer | Distant TV hum, water pipe | Silence, faint ticking |
| Interactable state | 303's buzzer works | 303's buzzer plays wrong sound |

**Rule 7: Base layout never changes.**
Wall positions, floor plan, door frame positions, ceiling height, corridor length — these are constant. Only the *dressing* changes. This keeps the transformation subtle and prevents spatial disorientation that would break navigation.

**Rule 8: One authorized traversal can cause at most one transformation.**
When script permission is granted for a transformation, that permission is consumed immediately after one successful state switch. Re-entering, backtracking, or crossing the trigger again during the same traversal must not cause an additional switch unless the event sequencer explicitly grants a new permission.

**Rule 9: Only whitelisted presentation and interaction nodes may change between states.**
State swaps may affect only predefined authored elements such as number plates, selected light parameters, small props, specific door open/closed states, ambient audio layers, and explicitly marked interactables. Base collision, navigation, wall positions, door frame transforms, corridor dimensions, and core traversal geometry must never change.

### States and Transitions

**System States**

| State | Name | Description |
|-------|------|-------------|
| `STATE_A` | Baseline | The "normal" corridor. Player's first impression. Establishes what "correct" looks like. |
| `STATE_B` | Altered | The "wrong" corridor. Same layout, different dressing. Designed to feel uncanny against the baseline. |

**Internal Manager States**

The CorridorStateManager itself tracks a separate operational state:

| Manager State | Meaning |
|---------------|---------|
| `IDLE` | Player is inside or near the corridor. No transition eligible. |
| `ARMED` | Player has exited via a corridor-end trigger AND script permission is granted. Waiting for line-of-sight break. |
| `SWITCHING` | Line-of-sight break confirmed. Swap executes this frame. Transitions immediately to `COOLDOWN`. |
| `COOLDOWN` | Post-switch debounce. New arming is ignored until the player has meaningfully re-entered and progressed through the corridor flow again. Prevents trigger jitter, accidental re-arming, and edge-case double transitions. |

**Transition Table**

| From | To | Condition |
|------|----|-----------|
| `IDLE` | `ARMED` | Player crosses corridor-end trigger AND script permission exists (unconsumed) |
| `ARMED` | `SWITCHING` | Line-of-sight break confirmed (player fully around corner / inside apartment) |
| `SWITCHING` | `COOLDOWN` | Swap executed. Permission consumed. Active corridor state is now the target state. |
| `COOLDOWN` | `IDLE` | Player has entered an authored `re_entry_trigger` volume placed inside the corridor flow, confirming meaningful re-engagement with the space. This is a traversal-based spatial rule, not a fixed timer. The re-entry trigger must be positioned so the player has physically progressed into the corridor past the end-trigger zone. |
| `ARMED` | `IDLE` | Player re-enters corridor before line-of-sight break (cancelled). Authorization remains available only if the current script beat still intends that transformation. Otherwise the sequencer revokes it. |

**No-Op Guard**

If the authorized target state is already the active corridor state, no switch occurs and the authorization is consumed or revoked according to sequencer intent. The system must not perform redundant swaps.

**Line-of-Sight Break Detection (MVP)**

Full raycasting LOS is expensive and fragile. MVP implementation:

Use a second trigger volume placed around the corner in the stairwell (or inside an apartment doorway). When the player enters this "safe zone" trigger, LOS is considered broken. This is a spatial proxy, not a true visibility check.

```
Corridor ----[End Trigger]---- Corner ----[Safe Zone Trigger]---- Stairwell
                 ^                              ^
           Player exits                   LOS confirmed broken
           (IDLE → ARMED)                (ARMED → SWITCHING)
```

The safe zone trigger must be placed where the corridor is architecturally guaranteed to be invisible (around a 90° corner, behind a closed door, etc.). This avoids any need for occlusion queries or raycasting.

**Script Permission Interface**

The event sequencer grants permission via a simple method call:

```
corridor_manager.authorize_switch(target_state: CorridorState)
```

This sets a pending authorization. Authorization is scoped to the current intended traversal window or script step. If the player abandons the traversal, leaves the relevant encounter flow, or the sequencer advances past that beat, the authorization should be revoked automatically. Authorization must not persist indefinitely across unrelated traversal loops.

The sequencer can also explicitly revoke:
```
corridor_manager.revoke_authorization()
```

### Interactions with Other Systems

**Ownership Boundary**

The Corridor Transformation System owns only corridor-local presentation and authored state execution. It does not own gameplay progression, narrative timing, player movement, interaction handling, or audio mix logic outside selecting corridor-local state changes and emitting state-change signals.

**Upstream (systems that feed into Corridor Transformation)**

| System | Interface | Data Flow | Ownership |
|--------|-----------|-----------|-----------|
| **Event Sequencer** | `authorize_switch(target_state)`, `revoke_authorization()` | Sequencer tells corridor *when* and *what* to switch. Corridor never decides autonomously. | Sequencer owns timing; Corridor owns execution. |
| **Player Controller** | Player position, trigger volume `body_entered`/`body_exited` signals | Corridor reads player position indirectly via trigger overlaps. No direct coupling to controller internals. | Player Controller owns movement; Corridor owns trigger interpretation. |

**Downstream (systems that react to Corridor Transformation)**

| System | Interface | Data Flow | Ownership |
|--------|-----------|-----------|-----------|
| **Audio Manager** | Signal: `corridor_state_changed(old_state, new_state)` | On state switch, Audio Manager crossfades ambient layers to match the new state. Corridor emits the signal; Audio Manager decides the response. | Corridor owns the signal; Audio Manager owns the mix. |
| **Trigger/Scripted Event System** | Signal: `corridor_state_changed(old_state, new_state)` | Scripted events may listen for state changes to fire additional beats (e.g., a sound stinger after the first B-state entry). | Corridor owns the signal; Event system owns the reaction. |

**Peer (bidirectional or shared-resource relationships)**

| System | Relationship | Notes |
|--------|-------------|-------|
| **Interaction System** | Shared nodes — some interactables (buzzers, door handles) change behavior per state. Corridor swaps visibility/enabled state on authored interactable nodes; Interaction system handles player use. | No direct code coupling. Corridor toggles node properties; Interaction reads them. |
| **Lighting** | Not a separate system — light nodes are children of the corridor scene, toggled directly by the state manager. No abstraction layer needed for MVP. | If lighting becomes complex later, extract to a LightingManager. |

**Interactable Scope**

The corridor system may only enable, disable, reveal, hide, or swap authored interactable variants that are already placed in the corridor scene. It must not dynamically create interactables or inject custom interaction logic at runtime.

**MVP Scope: Lighting and Audio**

For MVP, lighting and ambient audio changes should be corridor-local only. No global lighting manager, global horror state, or cross-level ambience system should be introduced for this mechanic.

**Signal Contract**

The corridor system emits exactly one signal:

```gdscript
signal corridor_state_changed(old_state: CorridorState, new_state: CorridorState)
```

Emitted once per successful state switch, after all node swaps are complete, before the next frame renders. Listeners receive both the previous and new state for clearer audio transitions, scripted beats, and debugging. Any system can connect to this signal. The corridor system does not know or care who is listening.

**Read Interface**

The corridor manager exposes a read-only query for debugging and for systems that need to inspect, but not control, the current corridor state:

```gdscript
func get_active_state() -> CorridorState
```

## Formulas

This system is deterministic and authored, not formula-driven. There are no damage curves, scaling functions, or procedural generation algorithms. The following specifications define the quantifiable constraints.

**Cooldown / Debounce Rule**

This system should not rely on a fixed time-based cooldown for correctness. The primary debounce condition is traversal-based:

- After a successful switch, the manager ignores new arming attempts
- Until the player has meaningfully re-entered the corridor flow through the intended re-entry path
- And the current authorization window or script beat allows a future switch

A short fallback debounce timer (for example 0.25s–0.5s) may exist only as a safety guard against trigger jitter, overlapping `body_entered` events, or edge-case physics noise. It must not be the main logic that makes the system work.

**State Difference Budget**

Per transformation, target exactly this many noticeable changes:

| Pass | Target Changes | Noticeability |
|------|---------------|---------------|
| First transformation (A→B) | 2–3 elements | 1 obvious (door state or light color), 1–2 subtle (number swap, prop moved) |
| Subsequent transformations | 3–5 elements | Mix of obvious and subtle, increasing over time per script direction |

Rationale: Too few changes and the player misses it. Too many and it feels like a different room, breaking the "same but wrong" illusion. The sweet spot is enough to trigger doubt but not enough to feel like a level swap.

The state difference budget is an authored design target, not a runtime-enforced rule. It exists to guide content creation and keep the transformation subtle, legible, and cost-effective.

**Trigger Volume Sizing**

These dimensions are recommended MVP defaults for a human-scale apartment corridor and should be adjusted to the final level geometry as needed. They are implementation guidelines, not hardcoded universal constants.

```
end_trigger_depth   = 0.5m (thin plane across corridor exit)
end_trigger_width   = corridor_width (wall to wall)
end_trigger_height  = 2.5m (floor to ceiling)

safe_zone_depth     = 1.5m (deeper — player must commit to the corner)
safe_zone_width     = stairwell_width
safe_zone_height    = 2.5m
```

The end trigger is thin to detect the exact exit moment. The safe zone is deeper to ensure the player has genuinely moved past the LOS break point and cannot accidentally clip it while still seeing the corridor.

Trigger volumes must be positioned so the player cannot accidentally overlap both the corridor-end trigger and the safe-zone trigger while still maintaining visual access to the corridor.

## Edge Cases

| # | Edge Case | Resolution |
|---|-----------|------------|
| 1 | **Player stands in corridor-end trigger and doesn't move.** | No action. `ARMED` requires the player to have *crossed* the trigger (entered then exited toward the safe zone side). Standing in the trigger volume does nothing. Use `body_exited` on the corridor side + `body_entered` on the safe zone, not just overlap detection. |
| 2 | **Player rapidly oscillates across the end trigger (jitter).** | The fallback debounce timer (0.25s–0.5s) absorbs jitter. Additionally, `ARMED` requires forward progression into the safe zone — bouncing at the threshold never reaches `SWITCHING`. |
| 3 | **Player walks to the end trigger, turns around, and walks back.** | `ARMED` → `IDLE` (cancelled). Authorization remains only if the current script beat still intends the transformation, per the cancellation rule in States and Transitions. |
| 4 | **Player sprints through the corridor so fast they barely register the state.** | Not a problem — no sprint mechanic exists (design constraint: no run). Walk speed ensures adequate exposure time. If sprint is ever added, consider a minimum corridor dwell-time check. |
| 5 | **State switch is authorized but the target state equals the active state.** | No-op guard. No switch occurs. Authorization is consumed or revoked per sequencer intent. No signal emitted. |
| 6 | **Two authorizations are issued before the first is consumed.** | If `authorize_switch()` is called while an unconsumed authorization is already pending, the new request is rejected and a warning is logged in debug builds. The corridor system should not silently overwrite pending authorization, because that can hide sequencer errors and create hard-to-debug state mismatches. |
| 7 | **Player is inside an apartment when a switch occurs.** | Valid scenario — the player is behind a closed door (LOS broken). The corridor changes while they're inside the apartment. When they exit back to the corridor, it's different. This is an intended use case and one of the strongest horror moments. |
| 8 | **Player opens a door, looks into the corridor from an apartment, and a switch is pending.** | The safe zone trigger for apartment entries should be placed deep enough inside the apartment that the player cannot see the corridor while inside it. If the door is open and the player is in the doorway (not yet in the safe zone), `ARMED` does not advance to `SWITCHING`. |
| 9 | **Game script advances past a beat while authorization is pending.** | Sequencer revokes the stale authorization automatically. The corridor system receives `revoke_authorization()` and clears the pending state. Manager returns to `IDLE` if it was `ARMED`. |
| 10 | **Player quits or pauses mid-traversal.** | On unpause/resume, the manager re-validates any pending authorization against the current script beat. If the authorization is still valid, `ARMED` may remain active. If it is stale or no longer intended, it is revoked immediately and the manager returns to `IDLE`. The system should not assume that pause/resume preserves encounter validity automatically. |
| 11 | **Frame-perfect: player enters safe zone and re-enters corridor in the same physics tick.** | The debounce timer prevents this. Even if both triggers fire in the same tick, the switch completes and `COOLDOWN` blocks re-arming. Do not rely on engine callback ordering for correctness. If trigger events occur in the same physics tick, record them and resolve the corridor manager transition through a single deterministic evaluation step, preferably once per physics frame or via a deferred state-resolution method. Correctness must come from the manager's state machine, not signal arrival order. |
| 12 | **Player triggers a corridor switch, but one or more authored state-variant nodes are missing, disabled incorrectly, or misconfigured.** | Fail safely. The manager should skip invalid variant swaps, log a debug warning, and keep the corridor traversable. Missing presentation swaps must not break base movement, collision, or progression. |

## Dependencies

**Hard Dependencies (system cannot function without these)**

| Dependency | Direction | Interface | What Breaks Without It |
|-----------|-----------|-----------|----------------------|
| **Player Actor Presence** | Upstream | The corridor manager depends only on a valid player actor entering/exiting authored `Area3D` trigger volumes. It must not depend on Player Controller implementation details beyond overlap events and spatial progression through the corridor flow. | No trigger detection — manager never transitions from `IDLE` |
| **Event Sequencer** | Upstream | `authorize_switch(target_state)`, `revoke_authorization()` | No transformations ever occur — manager stays `IDLE` permanently |
| **Authored Trigger Volumes** | Internal | `end_trigger`, `safe_zone_trigger`, and any intended re-entry trigger volumes placed in valid geometry | The manager cannot arm, confirm LOS break, or debounce traversal correctly |
| **Authored Corridor Variant Nodes** | Internal | Predefined, whitelisted state-variant nodes for number plates, selected lights, small props, specific door states, ambient audio emitters, and authored interactable variants | Nothing to swap — system has no effect |

**Soft Dependencies (enhanced by, but works without)**

| Dependency | Direction | Interface | What Degrades Without It |
|-----------|-----------|-----------|------------------------|
| **Audio Manager** | Downstream | Listens to `corridor_state_changed` signal | Corridor swaps visually but ambient audio doesn't change — reduced atmospheric impact but system still functions |
| **Interaction System** | Downstream / shared-authored | Reads whichever authored interactable variant is currently enabled by the corridor manager | Corridor transformation still works without complex interaction logic, but authored interactables may lose behavioral consistency |
| **Debug Visualization / Debug Commands** (optional) | Internal / editor-only | Helpers such as printing active state, showing trigger names, or forcing `STATE_A` / `STATE_B` | Can accelerate implementation and QA, but are not required for runtime functionality |

**No Dependencies On (explicit exclusions)**

| System | Why Not |
|--------|---------|
| Save/Load | Game is short enough for session-based play. Corridor state is not persisted across sessions in MVP. |
| UI/HUD | No UI element reflects corridor state. This is by design — the system is invisible to the player. |
| AI/Enemy System | No enemies exist. No AI reads corridor state. |
| Inventory | No items are involved in corridor transformation. |
| Narrative/Dialogue | No dialogue triggers from corridor state. Environmental storytelling only. |
| Global Horror State / Global Game State | The corridor system is corridor-local and beat-driven. It must not rely on or mutate a broad global fear-state system in MVP. |
| Navigation / Pathfinding | No AI navigation is involved. Corridor traversal geometry remains constant. |
| Runtime Spawning / Procedural Content | All state differences are authored in advance. No runtime generation is needed. |

## Tuning Knobs

**Runtime-Adjustable (exported vars in GDScript)**

| Knob | Type | Default | Safe Range | Notes |
|------|------|---------|------------|-------|
| `debounce_guard_sec` | float | 0.3 | 0.1–0.5 | A low-level safety guard against trigger jitter and overlapping events. It must not be used to control pacing, tension, or perceived responsiveness. Core correctness should come from traversal logic, authorization scope, and state-machine rules, not timer tuning. |
| `initial_state` | CorridorState | `STATE_A` | `STATE_A` for production; `STATE_B` allowed for debug/testing only | In production, starting outside the intended authored baseline can weaken the player's first impression and break the emotional setup. |
| `debug_log_enabled` | bool | true (debug) / false (release) | — | No breakage — controls console output only. |
| `debug_force_state` | CorridorState or disabled | disabled | disabled / `STATE_A` / `STATE_B` | Debug-only. Allows QA and implementation checks without relying on sequencer timing. Must be unavailable in release builds. |

**Authored Content Knobs (adjusted in the scene editor, not code)**

| Knob | Where | Guidance |
|------|-------|---------|
| **Number of changed elements per state** | State A/B variant node groups | Target 2–3 for first transformation, 3–5 for later ones. See State Difference Budget in Formulas. |
| **Which elements change** | Individual variant nodes (visibility, properties) | Prioritize elements the player has already noticed. Change what they looked at, not what they ignored. |
| **Obviousness gradient** | Mix of subtle vs. obvious changes per state | At least one obvious change (light color, door state) per transformation. Purely subtle changes risk going unnoticed. |
| **Player-facing salience of changed elements** | State variant authoring | Ensure at least one already-seen element changes per meaningful transformation. Do not rely only on obscure props the player may never notice. |
| **End trigger placement** | `end_trigger` Area3D position in scene | Must be at the architectural exit point. Moving it deeper into the corridor creates early arming; moving it into the stairwell creates late arming. |
| **Safe zone trigger placement** | `safe_zone_trigger` Area3D position in scene | Must be past the LOS break point. Too shallow: player might see the swap. Too deep: player waits too long before the swap can happen. |
| **Ambient audio per state** | AudioStreamPlayer3D nodes in variant groups | State A and State B should have distinct but plausible audio. Avoid dramatic contrast — the difference should register as "wrong" not "different level." |
| **Base geometry mutability** | Corridor scene authoring rules | Must remain unchanged across states. Walls, floor plan, door frame transforms, collision, corridor length, and traversal geometry are not tuning knobs and must never be adjusted as part of state variation. |

**Sequencer-Level Knobs (authored beat-planning controls, not runtime procedural knobs)**

These exist to shape when the player is allowed to notice corridor changes, and should remain deterministic and script-driven.

| Knob | Where | Guidance |
|------|-------|---------|
| **Traversals before first transformation** | Event sequencer beat list | Minimum 2 traversals in State A before any switch. Player must establish a baseline. |
| **Transformation frequency** | Beat spacing in sequencer | Avoid authorizing a switch on every traversal. Transformations should be tied to explicit authored beats: establish baseline, create doubt, allow confirmation, then escalate. Hold patterns are useful, but they should be chosen deliberately by the sequencer rather than treated as a freeform pacing slider. |
| **Which state to target** | `authorize_switch(target)` calls | A→B→A→B is boring. Consider A→B→A (was it always like this?) or A→B→B→B (it's staying wrong). |

## Visual/Audio Requirements

[To be designed]

## Acceptance Criteria

**Critical (must pass before vertical slice is considered functional)**

| # | Criterion | How to Verify |
|---|-----------|---------------|
| AC-1 | Player can traverse the corridor in State A with no errors, no visual glitches, and no collision issues. | Walk the full corridor. Open/close doors. Confirm all props visible and positioned correctly. |
| AC-2 | After an authorized switch, the corridor displays State B elements and hides State A elements completely. No State A nodes remain visible, audible, or interactable. | Verify through visible presentation, audible presentation, interactable availability, and debug logging that State A variant nodes are inactive and State B variant nodes are active. Scene tree inspection is a debugging aid, not the primary acceptance method. |
| AC-3 | The transformation is invisible to the player. No pop-in, no flicker, no frame where both states are partially visible. | Trigger a switch only after the player has fully lost visual access to the corridor. On re-entry, confirm that the first visible frame of the corridor is already fully in the target state, with no pop-in, flicker, mixed-state frame, or visible transition artifact. |
| AC-4 | Transformation requires all three conditions (exit trigger + LOS break + script permission). Removing any one condition prevents the switch. | Test each: (a) cross end trigger without script permission — no switch. (b) get script permission but don't cross end trigger — no switch. (c) cross end trigger with permission but turn back before safe zone — no switch. |
| AC-5 | Authorization is consumed after one successful switch. Re-traversing without new authorization does not cause another switch. | Trigger one switch. Walk through the corridor again. Confirm it remains in the new state without switching back. |
| AC-6 | The `corridor_state_changed` signal fires exactly once per successful switch, with correct `old_state` and `new_state` values. After a successful switch, the corridor manager returns to `IDLE` (or the intended post-switch cooldown/debounce state if applicable), and authorization has been consumed or cleared as designed. | Connect a test listener. Trigger a switch. Verify one signal received with expected values. Verify manager state. Traverse again without authorization — verify no signal. |

**Important (must pass before playtesting)**

| # | Criterion | How to Verify |
|---|-----------|---------------|
| AC-7 | No-op guard: authorizing a switch to the already-active state produces no switch and no signal. | Set State A active. Authorize switch to State A. Complete traversal. Verify no signal, no node changes. |
| AC-8 | Cancellation: returning to the corridor before reaching the safe zone cancels arming. Manager returns to IDLE. | Get authorization. Cross end trigger. Turn back before safe zone. Verify manager is IDLE. Cross end trigger again — verify it can re-arm if authorization is still valid. |
| AC-9 | Debounce: rapidly oscillating across the end trigger does not cause erratic state changes. | Wiggle back and forth across the end trigger 10 times quickly. Verify manager state remains consistent and no unexpected switches occur. |
| AC-10 | Duplicate authorization rejection: calling `authorize_switch()` while one is already pending logs a warning and does not overwrite. | Issue two `authorize_switch()` calls in sequence without consuming the first. Verify warning logged and first authorization preserved. |
| AC-11 | Missing variant node resilience: if a State B variant node is deleted from the scene, the switch still executes for remaining nodes without errors. | Remove one State B variant node. Trigger a switch. Verify remaining elements swap correctly, warning is logged, corridor remains traversable. |
| AC-12 | `get_active_state()` returns the correct state at all times, including during COOLDOWN. | Query at each manager state. Verify accuracy. |
| AC-13 | Stale authorization safety: if authorization becomes stale before the player completes the traversal, the manager revokes or clears it safely and no transformation occurs. | Authorize a switch, then advance or invalidate the relevant script beat before safe zone confirmation. Verify no switch occurs and manager returns to a valid idle state. |

**Nice-to-Have (verify before release, not blocking for slice)**

| # | Criterion | How to Verify |
|---|-----------|---------------|
| AC-14 | Pause/resume re-validates authorization against the current script beat. Stale authorizations are revoked on resume. | Arm a switch. Pause. Advance the script beat externally (or simulate). Resume. Verify authorization was revoked and manager returned to IDLE. |
| AC-15 | Debug force-state works in debug builds and is unavailable in release builds. | In debug: set `debug_force_state` to STATE_B. Verify corridor swaps. In release: verify the knob has no effect or is absent. |

**Performance Budget**

| Metric | Target | Rationale |
|--------|--------|-----------|
| State swap time | Visually imperceptible and comfortably within a single frame on target hardware | The player must not perceive the swap |
| Memory overhead | Modest and proportional to duplicated authored variant content | Both states live in-scene, but only small props/lights/audio variants should duplicate |
| Swap hitching | No noticeable hitch during normal playtesting | Exact profiling can happen later; the MVP goal is perceptual smoothness, not premature micro-optimization |

**Optional debug metric:** In debug builds, log swap duration and node-count touched during a switch to detect accidental scope growth.

## Open Questions

[To be designed]
