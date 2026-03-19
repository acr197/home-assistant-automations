#!/bin/sh
set -eu

exec >> /config/git_pull.log 2>&1

PATH="/usr/local/sbin:/usr/local/bin:/usr/sbin:/usr/bin:/sbin:/bin"
REPO_DIR="/config"
BRANCH="main"

echo "==== $(date) ===="

cd "$REPO_DIR"

if ! command -v git >/dev/null 2>&1; then
  echo "ERROR: git is not available"
  exit 1
fi

if ! git rev-parse --is-inside-work-tree >/dev/null 2>&1; then
  echo "ERROR: /config is not a git repository"
  exit 1
fi

if [ -d .git/rebase-merge ] || [ -d .git/rebase-apply ] || [ -f .git/MERGE_HEAD ]; then
  echo "ERROR: git repo is busy with a rebase or merge"
  exit 1
fi

LOCAL_HEAD=$(git rev-parse HEAD)

# Stash any local uncommitted changes so pull doesn't conflict
git stash --quiet 2>/dev/null || true

if ! git pull --rebase origin "$BRANCH"; then
  echo "ERROR: git pull failed"
  git stash pop --quiet 2>/dev/null || true
  exit 1
fi

# Restore local changes on top
git stash pop --quiet 2>/dev/null || true

REMOTE_HEAD=$(git rev-parse HEAD)

if [ "$LOCAL_HEAD" = "$REMOTE_HEAD" ]; then
  echo "Already up to date"
  exit 0
fi

echo "Pulled new changes: $LOCAL_HEAD -> $REMOTE_HEAD"
exit 0
