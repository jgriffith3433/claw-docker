# Art & Content Pipeline — Sick Of It

## Overview

Two distinct pipelines: **Video Pipeline** (scenes, backgrounds, deaths) and **Character Pipeline** (enemies, NPCs). Both start from AI-generated video and end as Unity assets.

---

## Video Pipeline

### Purpose
Videos play as scene content: cutscenes (Video1-4), level backgrounds (Level1_Background1, etc.), death animations (Death1-3), and menu effects (MainMenu_Background1, MainMenu_Explode).

### Current Workflow (Manual Steps)

1. **Generate video** — LumaLabs Dream Machine (AI video generation)
2. **Edit in Camtasia Studio** — trim, composite, add effects, export:
   - `{Name}.mp4` — video file
   - `{Name}_Audio.mp3` — separate audio track
3. **Import to Unity** — drop both files into `Assets/Videos/`
4. **Extract frames** — Unity editor tool: `Tools > Video Frame Extractor`
   - Uses ffmpeg on Windows (`C:\ffmpeg\bin\ffmpeg.exe` or PATH)
   - Extracts at target FPS (default 30), outputs as `frame_00000.jpg`, `frame_00001.jpg`, etc.
   - Creates folder `Assets/Videos/{Name}_frames/`
   - Script: `FFmpegFrameExtractorWindow.cs` / `FFmpegHelper.cs`
5. **Create SpriteFramesData** — ScriptableObject at `Assets/Videos/{Name}.asset`
   - Stores: videoName, sourceFrameWidth/Height, maxSheetSize, grid config (cols/rows/framesPerSheet), frame cell dimensions, pixelsPerUnit
   - Has auto-calculate for optimal grid
6. **Pack into sprite sheets** — Unity editor tool: `Tools > Sprite Frames Manager` (Step 2)
   - Select all extracted frames in Project window
   - Packs into `{Name}_SpriteSheets/` folder
   - Output: `{Name}_sheet_0000.png`, `{Name}_sheet_0001.png`, etc.
   - Typical config: 2048x2048 sheets, 2 cols x 3 rows = 6 frames/sheet
   - Frames scaled to fit while preserving aspect ratio
7. **Auto-chunk** — Same editor tool (Step 3)
   - Groups sprite sheets into downloadable chunks (e.g., 64 frames per chunk)
   - Each chunk gets a name like `{Name}_Part1`, `{Name}_Part2`
8. **Assign Addressable labels** — Same editor tool (Step 5)
   - Each chunk's sprite sheets get labeled: `{Name}_Part1`, `{Name}_Part2`, etc.
   - Manually assign to Addressable groups
9. **Setup player** — Same editor tool (Step 6)
   - Extracts first frame as `{Name}_FirstFrame.png` (loading screen placeholder)
   - Audio file goes on Unity Timeline
10. **Timeline integration** — SpriteFrameTrack drives SpriteFrameRenderer
    - SpriteFrameMixerBehaviour manages chunk loading/unloading
    - Downloads addressable bundles on demand, streams sprite sheets

### Key Files
| File | Path | Purpose |
|------|------|---------|
| FFmpegFrameExtractor.cs | Scripts/VideoFrameExtractor/Editor/ | Frame extraction window + FFmpegHelper |
| SpriteFramesEditorWindow.cs | Scripts/VideoFrameExtractor/Editor/ | Sprite sheet packing, chunking, addressables |
| SpriteFramesData.cs | Scripts/VideoFrameExtractor/Runtime/ | ScriptableObject definition |
| SpriteFrameRenderer.cs | Scripts/VideoFrameExtractor/Runtime/ | Runtime display component |
| SpriteFramePlaybackController.cs | Scripts/VideoFrameExtractor/Runtime/ | Playback control |
| SpriteFrameMixerBehaviour.cs | Scripts/VideoFrameExtractor/Runtime/Timeline/ | Timeline mixer, chunk management |

### Existing Videos
| Name | Type | Sheets | Notes |
|------|------|--------|-------|
| Video1 | Cutscene | 150 | 6 chunks (Part1-Part6+) |
| Video2 | Cutscene | 478 | Largest video |
| Video3 | Cutscene | 172 | |
| Video4 | Cutscene | ? | Asset exists, sheets TBD |
| Death1 | Death anim | 32 | |
| Death2 | Death anim | 150 | |
| Death3 | Death anim | 75 frames (not sheets) | Uses SpriteFrames folder |
| Level1_Background1 | Background | 550 | Largest background |
| Level2_Background1 | Background | 247 | |
| Level2_Background2 | Background | 5 | Short loop |
| Level3_Background1 | Background | 134 | |
| Level3_Background2 | Background | 5 | Short loop |
| MainMenu_Background1 | Menu | 6 | Short loop |
| MainMenu_Explode | Menu | 4 | Short effect |

### SpriteFramesData Config (typical - from Video1.asset)
- Source: 1280x720
- Max sheet size: 2048
- Grid: 2 cols x 3 rows = 6 frames/sheet
- Cell: 1024x572 (aspect-preserved)
- Sheet texture: 2048x2048 (power of 2)
- Pixels per unit: 100

---

## Character Pipeline

### Purpose
2D sprite-based enemies and NPCs with animations (idle, walk, attack, transitions).

### Current Workflow (Manual Steps)

1. **Generate animation videos** — AI video generation (separate video per animation: idle, attack, walk)
2. **Extract frames** — ffmpeg, same as video pipeline
3. **Remove backgrounds** — rembg or manual, on every frame
4. **Create sprite sheet** — arrange frames in a grid (single PNG per animation)
5. **Import to Unity** — place in `Assets/Images/`
   - Set Texture Type: Sprite (2D and UI)
   - Set Sprite Mode: **Multiple**
6. **Slice sprite sheet** — Unity Sprite Editor, grid or auto slice
   - Creates sub-sprites: `FighterIdle_0`, `FighterIdle_1`, etc.
7. **Create animation** — select all sub-sprites in Project, drag into Scene/Prefab
   - Unity auto-creates `.anim` clip + Animator Controller
8. **Build Animator Controller** — manually wire up states:
   - Idle (default) → Walk (IsWalking bool) → Attack (IsAttacking bool)
   - Transitions with conditions
   - Controller placed in `Assets/Animations/`
9. **Script control** — enemy scripts use `animator.SetBool("IsAttacking", true)` etc.

### Existing Characters
| Character | Animations | Sprite Sheets |
|-----------|-----------|---------------|
| Fighter (Bork?) | Idle (10 frames), Walk, Attack | FighterIdle.png, FighterWalk.png, FighterAttack.png |
| Demon | Idle, Attack | Demon1.png, Demon2.png |
| Level3Enemy (Sentinel?) | CrouchingIdle, CrouchingAttack, StandingIdle, StandingAttack, StandingAttack2, CrouchToStanding, StandingToCrouch | 7 sprite sheets |
| Diamond | Spinning animation | Diamond.png |
| Fireball | Animation | Fireball.png |
| Teleporter | Animation | Teleporter.png |
| Shadow | Animation | Shadow.png |
| Yooba (player) | 3D model | Only 3D model in game, uses YoobaAnimator.controller |

### Enemy Script Architecture
- `EnemyBase.cs` — base class
- `EnemyShooter.cs` — ranged enemy (Bork), uses `Animator.SetBool("IsAttacking", true/false)`
- `EnemyFighter.cs` — melee enemy
- `EnemyChaser.cs` — chasing enemy
- `EnemySentinel.cs` — Level3 enemy with crouch/stand states
- `AnimationEventRelay*.cs` — relay animation events to enemy scripts

---

## What Claw Can Automate

### Already Possible (Docker container tools)
- **Frame extraction from video** — ffmpeg is installed in the container
- **Background removal** — rembg is installed
- **Sprite sheet packing** — ImageMagick `montage` command
- **Image generation** — ComfyUI (set up and working)
- **Sound effects** — ElevenLabs/ClawVox (set up and working)
- **Video download** — yt-dlp for reference material

### Requires Unity Editor (MCP)
- Creating SpriteFramesData ScriptableObjects
- Auto-chunking and addressable label assignment
- Sprite import settings (Multiple mode, slicing)
- Creating .anim clips from sprite sequences
- Building Animator Controllers
- Setting up Timeline tracks

### Potential Automation Pipeline

#### Video → Game (automated)
1. User provides video file or ComfyUI generates it
2. Claw extracts frames (ffmpeg in container)
3. Claw packs sprite sheets (ImageMagick in container)
4. Claw copies sheets to Unity project
5. Unity MCP: create SpriteFramesData, assign addressables, set import settings
6. Unity MCP: setup Timeline track

#### Character → Game (automated)
1. User provides animation videos or ComfyUI generates them
2. Claw extracts frames (ffmpeg)
3. Claw removes backgrounds (rembg)
4. Claw packs into sprite sheets (ImageMagick)
5. Claw copies to Unity project
6. Unity MCP: set sprite import to Multiple, slice grid
7. Unity MCP: create .anim clips and Animator Controller
8. Connect to existing enemy script architecture

---

## Character Creation Pipeline (Automated)

### Architecture
Three layers: ComfyUI (generate) → Claw Container (process) → Unity MCP (import)

### Layer 1: ComfyUI (Generation)
- **Custom nodes installed:**
  - `ComfyUI-AnimateDiff-Evolved` — generates animation frame sequences from prompt/image
  - `ComfyUI-VideoHelperSuite` — frame handling utilities
  - `ComfyUI-KJNodes` — batch processing utilities
- **Motion model:** `v3_sd15_mm.ckpt` (1.67GB, AnimateDiff v3 for SD 1.5)
- **Workflows:**
  - `character-concept.json` — text → single character image (SD 1.5, 512x512)
  - `character-animate.json` — image → animation frames (AnimateDiff, 16 frames)

### Layer 2: Claw Container (Processing)
- **Script:** `scripts/character-pipeline.py`
- **Dependencies:** rembg[cpu,cli], ImageMagick (montage/convert), ffmpeg, Pillow
- **Pipeline steps:**
  1. Collect frames (from directory, video file, or ComfyUI output)
  2. Remove backgrounds (rembg)
  3. Normalize frame sizes (consistent dimensions, centered)
  4. Pack into sprite sheet grid (ImageMagick montage)
  5. Generate metadata JSON (cols, rows, fps, loop, etc.)
- **Usage:** `python3 scripts/character-pipeline.py -i frames/ -n BlobEnemy -a idle -o output/`
- **Flags:** `--no-rembg`, `--frame-size N`, `--cols N`, `--fps N`, `--unity-project path`

### Layer 3: Unity Editor (Import via MCP)
- **Script:** `Scripts/Tools/Editor/ClawCharacterPipeline.cs`
- **Assembly:** `SickOfIt.Tools.Editor`
- **Methods (callable via MCP):**
  - `ImportSpriteSheet(assetPath, columns, rows, pixelsPerUnit)` — Sprite/Multiple + grid slice
  - `CreateAnimClip(spriteSheetPath, clipName, fps, loop, outputDir)` — creates .anim
  - `CreateAnimatorController(name, clipPaths, defaultState, outputDir)` — creates .controller with state machine
  - `CreateEnemyPrefab(name, controllerPath, idleSheetPath, enemyType, outputDir)` — full prefab
- **Menu items:**
  - `Tools/Claw/Import Sprite Sheet From Metadata` — select *_meta.json → auto-import
  - `Tools/Claw/Create Character From Metadata` — select all *_meta.json → full character creation
- **Metadata JSON format:**
  ```json
  {
    "name": "BlobEnemy",
    "animation": "idle",
    "frameCount": 16,
    "columns": 4,
    "rows": 4,
    "frameWidth": 256,
    "frameHeight": 256,
    "fps": 12,
    "loop": true
  }
  ```

### End-to-End Flow (what happens when user says "create a blob enemy")
1. Claw generates concept image via ComfyUI (`character-concept.json`)
2. Claw generates animation frames via ComfyUI (`character-animate.json` with AnimateDiff)
3. For each animation (idle, attack, explode, etc.):
   a. Run `character-pipeline.py` → sprite sheet + metadata JSON
   b. Copy to `Assets/Images/`
4. Via Unity MCP:
   a. Call `ImportSpriteSheet()` for each sprite sheet
   b. Call `CreateAnimClip()` for each animation
   c. Call `CreateAnimatorController()` with all clips
   d. Call `CreateEnemyPrefab()` with controller + type
5. Wire up enemy behavior in scripts (may need new C# class for custom behavior)

### ComfyUI Integration Opportunities
- **Background videos** — img2video workflows, loop generation
- **Death animations** — dramatic effect generation
- **Character sprites** — consistent style generation with ControlNet
- **Sprite upscaling** — upscale models for higher resolution assets
- **Style transfer** — apply consistent art style across assets
- **Inpainting** — fix/modify existing sprites

---

## File Locations

```
Assets/
├── Videos/                          # Video pipeline assets
│   ├── {Name}.mp4                   # Source video
│   ├── {Name}_Audio.mp3             # Audio track
│   ├── {Name}.asset                 # SpriteFramesData ScriptableObject
│   ├── {Name}_FirstFrame.png        # Loading placeholder
│   ├── {Name}_frames/               # Extracted frames (intermediate)
│   └── {Name}_SpriteSheets/         # Packed sprite sheets (final)
│       ├── {Name}_sheet_0000.png
│       └── ...
├── Images/                          # Character sprites
│   ├── {Character}{Animation}.png   # Sprite sheets (Multiple mode)
│   └── ...
├── Animations/                      # Animation assets
│   ├── {Character}.controller       # Animator Controllers
│   ├── {Character}{Animation}.anim  # Animation clips
│   └── ...
└── Scripts/
    ├── VideoFrameExtractor/
    │   ├── Editor/                  # Frame extraction + sprite sheet tools
    │   └── Runtime/                 # SpriteFramesData, renderer, Timeline
    └── Combat/Enemies/              # Enemy scripts with animator control
```
