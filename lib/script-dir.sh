# lib/script-dir.sh
# Get the directory where the calling script lives (resolves symlinks).
#
# Usage: source this file, then SCRIPT_DIR will be set.
# Note: BASH_SOURCE[1] refers to the script that sourced this file.

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[1]}")" && pwd)"
