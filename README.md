# Claude-in-Docker: Safe AI Development Environment

A containerized development environment that provides Claude AI with full development capabilities while keeping it isolated from your host system.

## 🎯 The Goal: "Dangerous Yet Safe"

Claude can:
- ✅ Clone and modify your GitHub repositories  
- ✅ Install packages and run scripts
- ✅ Access GitHub CLI and development tools
- ✅ Make commits and create pull requests
- ❌ Access your host filesystem (containerized)
- ❌ Affect your local environment (isolated)

## 🏗️ Quick Start

### Option 1: One Command Setup (Recommended)
```bash
nix run .#build-docker
```

### Option 2: Manual Setup
```bash
# Build the container
docker build --platform linux/arm64 -t claude-dev-ubuntu .

# Start the environment
docker-compose up -d

# Enter the container
./enter.sh
```

## 🚀 Usage

### Enter the Environment
```bash
./enter.sh
```

### Work with Repositories
```bash
# Inside the container
setup_repo customer-service    # Clone and enter a repo
setup_repo my-project         # Works with any repo you have access to
```

### Use Claude CLI
```bash
# Inside the container
claude "Help me implement a new feature"
```

## 🔧 Architecture

### What's Included
- **Ubuntu 22.04 Base**: Reliable ARM64 compatibility
- **Development Tools**: Node.js 20, Python 3, build tools
- **Version Control**: Git with your SSH keys, GitHub CLI
- **DevOps Tools**: Docker CLI, kubectl, AWS CLI
- **Utilities**: vim, nano, jq, fzf, direnv

### Mounted Credentials
- `~/.ssh` - Your SSH keys for GitHub access
- `./credentials/.gitconfig` - Git configuration
- `./credentials/.claude` - Claude CLI config  
- `./credentials/gh` - GitHub CLI tokens

### Persistent Storage
- `/workspace/repos/` - Cloned repositories persist between sessions
- Docker volume ensures work is never lost

## 🛠️ Management Commands

```bash
# Build and start everything
nix run .#build-docker

# Enter the environment
./enter.sh

# Stop the environment
docker-compose down

# View logs
docker logs claude-dev-env

# Remove everything (fresh start)
docker-compose down -v
docker rmi claude-dev-ubuntu
```

## 🔍 How It Works

- 🎯 **Reproducible**: Exact same environment every time with Nix
- 🔒 **Safe**: Docker isolation protects your host system  
- 💾 **Persistent**: Workspace survives container restarts
- ⚡ **Efficient**: Nix store caching and layered Docker images
- 🛠️ **Complete**: Full development environment following your patterns

## Features

- **Nix-built environment** following your existing patterns
- **Persistent workspace** for repos and work
- **GitHub integration** with gh CLI and git
- **Development tools**: Node.js, Python, Docker, kubectl, etc.
- **Claude CLI** pre-installed and configured
- **Easy management** with convenience scripts

## Quick Start

1. **Setup** (one time):
   ```bash
   chmod +x *.sh
   ./setup.sh
   ```

2. **Configure credentials** in `.env`:
   ```bash
   cp .env.example .env
   # Edit .env with your GitHub token and Claude API key
   ```

3. **Enter the environment**:
   ```bash
   ./enter.sh
   ```

4. **Work with repositories**:
   ```bash
   # Inside the container
   setup_repo customer-service  # Clones to /workspace/repos/customer-service
   claude  # Start Claude CLI
   ```

## Architecture

```
Host Machine → Nix Flake → Docker Image → Container
     ↓              ↓           ↓            ↓
  Your Nix     Environment   Isolated    Safe Claude
  Patterns     Definition    Runtime     Operations
```

**Nix Benefits:**
- Reproducible builds from `flake.nix`
- Efficient Docker layers with Nix store
- Easy to modify and extend environment
- Version-controlled development environment

**Docker Benefits:**
- Complete filesystem isolation
- Process isolation from host
- Easy to destroy/recreate if needed
- Persistent workspace volumes

## Commands

- `./setup.sh` - One-time setup with Nix build
- `./enter.sh` - Enter the development environment  
- `./stop.sh` - Stop the container (keeps workspace data)
- `nix develop` - Test environment locally (without Docker)
- `nix run .#build-docker` - Rebuild Docker image

## Inside Container Commands

- `setup_repo <name>` - Clone and enter a repository
- `claude` - Start Claude CLI
- `gh auth login` - Authenticate with GitHub (first time)
- Standard aliases: `gs` (git status), `gp` (git pull), etc.

## File Structure

```
claude-in-docker/
├── flake.nix              # Nix environment definition
├── docker-compose.yml     # Container orchestration
├── setup.sh              # One-time setup
├── enter.sh              # Enter container
├── stop.sh               # Stop container  
├── .env.example          # Credential template
├── credentials/          # Git config and Claude settings
└── README.md             # This file
```

## Customization

The environment is defined in `flake.nix`. To add tools:

```nix
# In flake.nix, add to buildInputs
buildInputs = with pkgs; [
  # ... existing tools
  ripgrep      # Add new tool
  terraform    # Add another tool
];
```

Then rebuild:
```bash
nix run .#build-docker
docker-compose up -d
```

## Safety Features

- **Host Protection**: Claude can't access your host filesystem
- **GitHub Workflow**: All changes go through proper git workflow  
- **Credential Isolation**: API keys contained within container
- **Nix Reproducibility**: Environment is deterministic and version-controlled
- **Easy Reset**: Can destroy and recreate container without data loss

## Development Workflow

1. **Clone repos once**: `setup_repo <repo-name>` - clones to `/workspace/repos/` and persists between sessions
2. **Work with Claude**: Full access to development tools and GitHub
3. **Commit and push**: Changes go to your GitHub repos via PR workflow  
4. **Exit safely**: Your host system stays completely untouched
5. **Resume later**: All repos and work persist in the workspace volume

## Requirements

- **Nix** with flakes enabled
- **Docker** and **Docker Compose**  
- **GitHub token** for repo access
- **Claude API key** for AI functionality