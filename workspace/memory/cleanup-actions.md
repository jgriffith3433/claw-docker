# Cleanup Actions - 2026-03-01

## Issues Found - UPDATED
- Main menu still loading Video1 scene instead of UnifiedVideoScene
- SceneTransitionManager hardcoded to load specific scene names
- Old scene folders still exist: Deaths, LevelS, VideoS
- Animation.unity scene broken (missing SlimeEnemy_Fixed prefab)  
- Enemy_Shooter prefabs have missing scripts on Demon2 GameObject

## Solution Created - UPDATED
- **CleanupAndFix.cs** - Comprehensive script that:
  1. **Fixes SceneTransitionManager** - Updates LoadLevel/LoadVideo/LoadDeathScene to use unified scenes
  2. **Deletes old scene folders** - Removes Deaths/, LevelS/, VideoS/ folders entirely
  3. Fixes broken prefabs (removes missing scripts, adds AnimationEventRelay)
  4. Creates clean unified scenes from scratch
  5. Updates build settings to only menu scenes

## Key Fix
- SceneTransitionManager.LoadVideo() now loads "UnifiedVideoScene" instead of "Video1"
- Config-driven approach: VideoRuntime reads CurrentVideoNumber from PlayerPrefs 
- Same pattern for levels and death scenes

## Files Removed
- FixVideoAndConsolidate.cs (had errors)
- All old scene folders and individual scenes

## Next Steps  
Run: `SickOfIt → Clean Up & Fix Everything` in Unity Editor menu