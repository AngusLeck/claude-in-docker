# Claude-in-Docker

A containerized development environment for Claude AI with development tools and credentials, isolated from your host system.

## Why

Essentially for safety. Now you can:
 1. Deliberately choose what credentials you give Claude.
 2. Let Claude run unsupervised (you were probably already doing this) with at least some protection against hallucinations.

## Quick Start

1. **Setup credentials**:
   ```bash
   cp .env.example .env
   # Edit .env with your GitHub token and Claude credentials
   ```

2. **Build, start, run claude in container**:
   ```bash
   yarn claude
   ```

## What
So... what is it? 

### Claude runs in a Docker container

- Ubuntu container with Node.js, Git, GitHub CLI, and Claude CLI
- Your GitHub and Claude credentials mounted securely
- Persistent workspace for repositories and work
- Complete isolation from your host system

### Credentials

The container uses:
- `~/.claude.json` - Claude CLI configuration (mounted)
- `GITHUB_TOKEN` - GitHub authentication via HTTPS (from `.env`)
- `CLAUDE_CREDENTIALS` - Claude authentication (from `.env`)
- `GIT_USER_NAME` - Git commit author name (from `.env`)
- `GIT_USER_EMAIL` - Git commit author email (from `.env`)

### Storage

- `/workspace` - Persistent directory mounted from host `./workspace`
- Survives container restarts and rebuilds
- Access your work directly from host at `./workspace`

### IDE and Development Tool Access

Since `./workspace` is mounted as a volume, you can:
- **Edit files using your favorite IDE** (VS Code, Cursor, IntelliJ, etc.) directly from your host machine
- **Use GUI tools** like GitKraken, SourceTree, or GitHub Desktop on files in `./workspace`
- **Run local analysis tools** on the code without entering the container
- **Keep your workflow** - work in your IDE as normal, run Claude commands in the container

This gives you the best of both worlds: your familiar development environment on the host, with Claude and all tools available in the container.

### Configuration

The container mounts several configuration files to provide a comfortable development environment:

- `config/bashrc` - Custom bash configuration
- `config/starship.toml` - Starship prompt settings
- `config/.gitconfig` - Git configuration
- `config/gh-config.yml` - GitHub CLI configuration

**Note:** Feel free to customize these config files to make yourself feel at home in the container! They're mounted from the host, so you can edit them to match your preferences.

## Commands

The project includes convenient npm scripts that auto-start the container:

```bash
# Start Claude CLI directly (auto-starts container if needed)
yarn claude
# or
yarn claude:dangerous

# Enter bash shell (auto-starts container if needed)  
yarn shell

# Start container
yarn start

# Stop and remove container
yarn stop

# stop then start
yarn restart  

# Rebuild Docker image
yarn build
```

## Requirements

- Docker and Docker Compose
- GitHub token (for repo access)
- Claude credentials (from `~/.claude.json` or keychain)