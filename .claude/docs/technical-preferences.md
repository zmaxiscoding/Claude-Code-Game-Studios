# Technical Preferences

<!-- Populated by /setup-engine. Updated as the user makes decisions throughout development. -->
<!-- All agents reference this file for project-specific standards and conventions. -->

## Engine & Language

- **Engine**: Godot 4.6.1-stable
- **Language**: GDScript (primary)
- **Rendering**: Forward+ (3D, PC — best visual quality for atmospheric horror)
- **Physics**: Jolt (default in 4.6; stable, fast, recommended for new projects)

## Naming Conventions

- **Classes**: PascalCase (e.g., `PlayerController`)
- **Variables/Functions**: snake_case (e.g., `move_speed`, `get_health`)
- **Signals**: snake_case past tense (e.g., `health_changed`, `door_opened`)
- **Files**: snake_case matching class (e.g., `player_controller.gd`)
- **Scenes**: PascalCase matching root node (e.g., `PlayerController.tscn`)
- **Constants**: UPPER_SNAKE_CASE (e.g., `MAX_WALK_SPEED`)

## Performance Budgets

- **Target Framerate**: 60fps
- **Frame Budget**: 16.6ms
- **Draw Calls**: ≤400 (atmospheric first-person, modest geometry)
- **Memory Ceiling**: 1GB (PC target, no streaming required at this scope)

## Testing

- **Framework**: Manual QA checklist for Sprint 1 (vertical slice)
- **Minimum Coverage**: Not enforced during vertical slice
- **Formal Testing**: Add GUT addon later if corridor state logic, trigger sequencing, or audio systems become complex enough to justify it
- **Required Tests**: Balance formulas, gameplay systems (deferred until post-slice)

## Forbidden Patterns

<!-- Add patterns that should never appear in this project's codebase -->
- [None configured yet — add as architectural decisions are made]

## Allowed Libraries / Addons

<!-- Add approved third-party dependencies here -->
- [None configured yet — add as dependencies are approved]

## Architecture Decisions Log

<!-- Quick reference linking to full ADRs in docs/architecture/ -->
- **ADR-001**: [Corridor Transformation Node Structure](../../docs/architecture/adr-001-corridor-transformation-node-structure.md) — Scene tree layout, variant groups, state manager script, trigger wiring
