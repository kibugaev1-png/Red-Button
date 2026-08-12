# Cinematic Photo World Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Deliver a polished, saveable Godot 4.7 game shell around the existing destructible photo-biome world.

**Architecture:** Keep the single programmatic root scene and add focused child-node managers for flow, transitions, dialogue, audio, menus, and world interaction. Preserve the existing terrain/player implementation and communicate through signals and explicit typed methods.

**Tech Stack:** Godot 4.7.1, typed GDScript, CanvasItem shaders, Control/Container UI, ConfigFile saves.

## Global Constraints

- Use only the six repository photo panoramas and existing material textures.
- Preserve photo proportions and use cover/crop instead of deformation.
- Keep the 1280×720 render budget and `canvas_items` stretch for performance.
- No random music or external art assets.
- Every completed slice must pass headless import and an executable smoke run.

---

### Task 1: Flow and persistence foundation

**Files:** Create `godot/scripts/managers/game_manager.gd`, `godot/scripts/managers/audio_manager.gd`; create `godot/tests/test_game_manager.gd`; modify `godot/scripts/game.gd`.

**Interfaces:** `GameManager.has_save() -> bool`, `save_game(game: Node) -> bool`, `load_game(game: Node) -> bool`, `new_game(game: Node) -> void`; `AudioManager.ensure_buses() -> void`.

- [ ] Write a failing headless test for missing save, round-trip save and malformed save handling.
- [ ] Run the test and confirm failure because `GameManager` does not exist.
- [ ] Implement typed ConfigFile persistence and idempotent audio-bus setup.
- [ ] Run the test and headless import until both pass.
- [ ] Commit the slice.

Skills: `gdscript-patterns`, `save-load`, `audio-system`, `godot-testing`.

### Task 2: Transition, menu and pause shell

**Files:** Create `godot/scripts/managers/transition_manager.gd`, `godot/scripts/ui/main_menu.gd`, `godot/scripts/ui/ui_style.gd`; modify `godot/scripts/game.gd`, `godot/project.godot`.

**Interfaces:** `TransitionManager.fade_from_black()`, `fade_to_black(callback)`; `MainMenu.start_requested`, `continue_requested`, `save_requested`, `resume_requested`, `menu_requested`.

- [ ] Add a smoke assertion that named menu controls exist and initial gameplay is paused.
- [ ] Confirm it fails against the current game.
- [ ] Implement photo-cover menu, custom theme styles, settings, pause screen and transition overlay.
- [ ] Verify menu and gameplay screenshots plus keyboard focus.
- [ ] Commit the slice.

Skills: `godot-ui`, `responsive-ui`, `tween-animation`, `camera-system`.

### Task 3: Dialogue and interaction

**Files:** Create `godot/scripts/systems/dialog_manager.gd`, `godot/scripts/interactions/interaction_beacon.gd`; modify `godot/scripts/game.gd`, `godot/scripts/player.gd`.

**Interfaces:** `DialogManager.show_dialogue(lines: Array[Dictionary])`; `InteractionBeacon.interacted`, `set_player(player: Node2D)`.

- [ ] Add a smoke mode that moves the player to the beacon and triggers interaction.
- [ ] Confirm it fails before the nodes exist.
- [ ] Implement an Area2D hotspot, proximity prompt, typed dialogue, typewriter skip and input locking.
- [ ] Verify interaction and dialogue screenshots and logs.
- [ ] Commit the slice.

Skills: `dialogue-system`, `godot-ui`, `tween-animation`, `physics-system`.

### Task 4: Cinematic camera, atmosphere and HUD

**Files:** Modify `godot/scripts/game.gd`, `godot/scripts/hud.gd`, `godot/shaders/sky.gdshader`, `godot/shaders/post.gdshader`, `godot/scripts/zone_look.gd`.

**Interfaces:** camera follow consumes player velocity; HUD exposes `notify(text)` and `set_interaction_prompt(text)`.

- [ ] Capture the baseline at representative zones.
- [ ] Implement look-ahead, restrained idle drift, layered dust, zone arrival cards and premium adaptive HUD.
- [ ] Tune every panorama independently without hiding its photographic identity.
- [ ] Capture all six zones and compare for readability and visual continuity.
- [ ] Commit the slice.

Skills: `camera-system`, `2d-essentials`, `particles-vfx`, `shader-basics`, `hud-system`, `responsive-ui`.

### Task 5: Full verification and delivery

**Files:** Modify any affected files needed to correct discovered defects; update the plan checkboxes.

- [ ] Run headless import and test scripts.
- [ ] Run new game, continue, save, pause and interaction smoke scenarios.
- [ ] Capture 1280×720, 1920×1080, 2560×1440 and a non-16:9 frame.
- [ ] Search logs for parser/runtime/resource errors and repair every defect.
- [ ] Review GDScript against the Godot checklist.
- [ ] Merge with `--no-ff`, push `main`, and remove the feature branch.

Skills: `godot-testing`, `godot-debugging`, `godot-code-review`, `godot-optimization`, `superpowers:verification-before-completion`.

