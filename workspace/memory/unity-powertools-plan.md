# Unity Power Tools Plan

## Goal
Give Claw maximum autonomy in Unity — read scenes, modify prefabs, wire references, build, test — without depending on a flaky MCP WebSocket connection.

## Tool Categories

### 1. Reliable MCP Connection (fix the flaky bridge)
- **Retry wrapper script**: `scripts/unity-call.sh <tool> <args>` — retries mcporter 3x with 5s delay between
- **OR persistent bridge**: Background process that keeps WebSocket alive, reconnects on domain reload, exposes a local HTTP API
- **Health check**: Script that confirms Unity MCP is up before starting work

### 2. Scene/Prefab Inspector (read without MCP)
Editor script that dumps scene/prefab data to JSON on demand:
- `Tools > Claw > Export Scene Info` → writes JSON with all GameObjects, components, serialized fields, hierarchy
- `Tools > Claw > Export Prefab Info <path>` → same for a prefab
- Output goes to a known path (e.g., `Assets/../ClawExport/`) that Claw can read
- Triggered via MCP `execute_menu_item` OR manually by user

### 3. Scene/Prefab Modifier (write without MCP)
Editor script that reads a JSON "patch" file and applies changes:
- `Tools > Claw > Apply Scene Patch` → reads `ClawExport/patch.json`, applies changes
- Supports: set field values, add/remove components, create GameObjects, wire references
- Claw writes the patch JSON, user (or MCP) triggers the apply
- Much safer than editing YAML directly — Unity handles serialization

### 4. Reference Resolver
Editor script that maps human-readable paths to Unity internals:
- Input: "Enemy_Chaser.EnemyChaser.moveSpeed" 
- Output: fileID, GUID, field path
- Lets Claw reason about references without parsing YAML GUIDs manually

### 5. Build & Console Tools
- `Tools > Claw > Get Console Errors` → dumps errors to a JSON file (backup when MCP is down)
- `Tools > Claw > Build WebGL` → triggers build, writes result to JSON
- These are fire-and-forget: Claw triggers via MCP or user clicks manually

### 6. Prefab Factory
Generalized version of SlimeCharacterSetup.cs:
- Editor script that reads a JSON config and creates:
  - Sprite sheet import settings
  - Animation clips from sprite sequences
  - Animator controllers with state machines
  - Prefabs with specified components and values
- Input: `ClawExport/create-prefab.json`
- Output: Complete prefab + animation assets

### 7. Live Game State Reader (Play Mode)
- Runtime script that exposes game state during Play mode
- HTTP server on localhost (survives domain reload since it's runtime, not editor)
- Endpoints: /health, /position, /enemies, /scene-info
- Lets Claw observe gameplay and suggest fixes

## Implementation Priority
1. **Retry wrapper** (5 min, instant value)
2. **Scene/Prefab Inspector** (export to JSON — most impactful single tool)
3. **Scene/Prefab Modifier** (patch from JSON — enables full autonomy)
4. **Console dump fallback** (backup for when MCP is down)
5. **Prefab Factory** (generalize the character pipeline)
6. **Reference Resolver** (nice-to-have, makes patch files easier to write)
7. **Live Game State Reader** (future, enables gameplay debugging)
