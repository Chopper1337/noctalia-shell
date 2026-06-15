#!/usr/bin/env bash
set -euo pipefail

UPSTREAM_URL="https://github.com/noctalia-dev/noctalia-shell"
UPSTREAM_REMOTE="upstream"
# Upstream's "main" is now the v5 native rewrite. The QML/Quickshell codebase
# this fork runs lives on legacy-v4, so we track that.
UPSTREAM_BRANCH="legacy-v4"
CUSTOM_BRANCH="custom"
SCRIPT_DIR="$(dirname "$0")"

# Ensure we're in the repo root
cd "$SCRIPT_DIR"

# Add upstream remote if missing
if ! git remote get-url "$UPSTREAM_REMOTE" &>/dev/null; then
  echo "Adding upstream remote: $UPSTREAM_URL"
  git remote add "$UPSTREAM_REMOTE" "$UPSTREAM_URL"
fi

echo "Fetching upstream..."
git fetch "$UPSTREAM_REMOTE"

# Update main to match upstream
echo "Updating main branch..."
git checkout main
git reset --hard "$UPSTREAM_REMOTE/$UPSTREAM_BRANCH"
# main is a pure mirror of upstream; upstream occasionally rewrites history,
# so force is required to keep the fork's main in sync.
git push origin main --force-with-lease

# Rebase custom onto updated main
echo "Rebasing $CUSTOM_BRANCH onto main..."
git checkout "$CUSTOM_BRANCH"
if ! git rebase main; then
  echo ""
  echo "ERROR: Rebase conflict. Resolve conflicts, then run:"
  echo "  git rebase --continue"
  echo "  git push origin $CUSTOM_BRANCH --force-with-lease"
  echo "  pkexec cp -r $SCRIPT_DIR/. /etc/xdg/quickshell/noctalia-shell/"
  exit 1
fi

git push origin "$CUSTOM_BRANCH" --force-with-lease

echo ""
echo "Installing..."
sudo cp -r "$SCRIPT_DIR/." /etc/xdg/quickshell/noctalia-shell/
echo "Done."
