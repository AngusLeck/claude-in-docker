# Claude-in-Docker

A containerized development environment for Claude AI with development tools and credentials, isolated from your host system.

## Why

Essentially for safety. Now you can:
1. Deliberately choose what credentials you give Claude.
2. Let Claude run unsupervised (you were probably already doing this) with at least some protection against hallucinations.

## Quick Start

### Option 1: Install for Use Anywhere (Recommended)

```bash
# Clone the repo
git clone https://github.com/AngusLeck/claude-in-docker.git
cd claude-in-docker

# Run the installer
./install.sh
```

The installer will:
- Build the Docker image
- Prompt for your credentials (GitHub token, Claude auth, Git config)
- Install `claude-docker` command to your PATH

Then use from any project directory:
```bash
cd ~/my-project
claude-docker
```

### Option 2: Run from Repo Directory Only

```bash
# Setup credentials
cp .env.example .env
# Edit .env with your GitHub token and Claude credentials

# Build and run
yarn claude
```

## Two Modes of Operation

### Project Mode (Default)

Run `claude-docker` from any directory to work on that specific project:

```bash
cd ~/projects/my-app
claude-docker
```

- Mounts the current directory into the container
- Creates a dedicated container for each project directory
- Container persists for reconnection (reuses existing container if you run again)
- Claude starts with context of your project directory

### Global Mode

Run `claude-docker -g` for a persistent workspace environment:

```bash
claude-docker -g
```

- Long-running container with persistent workspace
- Good for exploring multiple repos or general work
- Same behavior as the original `yarn claude` command

## What's Inside

### Docker Container

- Ubuntu container with Node.js, Git, GitHub CLI, and Claude CLI
- [gum](https://github.com/charmbracelet/gum) for friendly shell prompts
- Your GitHub and Claude credentials mounted securely
- Complete isolation from your host system
- Nix (Determinate) with a persistent shared store, so repos with a `flake.nix` can run their dev shells and validation in-container
- Headless Chromium for browser testing (puppeteer/playwright against localhost)

### Nix

Nix is installed in the image and `/nix` is backed by a shared named volume (`claude-docker-nix`), so dev shells built in one container are instantly available in every other one. Inside a repo with a `flake.nix`:

```bash
nix develop -c yarn validate
```

Private `git+ssh://git@github.com/...` flake inputs work without any SSH keys in the container: ssh GitHub URLs are rewritten to https and authenticated with the `GITHUB_TOKEN` you already provide.

Notes:
- The nix build sandbox is disabled (`sandbox = false`) — containers can't create the required namespaces; the container itself is the isolation boundary.
- After a nix version upgrade in the image, refresh the store volume: `docker volume rm claude-docker-nix` (it reseeds from the image).
- The volume grows over time; run `nix store gc` in a container occasionally to reclaim space.

### Browser Testing

Headless Chromium (installed via Playwright — Chrome for Testing ships no linux/arm64 build) lives at `/usr/local/bin/chromium`. `PUPPETEER_EXECUTABLE_PATH` and `PUPPETEER_SKIP_DOWNLOAD` are preset, so `npm install puppeteer` works out of the box. Claude can start a local server, click around it, and save screenshots into the mounted workspace where you can view them.

Chromium must be launched with `--no-sandbox` (its internal sandbox needs privileges the container deliberately doesn't have — the container is the sandbox).

### Credentials

The container uses:
- `~/.claude.json` - Claude CLI configuration (mounted from host)
- `GITHUB_TOKEN` - GitHub authentication via HTTPS
- `CLAUDE_CREDENTIALS` - Claude authentication
- `GIT_USER_NAME` - Git commit author name
- `GIT_USER_EMAIL` - Git commit author email

After running `install.sh`, credentials are stored in `~/.claude-in-docker/.env`.

### IDE and Development Tool Access

Since your project directory is mounted as a volume, you can:
- **Edit files using your favorite IDE** (VS Code, Cursor, IntelliJ, etc.)
- **Use GUI tools** like GitKraken, SourceTree, or GitHub Desktop
- **Run local analysis tools** on the code without entering the container

This gives you the best of both worlds: your familiar development environment on the host, with Claude in the container.

## Commands

### After Installation

```bash
# Project mode - run Claude in current directory
claude-docker

# Global mode - run Claude in persistent workspace
claude-docker -g

# Open a shell instead of claude
claude-docker -s           # Shell in project container
claude-docker -g -s        # Shell in global container

# Run claude in dangerous mode (--dangerously-skip-permissions)
claude-docker -d
claude-docker -g -d

# Pass additional args to claude
claude-docker --resume

# Get global workspace path (for IDE access)
claude-docker -w                    # Prints path
cd $(claude-docker -w)              # Navigate to workspace
cursor $(claude-docker -w)          # Open in IDE

# Update to latest version
claude-docker --update

# Uninstall
claude-docker --uninstall

# Show help
claude-docker --help
```

### From Repo Directory (yarn scripts)

```bash
# Start Claude CLI (global mode)
yarn claude

# Enter bash shell
yarn shell

# Container lifecycle
yarn start
yarn stop
yarn restart

# Rebuild Docker image
yarn build
```

## Safety Features

Project mode includes safety checks to prevent mounting dangerous directories:

- **Blocked**: `/`, `/home`, `/Users`, `/root`, `/etc`, `/var`, `/usr`, etc.
- **Warning**: Shallow directories (less than 3 levels deep) prompt for confirmation

## Configuration

The container mounts several configuration files:

- `config/bashrc` - Custom bash configuration
- `config/starship.toml` - Starship prompt settings
- `config/.gitconfig` - Git configuration
- `config/gh-config.yml` - GitHub CLI configuration

Feel free to customize these to make yourself at home in the container.

## Requirements

- Docker and Docker Compose
- GitHub token (for repo access)
- Claude credentials (from `~/.claude.json` or keychain)

## Uninstall

The easiest way to uninstall:

```bash
claude-docker --uninstall
```

This will interactively prompt you about what to remove (containers, image, credentials).

Or manually:

```bash
# Remove symlink
rm ~/.local/bin/claude-docker

# Remove installation directory
rm -rf ~/.claude-in-docker

# Remove Docker image
docker rmi claude-dev-ubuntu:latest

# Remove project containers
docker rm $(docker ps -a --filter "name=claude-docker-" -q | grep -v claude-docker-global)
```
