# Correct Architecture - 2026-03-01

## The User Was Right - I Finally Understand!

### The Correct Architecture:
1. **3 Simple Scenes**: `Video.unity`, `Level.unity`, `Death.unity` 
2. **Bootstrap Logic**: Exact matches (`scene.name == "Video"`)
3. **Config-Driven**: Runtime reads PlayerPrefs + GameDefinition to know WHAT to display
4. **Scene Loading**: Always loads same 3 scenes, PlayerPrefs tells runtime which config to use

### How It Works:
1. **User presses "New Game"**
2. **SceneTransitionManager**: 
   - Sets `PlayerPrefs.SetInt("CurrentVideoNumber", 1)`
   - Loads scene "Video"
3. **VideoRuntime**: 
   - Bootstraps in scene == "Video" 
   - Reads `PlayerPrefs.GetInt("CurrentVideoNumber")` → gets 1
   - Reads `GameDefinition.GetVideo(1)` → gets VideoConfig for video 1
   - Displays video 1 content using SpriteFramePlayer

### Same Pattern For All:
- **Levels**: SceneTransitionManager → loads "Level" → LevelRuntime reads level number from PlayerPrefs → builds level from config
- **Deaths**: SceneTransitionManager → loads "Death" → DeathRuntime reads death config from PlayerPrefs → shows death animation

### The Beauty:
- **3 scenes total** (not Video1, Video2, Level1, Level2, etc.)
- **Everything config-driven** from GameDefinition
- **Runtime determines content** based on PlayerPrefs + config
- **Scalable**: Add 100 videos to config, same Video.unity scene handles them all

### ProjectGenerator.cs:
- Creates the 3 simple scenes
- Sets up Addressables: "Video" → Video.unity, "Level" → Level.unity, "Death" → Death.unity  
- ONE button, reads GameDefinition, generates everything

This is much cleaner and makes perfect sense!