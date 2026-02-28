# Game Development Toolkit Vision

## The Goal
A layer that sits ON TOP of Unity development that both **dictates how the game is made** and **makes the game itself**. High-level commands like "Make level 4 with 3 chasers, 2 shooters, using forest background and battle.mp3" produce complete, playable levels.

## Phase 1: Reliable MCP Bridge

### Problem
The Unity MCP bridge (Node.js stdio via mcporter) spawns a fresh process per call. When Unity does a domain reload (script recompile), the WebSocket drops and the process dies. Every script edit = 10-20s of MCP downtime.

### Solution: Persistent Bridge Service
A long-running Node.js process that:
- Maintains a persistent WebSocket to Unity's MCP server (port 8090)
- **Auto-reconnects** after domain reload with exponential backoff (Unity restarts WebSocket in ~5s)
- **Queues commands** during disconnection, replays when reconnected
- Exposes a **local HTTP API** (e.g., `localhost:8091`) for Claw to call
- Reports connection state (`connected`, `reconnecting`, `disconnected`)
- Logs all traffic for debugging

This means:
- Claw calls `curl localhost:8091/tool/get_console_logs` instead of `mcporter call unity ...`
- If Unity is recompiling, the request waits (with timeout) and completes after reconnection
- No more "Connection closed" errors

### Implementation
- Single `unity-bridge.js` script in claw-docker
- Uses the same WebSocket protocol as mcp-unity
- Runs as a background process (started by entrypoint or on-demand)
- Health endpoint: `GET /status` → `{ connected: true, tools: 30, lastReconnect: "..." }`

## Phase 2: Game Structure Codification

### Current Game Structure (discovered from codebase)
```
Levels use a PREFAB VARIANT system:
- BaseLevel.prefab (template with ~2335 lines of YAML)
  ├── Level Manager (LevelManager.cs)
  ├── Camera
  ├── Content (enemies, platforms, pickups go here)
  ├── Timeline (PlayableDirector for backgrounds)
  ├── Boundaries (Top, Bottom, Left, Right colliders)
  ├── Health UI Manager
  ├── PointsUI
  ├── SceneContentController
  ├── EventSystem
  └── GameInputManager

Level1.unity → PrefabInstance of "Level1 Variant.prefab"
Level1 Variant.prefab → Variant of BaseLevel.prefab with overrides

Timelines use:
- AudioTrack (background music)
- ActivationTrack (show/hide GameObjects over time)
- SpriteFrameTrack (custom track for video-to-sprite playback)

Videos (SpriteFramesData .asset):
- videoName, sourceFrameWidth/Height
- Chunked into sprite sheets (framesPerSheet, sheetColumns/Rows)
- Referenced by addressable labels
```

### ScriptableObject Config System
Create data-driven configs for everything:

**LevelConfig.asset** (ScriptableObject):
```csharp
[CreateAssetMenu]
public class LevelConfig : ScriptableObject
{
    public int levelNumber;
    public string displayName;
    public string deathSceneName = "Death1";
    
    // Background
    public SpriteFramesData backgroundData;
    public AudioClip backgroundMusic;
    
    // Enemies
    public EnemySpawnConfig[] enemies;
    
    // Layout
    public Vector2 levelBounds;
    public PlatformConfig[] platforms;
    
    // Completion
    public float levelDuration; // timeline duration
    public bool hasTwoStageSequence;
}

[Serializable]
public class EnemySpawnConfig
{
    public EnemyType enemyType; // Chaser, Fighter, Sentinel, Shooter
    public Vector2 spawnPosition;
    public float spawnTime; // when in timeline to spawn
    public int health;
    public float moveSpeed;
    public float detectionRange;
    // Shooter-specific
    public float fireRate;
    public float projectileSpeed;
}
```

**EnemyConfig.asset** (ScriptableObject):
```csharp
public class EnemyConfig : ScriptableObject
{
    public EnemyType type;
    public GameObject prefab;
    public int defaultHealth;
    public float defaultMoveSpeed;
    public int contactDamage;
    public float detectionRange;
    public AudioClip[] hurtSounds;
    public AudioClip[] deathSounds;
    public float dropChance;
    public int dropPointsValue;
}
```

### Benefits
- I can create/modify levels by editing ScriptableObject YAML (simple field changes)
- No need to touch scene hierarchy for enemy placement
- Level configs are version-controllable, diffable, reviewable
- New levels = new config + scene that references it

## Phase 3: Level Factory (MCP Tools)

### Custom MCP Tools (Unity Editor scripts)
Register as Unity MCP tools that Claw can call:

**CreateLevel**
- Input: LevelConfig (or JSON matching the config schema)
- Creates: Scene file, Prefab Variant, Timeline, Addressable group
- Wires: LevelManager references, background, music, enemy spawns

**ModifyTimeline**
- Input: Timeline asset path + track operations (add clip, move clip, set duration)
- Supports: AudioTrack, ActivationTrack, SpriteFrameTrack
- Can add/remove/reorder tracks and clips programmatically

**SpawnEnemies**
- Input: Level scene + EnemySpawnConfig[]
- Places enemies in the scene Content container
- Configures each enemy's serialized fields from the config

**ConfigureLevel**
- Input: Level scene + changes (swap music, change bounds, adjust difficulty)
- Modifies the existing level without rebuilding from scratch

**CreateDeathScene**
- Input: DeathConfig (animation style, retry level reference)
- Creates a death scene with the standard death flow

**CreateVideoScene**
- Input: SpriteFramesData reference, video number
- Creates video scene with timeline, sprite frame playback, skip button

### How "Make Level 4" Would Work
```
User: "Make level 4 with 3 chasers and 2 shooters, forest background, battle.mp3"

Claw:
1. Creates LevelConfig ScriptableObject (Level4Config.asset)
2. Calls CreateLevel MCP tool → produces Level4.unity + Level4 Variant.prefab
3. Calls SpawnEnemies → places 3 chasers + 2 shooters with default positions
4. Calls ModifyTimeline → sets up background music track with battle.mp3
5. Creates Addressable group for Level4
6. Updates GameConfiguration.totalLevels = 4
7. Builds and tests
```

## Phase 4: Asset Pipeline Integration

### Import Settings Codification
Standardized import settings for all asset types:
- Sprite sheets: Multiple mode, Point filter, specific PPU per context
- Audio: Vorbis for music, PCM for SFX, specific quality settings
- Textures: Max size per platform (WebGL constraints)

### ComfyUI → Unity Bridge
Extend the AI character pipeline to be callable as MCP tools:
- Generate enemy concept → animate → process → import → create prefab
- All triggered from chat, output is a ready-to-use prefab

## Architecture Summary
```
Chat Message ("Make level 4 with...")
    ↓
Claw (orchestrator)
    ↓
Persistent MCP Bridge (localhost:8091)
    ↓ WebSocket (auto-reconnecting)
Unity Editor MCP Server (port 8090)
    ↓
Custom MCP Tools (LevelFactory, TimelineBuilder, EnemySpawner...)
    ↓
Unity Assets (ScriptableObjects, Scenes, Prefabs, Timelines)
```

## Implementation Order
1. **Persistent MCP Bridge** — Unblocks everything else
2. **ScriptableObject configs** — LevelConfig, EnemyConfig (data layer)
3. **Level Factory** — CreateLevel MCP tool
4. **Timeline Builder** — ModifyTimeline MCP tool  
5. **Enemy Spawner** — SpawnEnemies MCP tool
6. **Video/Death scene generators** — CreateVideoScene, CreateDeathScene
7. **Asset pipeline tools** — Import settings, ComfyUI integration
8. **Difficulty/balance tools** — Adjust enemy stats across all levels at once
