# Project Generator - Final Solution - 2026-03-01

## Problem Summary
The user was right - I had overcomplicated everything with "Unified" scenes and multiple tools. The solution needed to be:
1. ONE script that generates everything from config
2. Standard scene names (Video1, Level1, Death1)
3. Everything driven by GameDefinition
4. One button: "Generate Project"

## Final Solution: ProjectGenerator.cs

### What it does:
1. **Reads GameDefinition** from Assets/Resources/GameDefinition.asset
2. **Cleans up old scenes** - deletes any existing Video*, Level*, Death*, Unified* scenes
3. **Generates scenes from config**:
   - Video1.unity, Video2.unity, etc. (one per VideoConfig)
   - Level1.unity, Level2.unity, etc. (one per LevelConfig) 
   - Death1.unity, Death2.unity, etc. (one per DeathConfig)
4. **Sets up Addressables** - adds all scenes to GameScenes group with proper addresses
5. **ONE BUTTON** - `SickOfIt → Generate Project`

### Scene Structure:
Each generated scene contains only the basics:
- **Video scenes**: Camera (-10z), VideoPlayer GameObject (SpriteRenderer), Audio GameObject
- **Level scenes**: Camera (-10z), Level/Spawns/PlayerSpawn hierarchy  
- **Death scenes**: Camera (-10z), DeathPlayer GameObject (SpriteRenderer)

### Runtime Bootstrap:
- VideoRuntime auto-bootstraps in any scene starting with "Video"
- LevelRuntime auto-bootstraps in any scene starting with "Level"  
- DeathRuntime auto-bootstraps in any scene starting with "Death"
- Each runtime reads the scene number from PlayerPrefs and loads the appropriate config

### Flow:
1. User runs `SickOfIt → Generate Project`
2. Script reads GameDefinition, generates all scenes from config
3. User presses "New Game" in MainMenu
4. SceneTransitionManager loads "Video1" via Addressables
5. VideoRuntime auto-bootstraps, reads config, displays video

## Files Changed:
- **NEW**: ProjectGenerator.cs - The ONE script that does everything
- **REVERTED**: VideoRuntime, LevelRuntime, DeathRuntime - back to StartsWith() bootstrap
- **REVERTED**: SceneTransitionManager - back to standard scene names (Video1, Level1)
- **DELETED**: UnifiedGameBuilder, CleanupAndFix, SimpleAddressablesSetup, debug scripts

## Result:
- ONE script, ONE button, config-driven project generation
- Standard scene names that match expectations
- Clean, simple architecture
- Everything driven by GameDefinition source of truth