FROM ubuntu:22.04

# Prevent interactive prompts during installation
ENV DEBIAN_FRONTEND=noninteractive

# Essential system packages and development tools
RUN apt-get update && apt-get install -y \
    # Core system tools
    bash \
    curl \
    wget \
    git \
    unzip \
    software-properties-common \
    apt-transport-https \
    ca-certificates \
    gnupg \
    lsb-release \
    # Development essentials
    build-essential \
    python3 \
    python3-pip \
    # Network and utility tools
    jq \
    vim \
    fzf \
    tree \
    ripgrep \
    # Clean up
    && rm -rf /var/lib/apt/lists/*

# Used by serena MCP
RUN pip install uv

# Install Starship prompt
RUN curl -sS https://starship.rs/install.sh | sh -s -- --yes

# Install nvm and Node.js versions
ENV NVM_DIR=/root/.nvm
RUN curl -o- https://raw.githubusercontent.com/nvm-sh/nvm/v0.40.1/install.sh | bash \
    && . "$NVM_DIR/nvm.sh" \
    && nvm install 20 \
    && nvm install 22 \
    && nvm install 24 \
    && nvm alias default 24 \
    && nvm use default \
    # Create a symlink so PATH can reference a stable location
    && ln -s "$(dirname $(nvm which default))" "$NVM_DIR/default"

# Make node/npm available in PATH for subsequent RUN commands and container runtime
ENV PATH=$NVM_DIR/default:$PATH

# Install GitHub CLI (using direct download for ARM64)
RUN curl -fsSL https://github.com/cli/cli/releases/download/v2.40.0/gh_2.40.0_linux_arm64.tar.gz | tar -xzC /tmp \
    && cp /tmp/gh_2.40.0_linux_arm64/bin/gh /usr/local/bin/ \
    && rm -rf /tmp/gh_* \
    && chmod +x /usr/local/bin/gh

# Install Docker CLI + compose/buildx plugins (client only - no daemon in the
# image; only usable when the socket is granted via `claude-docker --docker`)
RUN curl -fsSL https://download.docker.com/linux/static/stable/aarch64/docker-27.3.1.tgz | tar -xzC /tmp \
    && mv /tmp/docker/docker /usr/local/bin/docker \
    && rm -rf /tmp/docker \
    && mkdir -p /usr/local/lib/docker/cli-plugins \
    && curl -fsSL -o /usr/local/lib/docker/cli-plugins/docker-compose \
        https://github.com/docker/compose/releases/download/v2.32.4/docker-compose-linux-aarch64 \
    && curl -fsSL -o /usr/local/lib/docker/cli-plugins/docker-buildx \
        https://github.com/docker/buildx/releases/download/v0.19.3/buildx-v0.19.3.linux-arm64 \
    && chmod +x /usr/local/lib/docker/cli-plugins/docker-compose /usr/local/lib/docker/cli-plugins/docker-buildx

# Install Yarn globally via npm
RUN npm install -g yarn

# Install Claude CLI via the native installer (puts binary at ~/.local/bin/claude,
# which is the location `claude /doctor` checks)
RUN curl -fsSL https://claude.ai/install.sh | bash
ENV PATH="/root/.local/bin:${PATH}"

# Install Determinate Nix (same distribution as the host).
# --init none: no init system in the container, nix runs daemonless as root.
# sandbox = false: the build sandbox needs namespace privileges containers don't have;
# the container itself is the isolation boundary here.
# The /nix built into the image seeds the shared claude-docker-nix volume on first use,
# after which all containers share one persistent store (see compose.base.yml).
RUN curl --proto '=https' --tlsv1.2 -sSf -L https://install.determinate.systems/nix \
    | sh -s -- install linux --init none --no-confirm --extra-conf "sandbox = false"
ENV PATH="/nix/var/nix/profiles/default/bin:${PATH}"

# Install Chromium via Playwright (Chrome for Testing has no linux/arm64 build,
# and Ubuntu's apt chromium is a snap stub). --with-deps installs the shared libraries.
# The env vars make `npm install puppeteer` skip its own (unavailable) download and
# point puppeteer at this binary. Note: Chrome's internal sandbox can't run in an
# unprivileged container, so launch with --no-sandbox; the container is the boundary.
RUN apt-get update \
    && npx -y playwright install --with-deps chromium \
    && rm -rf /var/lib/apt/lists/* \
    && ln -s /root/.cache/ms-playwright/chromium-*/chrome-linux/chrome /usr/local/bin/chromium
ENV PUPPETEER_SKIP_DOWNLOAD=true \
    PUPPETEER_SKIP_CHROMIUM_DOWNLOAD=true \
    PUPPETEER_EXECUTABLE_PATH=/usr/local/bin/chromium

# Setup workspace directory (Claude config mounted from host)
RUN mkdir -p /workspace/repos

# Set working directory
WORKDIR /workspace

# Copy and set entrypoint
COPY scripts/entrypoint.sh /entrypoint.sh
RUN chmod +x /entrypoint.sh
ENTRYPOINT ["/entrypoint.sh"]
CMD ["bash"]

# Expose common development ports
EXPOSE 3000 8000 8080