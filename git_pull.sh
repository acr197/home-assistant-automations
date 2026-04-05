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

# Clean up any stuck rebase/merge state
if [ -d .git/rebase-merge ] || [ -d .git/rebase-apply ] || [ -f .git/MERGE_HEAD ]; then
  log "WARNING: cleaning up stuck rebase/merge state"
  git rebase --abort 2>/dev/null || true
  git merge --abort 2>/dev/null || true
fi

# Remove stale index.lock
if [ -f .git/index.lock ]; then
  log "WARNING: removing stale index.lock"
  rm -f .git/index.lock
fi

LOCAL_HEAD=$(git rev-parse HEAD)

# Fetch latest from remote
if ! git fetch origin "$BRANCH" >> "$LOG" 2>&1; then
  log "ERROR: git fetch failed"
  echo "error"
  exit 1
fi

REMOTE_HEAD=$(git rev-parse "origin/$BRANCH")

if [ "$LOCAL_HEAD" = "$REMOTE_HEAD" ]; then
  log "Already up to date"
  echo "unchanged"
  exit 0
fi

# Hard reset to remote — guarantees no merge conflict markers
git reset --hard "origin/$BRANCH" >> "$LOG" 2>&1

log "Pulled new changes: $LOCAL_HEAD -> $REMOTE_HEAD"
echo "changed"
exit 0
