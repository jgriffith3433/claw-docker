# Environment & Architecture

## Runtime

- **Container**: Docker (Debian Bookworm / Node.js 22)
- **Workspace**: `/home/node/.openclaw/workspace`
- **Scratch dir**: `/tmp/openclaw/` (use for temp files, clean up after)
- **Available runtimes**: Python 3, Node.js 22, Bun, bash, git, curl, wget

## Mounted Projects

Both game projects are volume-mounted from the Windows host into the container:

| Project | Host Path (Windows) | Container Path |
|---------|---------------------|----------------|
| Unity game | `C:\Projects\sickofitgame-unity` | `/home/node/.openclaw/workspace/sickofitgame-unity` |
| Website | `C:\Projects\sickofitgame-website` | `/home/node/.openclaw/workspace/sickofitgame-website` |

⚠️ **Path mapping**: When reading/writing project files, always use the container paths above. The host paths are only relevant for Unity Editor CLI commands (which run on Windows).

## Unity Project — Sick Of It (`sickofitgame-unity`)

### Engine & Build Target
- **Unity 6000.3.7f1** (Unity 6.3)
- **Build target**: WebGL
- **Asset system**: Addressables (remote content bundles)
- **Unity Editor path**: `C:\Program Files\Unity\Hub\Editor\6000.3.7f1\Editor\Unity.exe`

### Assembly Structure
| Assembly | Path | Purpose |
|----------|------|---------|
| `SickOfIt.Core` | `Scripts/Core/` | Scene loading, input, device, UI, analytics |
| `SickOfIt.Core.Progression` | `Scripts/Core/Progression/` | Level/video/upgrade progression, bundle downloads |
| `SickOfIt.Combat` | `Scripts/Combat/` | Enemies, health, damage, effects, pickups |
| `SickOfIt.Data` | `Scripts/Data/` | Game config, progress persistence, roguelite data |
| `SickOfIt.Tools.Editor` | `Scripts/Tools/Editor/` | Build scripts, deploy window (editor-only) |
| `SickOfIt.VideoFrameExtractor.Editor` | `Scripts/VideoFrameExtractor/Editor/` | FFmpeg frame extraction, sprite editor |
| `SickOfIt.VideoFrameExtractor.Runtime` | `Scripts/VideoFrameExtractor/Runtime/` | Sprite playback, timeline integration |

Third-party: `nappin.MobileControllerFramework` (mobile controls), `EZhex1991.EZSoftBone` (physics)

### Scene Inventory (15 scenes)
| Category | Scenes |
|----------|--------|
| **Menus** | MainMenu, LevelSelection, VideoSelection, UpgradeShop |
| **Levels** | Level1, Level2, Level3, Level4 |
| **Videos** | Video1, Video2, Video3, Video4 |
| **Death** | Death1, Death2, Death3 |
| **Utility** | Animation |

**Build settings**: Only 4 scenes enabled (MainMenu, LevelSelection, VideoSelection, UpgradeShop). Levels/videos/deaths are loaded via Addressables at runtime.

### Key Scripts
- `GameDeployWindow.cs` — Editor GUI with full 8-step deploy pipeline
- `ClawBuildScript.cs` — Headless CLI build methods (for you to invoke)
- `GameProgressManager.cs` — Save/load progression data
- `RogueliteManager.cs` — Roguelite game loop management
- `GameConfiguration.cs` — Central game config (ScriptableObject)
- `AddressablesSceneLoader.cs` — Remote scene loading via Addressables
- `BundleDownloadManager.cs` — Content bundle download and caching

### Build Script Methods (ClawBuildScript.cs)
Invoke via Unity CLI in batch mode:
```
Unity.exe -batchmode -projectPath "C:\Projects\sickofitgame-unity" -executeMethod SickOfIt.Tools.Editor.ClawBuildScript.<MethodName> -quit -logFile -
```

| Method | What it does |
|--------|-------------|
| `FullDeploy` | Complete pipeline: clean → addressables → version bump → copy → WebGL build → version replace |
| `BuildWebGL` | WebGL build only (no addressables, uses current version folder) |
| `BuildAddressables` | Build addressables only |

Environment variables for build:
- `BUILD_VERSION` — Override version number (auto-detects if not set)
- `WEBSITE_PATH` — Override website project path (default: `C:\Projects\sickofitgame-website`)

## Website Project (`sickofitgame-website`)

### Structure
```
sickofitgame-website/
├── index.html              # Landing page
├── Game/                   # Unity WebGL builds
│   ├── index.html          # Game loader page
│   ├── v0000000/           # Template (never deleted)
│   └── v{N}/               # Current version (currently v96)
│       └── SickOfIt/       # WebGL build output
│           ├── Build/
│           ├── index.html
│           ├── StreamingAssets/
│           └── TemplateData/
├── PreGame/                # Pre-game content (vp0000 template + vp6 current)
├── BuyGame/                # Purchase page
├── TakeGame/               # Claim page
├── blog/                   # Blog with posts, lore, music, shorts, stats
├── backend/                # Python/Flask paywall (Stripe + Resend)
├── Dockerfile              # Multi-stage nginx:alpine
├── docker-compose.*.yml    # Dev / prod / deploy
├── nginx.conf
└── *.bat                   # Windows automation scripts
```

### Deployment Pipeline
- **Docker Hub**: `jgriffith3433/sickofitgame:latest` (private)
- **Server**: EC2 instance
- **SSH key**: `sickofitgame-server.pem` in website project root
- **Workflow**: Dev → Docker build → Push to Hub → Pull on EC2 → Run

### Version Convention
- Template folder `v0000000` is never touched
- New builds go to `v{N+1}`, old `v{N}` is deleted
- All references to `v{N}` in HTML/JS/CSS/config files are find-replaced with `v{N+1}`

## MCP Servers

### GitHub MCP
- Full GitHub API access via official GitHub MCP server
- Configured in mcporter at startup
- Use `mcporter list github --schema` for all available tools

### Unity MCP (mcp-unity)
- 30+ tools for controlling Unity Editor remotely
- Connects via WebSocket to Unity Editor on Windows host (`host.docker.internal:8090`)
- Bridge server at `/opt/mcp-unity/Server~/build/index.js`
- Use `mcporter list unity-mcp --schema` for all available tools
- **Requires Unity Editor to be running with the mcp-unity package installed**

## Conventions

- Save output files to workspace before sending
- Clean up temp files in `/tmp/openclaw/` after processing
- Use absolute container paths for all file operations
- When editing C# files, always preserve `.meta` file pairs
- When creating new C# files, Unity will generate `.meta` files automatically when it refreshes
- Put editor scripts in `SickOfIt.Tools.Editor` assembly (or appropriate assembly)
- Put runtime scripts in the appropriate assembly by namespace

## Git Inside Docker

The game projects are **volume-mounted from Windows** (via Docker's 9p/gRPC FUSE). This creates a few gotchas:

### Line Endings (CRLF / LF)
- The container auto-sets `core.autocrlf true` so Git converts CRLF→LF on commit and LF→CRLF on checkout.
- If you still see phantom diffs (`git diff` shows changes on every file), run:
  ```bash
  git diff --stat   # confirm it's whitespace-only
  git checkout -- . # reset working tree
  ```
- Each mounted repo should have a `.gitattributes` with `* text=auto` to enforce consistent line endings across platforms.

### Git Credentials (Push / Pull)
- A credential helper is configured at startup that reads `GITHUB_PERSONAL_ACCESS_TOKEN` from the environment.
- `git push` and `git pull` to GitHub **just work** — no need to inject tokens into remote URLs.
- The same PAT is used by the GitHub MCP server, so all GitHub access uses one token.
- If credentials aren't working, verify the env var is set: `echo $GITHUB_PERSONAL_ACCESS_TOKEN | head -c 8`

### Git LFS
- `git-lfs` is installed in the container, but **smudge is skipped by default** (`GIT_LFS_SKIP_SMUDGE=1`) to avoid slow downloads on mounted volumes.
- LFS hooks work normally — no need for `core.hooksPath` workarounds.
- To download LFS objects for a specific file: `git lfs pull --include="path/to/file"`
- To enable full LFS smudge in a repo: `git lfs install --local` (overrides the skip)

### 9p Mount Performance
- Git operations on mounted Windows volumes are **significantly slower** than on native Linux filesystems, especially for repos with many files (like Unity projects with LFS).
- **Tips to reduce friction:**
  - Use `git --no-optional-locks status` instead of plain `git status`
  - Keep `GIT_LFS_SKIP_SMUDGE=1` (default) to avoid downloading large binaries inside the container
  - For large commits/pushes, consider asking the user to run them from the Windows host
  - Avoid running `git gc` or `git repack` on mounted volumes
  - If Git seems stuck, it may be waiting on filesystem locks — use `--no-optional-locks` flag
