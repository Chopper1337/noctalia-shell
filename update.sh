#!/usr/bin/env bash
set -euo pipefail

# v5 update flow.
#
# Upstream's "main" is the native C++ rewrite (v5). This branch (custom-v5) is
# just upstream/main + our 2 custom patches, so updating means: pull the latest
# upstream/main and replay our patches on top of it, then build & install the
# compiled binary. The v4/legacy QML line lives on other branches with their
# own update.sh; this script only concerns v5.

UPSTREAM_URL="https://github.com/noctalia-dev/noctalia-shell"
UPSTREAM_REMOTE="upstream"
UPSTREAM_BRANCH="main"          # v5 native rewrite
CUSTOM_BRANCH="custom-v5"
BUILD_DIR="build-release"
SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"

cd "$SCRIPT_DIR"

# Add upstream remote if missing
if ! git remote get-url "$UPSTREAM_REMOTE" &>/dev/null; then
  echo "Adding upstream remote: $UPSTREAM_URL"
  git remote add "$UPSTREAM_REMOTE" "$UPSTREAM_URL"
fi

echo "Fetching upstream..."
git fetch "$UPSTREAM_REMOTE"

# Replay our custom patches onto the latest upstream/main.
echo "Rebasing $CUSTOM_BRANCH onto $UPSTREAM_REMOTE/$UPSTREAM_BRANCH..."
git checkout "$CUSTOM_BRANCH"
if ! git rebase "$UPSTREAM_REMOTE/$UPSTREAM_BRANCH"; then
  echo ""
  echo "ERROR: Rebase conflict. Resolve conflicts, then run:"
  echo "  git rebase --continue"
  echo "  git push origin $CUSTOM_BRANCH --force-with-lease"
  echo "  ./update.sh   # re-run to build & install"
  exit 1
fi

git push origin "$CUSTOM_BRANCH" --force-with-lease

# Build and install the v5 binary (compiled, unlike v4's QML file copy).
echo ""
echo "Building v5 (release)..."
MESON_ARGS=(--buildtype=release -Dcpp_std=c++23 -Db_lto=true --prefix /usr/local)
if [[ -d "$BUILD_DIR" ]]; then
  meson setup "$BUILD_DIR" "${MESON_ARGS[@]}" --reconfigure
else
  meson setup "$BUILD_DIR" "${MESON_ARGS[@]}"
fi
meson compile -C "$BUILD_DIR"

echo ""
echo "Installing..."
sudo meson install --no-rebuild -C "$BUILD_DIR"
echo "Done."
