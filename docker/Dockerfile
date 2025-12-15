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

# Install Yarn and Claude CLI globally
RUN npm install -g yarn @anthropic-ai/claude-code

# Setup workspace and claude directories  
RUN mkdir -p /workspace/repos /root/.claude

# Set working directory
WORKDIR /workspace

# Copy and set entrypoint
COPY scripts/entrypoint.sh /entrypoint.sh
RUN chmod +x /entrypoint.sh
ENTRYPOINT ["/entrypoint.sh"]
CMD ["bash"]

# Expose common development ports
EXPOSE 3000 8000 8080