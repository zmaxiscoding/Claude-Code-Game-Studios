# Godot 4.6.1-stable — Current Best Practices

Last verified: 2026-03-28 | Project target: Godot 4.6.1-stable

Practices that are **new or changed** since the model's training data (~4.3).
This supplements (not replaces) the agent's built-in knowledge.
Items marked ★ are especially relevant to project 03:17.

---

## GDScript (4.5+)

- **Variadic arguments**: Functions can accept arbitrary parameter counts
  ```gdscript
  func log_values(prefix: String, values: Variant...) -> void:
      for v in values:
          print(prefix, ": ", v)
  ```

- **Abstract classes and methods**: Use `@abstract` to enforce inheritance
  ```gdscript
  @abstract
  class_name BaseEnemy extends CharacterBody3D

  @abstract
  func get_attack_pattern() -> Array[Attack]:
      pass  # Subclasses MUST override
  ```

- **Script backtracing**: Detailed call stacks available even in Release builds

- **StringName preference** ★: AnimationPlayer now uses `StringName` for animation
  properties. In new GDScript code, prefer `StringName` for animation names, node
  paths, and signal names. `String` and `StringName` compare correctly with `==`,
  but typed `Array[String]` won't accept `StringName`.

## Physics (4.6) ★

- **Jolt Physics is the default 3D engine** for new projects
  - Better determinism and stability than GodotPhysics3D
  - Some HingeJoint3D properties (`damp`) only work with GodotPhysics
  - Switch: Project Settings → Physics → 3D → Physics Engine
  - 2D physics unchanged (still Godot Physics 2D)
  - **Area3D overlaps with static bodies** always reported — use collision
    mask/layer to filter unwanted overlaps ★

## Rendering: Glow & Fog (4.6) ★

- **Glow defaults completely changed**:
  - Blend mode: Screen (was Soft Light)
  - Intensity: 0.3 (was 0.8)
  - Glow now blended **before tonemapping**
  - Mobile renderer glow significantly altered

> **03:17**: Glow and fog are core to atmospheric horror. Do NOT copy glow values
> from pre-4.6 tutorials. Start from 4.6 defaults and tune incrementally.

- **Volumetric fog appears brighter** due to physically correct blending.
  Start with lower density values than older tutorials suggest. ★

## Rendering: SSR (4.6) ★

- Screen Space Reflections completely overhauled
  - Improved roughness handling
  - Half-resolution mode for performance
  - Depth tolerance default: 0.5 (was 0.2)

> **03:17**: SSR on wet corridors and reflective surfaces will look better than
> pre-4.6 tutorials show. Worth enabling for atmospheric gains.

## Rendering: Other (4.5–4.6)

- **D3D12 is the default Windows backend** (was Vulkan) — for better driver compatibility
- **AgX tonemapper**: New white point and contrast controls
- **Shader Baker** (4.5): Pre-compile shaders — eliminates startup hitching ★
- **SMAA 1x** (4.5): New AA option — sharper than FXAA, cheaper than TAA ★
- **Stencil buffer** (4.5): Available for advanced masking/portal effects ★
- **Bent normal maps, specular occlusion** (4.5): Enhanced material realism

> **03:17**: Shader Baker prevents stuttering on first encounter with new
> shaders. Important for a horror game where smooth pacing matters.
> SMAA is likely the right AA choice for our visual style.
> Stencil buffer could enable corridor transformation illusions.

## IK System (4.6)

- Complete inverse kinematics restored: CCDIK, FABRIK, Jacobian IK, Spline IK,
  TwoBoneIK via `SkeletonModifier3D` nodes
- Unlikely to need for 03:17 (no character animation), but noted.

## Navigation (4.5+) ★

- **Async region updates by default.** NavigationServer regions update
  asynchronously for performance. Toggle:
  `navigation/world/region_use_async_iterations` in Project Settings.

> **03:17**: If corridor transformations touch navigation and something feels
> laggy, check this setting first.

## Resources (4.5+)

- **`duplicate_deep()`**: Explicit deep duplication for nested resource trees
  - Old `duplicate(true)` only copies internal resources now
  - Use `duplicate_deep(DEEP_DUPLICATE_ALL)` for full deep copies

## Accessibility (4.5+)

- Screen reader support via AccessKit
- FoldableContainer accordion node
- Recursive Control disable for node hierarchies
- Live translation preview in editor

## Scene Files (4.6) ★

- `load_steps` removed from `.tscn`/`.tres`; unique node IDs added
- Backwards-compatible, but **first re-save produces large VCS diffs**
- Use **Project > Tools > Upgrade Project Files...** then commit separately
- This is a one-time operation — do it before starting development ★

## Editor Workflow (4.6)

- **Decoupled Select and Transform**: Select Mode (v key) prevents accidental
  transforms; old mode renamed Transform Mode (q key)
- "Modern" editor theme enabled by default (grayscale, reduced visual clutter)
- Flexible dock drag-and-drop, floating windows (except Debugger)
- Export variable auto-generation from FileSystem dock
- Alt+O (Output), Alt+S (Shader) keyboard shortcuts

## Platform (4.5–4.6)

- visionOS export (4.5)
- SDL3 gamepad driver (4.5)
- Android: edge-to-edge, camera feed, 16KB page support (4.5)
- Android: Scrcpy integration, SAF permissions, GABE companion (4.6)
- Linux: Wayland subwindow support (4.5)

## Performance Tools (4.6) ★

- **C++ tracing profiler support**: Tracy, Perfetto, Instruments integration
- **ObjectDB snapshots**: Compare memory snapshots to find leaks ★
- **3D texture import 2x faster** via GPU RGB-to-RGBA conversion
- **Delta encoding for patch PCKs**: Dramatically smaller update files ★
