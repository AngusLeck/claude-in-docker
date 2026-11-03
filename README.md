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
- Creates a dedicated container per run, named `claude-<dir>-<HHMM>` and labelled `cid.project=<dir>` and `cid.dir=<host path>`
- The container is removed when the session exits (`--rm`); use `--ls`, `--pick` and `--attach` to find and rejoin running ones, and `--prune` to clean up ones left behind
- Claude starts with context of your project directory
- Launching from your repos root (the ailo-style-guide `repos.directory`, default `~/ailo`) prints a warning, since every repo under it gets mounted

### Finding and Rejoining Sessions

```bash
claude-docker --ls
# NAME                    PROJECT     STATE     ACTIVITY     AGE
# claude-api-1102         api         detached  waiting 12m  40 minutes ago
# claude-my-app-0915      my-app      attached  working 1m   2 hours ago
# claude-docker-global    (global)    global    -            3 days ago

claude-docker --attach my-app               # by project, if only one session matches
claude-docker --attach claude-my-app-0915   # by container name
claude-docker --pick                        # choose one with fzf and go to it
claude-docker --prune                       # stop sessions whose terminal is gone
```

**STATE** says whether anyone is looking at the session. Each project container records the terminal that launched it (labels `cid.client_pid` and `cid.tty`): it is **attached** while that `claude-docker` process, or a `--attach` client, is still alive, and **detached** once it is gone, which is what closing an iTerm tab without quitting Claude leaves behind: a container still running with nobody on it. Containers started before this tracking existed show as **legacy** unless a live `claude-docker` process for the same directory accounts for them, in which case they show as attached.

**ACTIVITY** is what Claude is doing, and for how long: `waiting` (finished, or asking a question, and waiting for you), `working`, or `idle` (started, no prompt yet). Sessions waiting for you are listed first. It comes from hooks that run only inside containers: the image ships `/etc/claude-code/managed-settings.json` (Claude Code's managed settings path on Linux), whose hooks merge with your own and your plugins' hooks rather than replacing them, and leave the shared `~/.claude/settings.json` and host sessions alone. Each hook writes `~/.claude/session-status/<container>.json`.

`--pick` lists the same sessions plus those that ended in the last 7 days (fzf if installed, a numbered menu otherwise). Enter on an attached session brings its iTerm tab to the front; on a detached one it attaches it in this terminal; on an ended one it changes to the project directory and runs `claude-docker -d --resume <session id>`.

`--prune` lists detached sessions, with how long each has been idle, and asks `Stop N detached sessions? [y/N]`; `--prune --yes` skips the question. Legacy sessions are included, since nothing proves anyone is on them; the list marks them so you can say no. Stopping removes the containers (they run with `--rm`).

`--attach` runs `docker attach` on the session's TTY, so you see and type into the same Claude as the original terminal (both stay connected). Detach with **Ctrl-Q Ctrl-Q**; the session keeps running. Docker's default detach sequence, Ctrl-P Ctrl-Q, is not used because Claude Code binds Ctrl-P to history and docker would hold every Ctrl-P back waiting for a possible Ctrl-Q. Exiting Claude ends the session (and removes the container) for every attached terminal. If the screen is blank after attaching, press a key to make Claude redraw.

These are flags rather than subcommands because `claude` has subcommands of its own (`claude attach` among them) and everything else after `claude-docker` is passed through to it.

The global container is listed but not attachable (it only runs a keep-alive); use `claude-docker -g`, which `docker exec`s a new Claude into it.

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

### MCP Sign-In (OAuth)

HTTP MCP servers that sign you in through the browser (e.g. via Okta) redirect back to `http://localhost:<port>/callback`, where Claude Code is waiting. Inside a container that listener is on the container's own localhost, so the redirect from your browser lands nowhere.

To make it work, pin the callback port on the MCP server once:

```bash
claude mcp remove <name> -s user
claude mcp add -s user --transport http --callback-port 8765 <name> <url>
```

`~/.claude.json` is shared with the containers, so this is the only place the port lives. When `claude-docker` starts, it launches a small relay (`lib/oauth-relay.py`) on the host that listens on `127.0.0.1` for every pinned callback port. When your browser hits the callback, the relay replays it inside the running claude-docker containers with `docker exec ... curl`; the container whose Claude is waiting on that port receives it. No container ports are published.

- One relay serves every session; it exits once no claude-docker containers are running. It logs to `$TMPDIR/claude-docker-oauth-relay.log`.
- Tokens land in the shared `~/.claude/.credentials.json`, so after signing in from one session, reconnect the server from `/mcp` in the others instead of signing in again. Avoid signing in from two sessions at once: the callback goes to whichever container answers first.
- Needs `python3` on the host; without it the relay is skipped.

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

# Grant Docker socket access for this session (root-equivalent on the Docker VM)
claude-docker --docker

# View a server the agent runs on :3000 at http://localhost:3000 (project mode)
claude-docker -p 3000
claude-docker -p 3001:3000   # parallel sessions: host 3001 -> container 3000
claude-docker -p 3000-3010   # small ranges work too

# Pass additional args to claude
claude-docker --resume

# List running sessions, rejoin one (detach with Ctrl-Q Ctrl-Q)
claude-docker --ls
claude-docker --attach my-app
claude-docker --pick
claude-docker --prune

# Get global workspace path (for IDE access)
claude-docker -w                    # Prints path
cd $(claude-docker -w)              # Navigate to workspace
cursor $(claude-docker -w)          # Open in IDE

# Update claude-docker and the Claude Code version in the image
claude-docker --update
claude-docker --update --no-cache   # also refresh every base layer (apt, node, nix...)

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

## Updating

```bash
claude-docker --update
```

This fetches the latest claude-in-docker, looks up the current Claude Code release, and rebuilds the image. The Claude Code install is the last layer of the image and is keyed on that version, so a routine update rebuilds only that layer; the apt, node, nix and chromium layers are reused from the cache. Pass `--no-cache` when you want those refreshed too.

Project-mode containers are created per run, so they use the new image the next time you start one. The global container is long-lived, so the update offers to recreate it (this ends any session attached to it). If you decline, do it later with `docker rm -f claude-docker-global && claude-docker -g`.

Claude Code's own auto-updater is switched off inside containers (`DISABLE_AUTOUPDATER=1` in `compose.base.yml`): the install lives in the image layer, so anything it downloaded would vanish when a project container exits. This only affects the containers; the host's Claude Code keeps its own setting.

## Stability on macOS (Docker Desktop)

Symptom seen with several long-running sessions in parallel: a container stops responding, `docker stop`/`docker kill` hang, and only restarting Docker Desktop recovers. Both usual causes leave container processes stuck inside the kernel (uninterruptible I/O, or memory reclaim), which is why `kill` cannot help and only restarting the VM does.

1. **File sharing backend.** Every bind mount (`~/.claude`, `~/.claude.json`, the project directory) goes through Docker Desktop's file-sharing daemon. If `mount | grep grpcfuse` inside a container shows `fuse.grpcfuse`, you are on the older gRPC FUSE backend; switch to **VirtioFS** in Docker Desktop → Settings → General → "Choose file sharing implementation". VirtioFS needs the Virtual Machine Manager to be **Docker VMM** (Docker's own hypervisor for Apple Silicon) or Apple Virtualization framework, not QEMU. gRPC FUSE is known to stall under sustained concurrent writes from multiple containers, and `~/.claude` is written constantly by every session (transcripts, file history, debug logs).
2. **VM memory.** Docker Desktop gives the Linux VM a fixed memory budget (Settings → Resources). If containers can use all of it, one heavy `nix develop`, `yarn install`, or test run can push the whole VM into swap, and once it thrashes `dockerd` stalls too. Each container is therefore capped (default 12g, swap disabled for the container) so the kernel kills the runaway process inside that one container instead. Set `CLAUDE_DOCKER_MEMORY_LIMIT` in `~/.claude-in-docker/.env` to change it; size it so the number of containers you typically run at once fits inside the VM budget with headroom for the VM itself. If a legitimate job is killed, you will see the container exit rather than a hang; raise the cap for that project or the VM budget.
3. **Process reaping.** Containers run with `init: true`, so orphaned processes from killed subagent shells and background servers are reaped rather than accumulating as zombies for the life of a session.

To tell the two causes apart, look at the VM logs after a hang. They survive the restart:

```bash
ls -t ~/Library/Containers/com.docker.docker/Data/log/vm/ | head
grep -iE 'oom|out of memory|hung task|fuse' ~/Library/Containers/com.docker.docker/Data/log/vm/*.log | tail -50
```

`oom-kill` / `Out of memory` points at memory; `hung task` traces naming node, claude or git, or fuse errors, point at the file-sharing backend. Docker Desktop's Troubleshoot → "Get diagnostics" bundles the same logs. While things are still healthy under load, `docker stats` on the host shows which container is consuming the memory budget.

## Safety Features

Project mode includes safety checks to prevent mounting dangerous directories:

- **Blocked**: `/`, `/home`, `/Users`, `/root`, `/etc`, `/var`, `/usr`, etc.
- **Warning**: Shallow directories (less than 3 levels deep) prompt for confirmation

Access beyond the container boundary is opt-in, per session:

- **Docker socket** (`--docker`): the socket is no longer mounted by default — it is root-equivalent on the Docker VM (a container holding it can mount any host directory shared with Docker, and reach into other Claude containers). Grant it only when the session needs docker, e.g. when Claude works on this project itself. The `docker` CLI and compose/buildx plugins are always in the image; they just have nothing to talk to without the flag.
- **MCP OAuth relay**: listens on `127.0.0.1` only, for ports pinned with `--callback-port`, and forwards nothing but `GET /callback` requests into containers.
- **Port publishing** (`-p`/`--publish`, project mode only): ports bind to `127.0.0.1` only, never the LAN. The long-lived global container publishes nothing. In-container servers must listen on `0.0.0.0` to be visible (e.g. `--host 0.0.0.0` for vite/next dev servers).

## Container Memory File

The image ships `docker/etc/claude-code/CLAUDE.md` at `/etc/claude-code/CLAUDE.md`, Claude Code's managed-policy memory path on Linux. Every containerised session loads it, so it holds facts about the container itself: the mount layout, what host things are missing (Keychain, Homebrew, host paths), which credentials exist, and not to create git worktrees (they record `/workspace/...` paths that break on the host). `~/.claude/CLAUDE.md` is shared with the host, so container facts don't belong there. Edit the file and rebuild (`claude-docker --update`) to change it.

## Configuration

Runtime settings live in `~/.claude-in-docker/.env` (or `.env` in the repo when running from it). Besides credentials it takes:

- `CLAUDE_DOCKER_MEMORY_LIMIT` - per-container memory cap, default `12g`. See "Stability on macOS" below.

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
docker rm -f $(docker ps -a --filter "label=cid.project" -q)
```
