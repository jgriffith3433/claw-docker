---
name: ComfyUI
description: Run local ComfyUI workflows via the HTTP API. Use when the user asks to run ComfyUI, execute a workflow by file path/name, or supply raw API-format JSON; supports the default workflow bundled in assets.
read_when:
  - User asks to generate images with ComfyUI
  - User provides a workflow file or JSON to run
  - User describes an image to generate (subject, style, scene)
  - User pastes or sends a list of model weight URLs to download for ComfyUI
metadata: {"clawdbot":{"emoji":"🖼️","requires":{"bins":["python3"]}}}
---

# ComfyUI Runner

## Architecture

ComfyUI runs in a **separate Docker container** (comfyui-docker), accessible via HTTP API.

- **API endpoint**: `http://${COMFYUI_HOST}:${COMFYUI_PORT}` (defaults: `host.docker.internal:8188`)
- **Local (CPU)**: `comfyui-docker/docker-compose.yml` — slow, for testing only
- **EC2 GPU**: `comfyui-docker/docker-compose.deploy.yml` — g4dn.xlarge (T4 16GB)
- **Shared volumes** (mounted into both claw-docker and comfyui-docker):
  - Models: `/home/node/.openclaw/workspace/comfyui-models/`
  - Output: `/home/node/.openclaw/workspace/comfyui-output/`
  - Input: `/home/node/.openclaw/workspace/comfyui-input/`

## Vendored Workflows

Located in `comfyui-docker/workflows/` (copied into container at build time):

| Workflow | What it does | Models needed |
|----------|-------------|---------------|
| `sd15-basic-test.json` | Single image, SD 1.5, 20 steps | `AOM3A1_orangemixs.safetensors` (2.13GB) |
| `character-concept.json` | Game character concept, 400x400 | Same checkpoint |
| `character-animate.json` | AnimateDiff 8-frame animation | Same checkpoint + `v3_sd15_mm.ckpt` (1.6GB) |

## Running a Workflow

### 1. Edit the workflow JSON
Before running, **inspect and edit** the workflow JSON:
- Find prompt nodes (`CLIPTextEncode`, `PrimitiveStringMultiline`, etc.) and update text
- Optionally set a new `seed` on sampler nodes (`KSampler`)
- Save edited version to a temp file

### 2. Run
```bash
python3 skills/comfyui/scripts/comfyui_run.py --workflow <path-to-workflow.json>
```

The script reads `COMFYUI_HOST` and `COMFYUI_PORT` from env vars. It queues the workflow, polls for completion, and prints JSON with `prompt_id` and output `images`.

### 3. Deliver output
Output images land in `/home/node/.openclaw/workspace/comfyui-output/`. **Always send the generated image(s) to the user** — never just print a filename.

## Model Resolution

Models are **not baked into the Docker image**. They're downloaded on first boot by the entrypoint hook.

- **Resolver script**: `comfyui-docker/scripts/resolve_models.py`
- **Override file**: `comfyui-docker/scripts/model-overrides.json` (auto-populated)
- **Resolution order**: Local overrides → ComfyUI-Manager index (488 models) → HuggingFace API → Civitai API → interactive prompt
- **Env var**: `RESOLVE_MODELS=true|false` controls auto-download on startup
- **Manual**: `python3 /scripts/resolve_models.py --workflow <path>` inside the comfyui container

### Current models:
- `checkpoints/AOM3A1_orangemixs.safetensors` — SD 1.5 anime/general (2.13GB)
- `animatediff_models/v3_sd15_mm.ckpt` — AnimateDiff v3 motion model (1.6GB)

## EC2 GPU Deployment

Managed by `scripts/server-manager.py`:
```bash
python3 scripts/server-manager.py launch --name comfyui-gpu --type g4dn.xlarge
python3 scripts/server-manager.py deploy --name comfyui-gpu
python3 scripts/server-manager.py stop --name comfyui-gpu    # pause billing
python3 scripts/server-manager.py start --name comfyui-gpu   # resume
python3 scripts/server-manager.py terminate --name comfyui-gpu  # destroy
```

Server state tracked in `memory/servers.json`.

When using an EC2 instance, update `COMFYUI_HOST` to the instance's public DNS.

## Custom Nodes

Installed via `comfyui-docker/Dockerfile`:
- `ComfyUI-AnimateDiff-Evolved` — animation generation
- `ComfyUI-VideoHelperSuite` — frame utilities
- `ComfyUI-KJNodes` — batch processing

To add more: clone into `comfyui-docker/custom_nodes/` or add git clone to Dockerfile.

## Character Pipeline Integration

Full pipeline for game characters:
1. **Concept**: Run `character-concept.json` → single 400x400 image
2. **Animate**: Run `character-animate.json` → 8 frames via AnimateDiff
3. **Process**: `python3 scripts/character-pipeline.py` → rembg + sprite sheet + metadata JSON
4. **Unity import**: `ClawCharacterPipeline.cs` → sprite slicing, .anim clips, animator controllers, prefabs

## Resources

### scripts/
- `comfyui_run.py` — Queue workflow, poll completion, print results. Reads `COMFYUI_HOST`/`COMFYUI_PORT` from env.
- `download_weights.py` — Download model URLs into ComfyUI models dir. Supports `--base`, `--subfolder`, `--overwrite`.

### assets/
- `default-workflow.json` — Generic default workflow (from clawhub).
