#!/usr/bin/env node
/**
 * Persistent Unity MCP Bridge
 * 
 * Wraps the mcp-unity bridge in a long-lived HTTP+SSE server so that:
 * 1. The WebSocket to Unity stays alive across domain reloads (auto-reconnects)
 * 2. mcporter connects via SSE transport (no process spawn/kill per call)
 * 3. Commands queue during Unity recompilation and replay when reconnected
 * 
 * Usage:
 *   node unity-bridge.mjs [--port 8091]
 * 
 * Then configure mcporter:
 *   mcporter config add unity-bridge --url http://localhost:8091 --transport sse
 */

console.log('[unity-bridge] Starting...');
import http from 'http';
import net from 'net';

// Resolve all imports from mcp-unity's node_modules
const SDK_BASE = '/opt/mcp-unity/Server~/node_modules/@modelcontextprotocol/sdk/dist/esm';
const UNITY_BASE = '/opt/mcp-unity/Server~/build';

console.log('[unity-bridge] Loading MCP SDK...');
const { McpServer } = await import(`${SDK_BASE}/server/mcp.js`);
console.log('[unity-bridge] Loading SSE transport...');
const { SSEServerTransport } = await import(`${SDK_BASE}/server/sse.js`);
console.log('[unity-bridge] Loading McpUnity...');
const { McpUnity } = await import(`${UNITY_BASE}/unity/mcpUnity.js`);
console.log('[unity-bridge] Loading Logger...');
const { Logger, LogLevel } = await import(`${UNITY_BASE}/utils/logger.js`);
console.log('[unity-bridge] All imports loaded');

// Import all tool registrations
const { registerCreateSceneTool } = await import(`${UNITY_BASE}/tools/createSceneTool.js`);
const { registerMenuItemTool } = await import(`${UNITY_BASE}/tools/menuItemTool.js`);
const { registerSelectGameObjectTool } = await import(`${UNITY_BASE}/tools/selectGameObjectTool.js`);
const { registerAddPackageTool } = await import(`${UNITY_BASE}/tools/addPackageTool.js`);
const { registerRunTestsTool } = await import(`${UNITY_BASE}/tools/runTestsTool.js`);
const { registerSendConsoleLogTool } = await import(`${UNITY_BASE}/tools/sendConsoleLogTool.js`);
const { registerGetConsoleLogsTool } = await import(`${UNITY_BASE}/tools/getConsoleLogsTool.js`);
const { registerUpdateComponentTool } = await import(`${UNITY_BASE}/tools/updateComponentTool.js`);
const { registerAddAssetToSceneTool } = await import(`${UNITY_BASE}/tools/addAssetToSceneTool.js`);
const { registerUpdateGameObjectTool } = await import(`${UNITY_BASE}/tools/updateGameObjectTool.js`);
const { registerCreatePrefabTool } = await import(`${UNITY_BASE}/tools/createPrefabTool.js`);
const { registerDeleteSceneTool } = await import(`${UNITY_BASE}/tools/deleteSceneTool.js`);
const { registerLoadSceneTool } = await import(`${UNITY_BASE}/tools/loadSceneTool.js`);
const { registerSaveSceneTool } = await import(`${UNITY_BASE}/tools/saveSceneTool.js`);
const { registerGetSceneInfoTool } = await import(`${UNITY_BASE}/tools/getSceneInfoTool.js`);
const { registerUnloadSceneTool } = await import(`${UNITY_BASE}/tools/unloadSceneTool.js`);
const { registerRecompileScriptsTool } = await import(`${UNITY_BASE}/tools/recompileScriptsTool.js`);
const { registerGetGameObjectTool } = await import(`${UNITY_BASE}/tools/getGameObjectTool.js`);
const { registerTransformTools } = await import(`${UNITY_BASE}/tools/transformTools.js`);
const { registerCreateMaterialTool, registerAssignMaterialTool, registerModifyMaterialTool, registerGetMaterialInfoTool } = await import(`${UNITY_BASE}/tools/materialTools.js`);
const { registerDuplicateGameObjectTool, registerDeleteGameObjectTool, registerReparentGameObjectTool } = await import(`${UNITY_BASE}/tools/gameObjectTools.js`);
const { registerBatchExecuteTool } = await import(`${UNITY_BASE}/tools/batchExecuteTool.js`);
const { registerGetMenuItemsResource } = await import(`${UNITY_BASE}/resources/getMenuItemResource.js`);
const { registerGetConsoleLogsResource } = await import(`${UNITY_BASE}/resources/getConsoleLogsResource.js`);
const { registerGetHierarchyResource } = await import(`${UNITY_BASE}/resources/getScenesHierarchyResource.js`);
const { registerGetPackagesResource } = await import(`${UNITY_BASE}/resources/getPackagesResource.js`);
const { registerGetAssetsResource } = await import(`${UNITY_BASE}/resources/getAssetsResource.js`);
const { registerGetTestsResource } = await import(`${UNITY_BASE}/resources/getTestsResource.js`);
const { registerGetGameObjectResource } = await import(`${UNITY_BASE}/resources/getGameObjectResource.js`);
const { registerGameObjectHandlingPrompt } = await import(`${UNITY_BASE}/prompts/gameobjectHandlingPrompt.js`);
console.log('[unity-bridge] All tool imports loaded');

// --- Configuration ---
const BRIDGE_PORT = parseInt(process.env.UNITY_BRIDGE_PORT || '8091');
const UNITY_HOST = process.env.UNITY_HOST || process.env.UNITY_MCP_HOST || 'host.docker.internal';
const UNITY_PORT = parseInt(process.env.UNITY_PORT || process.env.UNITY_MCP_PORT || '8090');

console.log('[unity-bridge] Creating loggers and server...');
// --- Loggers ---
const serverLogger = new Logger('Bridge', LogLevel.INFO);
const unityLogger = new Logger('Unity', LogLevel.INFO);
const toolLogger = new Logger('Tools', LogLevel.INFO);
const resourceLogger = new Logger('Resources', LogLevel.INFO);

// --- MCP Server ---
const server = new McpServer({
  name: "Unity Bridge (Persistent)",
  version: "1.0.0"
}, {
  capabilities: {
    tools: {},
    resources: {},
    prompts: {},
  },
});

console.log('[unity-bridge] Creating McpUnity connection...');
// --- Unity Connection ---
const mcpUnity = new McpUnity(unityLogger);
console.log('[unity-bridge] Registering tools...');

// --- Register all tools ---
registerMenuItemTool(server, mcpUnity, toolLogger);
registerSelectGameObjectTool(server, mcpUnity, toolLogger);
registerAddPackageTool(server, mcpUnity, toolLogger);
registerRunTestsTool(server, mcpUnity, toolLogger);
registerSendConsoleLogTool(server, mcpUnity, toolLogger);
registerGetConsoleLogsTool(server, mcpUnity, toolLogger);
registerUpdateComponentTool(server, mcpUnity, toolLogger);
registerAddAssetToSceneTool(server, mcpUnity, toolLogger);
registerUpdateGameObjectTool(server, mcpUnity, toolLogger);
registerCreatePrefabTool(server, mcpUnity, toolLogger);
registerCreateSceneTool(server, mcpUnity, toolLogger);
registerDeleteSceneTool(server, mcpUnity, toolLogger);
registerLoadSceneTool(server, mcpUnity, toolLogger);
registerSaveSceneTool(server, mcpUnity, toolLogger);
registerGetSceneInfoTool(server, mcpUnity, toolLogger);
registerUnloadSceneTool(server, mcpUnity, toolLogger);
registerRecompileScriptsTool(server, mcpUnity, toolLogger);
registerGetGameObjectTool(server, mcpUnity, toolLogger);
registerTransformTools(server, mcpUnity, toolLogger);
registerDuplicateGameObjectTool(server, mcpUnity, toolLogger);
registerDeleteGameObjectTool(server, mcpUnity, toolLogger);
registerReparentGameObjectTool(server, mcpUnity, toolLogger);
registerCreateMaterialTool(server, mcpUnity, toolLogger);
registerAssignMaterialTool(server, mcpUnity, toolLogger);
registerModifyMaterialTool(server, mcpUnity, toolLogger);
registerGetMaterialInfoTool(server, mcpUnity, toolLogger);
registerBatchExecuteTool(server, mcpUnity, toolLogger);

// --- Register all resources ---
registerGetTestsResource(server, mcpUnity, resourceLogger);
registerGetGameObjectResource(server, mcpUnity, resourceLogger);
registerGetMenuItemsResource(server, mcpUnity, resourceLogger);
registerGetConsoleLogsResource(server, mcpUnity, resourceLogger);
registerGetHierarchyResource(server, mcpUnity, resourceLogger);
registerGetPackagesResource(server, mcpUnity, resourceLogger);
registerGetAssetsResource(server, mcpUnity, resourceLogger);

// --- Register prompts ---
registerGameObjectHandlingPrompt(server);
console.log('[unity-bridge] All registrations complete, setting up HTTP server...');

// --- HTTP+SSE Server ---
// Track active SSE transports for cleanup
const activeTransports = new Map();

const httpServer = http.createServer(async (req, res) => {
  const url = new URL(req.url, `http://localhost:${BRIDGE_PORT}`);
  serverLogger.info(`${req.method} ${req.url}`);

  // Health/status endpoint
  if (url.pathname === '/status' && req.method === 'GET') {
    const status = {
      bridge: 'running',
      unity: mcpUnity.connection?.connectionState || 'unknown',
      queuedCommands: mcpUnity.queuedCommandCount || 0,
      queueStats: mcpUnity.getQueueStats?.() || {},
      port: BRIDGE_PORT,
      unityTarget: `${UNITY_HOST}:${UNITY_PORT}`,
      activeClients: activeTransports.size,
      uptime: process.uptime(),
    };
    res.writeHead(200, { 'Content-Type': 'application/json' });
    res.end(JSON.stringify(status, null, 2));
    return;
  }

  // SSE endpoint — MCP clients connect here for Server-Sent Events
  // Accept both /sse and / (mcporter hits the base URL)
  if ((url.pathname === '/sse' || url.pathname === '/') && req.method === 'GET') {
    serverLogger.info(`New SSE client connected from ${req.socket.remoteAddress}`);
    const transport = new SSEServerTransport('/messages', res);
    const sessionId = Date.now().toString();
    activeTransports.set(sessionId, transport);

    // Clean up on disconnect
    res.on('close', () => {
      activeTransports.delete(sessionId);
      serverLogger.info(`SSE client disconnected (${activeTransports.size} remaining)`);
    });

    await server.connect(transport);
    return;
  }

  // Messages endpoint — MCP clients POST messages here
  if (url.pathname === '/messages' && req.method === 'POST') {
    // Find the transport by session ID from query params
    const sessionId = url.searchParams.get('sessionId');
    const transport = activeTransports.get(sessionId);
    if (transport) {
      await transport.handlePostMessage(req, res);
    } else {
      // Try to find any active transport (single-client mode)
      const anyTransport = activeTransports.values().next().value;
      if (anyTransport) {
        await anyTransport.handlePostMessage(req, res);
      } else {
        res.writeHead(404);
        res.end('No active SSE session');
      }
    }
    return;
  }

  // 404 for everything else
  res.writeHead(404);
  res.end('Not found. Use /sse for MCP connection, /status for health check.');
});

// --- Watchdog: detect stale reconnection and force restart ---
let watchdogInterval;

function checkPort(host, port) {
  return new Promise((resolve) => {
    const sock = new net.Socket();
    sock.setTimeout(2000);
    sock.on('connect', () => { sock.destroy(); resolve(true); });
    sock.on('timeout', () => { sock.destroy(); resolve(false); });
    sock.on('error', () => { resolve(false); });
    sock.connect(port, host);
  });
}

function startWatchdog() {
  watchdogInterval = setInterval(async () => {
    const state = mcpUnity.connection?.connectionState;
    if (state === 'reconnecting' || state === 'disconnected') {
      const isOpen = await checkPort(UNITY_HOST, UNITY_PORT);
      if (isOpen) {
        console.log(`[Watchdog] Unity port open but bridge stuck in '${state}'. Force reconnecting...`);
        try { mcpUnity.connection?.disconnect('Watchdog reset'); } catch (e) { /* ignore */ }
        try { await mcpUnity.stop(); } catch (e) { /* ignore */ }
        try {
          await mcpUnity.start('Claw Unity Bridge');
          console.log('[Watchdog] Reconnected to Unity!');
        } catch (err) {
          console.log(`[Watchdog] Reconnection failed: ${err.message}`);
        }
      }
    }
  }, 15000);
}

// --- Startup ---
async function start() {
  serverLogger.info(`=== Unity MCP Persistent Bridge ===`);
  serverLogger.info(`Bridge port: ${BRIDGE_PORT}`);
  serverLogger.info(`Unity target: ${UNITY_HOST}:${UNITY_PORT}`);

  // Set Unity connection config via environment (the bridge reads these)
  process.env.UNITY_HOST = UNITY_HOST;
  process.env.UNITY_PORT = String(UNITY_PORT);

  // Start HTTP server FIRST (so we're responsive even if Unity is down)
  httpServer.listen(BRIDGE_PORT, '0.0.0.0', () => {
    console.log(`[unity-bridge] HTTP listening on port ${BRIDGE_PORT}`);
  });

  // Start Unity WebSocket connection (will auto-reconnect)
  try {
    console.log('[unity-bridge] Connecting to Unity WebSocket...');
    await mcpUnity.start('Claw Unity Bridge');
    console.log('[unity-bridge] Connected to Unity!');
  } catch (err) {
    serverLogger.warn(`Initial Unity connection failed: ${err.message}`);
    serverLogger.warn('Will auto-reconnect when Unity becomes available');
  }

  // Start watchdog to detect stale reconnections
  startWatchdog();

}

// --- Graceful Shutdown ---
async function shutdown(signal) {
  serverLogger.info(`Shutting down (${signal})...`);
  try {
    await mcpUnity.stop();
    httpServer.close();
  } catch (err) {
    // Ignore errors during shutdown
  }
  process.exit(0);
}

process.on('SIGINT', () => shutdown('SIGINT'));
process.on('SIGTERM', () => shutdown('SIGTERM'));

// Don't crash on uncaught errors - log and continue
process.on('uncaughtException', (error) => {
  if (error.code === 'EPIPE' || error.code === 'EOF') return;
  serverLogger.error(`Uncaught exception: ${error.message}`);
});

process.on('unhandledRejection', (reason) => {
  serverLogger.error(`Unhandled rejection: ${reason}`);
});

start();
