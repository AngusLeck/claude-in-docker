# What
This directory is a place to keep independent repositories (typically git repos)

# Typical actions from here
 - cd into a local repo
 - clone a remote repo

# Notes
 - Remember to check what branch you are on and whether or not your local is behind or ahead of remote, particularly if you are starting a new piece of work!
 - Be aware that the tech stack in each repo can be varied, take a moment to figure out what you are working with and what tooling is most appropriate (eg yarn vs npm).
 - If the repo has a `flake.nix`, use its dev shell for all build/test commands: `nix develop -c <cmd>`. This gives you the exact node/yarn/postgres versions the repo expects, so you can run validation locally instead of relying on the CI pipeline.
 - You should already be authenticated to use `git` and `gh` CLIs - use them!
 - You may be asked to raise PRs and respond to feedback, you can achieve this with the gh cli.
