# Godot — Deprecated & Removed APIs (up to 4.6.1-stable)

Last verified: 2026-03-28 | Project target: Godot 4.6.1-stable

If an agent suggests any API in the "Deprecated" column, it MUST be replaced
with the "Use Instead" column.

## Nodes & Classes

| Deprecated | Use Instead | Since | Notes |
|------------|-------------|-------|-------|
| `TileMap` | `TileMapLayer` | 4.3 | One node per layer instead of multi-layer node |
| `VisibilityNotifier2D` | `VisibleOnScreenNotifier2D` | 4.0 | Renamed for clarity |
| `VisibilityNotifier3D` | `VisibleOnScreenNotifier3D` | 4.0 | Renamed for clarity |
| `YSort` | `Node2D.y_sort_enabled` | 4.0 | Property on Node2D, not a separate node |
| `Navigation2D` / `Navigation3D` | `NavigationServer2D` / `NavigationServer3D` | 4.0 | Server-based API |
| `EditorSceneFormatImporterFBX` | `EditorSceneFormatImporterFBX2GLTF` | 4.3 | Renamed |

## Methods & Properties

| Deprecated | Use Instead | Since | Notes |
|------------|-------------|-------|-------|
| `yield()` | `await signal` | 4.0 | GDScript 2.0 coroutine syntax |
| `connect("signal", obj, "method")` | `signal.connect(callable)` | 4.0 | Callable-based connections |
| `instance()` | `instantiate()` | 4.0 | Renamed |
| `PackedScene.instance()` | `PackedScene.instantiate()` | 4.0 | Renamed |
| `get_world()` | `get_world_3d()` | 4.0 | Explicit 2D/3D split |
| `OS.get_ticks_msec()` | `Time.get_ticks_msec()` | 4.0 | Time singleton preferred |
| `duplicate()` for nested resources | `duplicate_deep()` | 4.5 | Explicit deep copy control |
| `Skeleton3D` signal `bone_pose_updated` | `skeleton_updated` | 4.3 | Renamed |
| `AnimationPlayer.method_call_mode` | `AnimationMixer.callback_mode_method` | 4.3 | Moved to base class |
| `AnimationPlayer.playback_active` | `AnimationMixer.active` | 4.3 | Moved to base class |
| `EditorScript.get_scene()` | Use alternative editor APIs | 4.6 | Deprecated (editor-only) |
| `JSONRPC.set_scope()` | `JSONRPC.set_method()` | 4.5 | Direct rename, no shim |

## Removed in 4.5

| Old API | Replacement | Notes |
|---------|-------------|-------|
| `RenderingServer.instance_reset_physics_interpolation()` | N/A — 3D physics interpolation moved to SceneTree | Internals changed; user API preserved on Node3D |
| `RenderingServer.instance_set_interpolated()` | N/A — same as above | |

## Moved in 4.6

| Old Location | New Location | Notes |
|-------------|--------------|-------|
| `StreamPeerTCP.disconnect_from_host()` | `StreamPeerSocket.disconnect_from_host()` | Networking refactor |
| `StreamPeerTCP.get_status()` | `StreamPeerSocket.get_status()` | |
| `StreamPeerTCP.poll()` | `StreamPeerSocket.poll()` | |
| `TCPServer.is_connection_available()` | `SocketServer.is_connection_available()` | |
| `TCPServer.is_listening()` | `SocketServer.is_listening()` | |
| `TCPServer.stop()` | `SocketServer.stop()` | |
| `EditorFileDialog.add_side_menu()` | Moved to base `FileDialog` class | Editor-only |

## Type Changes in 4.6 (Not Removals, But Watch For)

| API | Old Type | New Type | Notes |
|-----|----------|----------|-------|
| `AnimationPlayer.assigned_animation` | `String` | `StringName` | GDScript auto-converts, but typed arrays may warn |
| `AnimationPlayer.autoplay` | `String` | `StringName` | Same |
| `AnimationPlayer.current_animation` | `String` | `StringName` | Same |
| `AnimationPlayer.get_queue()` return | `PackedStringArray` | `StringName[]` | |
| `FileAccess.create_temp()` mode_flags | `int` | `FileAccess.ModeFlags` | Use enum instead of raw int |

## Compatibility Shims Still Active

These old names still work via compatibility layer but should not be used in new code:

| Old Name | New Name | Version |
|----------|----------|---------|
| `Node.get_rpc_config()` | `Node.get_node_rpc_config()` | 4.5+ |

## Patterns (Not Just APIs)

| Deprecated Pattern | Use Instead | Why |
|--------------------|-------------|-----|
| String-based `connect()` | Typed signal connections | Type-safe, refactor-friendly |
| `$NodePath` in `_process()` | `@onready var` cached reference | Performance: path lookup every frame |
| Untyped `Array` / `Dictionary` | `Array[Type]`, typed variables | GDScript compiler optimizations |
| `Texture2D` in shader parameters | `Texture` base type | Changed in 4.4 |
| Manual post-process viewport chains | `Compositor` + `CompositorEffect` | Structured post-processing (4.3+) |
| GodotPhysics3D for new projects | Jolt Physics 3D | Default since 4.6; better stability |
| `Resource.duplicate(true)` for deep copies | `Resource.duplicate_deep()` | Explicit control (4.5+) |
