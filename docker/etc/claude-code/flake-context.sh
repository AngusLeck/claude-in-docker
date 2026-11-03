#!/bin/bash
# SessionStart hook: only in repos with a flake.nix, tell Claude how to get the repo's
# toolchain and what the common aarch64 failure means. Silent everywhere else.
dir="${CLAUDE_PROJECT_DIR:-$PWD}"
[ -f "$dir/flake.nix" ] || exit 0
jq -n --arg ctx "This repo has a nix flake: run build/test commands through its dev shell, e.g. \`nix develop -c <command>\`, so you get the node/yarn/java/etc. versions the repo pins rather than the container's global ones. Private ailohq flake inputs work, and the nix store is shared between containers, so only the first build is slow. This container is aarch64-linux; if the flake fails with an attribute 'aarch64-linux' missing error, that's a known gap in the flake. Say so and fall back to global tools instead of debugging it." \
  '{hookSpecificOutput: {hookEventName: "SessionStart", additionalContext: $ctx}}'
exit 0
