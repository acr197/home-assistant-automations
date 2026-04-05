#!/bin/sh
set -u

LOG="/config/git_push.log"
REPO_DIR="/config"
BRANCH="main"

log() { echo "$@" >> "$LOG"; }

log "==== $(date) ===="

cd "$REPO_DIR" || { log "ERROR: cannot cd to $REPO_DIR"; echo "error"; exit 1; }

# make sure git exists
if ! command -v git >/dev/null 2>&1; then
  log "ERROR: git is not available"
  echo "error"
  exit 1
fi

# make sure we're in a git repo
if ! git rev-parse --is-inside-work-tree >/dev/null 2>&1; then
  log "ERROR: /config is not a git repository"
  echo "error"
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

REMOTE_URL=$(git remote get-url origin 2>/dev/null)
if [ -z "$REMOTE_URL" ]; then
  log "ERROR: Missing git remote 'origin'"
  echo "error"
  exit 1
fi

log "Remote: $REMOTE_URL"

git config user.name "Home Assistant"
git config user.email "homeassistant@local"

git add -A

if git diff --cached --quiet; then
  log "No changes detected"
  echo "unchanged"
  exit 0
fi

if ! git commit -m "HA backup: $(date '+%Y-%m-%dT%H:%M:%S%z')"; then
  log "ERROR: commit failed"
  echo "error"
  exit 1
fi

# Try normal push first
if git push origin "$BRANCH" >> "$LOG" 2>&1; then
  log "Push completed"
  echo "pushed"
  exit 0
fi

# Force push — HA config is the source of truth, always override remote
log "Normal push failed, force-pushing (HA is source of truth)"
if git push --force origin "$BRANCH" >> "$LOG" 2>&1; then
  log "Force push completed"
  echo "pushed"
  exit 0
fi

log "ERROR: push failed. Check that the remote URL contains a valid token."
log "Current remote: $REMOTE_URL"
log "Expected format: https://<TOKEN>@github.com/<user>/<repo>.git"
echo "error"
exit 1
