# Systems Index: 03:17 — Vertical Slice

> **Status**: Approved
> **Created**: 2026-03-28
> **Last Updated**: 2026-03-28
> **Scope**: Vertical slice only (5–10 min playable). Not full game.

---

## Overview

03:17 is a short first-person psychological horror game set in an apartment
building at night. The vertical slice requires 10 systems to prove: movement
feel, visual tone, corridor transformation (core mechanic), one sound-driven
tension moment, one simple interaction/puzzle, and one ending beat.

The system count is intentionally minimal. Systems are scoped to what a solo
developer can implement in a 14-day sprint using Godot 4.6.1-stable and GDScript.
No combat, enemies, inventory, AI, branching narrative, or live service systems.

---

## Systems Enumeration

| # | System Name | Category | Priority | Status | Design Doc | Depends On |
|---|-------------|----------|----------|--------|------------|------------|
| 1 | First-Person Controller | Core | MVP | Not Started | — | (none) |
| 2 | Trigger Zone System | Core | MVP | Not Started | — | (none) |
| 3 | Debug Overlay | Meta | MVP | Not Started | — | (none) |
| 4 | Event Sequencer | Core | MVP | Designed | [GDD](event-sequencer.md) | Trigger Zone System |
| 5 | Audio Manager | Audio | MVP | Not Started | — | (none — signal listener) |
| 6 | Corridor Transformation System | Gameplay | MVP | Approved | [GDD](corridor-transformation-system.md), [ADR-001](../../docs/architecture/adr-001-corridor-transformation-node-structure.md) | Trigger Zone System, Event Sequencer |
| 7 | Interaction System | Gameplay | MVP | Not Started | — | First-Person Controller |
| 8 | Door System | Gameplay | Slice | Not Started | — | Interaction System |
| 9 | Simple Puzzle Controller | Gameplay | Slice | Not Started | — | Interaction System, Event Sequencer, Corridor Transformation |
| 10 | Slice Flow Controller | Core | Slice | Not Started | — | Event Sequencer, Audio Manager, First-Person Controller |

---

## Categories (used in this project)

| Category | Description |
|----------|-------------|
| **Core** | Foundation systems everything depends on |
| **Gameplay** | Systems that create the player experience |
| **Audio** | Sound and music systems |
| **Meta** | Development support tools |

Categories not used: Progression, Economy, Persistence, UI (beyond interact prompt), Narrative.

---

## Priority Tiers

| Tier | Definition | Count |
|------|------------|-------|
| **MVP** | Required for the core loop to function: walk, trigger, transform, hear. | 7 systems |
| **Slice** | Required to complete the vertical slice: puzzle, doors, ending. | 3 systems |

No Alpha or Full Vision tiers for this index — those will be mapped after the slice validates the concept.

---

## Dependency Map

### Foundation Layer (no dependencies)

1. **First-Person Controller** — The player's body. Everything needs a player in the world.
2. **Trigger Zone System** — Reusable Area3D wrapper. Used by corridor triggers, sequencer beats, puzzle gates.
3. **Debug Overlay** — Pure dev accelerator. No gameplay dependencies.
4. **Audio Manager** — Standalone bus/layer system. Receives signals but depends on nothing.

### Core Layer (depends on Foundation)

5. **Event Sequencer** — Depends on: Trigger Zone System. The pacing brain that drives progression.
6. **Interaction System** — Depends on: First-Person Controller. Raycast + prompt + dispatch.

### Feature Layer (depends on Core)

7. **Corridor Transformation System** — Depends on: Trigger Zone System, Event Sequencer. **Approved.**
8. **Door System** — Depends on: Interaction System. Open/close + collision toggle.
9. **Simple Puzzle Controller** — Depends on: Interaction System, Event Sequencer, Corridor Transformation.

### Integration Layer (depends on Feature)

10. **Slice Flow Controller** — Depends on: Event Sequencer, Audio Manager, First-Person Controller. Built last.

### Bottleneck Systems

| System | Downstream Dependents | Risk Level |
|--------|----------------------|------------|
| Trigger Zone System | Event Sequencer, Corridor Transformation, Puzzle | **High** — build first |
| First-Person Controller | Interaction, Puzzle, Slice Flow | **High** — build first |
| Event Sequencer | Corridor Transformation, Puzzle, Slice Flow | **High** — pacing brain |

### Circular Dependencies

None found. Clean DAG.

---

## Recommended Design Order

| Order | System | Priority | Layer | Est. GDD Effort | Notes |
|-------|--------|----------|-------|-----------------|-------|
| 1 | Corridor Transformation System | MVP | Feature | — | **Already approved** |
| 2 | First-Person Controller | MVP | Foundation | S | Minimal — walk + look + raycast |
| 3 | Trigger Zone System | MVP | Foundation | S | Minimal — reusable Area3D wrapper |
| 4 | Event Sequencer | MVP | Core | M | Key design decisions: beat format, data vs hardcode |
| 5 | Interaction System | MVP | Core | S | Raycast + prompt + action routing |
| 6 | Audio Manager | MVP | Foundation | S–M | Layer crossfade + stinger system |
| 7 | Debug Overlay | MVP | Foundation | S | Minimal — may not need a GDD at all |
| 8 | Door System | Slice | Feature | S | Thin — may not need its own GDD |
| 9 | Simple Puzzle Controller | Slice | Feature | S | One puzzle, hardcoded logic |
| 10 | Slice Flow Controller | Slice | Integration | S | Thin wrapper — fades + lifecycle |

Effort: S = 1 session (~30 min), M = 2–3 sessions.

**Not every system needs a full GDD.** Systems marked S that are thin wrappers
(Debug Overlay, Door System, Slice Flow Controller) can be specified in their
ADR or directly in code with inline comments. Full GDDs are recommended for:
Corridor Transformation (done), Event Sequencer, and Audio Manager.

---

## Stub & Fake Strategy

| System | Stub for First Playable | Replace With Real Implementation |
|--------|------------------------|--------------------------------|
| Event Sequencer | Hardcode 5-beat sequence in `_ready()` | Data-driven beat list (Day 10) |
| Audio Manager | Placeholder beep on state change | Real ambient layers + stingers (Days 8–10) |
| Simple Puzzle | Hardcode "correct door = 303" | Environmental clue system (Day 9) |
| Door System | Instant rotation, no animation | Animated open/close (Day 12 if time) |
| Slice Flow Controller | `print("GAME START/END")` | Fade in/out + timestamp (Day 12) |
| Debug Overlay | `print()` to console | On-screen overlay (only if needed) |

---

## Implementation Schedule (14-Day Sprint)

| Day | Focus | Systems Touched | Deliverable |
|-----|-------|----------------|-------------|
| 1 | Foundation | First-Person Controller, Trigger Zone System | Player walks, crosses triggers, sees console output |
| 2 | Environment | (scene authoring — not a system) | Lobby + stairwell + corridor blockout, walkable |
| 3 | Interaction | Interaction System, Door System (stub) | Player opens/closes doors |
| 4 | Core Mechanic | Corridor Transformation System | Corridor switches states on trigger traversal |
| 5 | Pacing | Event Sequencer (hardcoded) | Sequencer authorizes switches per beat — "it works" moment |
| 6 | Atmosphere | Audio Manager (placeholder) | Ambient layers swap, one stinger on first B-state |
| 7 | Buffer | All — bug fixes | Fix worst 3 problems, playtest the loop |
| 8 | Polish: Audio | Audio Manager (real assets) | Real ambient audio, lighting/visual tone pass |
| 9 | Content | Simple Puzzle Controller | Player finds number, interacts with correct door |
| 10 | Integration | Event Sequencer (full beats), Puzzle integration | Complete 5–10 min scripted sequence |
| 11 | Escalation | (content authoring — not a system) | Lights out, corridor elongation illusion, audio stacking |
| 12 | Ending | Slice Flow Controller, Door polish | Clean start, ending fade, timestamp |
| 13 | QA | All — integration playtest | Full run-through, critical fixes only |
| 14 | Ship | Export + assessment | Windows build, one-page assessment, go/no-go |

---

## High-Risk Systems

| System | Risk Type | Risk Description | Mitigation |
|--------|-----------|-----------------|------------|
| Corridor Transformation | Design | Core mechanic — if it doesn't feel uncanny, the game fails | GDD approved, ADR written, implement Day 4, playtest Day 7 |
| Event Sequencer | Scope | Could over-engineer into a full scripting language | Hardcode first, data-drive only if needed. No visual editor. |
| Audio Manager | Quality | Placeholder audio may mask atmosphere problems | Source real audio by Day 8. User's audio strength is an asset. |

---

## Progress Tracker

| Metric | Count |
|--------|-------|
| Total systems identified | 10 |
| Design docs started | 2 |
| Design docs reviewed | 2 |
| Design docs approved | 1 |
| MVP systems designed | 2/7 |
| Slice systems designed | 0/3 |

---

## Next Steps

- [ ] Design Event Sequencer (next highest-priority undesigned system)
- [ ] Design First-Person Controller (or skip GDD — may be simple enough for ADR)
- [ ] Run `/sprint-plan new` to create the tracked 14-day sprint
- [ ] Run `/gate-check pre-production` when MVP systems are designed
- [ ] Begin implementation: Day 1 = First-Person Controller + Trigger Zone System
