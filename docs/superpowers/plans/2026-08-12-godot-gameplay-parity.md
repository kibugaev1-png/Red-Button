# Godot Gameplay Parity Implementation Plan

**Goal:** Make the current Godot build the coherent, public game by porting the old browser start loop and its minimum supporting systems.

**Architecture:** Keep the programmatic root scene. Add isolated inventory, interaction and combat nodes; integrate them through `game.gd`; extend JSON persistence with a backward-compatible schema; publish the existing `web/` export through a root redirect.

## Tasks

- [ ] Add failing unit tests, then implement item catalog and 30-slot inventory with six-slot hotbar and serialization.
- [ ] Add failing unit tests, then implement nearest-interaction coordination, world items and one-shot loot crates.
- [ ] Add failing unit tests, then implement a basic enemy FSM, damage and state round-trip.
- [ ] Integrate exact start loot, pickup/equip/use, mining drops, hotbar and inventory UI.
- [ ] Integrate melee/pistol combat, reload, player damage/death and notifications.
- [ ] Upgrade saves to v2 with v1 migration and world-entity persistence.
- [ ] Run all headless tests, executable smokes, screenshots and log scans; fix every discovered defect.
- [ ] Export Web, replace the public root with a relative redirect, update launch/publish helpers and documentation.
- [ ] Commit, push feature branch, merge with `--no-ff`, push `main`, verify GitHub Pages, delete feature branch.
