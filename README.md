# OpenClaw Docker Setup

Self-contained Docker setup for [OpenClaw](https://github.com/openclaw/openclaw) — a personal AI assistant with Telegram integration, background removal, video tools, and browser automation pre-installed.

## What's included

Everything is pre-baked into the Docker image — no first-run downloads:

- **OpenClaw gateway** built from source
- **rembg** (AI background removal) with pre-cached u2net model
- **Pillow** (image manipulation)
- **yt-dlp** (video downloads)
- **ffmpeg** (video/audio processing)
- **ImageMagick** (image conversion)
- **Playwright + Chromium** (browser automation)
- **GitHub CLI** (`gh`)
- **clawhub**, **mcporter**, **claude-code** (Node tools)

## Prerequisites

- [Docker Desktop](https://www.docker.com/products/docker-desktop/) (Windows for local dev)
- An [Anthropic API key](https://console.anthropic.com)
- A Telegram bot token — see [Telegram Setup](#telegram-setup) below
- Docker Hub account with access to `jgriffith3433/claw-docker` (private repo)

## Quick Start (Local Development)

1. **Clone this repo:**
   ```
   git clone https://github.com/jgriffith3433/claw-docker-docker.git
   cd openclaw-docker
   ```

2. **Create your `.env` file:**
   ```
   copy .env.example .env
   ```
   Edit `.env` and fill in your keys:
   - `OPENCLAW_GATEWAY_TOKEN` — generate one: `node -e "console.log(require('crypto').randomBytes(32).toString('hex'))"`
   - `ANTHROPIC_API_KEY` — from Anthropic Console
   - `TELEGRAM_BOT_TOKEN` — from @BotFather on Telegram

3. **Start it:**
   ```
   start.bat
   ```
   First build takes ~10 minutes. Subsequent starts use cached layers.

4. **Open the web UI:**
   ```
   open-web.bat
   ```

5. **Pair your Telegram account:**
   ```
   pair-telegram.bat
   ```

## Docker Compose Files

| File | Purpose | Where it runs |
|---|---|---|
| `docker-compose.dev.yml` | Local development — builds from Dockerfile | Windows (local) |
| `docker-compose.prod.yml` | Production build — tags as `jgriffith3433/claw-docker:latest` | Windows (local) |
| `docker-compose.deploy.yml` | Deployment — pulls from Docker Hub, no build | EC2 server |

## Batch Scripts

| File | What it does |
|---|---|
| `start.bat` | Build image + start gateway + show logs (local dev) |
| `reset.bat` | Wipe config volume (re-seeds on next start) |
| `open-web.bat` | Open the web UI in your browser |
| `pair-telegram.bat` | Pair your Telegram account with the bot |
| `deploy.bat` | Build, push to Docker Hub, deploy to EC2 |
| `deploy-full.bat` | Full rebuild (no cache) + deploy |
| `auto-copy-deploy.bat` | Copy `.env` and deploy compose to EC2 |
| `auto-ssh.bat` | SSH into the EC2 server |

## Deploying to AWS (EC2)

### Server info

Deployment is configured for the **Arc Crusader** EC2 server:

| Setting | Value |
|---|---|
| Host | `18.206.220.35` |
| User | `ec2-user` |
| PEM | `claw-server-key-server-key.pem` |
| Remote dir | `~/openclaw` |

Make sure **port 18789** (TCP) is open in the EC2 security group.

Place the `claw-server-key-server-key.pem` key file in this project folder.

### Deploy

1. **Log into Docker Hub** (first time only):
   ```
   docker login
   ```

2. **Run the deploy script:**
   ```
   deploy.bat
   ```

   This will:
   1. Build the image from Dockerfile (`docker-compose.prod.yml`)
   2. Push `jgriffith3433/claw-docker:latest` to Docker Hub
   3. Copy `.env` and `docker-compose.deploy.yml` to the server
   4. SSH in, pull the image, and restart the service
   5. Remove `.env` from the server for security

3. **Verify:**
   ```
   auto-ssh.bat
   docker ps
   ```

The server runs with `restart: always` so it survives reboots.

## Configuration

- **Seed config:** `openclaw.seed.json` — baked into the image, copied to `~/.openclaw/openclaw.json` on first run
- **Python deps:** `requirements.txt` — installed during image build
- **Telegram token:** injected from `TELEGRAM_BOT_TOKEN` env var at startup

To change the AI model, edit `openclaw.seed.json` → `agents.defaults.model.primary`.

## Environment Variables

| Variable | Required | Default | Description |
|----------|----------|---------|-------------|
| `OPENCLAW_GATEWAY_TOKEN` | Yes | — | Auth token for the gateway |
| `ANTHROPIC_API_KEY` | Yes | — | Anthropic API key for Claude |
| `TELEGRAM_BOT_TOKEN` | Yes | — | Telegram bot token |
| `GITHUB_PERSONAL_ACCESS_TOKEN` | No | — | GitHub PAT — used by GitHub MCP server **and** git credential helper |
| `UNITY_MCP_HOST` | No | `host.docker.internal` | Hostname for Unity MCP WebSocket server |
| `UNITY_MCP_PORT` | No | `8090` | Port for Unity MCP WebSocket server |
| `GIT_LFS_SKIP_SMUDGE` | No | `1` | Set to `0` to enable LFS smudge (downloads LFS files on checkout) |
| `UNITY_PROJECT_PATH` | No | `C:/Projects/sickofitgame-unity` | Host path to Unity project (mounted into container) |
| `WEBSITE_PROJECT_PATH` | No | `C:/Projects/sickofitgame-website` | Host path to website project (mounted into container) |

## Unity MCP Setup

The agent can control the Unity Editor remotely via the mcp-unity bridge. To set this up:

1. **Install the mcp-unity package** in your Unity project (via Package Manager or git URL).
2. **Open the MCP server window** in Unity: **Tools → MCP Unity → Server Window**.
3. **Check "Allow Remote Connections"** — this is critical. Without it, the server only listens on `127.0.0.1` and the Docker container cannot reach it.
4. **Verify the port** matches `UNITY_MCP_PORT` in your `.env` (default: `8090`).
5. **Windows Firewall**: If the connection fails, allow inbound TCP on port 8090 for Unity.

The entrypoint script auto-configures the mcporter config with `UNITY_HOST=host.docker.internal` and `UNITY_PORT=8090`.

## Git Inside Docker

### How It Works
The entrypoint script auto-configures:
- **Credential helper** — reads `GITHUB_PERSONAL_ACCESS_TOKEN` from the environment, so `git push`/`pull` to GitHub works without manual token injection
- **Line endings** — `core.autocrlf true` prevents phantom diffs from CRLF files on Windows volumes
- **Git LFS** — installed but smudge is skipped by default for performance

### `.gitattributes` Recommendation
Add this to any repo mounted into the container to enforce consistent line endings:
```
* text=auto
*.cs text eol=lf
*.meta text eol=lf
*.shader text eol=lf
*.png binary
*.jpg binary
*.wav binary
*.mp3 binary
*.fbx binary
*.asset binary
```

### 9p Mount Performance
Docker Desktop on Windows uses 9p/gRPC FUSE for volume mounts. This is **significantly slower** than native filesystem access, especially for large repos (Unity projects with LFS).

**Workarounds:**
- `GIT_LFS_SKIP_SMUDGE=1` (default) — don't download LFS blobs inside the container
- Use `git --no-optional-locks status` for faster status checks
- For large commits or pushes, run them from the **Windows host** instead of inside Docker
- Avoid `git gc` or `git repack` on mounted volumes
- If the agent needs to push, prefer smaller, focused commits over large batch operations

## Agent Workspace Files

Place these files in your workspace root (`OPENCLAW_WORKSPACE` path) to customize the bot:

| File | Purpose |
|---|---|
| `USER.md` | Your profile, path mappings, common tasks |
| `IDENTITY.md` | Bot name, personality, emoji |
| `SOUL.md` | Tone, boundaries, behavioral rules |
| `AGENTS.md` | Environment info, tool conventions |
| `TOOLS.md` | Tool-specific instructions (rembg, ffmpeg, etc.) |
| `HEARTBEAT.md` | Periodic task instructions |

These are automatically injected into the agent's context on each session.

## Telegram Setup

1. Open Telegram and message [@BotFather](https://t.me/BotFather).
2. Send `/newbot` and follow the prompts to create a bot.
3. Copy the bot token (looks like `123456789:ABCdefGHIjklMNOpqrSTUvwxYZ`).
4. Put the token in your `.env`:
   ```
   TELEGRAM_BOT_TOKEN=123456789:ABCdefGHIjklMNOpqrSTUvwxYZ
   ```
5. Start the gateway (`start.bat`), then send a message to your bot on Telegram.
6. You'll receive a pairing code — run `pair-telegram.bat` and enter it to approve.

## Architecture

```
┌─────────────────────────────────────────┐
│  Docker Container (node:22)             │
│                                         │
│  OpenClaw Gateway (:18789)              │
│  ├── Telegram bot                       │
│  ├── Web UI                             │
│  ├── Agent runtime (Claude)             │
│  └── Skills (rembg, ffmpeg, etc.)       │
│                                         │
│  Volumes:                               │
│  ├── openclaw-data → ~/.openclaw        │
│  └── workspace → ~/.openclaw/workspace  │
└─────────────────────────────────────────┘
```

## Building a specific version

To build from a tag or branch instead of `main`:

```
docker compose -f docker-compose.dev.yml build --build-arg OPENCLAW_VERSION=v2026.2.24
```

## License

This Docker configuration is provided as-is. OpenClaw itself is licensed under its own terms — see the [OpenClaw repository](https://github.com/openclaw/openclaw).
