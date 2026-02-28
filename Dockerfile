# =============================================================================
# OpenClaw Docker Image
# Builds a self-contained gateway with all skill dependencies pre-installed.
# No first-run downloads — everything works out of the box.
# =============================================================================
FROM node:22-bookworm@sha256:cd7bcd2e7a1e6f72052feb023c7f6b722205d3fcab7bbcbd2d1bfdab10b1e935

# -----------------------------------------------------------------------------
# 1. System packages (apt)
# Enables: weather, github, gh-issues, session-logs, tmux, video-frames,
#          image manipulation, browser automation deps
# -----------------------------------------------------------------------------
RUN apt-get update && \
    DEBIAN_FRONTEND=noninteractive apt-get install -y --no-install-recommends \
      curl git git-lfs jq ripgrep tmux ffmpeg \
      python3 python3-pip python3-venv \
      imagemagick \
      xvfb \
    && git lfs install --system --skip-smudge \
    && apt-get clean && rm -rf /var/lib/apt/lists/*

# Fix ImageMagick default policy (enables PDF/SVG processing)
RUN if [ -f /etc/ImageMagick-6/policy.xml ]; then \
      sed -i 's/<policy domain="coder".*rights="none".*pattern="PDF"/<policy domain="coder" rights="read|write" pattern="PDF"/' /etc/ImageMagick-6/policy.xml; \
    fi

# -----------------------------------------------------------------------------
# 2. GitHub CLI (gh) — enables: github, gh-issues skills
# -----------------------------------------------------------------------------
RUN curl -fsSL https://cli.github.com/packages/githubcli-archive-keyring.gpg \
      -o /usr/share/keyrings/githubcli-archive-keyring.gpg && \
    echo "deb [arch=$(dpkg --print-architecture) signed-by=/usr/share/keyrings/githubcli-archive-keyring.gpg] https://cli.github.com/packages stable main" \
      > /etc/apt/sources.list.d/github-cli.list && \
    apt-get update && \
    DEBIAN_FRONTEND=noninteractive apt-get install -y --no-install-recommends gh && \
    apt-get clean && rm -rf /var/lib/apt/lists/*

# -----------------------------------------------------------------------------
# 3. Python dependencies (from requirements.txt)
# Includes: rembg, Pillow, yt-dlp, uv
# -----------------------------------------------------------------------------
COPY requirements.txt /tmp/requirements.txt
RUN pip install --break-system-packages -r /tmp/requirements.txt && rm /tmp/requirements.txt

# Pre-download the rembg AI model so first use is instant (not a 170MB download)
RUN python3 -c "\
from rembg import new_session; \
session = new_session('u2net'); \
print('rembg u2net model cached')"

# -----------------------------------------------------------------------------
# 3a. AWS CLI v2 — enables: EC2 instance management, deployment automation
# -----------------------------------------------------------------------------
RUN curl -fsSL "https://awscli.amazonaws.com/awscli-exe-linux-x86_64.zip" -o /tmp/awscliv2.zip && \
    cd /tmp && unzip -q awscliv2.zip && ./aws/install && \
    rm -rf /tmp/aws /tmp/awscliv2.zip

# -----------------------------------------------------------------------------
# 4. GitHub MCP Server (official Go binary) — enables: native GitHub tools
# -----------------------------------------------------------------------------
RUN curl -fsSL https://github.com/github/github-mcp-server/releases/latest/download/github-mcp-server_Linux_x86_64.tar.gz \
    | tar xz -C /usr/local/bin github-mcp-server

# -----------------------------------------------------------------------------
# 5. Node global tools — enables: clawhub, mcporter, coding-agent skills
# -----------------------------------------------------------------------------
RUN npm install -g clawhub mcporter @anthropic-ai/claude-code rolldown

# -----------------------------------------------------------------------------
# 5a. ClawHub skills — pre-install so they're baked into the image
#     Copied from local workspace to avoid clawhub rate limits.
# -----------------------------------------------------------------------------
RUN mkdir -p /home/node/.openclaw/workspace/skills
COPY workspace/skills/awscli /home/node/.openclaw/workspace/skills/awscli
COPY workspace/skills/clawvox /home/node/.openclaw/workspace/skills/clawvox
COPY workspace/skills/comfyui /home/node/.openclaw/workspace/skills/comfyui

# -----------------------------------------------------------------------------
# 5b. Unity MCP bridge server (connects to Unity Editor on host via WebSocket)
# Enables: scene manipulation, build triggering, console log reading, etc.
# Unity Editor must be running with the mcp-unity package installed.
# -----------------------------------------------------------------------------
RUN git clone --depth 1 https://github.com/CoderGamester/mcp-unity.git /opt/mcp-unity && \
    cd /opt/mcp-unity/Server~ && \
    npm install && \
    npm run build && \
    rm -rf /opt/mcp-unity/.git

# Install Bun (required for build scripts) — install to /usr/local so all users can access it
ENV BUN_INSTALL="/usr/local"
RUN curl -fsSL https://bun.sh/install | bash

RUN corepack enable

# Ensure rembg model cache is accessible by the non-root user
RUN cp -r /root/.u2net /home/node/.u2net 2>/dev/null || true && \
    chown -R node:node /home/node/.u2net 2>/dev/null || true

# Pre-create ~/.openclaw so Docker initialises the named volume with node ownership
RUN mkdir -p /home/node/.openclaw && chown node:node /home/node/.openclaw

# -----------------------------------------------------------------------------
# 5. Clone and build OpenClaw from source
# This layer is cached after the first build. To pull latest OpenClaw code,
# run: deploy.bat --full
# -----------------------------------------------------------------------------
WORKDIR /app
RUN chown node:node /app

# Clone the OpenClaw repository
ARG OPENCLAW_VERSION=main
RUN git clone --depth 1 --branch ${OPENCLAW_VERSION} https://github.com/openclaw/openclaw.git /tmp/openclaw-src && \
    cp -a /tmp/openclaw-src/. /app/ && \
    rm -rf /tmp/openclaw-src && \
    chown -R node:node /app

USER node
RUN --mount=type=cache,id=pnpm-store,target=/pnpm-store,uid=1000,gid=1000 \
    pnpm config set store-dir /pnpm-store && \
    pnpm install --frozen-lockfile

# -----------------------------------------------------------------------------
# 6. Chromium for browser automation (Playwright)
# Pre-installed so there's no 60-90s download on container start.
# -----------------------------------------------------------------------------
USER root
RUN mkdir -p /home/node/.cache/ms-playwright && \
    PLAYWRIGHT_BROWSERS_PATH=/home/node/.cache/ms-playwright \
    node /app/node_modules/playwright-core/cli.js install --with-deps chromium && \
    chown -R node:node /home/node/.cache/ms-playwright

# -----------------------------------------------------------------------------
# 7. Build OpenClaw
# -----------------------------------------------------------------------------
USER node
RUN pnpm build
ENV OPENCLAW_PREFER_PNPM=1
RUN pnpm ui:build

# -----------------------------------------------------------------------------
# 8. Entrypoint + seed config (at the end — lightweight, change often)
# Editing these files only rebuilds two fast COPY steps, not the whole image.
# -----------------------------------------------------------------------------
COPY --chown=node:node openclaw.seed.json /opt/openclaw/openclaw.seed.json
COPY --chown=node:node docker-entrypoint.sh /opt/openclaw/docker-entrypoint.sh
USER root
RUN chmod +x /opt/openclaw/docker-entrypoint.sh

ENV NODE_ENV=production
USER node

ENTRYPOINT ["/opt/openclaw/docker-entrypoint.sh"]
CMD ["node", "dist/index.js", "gateway", "--bind", "lan", "--port", "18789"]
