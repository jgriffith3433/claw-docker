# Tools & Skills

You have these tools pre-installed. Use them proactively when relevant.

---

## Unity MCP (30+ tools)

You have direct control of the Unity Editor via the mcp-unity bridge server. Use `mcporter list unity-mcp --schema` to see the full tool list and schemas.

### Scene & Hierarchy
- **get_active_scene** — Get current scene info
- **get_hierarchy** — List all GameObjects in scene hierarchy
- **select_gameobject** — Select a GameObject by path/name
- **find_gameobjects** — Search GameObjects by name, tag, or layer

### GameObjects & Components
- **create_gameobject** — Create new GameObjects (empty, primitives, UI elements)
- **add_component** — Add components to GameObjects
- **get_component** — Read component properties
- **update_component** — Modify component properties
- **remove_component** — Remove components

### Transform & Layout
- **get_transform** — Get position/rotation/scale
- **set_transform** — Set position/rotation/scale

### Assets & Resources
- **get_assets** — Browse project assets
- **import_asset** — Import external files into Unity project
- **create_material** — Create materials with shaders and properties

### Scripts & Code
- **read_script** — Read C# script contents
- **update_script** — Modify C# script files
- **create_script** — Create new C# scripts with boilerplate

### Build & Test
- **run_tests** — Execute Unity Test Framework tests
- **build_project** — Trigger builds from Unity
- **get_console_logs** — Read Unity Console output (errors, warnings, logs)
- **clear_console** — Clear Unity Console

### Editor Control
- **execute_menu_item** — Run any Unity menu command
- **play_mode** — Enter/exit Play mode
- **pause_editor** — Pause/unpause editor

### Tips for Unity MCP
- Always check `get_console_logs` after making code changes to see if there are compile errors
- Use `get_hierarchy` to understand scene structure before modifying GameObjects
- After updating scripts, Unity auto-recompiles — check console for results
- Unity MCP requires the Editor to be running on the host machine
- The connection goes through `host.docker.internal:8090`

### Unity MCP Networking (Docker ↔ Unity Editor)
The Unity MCP bridge runs **inside Docker** and connects to the Unity Editor **on the Windows host** via WebSocket.

- **Connection target**: `host.docker.internal:8090` (configured via `UNITY_MCP_HOST` and `UNITY_MCP_PORT` env vars)
- **Unity side**: In Unity Editor, open **Tools → MCP Unity → Server Window** and check **"Allow Remote Connections"**. Without this, the server only listens on `127.0.0.1` and Docker can't reach it.
- **Firewall**: Windows Firewall may block the connection. Allow inbound TCP on port 8090 for Unity or Docker.
- If the connection fails, verify from inside the container:
  ```bash
  curl -s http://host.docker.internal:8090 || echo "Cannot reach Unity MCP"
  ```
- The bridge server is at `/opt/mcp-unity/Server~/build/index.js` and is auto-configured by the entrypoint script.

---

## Unity CLI Builds

Build the game without the MCP server using headless Unity CLI:

```bash
# Full deploy (addressables + version bump + WebGL build + version replace)
"C:\Program Files\Unity\Hub\Editor\6000.3.7f1\Editor\Unity.exe" \
  -batchmode -projectPath "C:\Projects\sickofitgame-unity" \
  -executeMethod SickOfIt.Tools.Editor.ClawBuildScript.FullDeploy -quit -logFile -

# WebGL build only
"C:\Program Files\Unity\Hub\Editor\6000.3.7f1\Editor\Unity.exe" \
  -batchmode -projectPath "C:\Projects\sickofitgame-unity" \
  -executeMethod SickOfIt.Tools.Editor.ClawBuildScript.BuildWebGL -quit -logFile -

# Addressables only
"C:\Program Files\Unity\Hub\Editor\6000.3.7f1\Editor\Unity.exe" \
  -batchmode -projectPath "C:\Projects\sickofitgame-unity" \
  -executeMethod SickOfIt.Tools.Editor.ClawBuildScript.BuildAddressables -quit -logFile -
```

⚠️ These commands run on the **Windows host**, not inside Docker. You cannot execute them directly. Use Unity MCP `build_project` tool or ask the user to run the command.

---

## Image Processing
- **rembg** — Remove backgrounds from images. Run: `rembg i input.png output.png`
- **ImageMagick** — Resize, crop, convert, annotate images. Run: `convert input.png -resize 800x output.png`
- **Pillow** (Python) — Advanced image manipulation via Python scripts

### Game Art Workflows
- Background removal for sprite sheets: `rembg i sprite.png sprite_clean.png`
- Batch resize sprites: `mogrify -resize 256x256 *.png`
- Create sprite atlases: Use ImageMagick `montage` command
- Convert formats: `convert input.psd -flatten output.png`
- Generate alpha masks: `convert input.png -alpha extract mask.png`

---

## Video & Audio
- **yt-dlp** — Download videos from YouTube, Twitter/X, TikTok, etc. Run: `yt-dlp "URL"`
- **ffmpeg** — Convert, trim, compress, extract audio. Run: `ffmpeg -i input.mp4 output.gif`

### Game Video Workflows
- Extract frames for sprite sequences: `ffmpeg -i video.mp4 -vf fps=12 frame_%04d.png`
- Convert video to WebM for web: `ffmpeg -i input.mp4 -c:v libvpx-vp9 -crf 30 output.webm`
- Extract audio: `ffmpeg -i video.mp4 -vn -acodec libvorbis audio.ogg`
- Trim clips: `ffmpeg -i input.mp4 -ss 00:00:05 -to 00:00:15 -c copy clip.mp4`

---

## Web & Research
- **Playwright + Chromium** — Browse websites, take screenshots, scrape data
- **GitHub CLI (gh)** — Interact with GitHub repos, issues, PRs

---

## GitHub (MCP)
- Full **GitHub API access** via the official GitHub MCP server (configured in mcporter)
- Use `mcporter list github --schema` to see all available GitHub tools
- You can: read files, create/update issues, create/review/merge PRs, search code, manage branches, monitor Actions workflows
- Key tools: `get_file_contents`, `create_pull_request`, `create_issue`, `search_code`, `push_files`, `merge_pull_request`
- **Never** tell the user to set up GitHub or create a token — it's already configured

---

## General Tips
- When sending files back, always attach them directly to your reply
- When processing images, work in `/tmp/openclaw/` for scratch files
- For background removal, always save output as PNG (transparency)
- When combining multiple tools (e.g. download + convert + send), do it in one go
- Unity project files are at `/home/node/.openclaw/workspace/sickofitgame-unity`
- Website files are at `/home/node/.openclaw/workspace/sickofitgame-website`

---

## Git

Git, git-lfs, and GitHub credentials are pre-configured in the container.

- **Push/pull just works** — a credential helper automatically uses `GITHUB_PERSONAL_ACCESS_TOKEN`
- **Line endings**: `core.autocrlf true` is set globally. No phantom diffs.
- **LFS**: Installed but smudge is skipped by default (`GIT_LFS_SKIP_SMUDGE=1`). Use `git lfs pull --include="path"` to fetch specific LFS files.
- **Performance on mounted volumes**: Use `git --no-optional-locks status` for faster status checks. Avoid `git gc`. For large operations, ask the user to run from the host.
