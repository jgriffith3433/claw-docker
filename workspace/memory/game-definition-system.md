# Game Definition System — Complete Architecture

## Philosophy
The game IS the config. Every scene, enemy, platform, timeline, and audio clip is defined in one place. The Unity scenes are OUTPUT, not source. You edit the definition, the system generates the game.

No backwards compatibility. No legacy support. Clean break.

## What Exists Today (to be replaced)
- 4 Level scenes: Each is a prefab variant of BaseLevel with enemies/platforms baked in as overrides
- Enemies positioned manually in prefab variants (positions in YAML)
- Timelines created manually per level/video/death
- LevelManager reads level number from serialized field
- TopDownController has player stats as serialized fields
- Audio clips referenced directly in timelines
- SpriteFramesData assets created manually per background
- No connection between "level 3 uses these enemies" and the actual scene content
- 6 enemy prefabs with stats set per-prefab in inspector

## Asset Inventory (what configs must reference)
- **Backgrounds**: 8 SpriteFramesData assets (Level1-3, Level4, MainMenu, MainMenu_Explode)
- **Audio**: 13 mp3 files in Assets/Videos/ (named *_Audio.mp3)
- **Videos**: 4 video SpriteFramesData (Video1-4)
- **Deaths**: 3 death SpriteFramesData (Death1-3)
- **Enemy prefabs**: 6 (Chaser, Fighter, Sentinel, Shooter, Shooter_Left, Shooter_Right)
- **Enemy sprites**: Fighter (3 sheets), Level3Enemy/Sentinel (7 sheets), Demon (2), Slime (1)
- **Timelines**: 14 playable files
- **Level prefabs**: BaseLevel + 4 variants
- **Player prefab**: Character.prefab
- **Platforms**: Platform.prefab, OldPlatform.prefab

## New Script Architecture

### Assembly: SickOfIt.Data (the source of truth)

```
Scripts/Data/
├── GameDefinition.cs          # THE root ScriptableObject
├── Config/
│   ├── LevelConfig.cs         # Everything about a level
│   ├── EnemySpawnConfig.cs    # One enemy in a level
│   ├── PlatformConfig.cs      # One platform in a level
│   ├── EnemyTemplate.cs       # ScriptableObject per enemy type
│   ├── VideoConfig.cs         # Cutscene definition
│   ├── DeathConfig.cs         # Death scene definition
│   ├── PlayerConfig.cs        # Player stats, movement, upgrades
│   └── TimelineConfig.cs      # Timeline track definitions
├── GameProgressManager.cs     # Keep (save/load works fine)
└── RogueliteManager.cs        # Keep (progression system works fine)
```

### Assembly: SickOfIt.Core (runtime)

```
Scripts/Core/
├── Flow/
│   ├── SceneTransitionManager.cs    # Keep (routing logic is good)
│   ├── DeathManager.cs              # Simplified: reads DeathConfig
│   └── SceneLoadingManager.cs       # Simplified: remove debug logs
├── Input/
│   ├── TopDownController.cs         # Reads from PlayerConfig
│   ├── GlobalTapJump.cs             # Keep
│   └── LetterboxInputExtender.cs    # Keep
├── Runtime/
│   ├── LevelRuntime.cs              # NEW: Reads LevelConfig, spawns enemies, builds timeline AT RUNTIME
│   ├── EnemySpawner.cs              # NEW: Instantiates enemies from config
│   ├── PlatformPlacer.cs            # NEW: Places platforms from config
│   └── TimelineRunner.cs            # NEW: Builds and plays timeline from config
├── Progression/
│   ├── MainMenuManager.cs           # Simplified: reads GameDefinition for level count
│   ├── LevelSelectionManager.cs     # Reads GameDefinition.Levels
│   ├── VideoSelectionManager.cs     # Reads GameDefinition.Videos
│   ├── UpgradeShopManager.cs        # Reads PlayerConfig for available upgrades
│   └── BundleDownloadManager.cs     # Keep (addressables system works)
├── Device/                          # Keep (aspect ratio, safe area)
└── AnalyticsManager.cs              # Keep
```

### Assembly: SickOfIt.Combat (runtime)

```
Scripts/Combat/
├── Enemies/
│   ├── EnemyBase.cs                 # Reads stats from EnemyTemplate at spawn time
│   ├── EnemyChaser.cs               # Behavior only, no stats in serialized fields
│   ├── EnemyFighter.cs              # Behavior only
│   ├── EnemySentinel.cs             # Behavior only
│   ├── EnemyShooter.cs              # Behavior only
│   └── SpriteLookAtCharacter.cs     # Keep
├── Health/
│   ├── IDamageable.cs               # Keep
│   ├── PlayerHealth.cs              # Keep (already reads from RogueliteManager)
│   └── EnemyHealth.cs               # Keep (health set by spawner from config)
├── Damage/
│   └── DamageDealer.cs              # Keep
├── PointsPickup.cs                  # Keep
└── Effects/
    └── GlitchEffect.cs              # Keep
```

### Assembly: SickOfIt.Tools.Editor

```
Scripts/Tools/Editor/
├── GameOverview/
│   ├── GameOverviewWindow.cs        # Main editor window
│   ├── LevelEditorPanel.cs          # Level drill-down view
│   ├── EnemyEditorPanel.cs          # Enemy config editor
│   ├── VideoEditorPanel.cs          # Video/cutscene editor
│   ├── DeathEditorPanel.cs          # Death scene editor
│   ├── PlayerEditorPanel.cs         # Player config editor
│   └── TimelinePreview.cs           # Visual timeline preview
├── Generation/
│   ├── LevelGenerator.cs            # Creates scene + addressable from LevelConfig
│   ├── TimelineGenerator.cs         # Creates .playable from TimelineConfig
│   ├── DeathSceneGenerator.cs       # Creates death scene from DeathConfig
│   ├── VideoSceneGenerator.cs       # Creates video scene from VideoConfig
│   ├── AddressableGroupGenerator.cs # Creates/updates addressable groups
│   └── GameBuilder.cs               # Builds ALL levels/videos/deaths from GameDefinition
├── Validation/
│   └── GameValidator.cs             # Checks entire game for issues
├── MCP/
│   └── ClawGameTools.cs             # Custom MCP-callable tools for Claw
├── Build/
│   ├── ClawBuildScript.cs           # Keep (WebGL build pipeline)
│   └── GameDeployWindow.cs          # Keep (deploy UI)
└── CharacterPipeline/
    └── ClawCharacterPipeline.cs     # Keep (AI character generation)
```

## Data Structures

### GameDefinition.cs
```csharp
[CreateAssetMenu(menuName = "Sick Of It/Game Definition")]
public class GameDefinition : ScriptableObject
{
    [Header("Player")]
    public PlayerConfig player;
    
    [Header("Content")]
    public List<LevelConfig> levels;
    public List<VideoConfig> videos;
    public List<DeathConfig> deaths;
    
    [Header("Enemy Templates")]
    public List<EnemyTemplate> enemyTemplates;
    
    [Header("Global Settings")]
    public float defaultLevelDuration = 60f;
    public int startingLevel = 1;
    public bool debugMode;
    
    // Convenience
    public int TotalLevels => levels.Count;
    public LevelConfig GetLevel(int number) => levels[number - 1];
    public VideoConfig GetVideo(int number) => videos[number - 1];
    public DeathConfig GetDeath(string name) => deaths.Find(d => d.deathName == name);
    public EnemyTemplate GetEnemyTemplate(EnemyType type) => enemyTemplates.Find(t => t.type == type);
}
```

### LevelConfig.cs
```csharp
[Serializable]
public class LevelConfig
{
    [Header("Identity")]
    public string levelName;           // "Level1", "Level2", etc.
    public string displayName;         // "The Beginning"
    public int levelNumber;
    
    [Header("Visuals")]
    public SpriteFramesData[] backgrounds;  // Can have multiple background layers
    public Color ambientColor = Color.white;
    
    [Header("Audio")]
    public AudioClip music;
    public float musicStartTime;
    
    [Header("Layout")]
    public Vector2 levelBounds = new Vector2(10, 6);
    public List<PlatformConfig> platforms;
    
    [Header("Enemies")]
    public List<EnemySpawnConfig> enemies;
    
    [Header("Flow")]
    public DeathConfig deathConfig;
    public float duration = 60f;         // Timeline total length
    public bool hasTwoStageSequence;
    public float firstSequenceDuration;
    
    [Header("Timeline")]
    public TimelineConfig timeline;
    
    [Header("Completion")]
    public int nextVideoNumber;          // Video to play after completion (0 = none)
}
```

### EnemySpawnConfig.cs
```csharp
[Serializable]
public class EnemySpawnConfig
{
    public EnemyType type;              // Chaser, Fighter, Sentinel, Shooter
    public Vector2 position;
    public float spawnTime;             // Seconds into level when this enemy appears
    public bool activeAtStart = true;   // If false, spawns at spawnTime
    
    [Header("Overrides (0 = use template defaults)")]
    public int healthOverride;
    public float speedOverride;
    public float detectionRangeOverride;
    
    // Shooter-specific
    public float fireRateOverride;
    public ShootDirection shootDirection; // Left, Right, AtPlayer
}

public enum EnemyType { Chaser, Fighter, Sentinel, Shooter }
public enum ShootDirection { AtPlayer, Left, Right }
```

### EnemyTemplate.cs
```csharp
[CreateAssetMenu(menuName = "Sick Of It/Enemy Template")]
public class EnemyTemplate : ScriptableObject
{
    public EnemyType type;
    public GameObject prefab;
    
    [Header("Base Stats")]
    public int defaultHealth = 3;
    public float defaultMoveSpeed = 2f;
    public int contactDamage = 1;
    public float detectionRange = 10f;
    
    [Header("Audio")]
    public AudioClip[] hurtSounds;
    public AudioClip[] deathSounds;
    public float hurtSoundHealthThreshold = 1f;
    
    [Header("Drops")]
    public float dropChance = 0.35f;
    public int dropPointsValue = 1;
    public int dropCount = 1;
    
    [Header("Type-Specific")]
    public float fireRate;              // Shooter
    public float projectileSpeed;       // Shooter
    public float attackRange;           // Fighter
    public float attackCooldown;        // Fighter/Sentinel
}
```

### PlayerConfig.cs
```csharp
[Serializable]
public class PlayerConfig
{
    [Header("Movement")]
    public float moveSpeed = 2f;
    public float jumpForce = 15f;
    public float gravityScale = 1.8f;
    
    [Header("Combat")]
    public bool enableShooting = true;
    public float fireRate = 0.25f;
    public float projectileSpeed = 10f;
    
    [Header("Roguelite")]
    public int baseMaxHealth = 5;
    public int maxExtraJumps = 2;
    public int extraJumpCost = 100;
    
    [Header("Upgrades Available")]
    public List<UpgradeDefinition> availableUpgrades;
}

[Serializable]
public class UpgradeDefinition
{
    public string upgradeId;
    public string displayName;
    public string description;
    public int cost;
    public int maxPurchases = 1;
}
```

### TimelineConfig.cs
```csharp
[Serializable]
public class TimelineConfig
{
    public List<TimelineTrackConfig> tracks;
}

[Serializable]
public class TimelineTrackConfig
{
    public TimelineTrackType trackType;
    public string trackName;
    public List<TimelineClipConfig> clips;
}

[Serializable]
public class TimelineClipConfig
{
    public float startTime;
    public float duration;
    
    // For audio tracks
    public AudioClip audioClip;
    
    // For activation tracks
    public string targetGameObjectPath;  // Path in hierarchy to activate/deactivate
    
    // For sprite frame tracks
    public SpriteFramesData spriteFramesData;
}

public enum TimelineTrackType { Audio, Activation, SpriteFrame }
```

## Runtime Flow (how a level loads)

### Old way:
1. SceneTransitionManager loads Level1.unity via Addressables
2. Level1 scene has everything baked in (enemies, platforms, timeline refs)
3. LevelManager reads serialized fields

### New way:
1. SceneTransitionManager loads a GENERIC level scene via Addressables
2. LevelRuntime.cs reads `GameDefinition.GetLevel(levelNumber)`
3. EnemySpawner instantiates enemies from config (type → template → prefab)
4. PlatformPlacer creates platforms from config
5. TimelineRunner builds timeline programmatically from TimelineConfig
6. LevelRuntime wires up completion/death events

### Implications:
- ONE level scene template, not 4+ variants
- Enemies are spawned dynamically, not placed in scene
- Timelines are built at runtime from config, not pre-authored .playable files
- Adding a level = adding a LevelConfig entry. No scene creation needed.
- The addressable groups only need: backgrounds, audio, enemy sprites (shared)

## MCP Tools for Claw

### Game Definition Tools
- `get_game_definition` — Full game as JSON
- `get_level levelNumber=N` — One level config
- `update_level levelNumber=N config={...}` — Modify a level
- `add_level config={...}` — Add new level
- `remove_level levelNumber=N` — Remove a level
- `reorder_levels order=[3,1,2,4]` — Reorder levels

### Enemy Tools
- `get_enemy_templates` — All enemy types
- `add_enemy_to_level levelNumber=N type=Chaser position="2,3" spawnTime=5`
- `remove_enemy_from_level levelNumber=N index=2`
- `update_enemy_in_level levelNumber=N index=2 health=5 speed=3`

### Content Tools
- `set_level_music levelNumber=N audioPath="Assets/Videos/..."`
- `set_level_background levelNumber=N backgroundPath="Assets/Videos/..."`
- `add_platform_to_level levelNumber=N position="0,2" width=3`

### Build Tools
- `validate_game` — Check everything
- `build_addressables` — Rebuild content bundles
- `get_game_stats` — Level count, enemy count, total duration, etc.

### Player Tools
- `get_player_config` — Player stats
- `update_player_config config={...}` — Modify player

## Editor Window Features

### Game Overview Tab
- Level cards showing: name, enemy count, duration, background thumbnail
- Click to drill down
- Drag to reorder
- [+ Add Level] button
- Summary stats at top

### Level Editor Tab
- All fields from LevelConfig editable inline
- Enemy list with drag-to-reorder
- Platform list with position fields
- Timeline visual preview
- [Generate Scene] [Play Test] [Validate] buttons

### Enemy Template Tab
- List of all enemy types
- Stats, sounds, prefab reference
- [+ Create New Enemy Type] integrates with AI character pipeline

### Validation Tab
- List of all issues found
- Click to navigate to the problem
- Auto-fix suggestions

## Files to DELETE (no backwards compat)
- Scripts/Data/GameConfiguration.cs (replaced by GameDefinition)
- Scripts/Combat/Health/HealthSystem.cs (duplicate of EnemyHealth)
- Scripts/Combat/Enemies/AnimationEventRelayFighter.cs (merge into one)
- Scripts/Combat/Enemies/AnimationEventRelaySentinel.cs
- Scripts/Combat/Enemies/AnimationEventRelayShooter.cs
- Scripts/Tools/Editor/AutoSlimeImport.cs (experimental)
- Scripts/Tools/Editor/AutoSlimeImport_Fixed.cs (experimental)
- Scripts/Tools/Editor/ImprovedEnemyPrefab.cs (experimental)
- Scripts/Tools/Editor/SlimeCharacterSetup.cs (replaced by pipeline)
- Scripts/Tools/SlimeIdleAnimation.cs (experimental)

## Files to HEAVILY REWRITE
- Scripts/Core/Input/TopDownController.cs — Read from PlayerConfig
- Scripts/Combat/Enemies/EnemyBase.cs — Initialize from EnemyTemplate
- Scripts/Combat/Enemies/EnemyChaser.cs — Remove serialized stats
- Scripts/Combat/Enemies/EnemyFighter.cs — Remove serialized stats
- Scripts/Combat/Enemies/EnemySentinel.cs — Remove serialized stats
- Scripts/Combat/Enemies/EnemyShooter.cs — Remove serialized stats
- Scripts/Core/Progression/MainMenuManager.cs — Read from GameDefinition
- Scripts/Core/Progression/LevelSelectionManager.cs — Read from GameDefinition
- Scripts/Core/Flow/SceneLoadingManager.cs — Remove debug spam

## Files to KEEP (mostly unchanged)
- Scripts/Data/GameProgressManager.cs
- Scripts/Data/RogueliteManager.cs
- Scripts/Core/Flow/SceneTransitionManager.cs
- Scripts/Core/Addressables/* (the addressable system works)
- Scripts/Core/Device/*
- Scripts/Core/AnalyticsManager.cs
- Scripts/Combat/Health/PlayerHealth.cs
- Scripts/Combat/Health/EnemyHealth.cs
- Scripts/Combat/Health/IDamageable.cs
- Scripts/Combat/Damage/DamageDealer.cs
- Scripts/Combat/PointsPickup.cs
- Scripts/Combat/Effects/GlitchEffect.cs
- Scripts/VideoFrameExtractor/* (the custom pipeline works)
- Scripts/Core/Progression/BundleDownloadManager.cs
- Scripts/Core/Progression/UpgradeShopManager.cs
- Scripts/Core/Progression/VideoManager.cs

## Implementation Order
1. Data layer: GameDefinition, LevelConfig, EnemyTemplate, PlayerConfig, etc.
2. Create the GameDefinition.asset with current game's data (4 levels, 4 videos, 3 deaths)
3. LevelRuntime: Dynamic enemy spawning + platform placement from config
4. Enemy refactor: EnemyBase reads from template, subclasses are behavior-only
5. TopDownController: Reads from PlayerConfig
6. Editor Window: Game Overview with drill-down
7. Generation pipeline: Scene + timeline + addressables from config
8. MCP tools: Register custom tools for Claw
9. Validation system
10. Delete old scripts, clean up
