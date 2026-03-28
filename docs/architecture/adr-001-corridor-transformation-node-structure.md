# ADR-001: Corridor Transformation System — Godot Node Structure

> **Status**: Proposed
> **Date**: 2026-03-28
> **Implements**: `design/gdd/corridor-transformation-system.md`
> **Decision Scope**: Scene tree layout, script architecture, enum representation

---

## Context

The Corridor Transformation System is the core mechanic of 03:17. The GDD
defines the design rules, state machine, and interfaces. This ADR specifies
the concrete Godot 4.6.1 implementation: how the corridor scene is organized,
how state variants are represented, where scripts live, and what each script
is responsible for.

**Constraints from the GDD:**
- One corridor scene, two authored states (A/B)
- Only whitelisted presentation nodes change between states
- Base geometry, collision, and navigation never change
- System is script-driven via an Event Sequencer
- Single signal: `corridor_state_changed(old_state, new_state)`
- Must be implementable in 1–2 focused days

---

## Decision

### 1. CorridorState Enum

A single-file GDScript enum, not an autoload. Kept minimal.

```gdscript
# corridor_state.gd
class_name CorridorState

enum State {
    STATE_A = 0,
    STATE_B = 1,
}
```

Referenced as `CorridorState.State.STATE_A` throughout the codebase.
If a third state is added later, extend this enum — no other code changes
are needed beyond authoring the new variant nodes.

### 2. Corridor Scene Tree Layout

```
Corridor (Node3D) ← root of the corridor scene
│
├── BaseGeometry (Node3D) ← NEVER changes between states
│   ├── Walls (StaticBody3D + MeshInstance3D)
│   ├── Floor (StaticBody3D + MeshInstance3D)
│   ├── Ceiling (MeshInstance3D)
│   └── DoorFrames (Node3D)
│       ├── DoorFrame_301 (StaticBody3D + MeshInstance3D)
│       ├── DoorFrame_302 (StaticBody3D + MeshInstance3D)
│       ├── DoorFrame_303 (StaticBody3D + MeshInstance3D)
│       └── DoorFrame_304 (StaticBody3D + MeshInstance3D)
│
├── VariantA (Node3D) ← all State A presentation nodes, toggled as a group
│   ├── NumberPlates_A (Node3D)
│   │   ├── Plate_301 (MeshInstance3D or Sprite3D)
│   │   ├── Plate_302 (MeshInstance3D or Sprite3D)
│   │   ├── Plate_303 (MeshInstance3D or Sprite3D)
│   │   └── Plate_304 (MeshInstance3D or Sprite3D)
│   ├── Lights_A (Node3D)
│   │   ├── HallLight_1 (OmniLight3D or SpotLight3D)
│   │   └── HallLight_2 (OmniLight3D or SpotLight3D)
│   ├── Props_A (Node3D)
│   │   ├── Doormat_302 (MeshInstance3D)
│   │   └── Umbrella_304 (MeshInstance3D)
│   ├── Doors_A (Node3D)
│   │   ├── Door_301_Closed (StaticBody3D + MeshInstance3D)
│   │   └── Door_302_Ajar (AnimatableBody3D + MeshInstance3D)
│   ├── Audio_A (Node3D)
│   │   ├── AmbientTV (AudioStreamPlayer3D)
│   │   └── WaterPipe (AudioStreamPlayer3D)
│   └── Interactables_A (Node3D)
│       └── Buzzer_303_Normal (Area3D + interaction script)
│
├── VariantB (Node3D) ← all State B presentation nodes, toggled as a group
│   ├── NumberPlates_B (Node3D)
│   │   └── ... (different number textures/labels)
│   ├── Lights_B (Node3D)
│   │   └── ... (different color temperature, one bulb off)
│   ├── Props_B (Node3D)
│   │   └── Shoes_303 (MeshInstance3D)
│   ├── Doors_B (Node3D)
│   │   ├── Door_301_Ajar (AnimatableBody3D + MeshInstance3D)
│   │   └── Door_302_Closed (StaticBody3D + MeshInstance3D)
│   ├── Audio_B (Node3D)
│   │   └── FaintTicking (AudioStreamPlayer3D)
│   └── Interactables_B (Node3D)
│       └── Buzzer_303_Wrong (Area3D + interaction script)
│
├── Triggers (Node3D) ← spatial triggers for the state machine
│   ├── EndTrigger_North (Area3D) ← thin plane at corridor north exit
│   ├── EndTrigger_South (Area3D) ← thin plane at corridor south exit (if two exits)
│   ├── SafeZone_Stairwell (Area3D) ← past the corner, LOS guaranteed broken
│   ├── SafeZone_Apt301 (Area3D) ← inside apartment, deep enough for LOS break
│   └── ReEntryTrigger (Area3D) ← inside corridor, clears COOLDOWN → IDLE
│
└── CorridorStateManager (Node) ← the brain — script attached here
```

**Key design decisions:**
- `VariantA` and `VariantB` are sibling `Node3D` containers. The swap is
  `VariantA.visible = true/false` and `VariantB.visible = false/true`, plus
  toggling `process_mode` to disable audio/interaction on hidden variants.
- `BaseGeometry` is a peer, never touched by the state manager.
- `Triggers` are peers, never touched by state swaps.
- Doors that change state between A/B are variant children (duplicated per
  state), not shared. This avoids runtime animation/property juggling.
- Audio emitters are children of their variant group. When the variant is
  hidden and process_mode is disabled, audio stops automatically.

### 3. CorridorStateManager Script

Single script, attached to the `CorridorStateManager` node. Approximately
80–120 lines for MVP.

```gdscript
# corridor_state_manager.gd
class_name CorridorStateManager
extends Node

signal corridor_state_changed(old_state: CorridorState.State, new_state: CorridorState.State)

enum ManagerState { IDLE, ARMED, SWITCHING, COOLDOWN }

@export var initial_state: CorridorState.State = CorridorState.State.STATE_A
@export var debounce_guard_sec: float = 0.3
@export var debug_log_enabled: bool = true
@export var debug_force_state: int = -1  # -1 = disabled, 0 = STATE_A, 1 = STATE_B

var _active_state: CorridorState.State
var _manager_state: ManagerState = ManagerState.IDLE
var _pending_target: CorridorState.State = CorridorState.State.STATE_A
var _has_pending_auth: bool = false
var _debounce_timer: float = 0.0

@onready var _variant_a: Node3D = $"../VariantA"
@onready var _variant_b: Node3D = $"../VariantB"
```

**Responsibilities (CorridorStateManager owns):**
- Tracking `_active_state` and `_manager_state`
- Receiving trigger signals (`body_entered`/`body_exited` from Area3D children)
- Evaluating state machine transitions once per physics frame
- Executing variant swaps (show/hide + process_mode toggle)
- Emitting `corridor_state_changed`
- Enforcing authorization rules (consume, reject duplicate, no-op guard)
- Debug logging and `debug_force_state`

**Responsibilities (CorridorStateManager does NOT own):**
- Deciding *when* to authorize a switch → Event Sequencer
- Deciding *what audio* to play globally → Audio Manager
- Handling player interaction with buzzers/doors → Interaction System
- Player movement, input, or controller logic → Player Controller
- Narrative progression or game-over conditions → Game flow scripts

### 4. Trigger Wiring

Triggers connect to the manager via Godot signals, wired in `_ready()`:

```gdscript
func _ready() -> void:
    _active_state = initial_state
    _apply_state(_active_state)

    # Wire trigger signals
    $"../Triggers/EndTrigger_North".body_exited.connect(_on_end_trigger_exited)
    $"../Triggers/SafeZone_Stairwell".body_entered.connect(_on_safe_zone_entered)
    $"../Triggers/ReEntryTrigger".body_entered.connect(_on_reentry_trigger_entered)
    # Add more triggers as corridor geometry requires
```

Trigger evaluation happens in `_physics_process()` via deferred state
resolution — signals set flags, the physics tick evaluates the state machine
once per frame. This avoids dependence on signal arrival order.

```gdscript
var _exit_triggered: bool = false
var _safe_zone_reached: bool = false
var _reentry_reached: bool = false

func _on_end_trigger_exited(body: Node3D) -> void:
    if body == _player_ref:
        _exit_triggered = true

func _on_safe_zone_entered(body: Node3D) -> void:
    if body == _player_ref:
        _safe_zone_reached = true

func _on_reentry_trigger_entered(body: Node3D) -> void:
    if body == _player_ref:
        _reentry_reached = true

func _physics_process(delta: float) -> void:
    _debounce_timer = max(0.0, _debounce_timer - delta)
    _evaluate_state_machine()
    _exit_triggered = false
    _safe_zone_reached = false
    _reentry_reached = false
```

### 5. State Machine Evaluation

Single method, called once per physics frame. Mirrors the GDD transition table.

```gdscript
func _evaluate_state_machine() -> void:
    match _manager_state:
        ManagerState.IDLE:
            if _exit_triggered and _has_pending_auth and _debounce_timer <= 0.0:
                _manager_state = ManagerState.ARMED
                _log("IDLE → ARMED")

        ManagerState.ARMED:
            if _reentry_reached:
                # Player turned back into corridor — cancel
                _manager_state = ManagerState.IDLE
                _log("ARMED → IDLE (player returned)")
            elif _safe_zone_reached:
                _manager_state = ManagerState.SWITCHING
                _log("ARMED → SWITCHING")

        ManagerState.SWITCHING:
            _execute_switch()
            _manager_state = ManagerState.COOLDOWN
            _debounce_timer = debounce_guard_sec
            _log("SWITCHING → COOLDOWN")

        ManagerState.COOLDOWN:
            if _reentry_reached and _debounce_timer <= 0.0:
                _manager_state = ManagerState.IDLE
                _log("COOLDOWN → IDLE (re-entry confirmed)")
```

### 6. Variant Swap Implementation

The actual swap is ~15 lines. Both variant groups are always in the scene
tree — only visibility and processing are toggled.

```gdscript
func _execute_switch() -> void:
    if not _has_pending_auth:
        return

    var old_state := _active_state
    var new_state := _pending_target

    # No-op guard
    if old_state == new_state:
        _has_pending_auth = false
        _log("No-op: target state == active state")
        return

    # Swap variants
    _set_variant_active(_variant_a, new_state == CorridorState.State.STATE_A)
    _set_variant_active(_variant_b, new_state == CorridorState.State.STATE_B)

    _active_state = new_state
    _has_pending_auth = false
    corridor_state_changed.emit(old_state, new_state)
    _log("Switched: %s → %s" % [old_state, new_state])


func _set_variant_active(variant: Node3D, active: bool) -> void:
    variant.visible = active
    variant.process_mode = Node.PROCESS_MODE_INHERIT if active else Node.PROCESS_MODE_DISABLED
```

`PROCESS_MODE_DISABLED` stops audio playback, interaction processing, and
animation on all children of the hidden variant. No per-node cleanup needed.

### 7. Authorization Interface

```gdscript
func authorize_switch(target_state: CorridorState.State) -> void:
    if _has_pending_auth:
        push_warning("CorridorStateManager: authorize_switch() called with pending auth — rejected")
        return
    if target_state == _active_state:
        _log("authorize_switch: target == active, will no-op on execution")
    _pending_target = target_state
    _has_pending_auth = true
    _log("Authorization granted: target=%s" % target_state)


func revoke_authorization() -> void:
    if _has_pending_auth:
        _has_pending_auth = false
        _log("Authorization revoked")
    if _manager_state == ManagerState.ARMED:
        _manager_state = ManagerState.IDLE
        _log("ARMED → IDLE (authorization revoked)")


func get_active_state() -> CorridorState.State:
    return _active_state
```

### 8. What Lives Where — Responsibility Map

| Concern | Owner | Notes |
|---------|-------|-------|
| Which variant nodes to show/hide | CorridorStateManager | Toggles VariantA/VariantB visibility + process_mode |
| When to authorize a switch | Event Sequencer (separate script) | Calls `authorize_switch()` and `revoke_authorization()` |
| When to revoke stale authorization | Event Sequencer | Revokes on beat advance, pause/resume, or traversal abandon |
| Ambient audio crossfade on state change | Audio Manager (separate script) | Listens to `corridor_state_changed` signal |
| Global audio stingers on first B entry | Event Sequencer → Audio Manager | Sequencer listens to signal, tells Audio Manager to play stinger |
| Door interaction logic | Interaction System (per-interactable scripts) | Reads enabled/visible state set by corridor manager |
| Corridor-local audio emitters | VariantA/VariantB child AudioStreamPlayer3D nodes | Managed by process_mode toggle — no manual start/stop |
| Trigger volume placement | Level designer (scene editor) | Positioned per GDD trigger sizing guidelines |
| Player detection in triggers | CorridorStateManager._ready() signal wiring | Filters by player reference to ignore other bodies |
| Debug force-state | CorridorStateManager | Checked in _ready() for debug builds only |

### 9. File List (MVP)

```
src/
├── corridor/
│   ├── corridor_state.gd          # CorridorState enum (~10 lines)
│   └── corridor_state_manager.gd  # CorridorStateManager (~120 lines)
assets/
└── scenes/
    └── corridor/
        └── Corridor.tscn          # The corridor scene (all nodes above)
```

Two GDScript files. One scene. That's the entire system.

---

## Alternatives Considered

### A: Resource-based state definitions (CorridorStateData as Resource)

Store each state's configuration in a `.tres` Resource file with arrays of
node paths and property overrides. The manager reads the resource and applies
changes generically.

**Rejected because:** Adds abstraction before it's needed. With only two
states, hardcoded VariantA/VariantB groups are simpler, faster to author in
the editor, and easier to debug visually. If a third state is added later,
refactoring to Resources is a 1–2 hour task, not a rewrite.

### B: Node groups instead of parent containers

Tag State A nodes with Godot group `"variant_a"` and State B with
`"variant_b"`. Manager queries groups at runtime.

**Rejected because:** Groups are invisible in the scene tree hierarchy, making
visual inspection harder. A parent container (VariantA/VariantB) is visible,
selectable, and togglable in the editor. Groups also can't toggle
`process_mode` on a subtree in one call.

### C: Single-node property overrides (same door node, different properties per state)

Instead of duplicating doors per state, use one door node and change its
`rotation`, `collision_layer`, etc. per state.

**Rejected because:** Mixes base geometry with variant state, violating Rule 9
(whitelisted nodes only). Also harder to author — the designer must remember
which properties to change rather than just placing two versions side by side.
The duplication cost of a few door meshes is negligible.

---

## Consequences

**Positive:**
- Two files, one scene — entire system is graspable in a single session
- Variant swap is a visibility toggle — no serialization, no resource loading
- Audio stops automatically via `PROCESS_MODE_DISABLED`
- Deferred state resolution prevents signal-ordering bugs
- Node structure is visually inspectable in the Godot editor
- Adding new variant elements = add a child to VariantA and VariantB

**Negative:**
- Duplicated door meshes and props in the scene tree (minor memory overhead)
- If a third state is added, a third VariantC group must be authored manually
- CorridorStateManager references siblings by path — renaming the Variant
  nodes breaks the references (mitigated by @onready + clear naming)

**Risks:**
- If the corridor scene becomes very large, toggling visibility on a deep
  subtree could cause a minor frame hitch. Mitigated by keeping variant groups
  small (per the GDD's state difference budget: 2–5 elements).

---

## References

- GDD: `design/gdd/corridor-transformation-system.md`
- Engine: Godot 4.6.1-stable, GDScript
- Godot docs: Node.process_mode, Node3D.visible
