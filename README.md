# Acheron-9: Incident — Godot Port

> Brutalist 80s industrial horror • 60-minute purge timer • Mic-driven AI pursuit

This is the **Godot 4** port of the original **Unreal Engine 5** project (`Acheron9`).
All 19 C++ modules have been translated to GDScript 2.0, with Godot-native equivalents
for engine subsystems.

## Architecture: UE5 → Godot Mapping

| UE5 System | Godot Equivalent |
|---|---|
| `FAcheron9Module` (Module) | Autoload singletons |
| `AAcheron9GameMode` | `GameManager` autoload |
| `AAcheron9GameState` | `GameManager` (timer + ending state) |
| `AAcheron9PlayerController` | `PlayerController` autoload |
| `AAcheron9Character` | `Player` scene (`CharacterBody3D`) |
| `UInputAction` / `UInputMappingContext` | `InputMap` in `project.godot` + `Input` singleton |
| `AAcheron9LevelGenerator` | `LevelGenerator` script (`MultiMeshInstance3D`) |
| `UAcheron9FlashlightComponent` | `FlashlightComponent` (Node) |
| `UAcheron9InventoryComponent` | `InventoryComponent` (Node) |
| `UAcheron9InteractionComponent` | `InteractionComponent` (Node) |
| `UAcheron9FearSanityComponent` | `FearSanityComponent` (Node) |
| `UMicrophoneInputManager` | `MicrophoneInputManager` (Node, `AudioServer` capture) |
| `AAcheron9HumanoidAI` | `HumanoidAI` scene (`CharacterBody3D`) |
| `AAcheron9QuestManager` | `QuestManager` autoload |
| `AAcheron9Audio3DAmbientManager` | `AudioManager` autoload |
| `APROBOSSpeechManager` | `SpeechManager` autoload |
| `AAcheron9EndingSequenceManager` | `EndingManager` autoload |
| `AAcheron9HUDManager` | `HUD` scene (`CanvasLayer`) |
| `UCRTScanlineComponent` | CRT shader on `ColorRect` overlay |
| `AEnvironmentalDestructionSystem` | `EnvironmentalDestructionSystem` (Node3D) |
| `AWallRotationParanoiaSystem` | `WallRotationParanoia` scene (Node3D) |
| `AEndingTriggerVolume` | `EndTrigger` (Area3D) |
| `UAcheron9SaveGame` | `SaveSystem` (JSON to `user://`) |
| `AAcheron9SettingsManager` | `SettingsManager` (INI in `user://`) |
| `AAcheron9AssetSetup` | `AssetSetup` autoload |
| UE_MCP_Bridge (WebSocket) | `MCPBridge` autoload (`WebSocketServer`) |
| Blender pipeline | `Acheron9AssetPipeline` (SurfaceTool meshes) |

## Project Structure

```
achron9-godot/
├── project.godot              # Project settings + input map
├── autoload/                  # 10 singletons (mirrors UE module lifecycle)
│   ├── asset_setup.gd
│   ├── game_manager.gd
│   ├── player_controller.gd
│   ├── settings_manager.gd
│   ├── quest_manager.gd
│   ├── speech_manager.gd
│   ├── ending_manager.gd
│   ├── save_system.gd
│   ├── audio_manager.gd
│   └── mcp_bridge.gd
├── scripts/
│   ├── main_scene.gd          # Scene bootstrap (GameMode::BeginPlay)
│   ├── player.gd              # CharacterBody3D player
│   ├── components/            # 5 UE actor components
│   │   ├── flashlight_component.gd
│   │   ├── inventory_component.gd
│   │   ├── interaction_component.gd
│   │   ├── fear_sanity_component.gd
│   │   └── microphone_input.gd
│   ├── levelgen/              # Level generation + AI
│   │   ├── level_generator.gd
│   │   ├── environmental_destruction.gd
│   │   ├── wall_rotation_paranoia.gd
│   │   └── end_trigger.gd
│   └── ai/
│       └── humanoid_ai.gd
├── scripts/asset_pipeline.gd  # Procedural mesh generation (Blender replacement)
├── shaders/                    # CRT + materials
│   ├── crt_shader.gdshader
│   ├── concrete_material.gdshader
│   ├── blood_decal.gdshader
│   └── whiteout_shader.gdshader
├── scenes/                     # Scene files
│   ├── main.tscn
│   ├── player.tscn
│   ├── hud.tscn
│   ├── humanoid_ai.tscn
│   ├── tape_pickup.tscn
│   └── wall_rotation_paranoia.tscn
└── assets/audio/               # Audio assets (add .ogg files here)
```

## Getting Started

### Prerequisites
- **Godot 4.7+** (tested with 4.7.2-stable)

### Running
1. Open `project.godot` in Godot 4
2. Install the Godot Python module if you need `execute_python` MCP handler support
3. Add audio assets to `res://assets/audio/` (see `AudioManager` for expected paths)
4. Press **F5** to run

### MCP Bridge
The MCP bridge starts automatically as an autoload on port **54362** (same as UE).
It provides JSON-RPC methods: `get_engine_state`, `get_bridge_capabilities`,
`get_game_state`, `start_game`, `list_resources`, `read_resource`, `echo`, and more.

## Key Systems

### 60-Minute Purge Timer
`GameManager` runs a 1-second tick timer counting down from 3600 seconds.
When it hits zero → `TIME_EXPIRED` ending.

### Procedural Level Generation
`LevelGenerator` creates a 32×32×4 grid (seed 97312) with:
- Deterministic room + L-shaped corridor carving
- BFS path verification (player spawn → reactor core)
- MultiMeshInstance3D rendering for efficient tile instancing
- 5 HISM buckets: walls, floors, server racks, steam pipes, terminals

### Mic-Driven AI Pursuit
`MicrophoneInputManager` uses Godot's `AudioServer.capture_*` API.
Audio peaks above `-40dB` trigger `noise_detected` → `HumanoidAI` sprints to sound.
AI has 6s sprint duration, 8s sound decay, and checks distance for idle transition.

### fear/Sanity System
- Proximity to AI increases fear (8/4/1 at <100/300/600 units)
- Mic peaks trigger fear spikes
- Fear > 90% = critical (camera shake + game over risk)
- Low battery → flashlight flicker + increased drain
- Heartbeat audio scales with fear level

### PROBOS-Core Speech
Queue-based TTS system with 12 voice assets:
- `Startup`, `Meltdown`, `TimeWarning`
- `NoisePeak`, `SprintDetected`, `SlideEvaded`, `IdleParanoia`
- `Tape1`, `Tape2`, `FlashlightFlicker`, `SabotageTrigger`, `EndingGoodFailure`
Random speech every 8-20 seconds when enabled.

### CRT Post-Processing
Full-screen `ColorRect` with canvas shader applying:
- Scanline overlay (48Hz frequency)
- Barrel curvature
- Chromatic aberration
- Refresh flicker
- Blood/whiteout overlays for endings

## License
Proprietary — Hartwell Labs Studios
