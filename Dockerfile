# Claude Development Environment - Ubuntu based for reliability
FROM ubuntu:22.04

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
    python3-dev \
    # Network and utility tools
    jq \
    vim \
    nano \
    fzf \
    # Clean up
    && rm -rf /var/lib/apt/lists/*

# Install Node.js 20
RUN curl -fsSL https://deb.nodesource.com/setup_20.x | bash - \
    && apt-get install -y nodejs

# Install Yarn
RUN npm install -g yarn

# Install Docker CLI (using static binaries for ARM64 compatibility)
RUN curl -fsSL https://download.docker.com/linux/static/stable/aarch64/docker-24.0.7.tgz | tar -xzC /tmp \
    && cp /tmp/docker/docker /usr/local/bin/ \
    && rm -rf /tmp/docker \
    && chmod +x /usr/local/bin/docker \
    && curl -fsSL https://github.com/docker/compose/releases/download/v2.23.0/docker-compose-linux-aarch64 -o /usr/local/bin/docker-compose \
    && chmod +x /usr/local/bin/docker-compose

# Install GitHub CLI (using direct download for ARM64)
RUN curl -fsSL https://github.com/cli/cli/releases/download/v2.40.0/gh_2.40.0_linux_arm64.tar.gz | tar -xzC /tmp \
    && cp /tmp/gh_2.40.0_linux_arm64/bin/gh /usr/local/bin/ \
    && rm -rf /tmp/gh_* \
    && chmod +x /usr/local/bin/gh

# Install kubectl (direct download for ARM64)
RUN curl -fsSL https://dl.k8s.io/release/v1.28.0/bin/linux/arm64/kubectl -o /usr/local/bin/kubectl \
    && chmod +x /usr/local/bin/kubectl

# Install AWS CLI
RUN curl "https://awscli.amazonaws.com/awscli-exe-linux-aarch64.zip" -o "awscliv2.zip" \
    && unzip awscliv2.zip \
    && ./aws/install \
    && rm -rf aws awscliv2.zip

# Install direnv
RUN curl -sfL https://direnv.net/install.sh | bash

# Install Claude CLI globally
RUN npm install -g @anthropic-ai/claude-code

# Setup workspace and claude directories
RUN mkdir -p /workspace/repos /root/.claude

# Set working directory
WORKDIR /workspace

# Copy startup script
COPY startup.sh /startup.sh
RUN chmod +x /startup.sh

# Create entrypoint script for credential setup
RUN echo '#!/bin/bash\n\
# Source startup script to setup environment\n\
/startup.sh &\n\
\n\
# Keep container running\n\
exec tail -f /dev/null' > /entrypoint.sh \
    && chmod +x /entrypoint.sh

# Expose common development ports
EXPOSE 3000 8000 8080

# Use entrypoint script
ENTRYPOINT ["/entrypoint.sh"]