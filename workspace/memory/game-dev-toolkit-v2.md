# Game Dev Toolkit — Revised Vision (v2)

## Honest Assessment of Current Plan

The Phase 2-3 plan (ScriptableObject configs + factory tools) was thinking too small and too "developer-tool-ish." It would make configs that I read, not a system that both humans and AI can navigate top-down.

### What's Missing from v1 Plan:
1. **No visual editor** — ScriptableObjects are just files. There's no way to see the whole game at a glance.
2. **No drill-down** — Can't go Game → Levels → Level 3 → Enemies → Enemy #2 → Stats
3. **Configs don't drive the game** — They'd be alongside the game, not the source of truth
4. **No validation** — Nothing stops you from creating a level with no enemies or broken references
5. **No preview** — Can't see what a level looks like without entering play mode
6. **Tools are disconnected** — Each tool does one thing but they don't compose into a workflow

## The Real Vision: Game Definition System

### Core Principle
**The game IS the config.** Not "configs that describe the game" but "a single source of truth that generates everything."

### Architecture
```
GameDefinition (ScriptableObject - ONE root object)
├── GameSettings (difficulty curves, global params)
├── PlayerConfig (health, movement, upgrades available)
├── Levels[] (ordered list)
│   ├── Level1Config
│   │   ├── displayName, difficulty
│   │   ├── background: SpriteFramesData ref
│   │   ├── music: AudioClip ref
│   │   ├── deathScene: DeathConfig ref
│   │   ├── duration (timeline length)
│   │   ├── enemies[] (spawn configs)
│   │   │   ├── { type: Chaser, pos: (2,3), spawnTime: 5s, health: 3, speed: 2 }
│   │   │   ├── { type: Shooter, pos: (-4,2), spawnTime: 10s, fireRate: 1.5 }
│   │   │   └── ...
│   │   ├── platforms[] (layout configs)
│   │   ├── pickups[] (diamond positions)
│   │   └── timeline overrides (activation tracks, sequences)
│   ├── Level2Config
│   └── ...
├── Videos[] (cutscene configs)
│   ├── Video1Config { spriteFramesData, afterLevel: 0 }
│   └── ...
├── Deaths[] (death scene configs)
│   ├── Death1Config { animation, retryPrompt }
│   └── ...
└── EnemyTemplates[] (base enemy definitions)
    ├── ChaserTemplate { prefab, defaultHP, defaultSpeed, sounds }
    ├── ShooterTemplate { prefab, defaultHP, fireRate, projectile }
    └── ...
```

### The Editor Window: Game Overview
One editor window (`Tools > Sick Of It > Game Overview`) that shows:

```
┌─────────────────────────────────────────────────┐
│ SICK OF IT — Game Overview                       │
├─────────────────────────────────────────────────┤
│ ▶ Game Settings    │ Player: 5 HP, 2 jumps      │
│                    │ Levels: 4, Videos: 4        │
├─────────────────────────────────────────────────┤
│ LEVELS                                          │
│ ┌──────┐ ┌──────┐ ┌──────┐ ┌──────┐           │
│ │ Lv.1 │ │ Lv.2 │ │ Lv.3 │ │ Lv.4 │           │
│ │ 3 ene│ │ 5 ene│ │ 7 ene│ │ NEW  │           │
│ │ 60s  │ │ 90s  │ │ 120s │ │      │           │
│ └──────┘ └──────┘ └──────┘ └──────┘           │
│                                                 │
│ [+ Add Level]                                   │
├─────────────────────────────────────────────────┤
│ VIDEOS           │ DEATHS          │ ENEMIES    │
│ Video1 (intro)   │ Death1          │ Chaser     │
│ Video2 (lv1→2)   │ Death2          │ Fighter    │
│ Video3 (lv2→3)   │ Death3          │ Sentinel   │
│ Video4 (lv3→4)   │                 │ Shooter    │
│ [+ Add Video]    │ [+ Add Death]   │ [+ Add]    │
└─────────────────────────────────────────────────┘
```

Clicking a level opens the **Level Editor panel**:
```
┌─────────────────────────────────────────────────┐
│ LEVEL 1 — "The Beginning"                        │
├─────────────────────────────────────────────────┤
│ Background: Level1_Background1 [Change]          │
│ Music: battle.mp3 [Change]                       │
│ Death Scene: Death1 [Change]                     │
│ Duration: 60s                                    │
├─────────────────────────────────────────────────┤
│ ENEMIES (3)                                      │
│ ┌─────────────────────────────────────────────┐ │
│ │ Chaser   @ (2, 3)   HP:3  Speed:2  t=5s    │ │
│ │ Chaser   @ (-3, 1)  HP:3  Speed:2  t=15s   │ │
│ │ Shooter  @ (0, 4)   HP:2  Rate:1.5 t=10s   │ │
│ └─────────────────────────────────────────────┘ │
│ [+ Add Enemy]                                    │
├─────────────────────────────────────────────────┤
│ TIMELINE                                         │
│ 0s──────30s──────60s                            │
│ ▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓ Background                │
│ ♪♪♪♪♪♪♪♪♪♪♪♪♪♪♪♪♪♪♪ Music                     │
│ ·····E1·····E2···E3·· Enemy Spawns              │
├─────────────────────────────────────────────────┤
│ [Open Scene] [Build Level] [Play Test] [Delete]  │
└─────────────────────────────────────────────────┘
```

### The Generation Pipeline
When you click **[Build Level]** or Claw calls the API:

1. Reads the LevelConfig from GameDefinition
2. Creates/updates the Level scene (from BaseLevel prefab variant)
3. Populates enemy spawners from config
4. Builds/updates the Timeline (audio + activation + sprite frame tracks)
5. Configures Addressable group
6. Updates GameConfiguration.totalLevels
7. Validates everything (no missing refs, sounds exist, enemies have prefabs)

### How Claw Uses It
```
User: "Make level 4 with 3 chasers and 2 shooters, forest background, battle.mp3"

Claw:
1. Reads GameDefinition via MCP
2. Adds Level4Config to the Levels array:
   - background: forest sprite data
   - music: battle.mp3
   - enemies: 3 chasers (auto-positioned), 2 shooters (auto-positioned)
3. Calls "Build Level" which generates everything
4. Runs validation
5. Reports: "Level 4 created: 5 enemies, 60s duration, forest background"
```

### How Human Uses It
1. Opens Game Overview window
2. Clicks [+ Add Level]
3. Fills in the fields
4. Clicks [Build Level]
5. Enters play mode to test
6. Adjusts enemy positions/stats in the level editor panel
7. Rebuilds

### MCP Tools for Claw
- `get_game_definition` — Returns full game structure as JSON
- `get_level_config levelNumber=N` — Returns one level's config
- `set_level_config levelNumber=N config={...}` — Updates a level config
- `add_level config={...}` — Adds a new level
- `build_level levelNumber=N` — Generates scene/prefab/timeline from config
- `build_all` — Regenerates all levels
- `validate_game` — Checks for broken refs, missing assets, balance issues
- `get_enemy_templates` — Returns all enemy type definitions
- `add_enemy_to_level levelNumber=N enemy={...}` — Adds an enemy spawn

## Implementation Strategy

### Phase 1: Data Layer (ScriptableObjects)
Create the config hierarchy:
- `GameDefinition.cs` (root SO)
- `LevelConfig.cs` (nested serializable class)
- `EnemySpawnConfig.cs` (nested serializable class)
- `EnemyTemplate.cs` (SO per enemy type)
- `DeathConfig.cs`, `VideoConfig.cs`

### Phase 2: Editor Window
- `GameOverviewWindow.cs` — The main editor window
- `LevelEditorPanel.cs` — Drill-down into a level
- `EnemyEditorPanel.cs` — Edit enemy spawns
- Custom property drawers for inline editing

### Phase 3: Generation Pipeline
- `LevelBuilder.cs` — Creates scene/prefab from LevelConfig
- `TimelineBuilder.cs` — Creates/updates timelines programmatically
- `EnemySpawner.cs` — Places enemies in scene from config
- `ValidationSystem.cs` — Checks entire game for issues

### Phase 4: MCP Integration
- Register custom tools that wrap the generation pipeline
- Claw can read/write GameDefinition via MCP
- Full automation: "make level 4" → config → build → validate → done

### Phase 5: Runtime Integration
- LevelManager reads from LevelConfig at runtime (no more hardcoded values)
- Enemy spawning driven by config (no more manual prefab placement in scenes)
- Timeline builds itself from config data
- Levels become entirely data-driven

## What Needs to Change in Current Codebase
1. LevelManager.cs — Read settings from LevelConfig instead of serialized fields
2. EnemyBase subclasses — Initialize from EnemyTemplate configs
3. Scene structure — BaseLevel prefab needs a "spawn point container" for dynamic enemies
4. Timeline — Need programmatic API to create/modify tracks (exists in Unity, just need to wrap it)
5. Build pipeline — GameConfiguration.totalLevels needs to auto-update from GameDefinition

## What Stays the Same
- Assembly structure (Core, Combat, Data, etc.)
- Addressables system
- PlayerHealth/RogueliteManager progression
- VideoFrameExtractor pipeline
- Mobile controls
- All existing prefabs (used as templates)
