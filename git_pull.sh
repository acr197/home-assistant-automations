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

# Clean up any stuck rebase/merge state before proceeding
if [ -d .git/rebase-merge ] || [ -d .git/rebase-apply ] || [ -f .git/MERGE_HEAD ]; then
  log "WARNING: cleaning up stuck rebase/merge state"
  git rebase --abort 2>/dev/null || true
  git merge --abort 2>/dev/null || true
fi

LOCAL_HEAD=$(git rev-parse HEAD)

# Stash any local uncommitted changes so pull doesn't conflict
git stash --quiet 2>/dev/null || true

# Use ff-only: if it fails, the local and remote have diverged.
# In that case, local (HA) wins — skip the pull entirely.
if ! git pull --ff-only origin "$BRANCH" >> "$LOG" 2>&1; then
  log "WARNING: pull --ff-only failed (histories diverged). Skipping pull — HA config is source of truth."
  git stash pop --quiet 2>/dev/null || true
  echo "unchanged"
  exit 0
fi

# Restore local changes on top
git stash pop --quiet 2>/dev/null || true

REMOTE_HEAD=$(git rev-parse HEAD)

if [ "$LOCAL_HEAD" = "$REMOTE_HEAD" ]; then
  log "Already up to date"
  echo "unchanged"
  exit 0
fi

# Safety check: scan YAML files for merge conflict markers
if grep -rEl '^(<{7}|>{7}|={7})' "$REPO_DIR"/*.yaml "$REPO_DIR"/**/*.yaml 2>/dev/null; then
  log "ERROR: merge conflict markers found in YAML after pull — reverting to $LOCAL_HEAD"
  git reset --hard "$LOCAL_HEAD" >> "$LOG" 2>&1
  echo "error"
  exit 1
fi

log "Pulled new changes: $LOCAL_HEAD -> $REMOTE_HEAD"
echo "changed"
exit 0
