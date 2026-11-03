# claude-docker container

- You're in a claude-docker container (Ubuntu, arm64), not on the host. Only the directory the session started from is mounted (at `/workspace/repos/<dir-name>`); other host paths, the Keychain, the microphone and Homebrew don't exist here.
- Credentials are only what claude-docker passes in (`GITHUB_TOKEN`, `NPM_TOKEN`); ask rather than work around missing access.
- Worktrees created here record `/workspace/...` paths and break on the host; don't create them unless asked.
