# Красная кнопка

The canonical game is the JavaScript game in `js/`, served by the root
`index.html`. GitHub Pages publishes `main` from the repository root, so the
root entry point IS the game. This is the version with the full set of
mechanics: building, crafting, workbench tiers, seven guns plus the sawn-off,
farming, traders, missions, machines and power. Ship gameplay work here.

`Красная кнопка v2.html` is that same game inlined into one file — rebuild it
with `python3 собрать_одним_файлом.py` after every change under `js/`, or it
falls behind the sources.

The Godot 4.7 project in `godot/` and its Web build in `web/` are a partial
port: they carry only a subset of the mechanics. Keep them, but do NOT make
them the public entry point again — that swap is what silently removed the
player's mechanics from the published game (commit a7e56b0, reverted).

A standalone WebGL 3D version existed under `3d/` and `godot/scripts/three/`.
The player rejected it; it was deleted on purpose. Do not resurrect it.

## GodotPrompter

This is a Godot project with GodotPrompter skills available. Before implementing any game system, you MUST check for a matching `godot-prompter:*` skill and invoke it. This applies to all agents, subagents, and sessions working in this repository.

Key skills: `player-controller`, `state-machine`, `event-bus`, `scene-organization`, `component-system`, `resource-pattern`, `godot-ui`, `hud-system`, `ai-navigation`, `camera-system`, `audio-system`, `save-load`, `inventory-system`, `godot-testing`.

For the full skill list, invoke `godot-prompter:using-godot-prompter`.
