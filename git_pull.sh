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

# Stash any local uncommitted changes so pull doesn't fail
git stash --quiet 2>/dev/null || true

if ! git pull --rebase origin "$BRANCH"; then
  echo "ERROR: pull failed. Check remote or credentials."
  git stash pop --quiet 2>/dev/null || true
  exit 1
fi

# Re-apply any stashed local changes
git stash pop --quiet 2>/dev/null || true

echo "Pull completed"
