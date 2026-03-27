#!/bin/sh
set -u

LOG="/config/git_push.log"
REPO_DIR="/config"
BRANCH="main"

log() { echo "$@" >> "$LOG"; }

log "==== $(date) ===="

cd "$REPO_DIR"

if ! command -v git >/dev/null 2>&1; then
  log "ERROR: git is not available"
  exit 1
fi

if ! git rev-parse --is-inside-work-tree >/dev/null 2>&1; then
  log "ERROR: /config is not a git repository"
  exit 1
fi

if [ -d .git/rebase-merge ] || [ -d .git/rebase-apply ] || [ -f .git/MERGE_HEAD ]; then
  log "ERROR: git repo is busy with a rebase or merge — aborting leftover state"
  git rebase --abort 2>/dev/null || true
  git merge --abort 2>/dev/null || true
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

# Push directly — HA config is the source of truth, no need to pull first.
# Try normal push first; if it fails (diverged history), force-push with lease.
if git push origin "$BRANCH" >> "$LOG" 2>&1; then
  log "Backup push completed"
  echo "pushed"
  exit 0
fi

log "Normal push failed — force-pushing (HA is source of truth)"
if git push --force-with-lease origin "$BRANCH" >> "$LOG" 2>&1; then
  log "Force push completed"
  echo "pushed"
  exit 0
fi

log "ERROR: push failed. Check remote or credentials."
exit 1
