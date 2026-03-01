# Unified Game Builder - 2026-03-01

## Problem Identified
GameBuilder was still using old individual scene generation approach instead of unified scenes, which caused the main menu loading issues.

## Solution Created
**UnifiedGameBuilder.cs** - Complete rewrite of the build system:

### Architecture
- **3 Unified Scenes**: UnifiedVideoScene, UnifiedLevelScene, UnifiedDeathScene
- **Config-Driven Content**: Everything loaded via GameDefinition + Runtime bootstraps
- **Smart Addressables**: Creates addresses for "Video1", "Level1", etc. that point to unified scenes

### Key Features
1. **Ensures Unified Scenes Exist** - Creates if missing
2. **Smart Addressables Setup** - Creates duplicate entries so "Video1" → UnifiedVideoScene
3. **Validation** - Checks GameDefinition for missing assets/config
4. **Deprecation Path** - Old GameBuilder warns and redirects to unified approach

### Addressables Logic
For each video in GameDefinition:
- Creates addressable entry "Video1" → UnifiedVideoScene
- Creates addressable entry "Video2" → UnifiedVideoScene  
- etc.

Same pattern for levels and deaths.

## Files Updated
- `UnifiedGameBuilder.cs` - New unified build system
- `GameBuilder.cs` - Updated to warn about deprecation and redirect
- `SceneTransitionManager.cs` - Already updated to use unified scenes

## Data Flow (Fixed)
1. **Main Menu** → "New Game" → `SceneTransitionManager.LoadVideo(1)`
2. **SceneTransitionManager** → Sets PlayerPrefs → Loads "Video1" via Addressables  
3. **Addressables** → "Video1" address points to UnifiedVideoScene → Loads UnifiedVideoScene
4. **VideoRuntime** → Auto-bootstraps → Reads PlayerPrefs → Uses GameDefinition → Displays Video 1

## Next Steps  
1. Run: `Tools → Claw → Build Unified Project` in Unity
2. Test main menu → should load video properly
3. All content now config-driven via unified scenes