FROM node:22-bookworm

# Install Bun (required for build scripts)
RUN curl -fsSL https://bun.sh/install | bash
ENV PATH="/root/.bun/bin:${PATH}"

RUN corepack enable

WORKDIR /app

# --- INSTALACIÓN DE BINARIOS ADICIONALES ---
RUN apt-get update && apt-get install -y --no-install-recommends \
    socat curl tar ca-certificates && \
    # Instalar wacli
    curl -fsSL https://github.com/steipete/wacli/releases/latest/download/wacli_Linux_x86_64.tar.gz -o wacli.tar.gz && \
    tar -xzf wacli.tar.gz -C /usr/local/bin && \
    chmod +x /usr/local/bin/wacli && \
    rm wacli.tar.gz && \
    # Instalar gog
    curl -fsSL https://github.com/steipete/gog/releases/latest/download/gog_Linux_x86_64.tar.gz -o gog.tar.gz && \
    tar -xzf gog.tar.gz -C /usr/local/bin && \
    chmod +x /usr/local/bin/gog && \
    rm gog.tar.gz && \
    # Limpieza
    apt-get clean && rm -rf /var/lib/apt/lists/*
# -------------------------------------------

ARG OPENCLAW_DOCKER_APT_PACKAGES=""
RUN if [ -n "$OPENCLAW_DOCKER_APT_PACKAGES" ]; then \
      apt-get update && \
      DEBIAN_FRONTEND=noninteractive apt-get install -y --no-install-recommends $OPENCLAW_DOCKER_APT_PACKAGES && \
      apt-get clean && \
      rm -rf /var/lib/apt/lists/* /var/cache/apt/archives/*; \
    fi

COPY package.json pnpm-lock.yaml pnpm-workspace.yaml .npmrc ./
COPY ui/package.json ./ui/package.json
COPY patches ./patches
COPY scripts ./scripts

RUN pnpm install --frozen-lockfile

COPY . .
RUN OPENCLAW_A2UI_SKIP_MISSING=1 pnpm build
ENV OPENCLAW_PREFER_PNPM=1
RUN pnpm ui:build

ENV NODE_ENV=production

RUN chown -R node:node /app
USER node

# IMPORTANTE: Cambiamos el CMD para que escuche en todas las interfaces (0.0.0.0) 
# de lo contrario Traefik no podrá conectar con el contenedor.
CMD ["node", "dist/index.js", "gateway", "--allow-unconfigured", "--bind", "lan"]
