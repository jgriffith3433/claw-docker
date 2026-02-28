# Unity Project Architecture — Sick Of It

## Stats
- 72 C# scripts, ~13,750 lines total
- 16 scenes (15 game + 1 nappin example)
- 6 assemblies: Core (6144 LOC), VideoFrameExtractor (3041), Tools/Editor (2049), Combat (1937), Data (576)

## Architecture Overview

### Scene Flow
```
MainMenu → LevelSelection → Level{N} → Death{N} (on death) → Level{N} (retry)
         → VideoSelection → Video{N}
         → UpgradeShop
         
Level completion: Level{N} → Video{N+1} → Level{N+1}
New Game: MainMenu → Video1 → Level1
```

### Build Settings vs Addressables
- **In build settings** (load normally): MainMenu, LevelSelection, VideoSelection, UpgradeShop
- **Via Addressables** (remote bundles): Level1-4, Video1-4, Death1-3, Animation
- Addressable groups: one per scene + Common_Group for shared assets

### Singleton Pattern (DontDestroyOnLoad)
These persist across scenes:
- `GameProgressManager` — Level completion, video unlocks, PlayerPrefs
- `RogueliteManager` — Health tracking, points/currency, upgrades
- `SceneTransitionManager` — Scene loading (Addressables or direct)
- `AddressablesSceneLoader` — Addressable scene loading with retry
- `AddressablesOperationManager` — Memory management for addressable handles
- `AnalyticsManager` — Umami analytics events

All use lazy Instance pattern: `if (_instance == null) { new GameObject → AddComponent → DontDestroyOnLoad }`

### Data Layer (`SickOfIt.Data`)
- **GameConfiguration** — ScriptableObject, just `totalLevels` + `debugMode`
- **GameProgressManager** — PlayerPrefs-based: level completion, video unlocks, highest level reached
- **RogueliteManager** — PlayerPrefs-based: health tracking per level, points/currency, upgrades (extra jumps, max health)
  - Health cascading: improving a level's end-health propagates forward to all subsequent saved levels
  - Points persist across new games; upgrades/progress reset on New Game

### Combat System (`SickOfIt.Combat`)
- **EnemyBase** (abstract) — Base for all enemies. Detection range, contact damage, point drops, audio
  - `EnemyChaser` — Moves toward player
  - `EnemyFighter` — Melee with animation states
  - `EnemySentinel` — Stationary, attacks when close
  - `EnemyShooter` — Ranged, fires projectiles
- **Health**:
  - `IDamageable` — Interface: `TakeDamage(int)`
  - `PlayerHealth` — Implements IDamageable. Health from RogueliteManager, invincibility frames, death → DeathScene
  - `EnemyHealth` — Implements IDamageable. Inspector-configured, optional health bar, destroyOnDeath
  - `HealthSystem` — Generic (legacy?), used by some entities. Has health bar creation.
- **DamageDealer** — Trigger-based damage on collision
- **PointsPickup** — Collectible that adds points to RogueliteManager
- **GlitchEffect** — Visual damage feedback

### Core Systems (`SickOfIt.Core`)

#### Scene Loading / Flow
- `SceneTransitionManager` — Central routing. Menu scenes load normally, game scenes via Addressables
- `SceneLoadingManager` — UI state during loads (show spinner, hide menus). Static ShowLoadingUI()
- `AddressablesSceneLoader` — Handles addressable scene loads with error handling
- `AddressablesOperationManager` — Tracks loaded operations, releases handles, memory management
- `SceneContentController` — Controls what's visible in a scene
- `SpriteFrameLoadWaiter` — Waits for sprite frame data to load before proceeding
- `DeathManager` — Manages death scene → retry flow

#### Input
- `TopDownController` (771 LOC, biggest gameplay script) — Player movement, jumping, double jump (from roguelite upgrades), mobile controls integration
- `GlobalTapJump` — Tap-to-jump for mobile
- `LetterboxInputExtender` — Extends touch input to letterbox areas
- `DropThroughPlatform` — One-way platform dropping
- `MusicCycler` — Background music management
- `GameInputManager` — Minimal input routing

#### Progression
- `MainMenuManager` — Button wiring, transition animations, bundle download awareness
- `LevelManager` — Level lifecycle: start → two-stage sequences → completion → save health → next level
- `LevelSelectionManager` — Grid of level buttons
- `VideoManager` — Video playback scene management
- `VideoSelectionManager` — Grid of video buttons
- `UpgradeShopManager` — Purchase extra jumps, health upgrades
- `BundleDownloadManager` — Download addressable bundles with progress UI

#### UI
- `LevelButton` — Individual level button with state (locked/unlocked/completed)
- `VideoButton` — Individual video button with state
- `HealthUI` — Heart display for player health
- `PointsUI` — Points counter display

### VideoFrameExtractor (`SickOfIt.VideoFrameExtractor`)
Custom system for the game's unique video-to-sprite pipeline:
- **Editor**: FFmpegFrameExtractor, SpriteFramesEditorWindow, SpriteFrameClipEditor
- **Runtime**: SpriteFrameRenderer, SpriteFramePlaybackController, SpriteFramesData
- **Timeline**: Custom timeline track for sprite frame playback in PlayableDirectors

### Third Party
- `nappin.MobileControllerFramework` — Mobile joystick, buttons, D-pad (used extensively for UI buttons too)
- `EZhex1991.EZSoftBone` — Physics-based bone animation
- `TextMesh Pro` — UI text

## Key Patterns & Observations

### Things That Work Well
- Assembly separation is clean (Combat can't see Editor, Data is standalone)
- Roguelite health cascade system is clever
- Addressables split keeps WebGL build small (~4 scenes in base, rest downloaded)
- VideoFrameExtractor is a unique custom tool pipeline

### Potential Issues / Tech Debt
1. **Duplicate health systems**: `HealthSystem` and `EnemyHealth` have nearly identical code (health bar creation is copy-pasted). `PlayerHealth` is separate and correct. `HealthSystem` might be legacy.
2. **Excessive debug logging**: SceneLoadingManager has ~30 Debug.Log lines including `[MOBILE DEBUG]` tags — looks like leftover debugging
3. **PlayerPrefs for everything**: All persistence is PlayerPrefs (keys like `Level_1_Completed`, `Rogue_Level_1_EndHealth`). Works for WebGL but fragile — no migration path, no data validation, keys scattered across GameProgressManager + RogueliteManager
4. **Magic strings**: Scene names, PlayerPrefs keys, addressable addresses are string literals throughout
5. **Singleton explosion**: 6+ singletons with identical boilerplate. No service locator or DI.
6. **FindObjectsOfType in Awake**: EnemyBase searches all GameObjects to find player — expensive, runs per enemy
7. **Multiple AnimationEventRelay scripts**: Three near-identical relay scripts (Fighter, Sentinel, Shooter) — should be one generic
8. **SlimeIdleAnimation.cs in Tools (runtime)**: Not in Editor assembly but seems like a tool script
9. **Editor scripts from AI pipeline**: AutoSlimeImport.cs, AutoSlimeImport_Fixed.cs, ImprovedEnemyPrefab.cs, SlimeCharacterSetup.cs, ClawCharacterPipeline.cs — some may be redundant/experimental

## Assembly Dependencies (from asmdef files)
```
SickOfIt.Data → (none, standalone)
SickOfIt.Combat → SickOfIt.Core, SickOfIt.Data
SickOfIt.Core → SickOfIt.Data, nappin, TextMeshPro, Addressables, InputSystem
SickOfIt.Core.Progression → SickOfIt.Data, SickOfIt.Core, SickOfIt.Combat, VideoFrameExtractor.Runtime, nappin, TextMeshPro, Addressables
SickOfIt.Tools.Editor → Addressables (editor-only)
SickOfIt.VideoFrameExtractor.Editor → VideoFrameExtractor.Runtime, Addressables, Timeline (editor-only)
SickOfIt.VideoFrameExtractor.Runtime → SickOfIt.Core, Addressables, Timeline
```

Note: Core.Progression is a SEPARATE assembly from Core — it's the bridge that can reference Combat. LevelManager lives there because it needs PlayerHealth.
Note: Combat references Core (circular-ish: Combat → Core, Core.Progression → Combat). Works because Core.Progression is separate from Core.
