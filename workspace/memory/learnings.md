# Hard-Won Learnings

## AWS EC2

### GPU Instances
- g4dn/g5 NVMe is **ephemeral** — wiped on stop/terminate. NEVER put Docker data-root or models there.
- Move Docker data-root to EBS: edit `/etc/docker/daemon.json` → `"data-root": "/path/on/ebs"`
- 200GB EBS root is the sweet spot: ~21GB Docker image + ~21GB models + headroom
- g4dn and g5 share the same **"G and VT" vCPU quota bucket** — can't run both simultaneously with 4 vCPU limit
- Request quota increases BEFORE you need them — takes minutes to approve but easy to forget
- **IPs change on every stop/start** — always re-check and update servers.json
- Deep Learning AMI (`ami-0669ac5db8b1292fe`) comes with NVIDIA drivers pre-installed — don't waste time installing them manually
- `nvidia-smi` works immediately after boot on Deep Learning AMI, but you still need nvidia-container-toolkit for Docker GPU access

### Cost Control
- g5.xlarge = $1.02/hr. A full character generation takes ~5 min. **Stop instances when not generating.**
- Build server (t3.large $0.09/hr) is cheap enough to leave stopped between builds
- Named Docker volumes persist across container recreates — don't re-download models on every deploy

### SSH / Networking
- Always use `-o StrictHostKeyChecking=no` for EC2 (IPs rotate, host keys change)
- PEM key must be chmod 600: `cp key.pem /tmp/ && chmod 600 /tmp/key.pem`
- Security group `sg-063d27eee16d8f626` has 22 (SSH), 8188 (ComfyUI), 443 (HTTPS)

## Docker

### Build Server Pattern
- Don't build large GPU images locally — network upload of 6GB+ CUDA layers is brutal
- Dedicated t3.large build server: git pull → docker build → docker push. Fast.
- ComfyUI server: docker pull → docker compose up. No build needed.
- This separation saves 30-60 min per build cycle

### Docker Compose GPU
- `runtime: nvidia` in docker-compose requires nvidia-container-toolkit installed on host
- Named volumes (`comfyui-models:`, `comfyui-output:`) survive `docker compose down && up`
- Bind mounts from host are fragile with permissions — prefer named volumes for model storage
- `deploy.resources.reservations.devices` syntax for GPU in compose v2

### Image Layers
- Order COPY statements by change frequency (least → most) to maximize layer caching
- Static assets first, frequently-changing code last

## ComfyUI

### Model Management
- ComfyUI references models by **filename only** — no URLs, no paths. You must know where to get them.
- Our resolve_models.py solves this: checks 5 sources in order (local overrides → ComfyUI-Manager list → HuggingFace → Civitai → manual)
- model-overrides.json maps filename → direct download URL for known models
- LOADER_MAP in resolve_models.py maps node class_type → model subfolder (e.g., `CLIPLoader` → `clip/`)
- **New node types need LOADER_MAP entries** or the resolver won't know where to put the model

### API Usage
- Queue workflow: `POST /prompt` with `{"prompt": <workflow_json>}`
- Check queue: `GET /queue` — shows `queue_running` and `queue_pending`
- Check history: `GET /history/<prompt_id>`
- System stats: `GET /system_stats` — VRAM usage, GPU info
- Workflow JSON is the **API format** (node IDs as keys), NOT the visual editor format

### CogVideoX Specifics
- CogVideoX 1.5 supports flexible resolution: Min(W,H)≥768, Max(W,H)≤1360, divisible by 16
- CogVideoX 5B (non-1.5) is locked to 720×480 — don't try other resolutions
- GGUF Q4_0 quantization: 3GB file, 6.1GB VRAM — vastly better than bf16 (10GB, OOM)
- **DPM++ scheduler required for GGUF** — Euler causes `indices should be either on cpu or on the same device`
- CFG 6.0-7.0 only. CFG 10 = severe artifacts ("painted glass")
- `enable_sequential_cpu_offload: false` — offloading kills quality and speed
- `fp8_fastmode: false` — fp8 quantization causes color drift
- `force_offload: true` on text encoder is fine (frees CLIP VRAM after encoding)
- Model auto-downloads via `DownloadAndLoadCogVideoGGUFModel` node — just reference the filename
- 25 frames in → 29 frames out (model rounds up to nearest valid frame count)

### Prompting for Game Animations
- **Stillness-focused prompts work best** for idle animations
- "pulsing and breathing" → morphing mess. "motionless, barely moving, only tiniest wobble" → clean idle
- Always include "static camera, no movement" to prevent camera drift
- Black background helps with later background removal
- Negative prompt: "not high quality, low resolution, watermark, strange motion trajectory"

### Custom Nodes
- Install at build time in Dockerfile for speed, but some need runtime pip install
- entrypoint-hook.sh handles runtime node cloning + pip install for nodes not in base image
- Check `/root/ComfyUI/custom_nodes/*/requirements.txt` for missing deps

## Unity MCP

### Connection
- mcporter server name: `unity` (not `unity-mcp`)
- Connects via WebSocket to `host.docker.internal:8090`
- **Requires**: Unity Editor running + MCP Server Window → "Allow Remote Connections" checked
- Windows Firewall may block port 8090 — add inbound rule for Unity.exe

### Reliability
- **Drops during domain reload** — every time you add/edit a .cs file, Unity recompiles and MCP disconnects
- Wait 10-20 seconds after script changes before retrying MCP calls
- If consistently failing, the MCP server process in Unity may have crashed — user needs to restart it
- `mcporter list` showing "30 tools, healthy" doesn't mean it works — that's cached schema

### Editor Scripts
- Place in `Assets/Scripts/Tools/Editor/` for `SickOfIt.Tools.Editor` assembly
- Assembly is editor-only (includePlatforms: Editor) — can use UnityEditor namespace
- `AssetDatabase.Refresh()` needed after writing files from outside Unity
- `TextureImporter.SaveAndReimport()` to apply sprite sheet settings
- UV coordinates start from BOTTOM-LEFT — row 0 in spritesheet metadata is the bottom row
- `AnimationUtility.SetObjectReferenceCurve` for sprite animation keyframes
- `PrefabUtility.SaveAsPrefabAsset` + `Object.DestroyImmediate` pattern for prefab creation

## rembg (Background Removal)
- Works great for game sprites on solid/simple backgrounds
- Leaves slight white halo on edges — acceptable for game sprites at 400×400
- Process time: ~5-8 seconds per frame on CPU
- For batch: simple bash loop, no parallelism needed for 8 frames

## General Workflow
- **Don't poll in loops** — use exec with yieldMs or process poll with timeout
- **SSH commands timeout** — always set explicit timeouts on remote exec
- **Large file transfers** (SCP) can take 10-30s for multi-MB files — use background + poll
- **Memory files**: Always sync to BOTH `/home/node/.openclaw/workspace/` AND `claw-docker/workspace/`
