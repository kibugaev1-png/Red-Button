# Красная кнопка

The canonical game is the Godot 4.7 project in `godot/`. Its generated Web
release lives in `web/`; GitHub Pages publishes `main` from the repository root,
and the root entry point opens that Godot Web build.

The old `js/` game and `Красная кнопка v2.html` are legacy artifacts. Preserve
them unless a task explicitly removes them, but never use them as the current
public game or GitHub Pages entry point.

## GodotPrompter

This is a Godot project with GodotPrompter skills available. Before implementing any game system, you MUST check for a matching `godot-prompter:*` skill and invoke it. This applies to all agents, subagents, and sessions working in this repository.

Key skills: `player-controller`, `state-machine`, `event-bus`, `scene-organization`, `component-system`, `resource-pattern`, `godot-ui`, `hud-system`, `ai-navigation`, `camera-system`, `audio-system`, `save-load`, `inventory-system`, `godot-testing`.

For the full skill list, invoke `godot-prompter:using-godot-prompter`.
