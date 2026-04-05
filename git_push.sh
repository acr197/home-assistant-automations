#!/bin/sh
set -u

LOG="/config/git_push.log"
REPO_DIR="/config"
BRANCH="main"

log() { echo "$@" >> "$LOG"; }

log "==== $(date) ===="

cd "$REPO_DIR"

# make sure git exists
if ! command -v git >/dev/null 2>&1; then
  log "ERROR: git is not available"
  exit 1
fi

# make sure we're in a git repo
if ! git rev-parse --is-inside-work-tree >/dev/null 2>&1; then
  log "ERROR: /config is not a git repository"
  exit 1
fi

# clean up any stuck rebase or merge state from previous failed runs
if [ -d .git/rebase-merge ] || [ -d .git/rebase-apply ] || [ -f .git/MERGE_HEAD ]; then
  log "WARNING: cleaning up stuck rebase/merge state"
  git rebase --abort 2>/dev/null || true
  git merge --abort 2>/dev/null || true
fi

# remove stale index.lock if a previous git process crashed
if [ -f .git/index.lock ]; then
  log "WARNING: removing stale index.lock"
  rm -f .git/index.lock
fi

if ! git remote get-url origin >/dev/null 2>&1; then
  log "ERROR: Missing git remote 'origin'"
  exit 1
fi

git config user.name "Home Assistant"
git config user.email "homeassistant@local"

git add -A

if git diff --cached --quiet; then
  log "No changes detected"
  exit 0
fi

if ! git commit -m "Auto backup: $(date '+%Y-%m-%dT%H:%M:%S%z')"; then
  log "ERROR: commit failed"
  exit 1
fi

# try normal push first
if git push origin "$BRANCH" >> "$LOG" 2>&1; then
  log "Push completed"
  echo "pushed"
  exit 0
fi

# if normal push fails (diverged from merged PRs), force push
# HA config is source of truth
log "Normal push failed, force-pushing"
if git push --force-with-lease origin "$BRANCH" >> "$LOG" 2>&1; then
  log "Force push completed"
  echo "pushed"
  exit 0
fi

log "ERROR: push failed. Check remote or credentials."
exit 1
