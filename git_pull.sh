#!/bin/sh
set -u

LOG="/config/git_pull.log"
REPO_DIR="/config"
BRANCH="main"

log() { echo "$@" >> "$LOG"; }

log "==== $(date) ===="

cd "$REPO_DIR"

if ! command -v git >/dev/null 2>&1; then
  log "ERROR: git is not available"
  echo "error"
  exit 1
fi

if ! git rev-parse --is-inside-work-tree >/dev/null 2>&1; then
  log "ERROR: /config is not a git repository"
  echo "error"
  exit 1
fi

if [ -d .git/rebase-merge ] || [ -d .git/rebase-apply ] || [ -f .git/MERGE_HEAD ]; then
  log "ERROR: git repo is busy with a rebase or merge"
  echo "error"
  exit 1
fi

LOCAL_HEAD=$(git rev-parse HEAD)

# Stash any local uncommitted changes so pull doesn't conflict
git stash --quiet 2>/dev/null || true

if ! git pull --rebase origin "$BRANCH" >> "$LOG" 2>&1; then
  log "ERROR: git pull failed"
  git rebase --abort 2>/dev/null || true
  git stash pop --quiet 2>/dev/null || true
  echo "error"
  exit 1
fi

# Restore local changes on top
git stash pop --quiet 2>/dev/null || true

REMOTE_HEAD=$(git rev-parse HEAD)

if [ "$LOCAL_HEAD" = "$REMOTE_HEAD" ]; then
  log "Already up to date"
  echo "unchanged"
  exit 0
fi

log "Pulled new changes: $LOCAL_HEAD -> $REMOTE_HEAD"
echo "changed"
exit 0
