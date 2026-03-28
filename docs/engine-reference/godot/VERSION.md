# Godot Engine — Version Reference

| Field | Value |
|-------|-------|
| **Engine Version** | Godot 4.6.1-stable |
| **Release Date** | ~February 2026 (maintenance patch) |
| **Project Pinned** | 2026-03-28 |
| **Last Docs Verified** | 2026-03-28 |
| **LLM Knowledge Cutoff** | May 2025 |

## Knowledge Gap Warning

The LLM's training data likely covers Godot up to ~4.3. Versions 4.4, 4.5,
and 4.6 introduced significant changes that the model does NOT know about.
Always cross-reference this directory before suggesting Godot API calls.

## Post-Cutoff Version Timeline

| Version | Release | Risk Level | Key Theme |
|---------|---------|------------|-----------|
| 4.4 | ~Mid 2025 | MEDIUM | Jolt physics option, FileAccess return types, shader texture type changes |
| 4.5 | ~Late 2025 | HIGH | Accessibility (AccessKit), variadic args, @abstract, shader baker, SMAA, Resource.duplicate changes |
| 4.6 | Jan 2026 | HIGH | Jolt default, glow rework, D3D12 default on Windows, IK restored, SSR overhaul |
| 4.6.1 | ~Feb 2026 | LOW | Maintenance patch — regression fixes only |

## Pinning Policy

This project targets **4.6.1-stable**. Do not use 4.6.2 RC, dev snapshots, or
any pre-release build. If a newer stable patch (4.6.2, 4.6.3) ships, evaluate
the changelog before upgrading.

## Verified Sources

- Official docs: https://docs.godotengine.org/en/stable/
- 4.5→4.6 migration: https://docs.godotengine.org/en/stable/tutorials/migrating/upgrading_to_godot_4.6.html
- 4.4→4.5 migration: https://docs.godotengine.org/en/4.5/tutorials/migrating/upgrading_to_godot_4.5.html
- Changelog: https://github.com/godotengine/godot/blob/master/CHANGELOG.md
- Release notes (4.6): https://godotengine.org/releases/4.6/
- 4.6.1 patch notes: https://godotengine.org/article/maintenance-release-godot-4-6-1/
- Breaking changes gist: https://gist.github.com/raulsntos/06ac5dd10ebccc3a4f1e7e3ad30dc876
