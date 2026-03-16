#!/bin/sh
set -eu

exec >> /config/git_push.log 2>&1

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

if ! git remote get-url origin >/dev/null 2>&1; then
  echo "ERROR: Missing git remote 'origin'"
  exit 1
fi

git config user.name "Home Assistant"
git config user.email "homeassistant@local"

git add -A

if git diff --cached --quiet; then
  echo "No changes detected"
  exit 0
fi

git commit -m "Auto backup: $(date '+%Y-%m-%dT%H:%M:%S%z')"

git pull --rebase origin "$BRANCH"

if ! git push origin "$BRANCH"; then
  echo "ERROR: push failed. Check remote or credentials."
  exit 1
fi

echo "Backup push completed"
