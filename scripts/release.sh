#!/usr/bin/env bash
set -euo pipefail

REPO_OWNER="magobaol"
REPO_NAME="always-with"
SCHEME="AlwaysWith"
PROJECT="AlwaysWith.xcodeproj"
PBXPROJ="$PROJECT/project.pbxproj"

# --- argument parsing --------------------------------------------------------
CURRENT_VERSION=$(grep -m1 "MARKETING_VERSION" "$PBXPROJ" | sed -E 's/.*MARKETING_VERSION = ([0-9.]+);.*/\1/')

VERSION="${1:-}"
if [ -z "$VERSION" ]; then
    echo "current version: $CURRENT_VERSION"
    echo
    echo "usage: scripts/release.sh <version>"
    echo "  e.g. scripts/release.sh 1.0.1"
    exit 0
fi

if ! [[ "$VERSION" =~ ^[0-9]+\.[0-9]+(\.[0-9]+)?$ ]]; then
    echo "error: version must look like X.Y or X.Y.Z (got: $VERSION)"
    exit 1
fi

TAG="v$VERSION"
ZIP_NAME="AlwaysWith-$VERSION.zip"
CHANGELOG_PATH="CHANGELOG.md"
RELEASE_DATE=$(date +%Y-%m-%d)

# --- prerequisites -----------------------------------------------------------
command -v gh >/dev/null 2>&1 || { echo "error: gh CLI not found"; exit 1; }
command -v xcodebuild >/dev/null 2>&1 || { echo "error: xcodebuild not found"; exit 1; }
command -v ditto >/dev/null 2>&1 || { echo "error: ditto not found"; exit 1; }
command -v python3 >/dev/null 2>&1 || { echo "error: python3 not found"; exit 1; }

if ! gh auth status >/dev/null 2>&1; then
    echo "error: gh CLI not authenticated (run: gh auth login)"
    exit 1
fi

if git rev-parse "$TAG" >/dev/null 2>&1; then
    echo "error: tag $TAG already exists locally"
    exit 1
fi

if gh release view "$TAG" --repo "$REPO_OWNER/$REPO_NAME" >/dev/null 2>&1; then
    echo "error: release $TAG already exists on GitHub"
    exit 1
fi

if [ -n "$(git status --porcelain)" ]; then
    echo "error: working tree not clean — commit or stash first"
    git status --short
    exit 1
fi

# --- extract [Unreleased] from changelog -------------------------------------
if [ ! -f "$CHANGELOG_PATH" ]; then
    echo "error: $CHANGELOG_PATH not found"
    exit 1
fi

UNRELEASED_BODY=$(python3 - "$CHANGELOG_PATH" <<'PYEOF'
import re, sys
path = sys.argv[1]
with open(path) as f:
    text = f.read()
pattern = re.compile(r"^## \[Unreleased\]\s*\n(.*?)(?=^## \[|\Z)", re.DOTALL | re.MULTILINE)
match = pattern.search(text)
if not match:
    sys.exit(1)
body = match.group(1).strip("\n")
# trim trailing blank lines and leading blank lines while preserving structure
lines = body.splitlines()
while lines and not lines[0].strip():
    lines.pop(0)
while lines and not lines[-1].strip():
    lines.pop()
print("\n".join(lines))
PYEOF
)

if [ -z "$(printf '%s' "$UNRELEASED_BODY" | tr -d '[:space:]')" ]; then
    echo "error: [Unreleased] section in $CHANGELOG_PATH is empty"
    echo "       add your changes under ## [Unreleased] before releasing"
    exit 1
fi

CURRENT_BRANCH=$(git rev-parse --abbrev-ref HEAD)
if [ "$CURRENT_BRANCH" != "main" ]; then
    echo "warning: current branch is '$CURRENT_BRANCH', not 'main'"
    read -r -p "continue anyway? [y/N] " yn
    [[ "$yn" =~ ^[Yy]$ ]] || exit 1
fi

# --- confirm -----------------------------------------------------------------
echo
echo "About to release:"
echo "  version : $VERSION"
echo "  tag     : $TAG"
echo "  repo    : $REPO_OWNER/$REPO_NAME"
echo "  branch  : $CURRENT_BRANCH"
echo
read -r -p "proceed? [y/N] " yn
[[ "$yn" =~ ^[Yy]$ ]] || { echo "aborted"; exit 1; }

# --- bump version + promote changelog ----------------------------------------
echo
echo "→ bumping MARKETING_VERSION to $VERSION in $PBXPROJ"
sed -i '' "s/MARKETING_VERSION = [0-9.]*;/MARKETING_VERSION = $VERSION;/g" "$PBXPROJ"

echo "→ promoting [Unreleased] to [$VERSION] - $RELEASE_DATE in $CHANGELOG_PATH"
python3 - "$CHANGELOG_PATH" "$VERSION" "$RELEASE_DATE" <<'PYEOF'
import sys
path, version, date = sys.argv[1], sys.argv[2], sys.argv[3]
with open(path) as f:
    text = f.read()
replacement = f"## [Unreleased]\n\n## [{version}] - {date}"
text = text.replace("## [Unreleased]", replacement, 1)
with open(path, "w") as f:
    f.write(text)
PYEOF

if [ -z "$(git status --porcelain "$PBXPROJ" "$CHANGELOG_PATH")" ]; then
    echo "  (no changes — version was already $VERSION)"
else
    git add "$PBXPROJ" "$CHANGELOG_PATH"
    git commit -m "Release $VERSION"
fi

# --- build -------------------------------------------------------------------
BUILD_DIR="build"
rm -rf "$BUILD_DIR"
mkdir -p "$BUILD_DIR"

echo
echo "→ building Release configuration"
xcodebuild -project "$PROJECT" \
           -scheme "$SCHEME" \
           -configuration Release \
           -destination 'platform=macOS' \
           -derivedDataPath "$BUILD_DIR" \
           clean build \
    | grep -E "warning: '|error:|BUILD" || true

APP_PATH="$BUILD_DIR/Build/Products/Release/$SCHEME.app"
if [ ! -d "$APP_PATH" ]; then
    echo "error: build did not produce $APP_PATH"
    exit 1
fi

# --- zip ---------------------------------------------------------------------
DIST_DIR="dist"
mkdir -p "$DIST_DIR"
ZIP_PATH="$DIST_DIR/$ZIP_NAME"
rm -f "$ZIP_PATH"

echo
echo "→ zipping $APP_PATH to $ZIP_PATH"
ditto -c -k --sequesterRsrc --keepParent "$APP_PATH" "$ZIP_PATH"

ZIP_SIZE=$(du -h "$ZIP_PATH" | cut -f1)
echo "  $ZIP_PATH ($ZIP_SIZE)"

# --- tag & push --------------------------------------------------------------
echo
echo "→ tagging $TAG and pushing"
git tag "$TAG"
git push origin "$CURRENT_BRANCH"
git push origin "$TAG"

# --- release -----------------------------------------------------------------
INSTALL_FOOTER="## Install

Download \`$ZIP_NAME\`, unzip and move \`AlwaysWith.app\` to \`/Applications\`.

This build is signed ad-hoc. On first launch macOS may block it as coming from an unidentified developer — right-click the app → **Open** to bypass Gatekeeper once."

NOTES="$UNRELEASED_BODY

$INSTALL_FOOTER"

echo
echo "→ creating GitHub release $TAG"
gh release create "$TAG" "$ZIP_PATH" \
    --repo "$REPO_OWNER/$REPO_NAME" \
    --title "$TAG" \
    --notes "$NOTES"

echo
echo "✓ Done"
echo "  https://github.com/$REPO_OWNER/$REPO_NAME/releases/tag/$TAG"
