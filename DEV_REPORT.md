# Acheron9 Godot Port — Dev Report (2026-10-23)

## Status: Almost Done

### Co działa ✅

| Kategoria | Stan | Szczegóły |
|-----------|------|-----------|
| Parse errors | **0** | Wszystkie 26 skrypty `.gd` parsują się poprawnie |
| Shader errors | **0** | Wszystkie 4 shadery kompilują się poprawnie |
| Autoloady (9/9) | **Online** | AssetSetup, GameManager, PlayerController, SettingsManager, QuestManager, SpeechManager, EndingManager, AudioManager, MCPBridge — wszystkie ładują się i inicjalizują |
| Stderr | **Pusty** | Zero błędów w czasie działania |
| Cache | **Zbudowany** | `.godot/global_scriptong_class_cache.cfg` — 26 class_name rejestrowanych |

### Co nie działa ❌

| Problem | Szczegóły |
|---------|-----------|
| MainScene `_ready()` nie wywoływane | Autoloady ładują się, ale `main_scene.gd` nie startuje — nie ma "All systems wired" ani "Game started" w output. |
| Exit code 124 (timeout) | Gra nie kończy się samoczynnie. `--quit` nie działa w Godot 4.7.2 flatpak. Auto-quit timer nie uruchamia się (bo `_start_game()` nie jest wywoływany). |

### Co zostało zrobione (lista napraw)

1. **project.godot**: `run/auto_load` → `[autoload]` sekcja, usunięcie `binding/` prefixów z InputMap, usunięcie duplikatu `run/main_scene`

2. **Autoloady (10 plików)**: Przerobienie wszystkich cross-autoload referencji z `ClassName.method()` → `get_node_or_null("/root/ClassName").method()` z dynamic dispatch (`call()`)

3. **Non-autoload skrypty (6 plików)**: 
   - `main_scene.gd`, `hud.gd`, `player.gd`, `flashlight_component.gd`, `fear_sanity_component.gd`, `interaction_component.gd`, `humanoid_ai.gd`, `end_trigger.gd`
   - `@onready var _xxx = get_node_or_null("/root/ClassName")` → `var _xxx = null` + init w `_ready()` (untype `Variant` dla dynamic dispatch)

4. **API fixes**:
   - `OS.get_ticks_msec()` → `Time.get_ticks_msec()`
   - `JSON.parse()` → `JSON.parse_string()`
   - `AudioStreamWAV.FORMAT_MONO` → int `0` (FORMAT_STEREO)
   - `Set` type → `Dictionary`
   - `CubeMesh` → `BoxMesh`
   - `MultiMesh.COLOR_FLOAT` → int `1`
   - `preload(non-constant)` → `load()`
   - `set_transform()` → `set_instance_transform()`
   - `set_target_location()` → `target_location =` property
   - `Dictionary.new()` → `{}`
   - `Dictionary.insert()` → `dict[key] = value`
   - `TIME.y` → `TIME` (float, not vec2)
   - `NORMALMAP` removed (nie istnieje w Godot 4.7.2)
   - `diffuse lambert` usunięte z render_mode
   - `#` comments → `//` w shaderach
   - `SCREEN_TEXTURE` → `uniform sampler2D : hint_screen_texture`
   - `ALPHA_TEXTURE` usunięte
   - `return` w `fragment()` → `if-else` (canvas_item nie wspiera return)
   - `shadow_depth_range` usunięte z DirectionalLight3D
   - `auto_exposure_enabled` → `set("exposure_enabled", true)`
   - `ClassDB.get_class("X").new()` → usunięte (WebSocket nie kompilowany)
   - `SettingsManager.get()` → `SettingsManager.get_instance()`
   - Signal `.emit()` dla wszystkich sygnałów

5. **Shaders**: Wszystkie 4 (concrete_material, blood_decal, crt_shader, whiteout_shader) naprawione pod Godot 4.7.2

### Jak uruchomić

```bash
cd /mnt/data/Projects/acheron9-godot
rm -rf .godot
godot --headless --editor --path .  # Build cache (20s timeout)
godot --headless --path .           # Run (stuck in autoload loop, exit 124)
```

### Co trzeba zrobić jutro (TODO)

1. **Zdebugować dlaczego MainScene się nie ładuje** — prawdopodobnie issue z Godot 4.7.2 headless + flatpak. Spróbować:
   - `godot --headless --quit-after 180 --path .` (quit after 180 frames ~ 3 sekundy)
   - Albo dodać `get_tree().quit()` w `_ready()` z timerem na starcie

2. **Exit code 0** — gra musi się samoczynnie zakończyć

### Pliki zmodyfikowane (26 skryptów + 4 shadery)
- `autoload/`: game_manager.gd, settings_manager.gd, quest_manager.gd, speech_manager.gd, ending_manager.gd, save_system.gd, mcp_bridge.gd, asset_setup.gd, audio_manager.gd, player_controller.gd
- `scripts/`: main_scene.gd, hud.gd, player.gd
- `scripts/components/`: flashlight_component.gd, fear_sanity_component.gd, interaction_component.gd, microphone_input.gd
- `scripts/levelgen/`: level_generator.gd, end_trigger.gd, environmental_destruction.gd
- `scripts/ai/`: humanoid_ai.gd
- `shaders/`: concrete_material.gdshader, blood_decal.gdshader, crt_shader.gdshader, whiteout_shader.gdshader
