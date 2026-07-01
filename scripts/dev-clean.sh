#!/usr/bin/env bash
set -euo pipefail

# Removes local build artifacts so stale AlwaysWith.app bundles stop showing up
# in Spotlight / Alfred. Leaves the installed /Applications/AlwaysWith.app alone.

# Avoid CDPATH echoing the target dir into our command substitutions.
unset CDPATH

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" >/dev/null 2>&1 && pwd)"
REPO_ROOT="$(cd "$SCRIPT_DIR/.." >/dev/null 2>&1 && pwd)"
DERIVED_GLOB="$HOME/Library/Developer/Xcode/DerivedData/AlwaysWith-*"

remove() {
    local path="$1"
    if [ -e "$path" ]; then
        echo "  removing $path"
        rm -rf "$path"
    fi
}

echo "→ cleaning repo build artifacts in $REPO_ROOT"
remove "$REPO_ROOT/build"
remove "$REPO_ROOT/dist"
remove "$REPO_ROOT/default.profraw"

echo "→ cleaning Xcode DerivedData for AlwaysWith"
shopt -s nullglob
for dir in $DERIVED_GLOB; do
    remove "$dir"
done
shopt -u nullglob

echo
echo "✓ Done. The installed app at /Applications/AlwaysWith.app was left untouched."
echo "  Spotlight/Alfred may take a moment to drop the removed bundles from its index."
