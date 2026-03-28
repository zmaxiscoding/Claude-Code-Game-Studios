## Reusable trigger zone — Area3D wrapper for spatial event detection.
##
## Filters for bodies in the "player" group. Emits named signals with the
## zone_name so listeners can identify which zone fired without needing
## a direct reference.
##
## Used by: Event Sequencer (condition source), Corridor Transformation
## (end triggers, safe zones, re-entry), Puzzle Controller (progression gates).

class_name TriggerZone
extends Area3D


## Emitted when a player-group body enters this zone.
signal player_entered(zone_name: StringName)

## Emitted when a player-group body exits this zone.
signal player_exited(zone_name: StringName)


## Identifier for this zone. Used in signal payloads and debug output.
## Must be unique per scene — not enforced, but duplicates will cause
## ambiguous signal routing.
@export var zone_name: StringName = &""

## If true, player_entered fires only once. The zone stays active for
## player_exited but will not re-fire player_entered after the first entry.
@export var one_shot: bool = false

## Print enter/exit events to console.
@export var debug_enabled: bool = true


var _has_fired: bool = false


func _ready() -> void:
	body_entered.connect(_on_body_entered)
	body_exited.connect(_on_body_exited)
	if debug_enabled:
		print("[TriggerZone] Ready: ", zone_name)


func _on_body_entered(body: Node3D) -> void:
	if not body.is_in_group(&"player"):
		return
	if one_shot and _has_fired:
		return
	_has_fired = true
	if debug_enabled:
		print("[TriggerZone] Player entered: ", zone_name)
	player_entered.emit(zone_name)


func _on_body_exited(body: Node3D) -> void:
	if not body.is_in_group(&"player"):
		return
	if debug_enabled:
		print("[TriggerZone] Player exited: ", zone_name)
	player_exited.emit(zone_name)


## Reset the one_shot guard so the zone can fire again.
## Called by Event Sequencer or debug tools if a zone needs reactivation.
func reset() -> void:
	_has_fired = false
	if debug_enabled:
		print("[TriggerZone] Reset: ", zone_name)
