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

# SAFETY GUARD: never let a pull destroy unsaved work on the Pi.
# HA is the source of truth (git_push.sh force-pushes), so if the Pi has
# uncommitted local edits, or local commits not yet on the remote, ABORT the
# pull instead of running reset --hard. The nightly push then carries the local
# state up to GitHub. Only a clean, strictly-behind Pi (a true fast-forward) is
# allowed to reset. Applies to both the Pull button and the webhook auto-pull.
if ! git diff --quiet HEAD 2>/dev/null; then
  log "ABORT: local uncommitted changes present — refusing reset --hard. Pi left untouched."
  echo "aborted"
  exit 0
fi
if ! git merge-base --is-ancestor HEAD "origin/$BRANCH" 2>/dev/null; then
  log "ABORT: local has commits not on remote (diverged) — refusing reset --hard. Pi left untouched."
  echo "aborted"
  exit 0
fi

# Safe fast-forward: working tree is clean and local is strictly behind remote.
git reset --hard "origin/$BRANCH" >> "$LOG" 2>&1

# VALIDATE the pulled config before it counts as applied. A broken remote commit
# (conflict markers or unparseable YAML) must not go live and must not restart HA.
# On failure, roll back to the last-good commit checked out a moment ago and
# report "invalid" so the calling automation skips the restart. Fail loud.
INVALID=""

# 1) Conflict markers in any tracked config file — the exact fault that has taken
#    HA down before. git grep scans tracked files only.
if git grep -qE '^(<<<<<<<|>>>>>>>|\|\|\|\|\|\|\||=======$)' -- '*.yaml' '.HA_VERSION'; then
  INVALID="conflict markers in tracked config"
fi

# 2) Parse every tracked yaml. HA custom !tags (!include, !secret, ...) are
#    tolerated; includes are not resolved. Broken indentation or stray markers
#    fail here. Skipped only if no python is present, leaving the grep as cover.
if [ -z "$INVALID" ]; then
  PY=$(command -v python3 || command -v python || true)
  if [ -n "$PY" ]; then
    if ! git ls-files -- '*.yaml' | "$PY" -c '
import sys, yaml
yaml.SafeLoader.add_multi_constructor("!", lambda loader, suffix, node: None)
bad = []
for f in sys.stdin.read().splitlines():
    f = f.strip()
    if not f:
        continue
    try:
        with open(f, encoding="utf-8") as fh:
            yaml.safe_load(fh)
    except Exception as e:
        bad.append(f + ": " + str(e))
if bad:
    sys.stderr.write("YAML parse failed:\n" + "\n".join(bad) + "\n")
    sys.exit(1)
' >> "$LOG" 2>&1; then
      INVALID="YAML parse error in tracked config"
    fi
  else
    log "WARNING: no python found — skipped YAML parse, conflict-marker scan still ran"
  fi
fi

if [ -n "$INVALID" ]; then
  log "INVALID: $INVALID — rolling back $REMOTE_HEAD -> $LOCAL_HEAD (last-good kept live)"
  git reset --hard "$LOCAL_HEAD" >> "$LOG" 2>&1
  echo "invalid"
  exit 1
fi

log "Pulled new changes: $LOCAL_HEAD -> $REMOTE_HEAD"
echo "changed"
exit 0
