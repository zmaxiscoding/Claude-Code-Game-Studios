# Godot — Breaking Changes (4.3 → 4.6.1-stable)

Last verified: 2026-03-28 | Project target: Godot 4.6.1-stable

Changes between Godot versions, focused on post-LLM-cutoff changes (4.4+).
Includes API-level detail from official migration guides.

**Relevance key:** ★ = likely affects project 03:17, ○ = noted for completeness

---

## 4.5 → 4.6 (Jan 2026 — POST-CUTOFF, HIGH RISK)

### Animation ★

- `AnimationPlayer.assigned_animation`: type `String` → `StringName`
- `AnimationPlayer.autoplay`: type `String` → `StringName`
- `AnimationPlayer.current_animation`: type `String` → `StringName`
- `AnimationPlayer.get_queue()`: return type `PackedStringArray` → `StringName[]`
- `AnimationPlayer.current_animation_changed` signal: param type `String` → `StringName`

> **03:17 impact**: GDScript `==` comparison works across String/StringName.
> But typed `Array[String]` won't accept `StringName` without conversion.
> Prefer `StringName` for animation names in new code.

### Rendering ★

| Setting | Old Default | New Default |
|---------|-------------|-------------|
| `Environment.glow_blend_mode` | Soft Light (2) | Screen (1) |
| `Environment.glow_intensity` | 0.8 | 0.3 |
| `Environment.glow_levels` (2–5) | Various | Adjusted |
| `Environment.ssr_depth_tolerance` | 0.2 | 0.5 |
| `rendering/reflections/sky_reflections/roughness_layers` | 8 | 7 |

- **Volumetric fog**: Blending adjusted for physical accuracy — appears brighter. ★
- **Glow**: Now blended before tonemapping. Mobile renderer significantly altered. ★
- **SSR**: Completely overhauled — improved roughness, half-res mode available. ★

> **03:17 impact**: Glow and fog are critical for atmosphere. Do NOT use
> pre-4.6 tutorial values. Start from 4.6 defaults and tune.

### Physics ★

| Change | Details |
|--------|---------|
| Jolt is now default 3D physics engine | New projects use Jolt automatically |
| IK system restored | CCDIK, FABRIK, Jacobian IK, Spline IK, TwoBoneIK via SkeletonModifier3D |

### Core

- `FileAccess.create_temp()`: `mode_flags` param type `int` → `FileAccess.ModeFlags`. ○
- `FileAccess.get_as_text()`: `skip_cr` parameter removed. ○
- `Performance.add_custom_monitor()`: optional `type` parameter added. ○

### Pathfinding ★

- **AStar methods**: Return empty path when source is disabled/solid point (was partial path). ★

### 3D

- `MeshInstance3D.skeleton`: default `NodePath("..")` → `NodePath("")`. ○
- `SpringBoneSimulator3D` enum types moved to `SkeletonModifier3D`. ○

### GUI

- `PopupMenu.submenu_popup_delay`: default 0.3 → 0.2. ○
- `Control.grab_focus()`: optional `hide_focus` parameter added. ○
- `EditorFileDialog.add_side_menu()`: removed (moved to base `FileDialog`). ○

### Networking ○

- `StreamPeerTCP.disconnect_from_host/get_status/poll` → moved to `StreamPeerSocket`
- `TCPServer.is_connection_available/is_listening/stop` → moved to `SocketServer`

### Shaders ★ (UNDOCUMENTED — GitHub issue godotengine/godot-docs#11744)

- GLSL `view_matrix` and `inv_view_matrix` from `SceneData` uniform changed
  from `mat4` to `mat3x4`. Custom GLSL shaders using these need transposed
  matrix operations.

### Scene Files ○

- `load_steps` no longer written to `.tscn`/`.tres`
- Unique node IDs now saved (tracks moved/renamed nodes)
- Both backwards-compatible. Expect large VCS diffs on first re-save.
- Use **Project > Tools > Upgrade Project Files...** then commit.

### Editor/Workflow

- "Select Mode" (v key) prevents accidental transforms; old mode renamed "Transform Mode" (q key)
- New "Modern" editor theme enabled by default
- D3D12 default renderer on Windows (was Vulkan)

---

## 4.4 → 4.5 (Late 2025 — POST-CUTOFF, HIGH RISK)

### Core ★

- `JSONRPC.set_scope()` → `set_method()`. Incompatible — no shim. ○
- `Node.get_rpc_config()` → `get_node_rpc_config()`. Shim active. ○
- **`Resource.duplicate(true)`**: Now duplicates only internal resources. Use
  `duplicate_deep(DEEP_DUPLICATE_ALL)` for old behavior. ★

### Rendering

- `RenderingServer.instance_reset_physics_interpolation()`: Removed. ○
- `RenderingServer.instance_set_interpolated()`: Removed. ○

### Physics ★

- **Area3D overlaps with static bodies** always reported now (Jolt behavior).
  Filter with collision mask/layer. ★

### Navigation ★

- **Regions update asynchronously by default.** Toggle:
  `navigation/world/region_use_async_iterations`. ★

### 3D Import

- New `.gltf`, `.glb`, `.blend`, `.fbx` files import with corrected skeleton
  behavior. Existing files keep old behavior unless "Naming Version" updated. ○

### Text Rendering

- `RichTextLabel.add_image()`: `size_in_percent` replaced with `width_in_percent`
  and `height_in_percent`. Compatible. ○
- Font/text drawing methods add optional `oversampling` parameter. Compatible. ○

### GDScript (New Features, Not Breaking)

- Variadic arguments (`...` syntax)
- `@abstract` decorator
- Script backtracing in Release builds
- Shader Baker (pre-compile shaders)
- SMAA 1x antialiasing option

### Accessibility

- Screen reader support via AccessKit
- FoldableContainer node
- Recursive Control disable

---

## 4.3 → 4.4 (Mid 2025 — NEAR CUTOFF, VERIFY)

### Core

- **FileAccess store methods** (`store_8` through `store_var`): return type
  `void` → `bool`. ○
- `OS.execute_with_pipe`: optional `blocking` parameter added. ○
- `RegEx.compile/create_from_string`: optional `show_error` parameter added. ○

### Rendering

- `RenderingDevice.draw_list_begin`: many parameters removed; `breadcrumb` added. ○
- `Shader.get/set_default_texture_parameter`: type `Texture2D` → `Texture`. ○
- `VisualShaderNodeCubemap.cube_map`: `Cubemap` → `TextureLayered`. ○
- `VisualShaderNodeTexture2DArray.texture_array`: `Texture2DArray` → `TextureLayered`. ○

### Particles

- `CPUParticles2D/3D, GPUParticles2D/3D.restart()`: optional `keep_seed` param. ○

### Navigation

- `NavigationServer2D/3D.query_path()`: optional `callback` parameter. ○

---

## 4.2 → 4.3 (In Training Data — LOW RISK)

| Subsystem | Change | Details |
|-----------|--------|---------|
| Animation | `Skeleton3D.add_bone` returns `int32` | Was `void` |
| Animation | `bone_pose_updated` signal | Replaced by `skeleton_updated` |
| TileMap | `TileMapLayer` replaces `TileMap` | One node per layer |
| Navigation | `NavigationRegion2D` | Removed `avoidance_layers`, `constrain_avoidance` |
| Editor | `EditorSceneFormatImporterFBX` | Renamed to `EditorSceneFormatImporterFBX2GLTF` |
| Animation | AnimationMixer base class | AnimationPlayer and AnimationTree extend it |
