# Claude Development Environment - Ubuntu based, simple and reliable
FROM --platform=linux/arm64 ubuntu:22.04

# Prevent interactive prompts during installation
ENV DEBIAN_FRONTEND=noninteractive

# Set timezone
ENV TZ=UTC

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
    nano \
    fzf \
    tree \
    ripgrep \
    # Clean up
    && rm -rf /var/lib/apt/lists/*

# Install zoxide (smarter cd command) and Starship prompt
RUN curl -sSfL https://raw.githubusercontent.com/ajeetdsouza/zoxide/main/install.sh | sh
RUN curl -sS https://starship.rs/install.sh | sh -s -- --yes

# Install Node.js 22 (for Claude CLI and general development)
RUN curl -fsSL https://deb.nodesource.com/setup_22.x | bash - \
    && apt-get install -y nodejs

# Install GitHub CLI (using direct download for ARM64)
RUN curl -fsSL https://github.com/cli/cli/releases/download/v2.40.0/gh_2.40.0_linux_arm64.tar.gz | tar -xzC /tmp \
    && cp /tmp/gh_2.40.0_linux_arm64/bin/gh /usr/local/bin/ \
    && rm -rf /tmp/gh_* \
    && chmod +x /usr/local/bin/gh

# Install Docker CLI (for container operations)
RUN curl -fsSL https://download.docker.com/linux/static/stable/aarch64/docker-24.0.7.tgz | tar -xzC /tmp \
    && cp /tmp/docker/docker /usr/local/bin/ \
    && rm -rf /tmp/docker \
    && chmod +x /usr/local/bin/docker \
    && curl -fsSL https://github.com/docker/compose/releases/download/v2.23.0/docker-compose-linux-aarch64 -o /usr/local/bin/docker-compose \
    && chmod +x /usr/local/bin/docker-compose

# Install Yarn and Claude CLI globally
RUN npm install -g yarn @anthropic-ai/claude-code

# Setup workspace and claude directories  
RUN mkdir -p /workspace/repos /root/.claude

# Set working directory
WORKDIR /workspace

# Expose common development ports
EXPOSE 3000 8000 8080