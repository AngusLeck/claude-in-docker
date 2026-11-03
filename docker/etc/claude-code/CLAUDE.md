# claude-docker container

You are running inside a claude-docker container (Ubuntu 22.04, linux/arm64), not on the host machine.

## Filesystem
- Project mode: the host directory the session was started from is mounted at `/workspace/repos/<dir-name>`, which is the working directory. Nothing else from the host's file tree is visible.
- Global mode: claude-docker's own workspace directory is mounted at `/workspace`; repos live under `/workspace/repos`.
- `/workspace/CLAUDE.md` and `/workspace/repos/CLAUDE.md` are read-only, provided by claude-docker.
- `~/.claude` and `~/.claude.json` are the host's own files, mounted read-write and shared with the host and every other container. `~/.claude/CLAUDE.md` is the user's host-wide memory, so put facts about this container environment in this file (it ships with the image), not there.
- `/nix` is a volume shared by all claude-docker containers.
- The host home path (e.g. `/Users/<name>`) is a symlink to `/root`, only so paths recorded in `~/.claude` resolve. Other host paths do not exist here.

## Not available
Host-only things: the macOS Keychain, the microphone, Homebrew, macOS apps, and the host's SSH keys and shell environment.

## Credentials
Only what claude-docker passes in: `GITHUB_TOKEN`/`GH_TOKEN` (used by `git` and `gh`), `NPM_TOKEN`, and the git user name and email. Anything else has not been granted; ask rather than work around it.

## Git worktrees
A worktree created here records `/workspace/...` paths in its `.git` metadata, which are broken on the host. Don't create git worktrees unless asked.
