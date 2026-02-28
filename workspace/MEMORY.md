# Memory

## Project: Sick Of It
- 2D action game with roguelite elements, Unity 6 WebGL
- 15 scenes: 4 menus, 4 levels, 4 videos, 3 deaths, 1 animation
- Only menu scenes in build settings; levels/videos/deaths loaded via Addressables
- Current deployed version: v97
- Hosted on EC2 via Docker (nginx:alpine)
- Docker Hub: jgriffith3433/sickofitgame:latest

## Project: Claw (This AI)
- OpenClaw-based AI game dev assistant
- Custom Docker image: jgriffith3433/claw-docker:latest
- Source mounted at: /home/node/.openclaw/workspace/claw-docker
- Channels: Telegram bot
- Tools: Unity MCP, GitHub MCP, rembg, ffmpeg, ImageMagick, Claude Code, yt-dlp
- Memory files live in claw-docker/workspace/ so they're version-controlled

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
- Deploy flow: aws ec2 run-instances → ssh → docker login → docker compose up
- ComfyUI on GPU: yanwk/comfyui-boot:latest with nvidia runtime

## Skill Installation Convention
- Install skill live with `clawhub install <name>`
- Add `COPY workspace/skills/<name> /home/node/.openclaw/workspace/skills/<name>` to Dockerfile
- Skills are vendored in git (tracked via `!workspace/skills/` in .gitignore)
- Fresh clone builds work out of the box — no clawhub dependency at build time
- To update: `clawhub update <name>` live, then commit the changed files
- New skill folders need explicit `git add workspace/skills/<name>` on first commit
