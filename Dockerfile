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

# Install Node.js 22 (for Claude CLI and general development)
RUN curl -fsSL https://deb.nodesource.com/setup_22.x | bash - \
    && apt-get install -y nodejs

# Install GitHub CLI (using direct download for ARM64)
RUN curl -fsSL https://github.com/cli/cli/releases/download/v2.40.0/gh_2.40.0_linux_arm64.tar.gz | tar -xzC /tmp \
    && cp /tmp/gh_2.40.0_linux_arm64/bin/gh /usr/local/bin/ \
    && rm -rf /tmp/gh_* \
    && chmod +x /usr/local/bin/gh

# Install gum for friendly shell prompts (using direct download for ARM64)
RUN curl -fsSL https://github.com/charmbracelet/gum/releases/download/v0.14.0/gum_0.14.0_Linux_arm64.tar.gz | tar -xzC /tmp \
    && cp /tmp/gum /usr/local/bin/ \
    && rm -rf /tmp/gum* \
    && chmod +x /usr/local/bin/gum

# Install Yarn and Claude CLI globally
RUN npm install -g yarn @anthropic-ai/claude-code

# Setup workspace and claude directories  
RUN mkdir -p /workspace/repos /root/.claude

# Set working directory
WORKDIR /workspace

# Expose common development ports
EXPOSE 3000 8000 8080