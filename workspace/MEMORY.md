# Memory

## Project: Sick Of It
- 2D action game with roguelite elements, Unity 6 WebGL
- 15 scenes: 4 menus, 4 levels, 4 videos, 3 deaths, 1 animation
- Only menu scenes in build settings; levels/videos/deaths loaded via Addressables
- Current deployed version: v97
- Hosted on EC2 via Docker (nginx:alpine)
- Docker Hub: jgriffith3433/sickofitgame:latest
- Website has /videos folder now (added for Slimed.mp4)

## Project: Claw (This AI)
- OpenClaw-based AI game dev assistant
- Custom Docker image: jgriffith3433/claw-docker:latest
- Source mounted at: /home/node/.openclaw/workspace/claw-docker
- Channels: Telegram bot
- Tools: Unity MCP, GitHub MCP, rembg, ffmpeg, ImageMagick, Claude Code, yt-dlp
- Memory files live in claw-docker/workspace/ so they're version-controlled

## Project: ComfyUI Docker (`comfyui-docker` repo)
- GitHub: jgriffith3433/comfyui-docker
- Docker Hub: jgriffith3433/comfyui-docker:gpu
- Base image: yanwk/comfyui-boot:cu128-slim
- Custom Dockerfile.gpu with multi-source model resolver, vendored workflows, custom nodes
- 10 custom nodes: AnimateDiff-Evolved, CogVideoXWrapper, VideoHelperSuite, KJNodes, IC-Light, Advanced-ControlNet, Frame-Interpolation, LTXVideo, Manager, controlnet_aux
- Model auto-resolution: resolve_models.py checks local overrides → ComfyUI-Manager list → HuggingFace → Civitai
- T5-XXL fp8 encoder auto-downloads via entrypoint-hook.sh (~4.9GB)
- CogVideoX GGUF + VAE auto-download on first workflow run
- Named Docker volumes: comfyui-models, comfyui-output, comfyui-input
- Latest commit: `9e6c96f` — "feat: solidify CogVideoX 1.5 GGUF pipeline"
- **From-scratch deployment validated**: Terminate instance → fresh launch → docker compose up → all models auto-download → workflow succeeds

## AI Character Pipeline (FULLY WORKING)
- **End-to-end**: Text prompt → concept image → video animation → frame extraction → background removal → sprite sheet → Unity prefab
- **Concept generation**: SD 1.5 via ComfyUI (~30 seconds on A10G)
- **Animation**: CogVideoX 1.5 GGUF Q4_0 I2V (image-to-video)
  - Resolution: 768×768, Frames: 25→29, Steps: 25, CFG: 6.0, Scheduler: DPM++
  - VRAM: 6.1GB peak, Speed: 6.23s/step, Total: ~3 min generation
  - No CPU offload, no fp8 hack — pure GGUF on GPU
  - **Prompt style**: Emphasize STILLNESS — "motionless, barely moving, only tiniest wobble"
  - **Negative**: "not high quality, low resolution, watermark, strange motion trajectory"
  - CFG must stay 6-7 (10 causes artifacts), DPM++ scheduler required (Euler causes device mismatch)
- **Frame extraction**: ffmpeg, sample 8 evenly-spaced frames from 29
- **Background removal**: rembg (U2-Net) batch processing
- **Sprite sheet**: ImageMagick montage, 4×2 grid, 400×400 per frame
- **Unity import**: C# editor script (SlimeCharacterSetup.cs) — one menu click creates:
  - Sprite sheet import config (Multiple mode, grid slice)
  - SlimeIdle.anim (8-frame loop at 8fps)
  - SlimeAnimator.controller
  - SlimeEnemy.prefab (SpriteRenderer, Animator, CircleCollider2D, kinematic Rigidbody2D)
- **Cost**: ~$0.10/character in GPU compute time

## Models Tested (Video Generation)
- AnimateDiff: Generated different characters each frame (wrong approach for character anim)
- SVD XT: Uncontrolled motion, melting effect
- LTX-Video: Broken — VAE KeyError 'post_quant_conv.weight'
- CogVideoX-5B bf16: OOM on 16GB RAM system
- CogVideoX fp8 + CPU offload: Color drift, artifacts
- **CogVideoX 1.5 GGUF Q4_0: WINNER** — 3GB file, 6.1GB VRAM, great quality

## User: jgrif
- Windows 11, VS Code + Unity 6.3
- Direct communicator, prefers action over explanation
- Iterates fast: build → test → fix → repeat

## Conventions
- Memory writes go to BOTH live workspace and claw-docker/workspace/ (keeps repo in sync)
- Daily logs in memory/YYYY-MM-DD.md
- Long-term notes in this file (MEMORY.md)

## EC2 / Server Management
- Server manager script: `scripts/server-manager.py`
- Server state tracked in: `memory/servers.json`
- PEM key: `sickofitgame-website/sickofitgame-server.pem` (shared across all servers)
- Existing game server: `ubuntu@ec2-13-220-32-55.compute-1.amazonaws.com` (sickofitgame website)
- Docker Hub: `jgriffith3433` (private repos)
- GPU instance types: g4dn.xlarge (T4, $0.53/hr), g5.xlarge (A10G, $1/hr), g6.xlarge (L4, $0.81/hr)
- GPU server root EBS: 200GB gp3 (~$16/month), Docker on EBS (persistent)
- NVMe on g4dn/g5 is EPHEMERAL — never store persistent data there
- Deploy flow: aws ec2 run-instances → ssh → docker login → docker compose up
- Build server: t3.large ($0.09/hr) for Docker image builds
- init-server.sh: One-command server setup (swap + Docker + container start + API health wait)
- setup-server-storage.sh: Handles EBS Docker storage + 16GB swap (persists via fstab)
- g4dn/g5 share same "G and VT" vCPU quota bucket (4 vCPU limit) — can't run both
- IPs change on stop/start — must update servers.json each time
- AMI: ami-0669ac5db8b1292fe (Deep Learning AMI with NVIDIA drivers)
- Security group: sg-063d27eee16d8f626 (ports 22, 8188, 443)

## Current Server State (as of 2026-02-28)
- **comfyui-gpu**: i-031edc38a55aa46d7 (g5.xlarge) — STOPPED (last IP: 100.30.195.50)
- **docker-build**: i-081674320ea2f057d (t3.large) — STOPPED (last IP: 54.164.231.77)
- Both servers stopped to save costs. IPs will change on next start.

## Blog Posts
- `ai-content-pipeline.html` — Feb 27: First ComfyUI + ElevenLabs pipeline setup
- `from-prompt-to-prefab.html` — Feb 28: Full character pipeline walkthrough (concept → prefab)

## Unity MCP Notes
- mcporter server name: `unity` (stdio transport)
- Call format: `mcporter call unity <tool_name> key=value`
- Retry wrapper: `bash scripts/unity-call.sh <tool_name> [args]` — retries 3x with 5s delay
- Console logs: `mcporter call unity get_console_logs logType=error`
- Connection goes through host.docker.internal:8090
- **Requires**: Unity Editor running + MCP Unity Server Window → "Allow Remote Connections" checked
- **McpServerMonitor.cs**: Editor script that auto-restarts MCP server every 5s if it dies (fixes domain reload issue)
- **Persistent Bridge** (`scripts/unity-bridge.mjs`): Experimental, has watchdog but reconnection still unreliable. Use stdio bridge for now.
- **Known issue**: After domain reload, MCP server sometimes stops listening. McpServerMonitor fixes this automatically once compiled.

## Game Definition System — COMPLETE ✅
- **Architecture doc**: `memory/game-definition-system.md`
- **Status**: FULLY BUILT — config-driven everything, no PlayableDirectors, rewind system
- **Data layer**: GameDefinition.cs (singleton SO) + all config types
- **Runtimes**: LevelRuntime, VideoRuntime, DeathRuntime — auto-bootstrap, read from config
- **Experience Layer**: ExperienceRunner with 24 event types, driven by GameClock
- **Rewind System**: GameClock + StateRecorder + RewindController — time flows forward or backward
- **SpriteFramePlayer**: Replaces Timeline-based playback, same memory management, GameClock-driven
- **Scene Generation**: GameBuilder generates all scenes from config, updates Addressables
- **Enemy Pipeline**: EnemyPrefabGenerator creates prefab + template from sprite sheet
- **MCP Tools**: 15+ tools for querying/modifying game config and building scenes
- **Zero PlayableDirectors**: All Timeline assets and PlayableDirector components removed from entire project
- **1 remaining issue**: Level 4 needs music assigned
- **MCP Socket Fix**: Local package with 500ms close timeout, survives domain reloads

## Skill Installation Convention
- Install skill live with `clawhub install <name>`
- Add `COPY workspace/skills/<name> /home/node/.openclaw/workspace/skills/<name>` to Dockerfile
- Skills are vendored in git (tracked via `!workspace/skills/` in .gitignore)
- Fresh clone builds work out of the box — no clawhub dependency at build time
- To update: `clawhub update <name>` live, then commit the changed files
- New skill folders need explicit `git add workspace/skills/<name>` on first commit
