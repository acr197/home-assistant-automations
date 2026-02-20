#!/bin/bash
set -euo pipefail

REPO_DIR="${REPO_DIR:-/config}"

cd "$REPO_DIR"

if ! git rev-parse --is-inside-work-tree >/dev/null 2>&1; then
  echo "ERROR: $REPO_DIR is not a git repository" >&2
  exit 1
fi

BRANCH="$(git rev-parse --abbrev-ref HEAD)"
if [[ -z "$BRANCH" || "$BRANCH" == "HEAD" ]]; then
  echo "ERROR: Unable to determine git branch" >&2
  exit 1
fi

if ! git remote get-url origin >/dev/null 2>&1; then
  echo "ERROR: Missing git remote 'origin'" >&2
  exit 1
fi

git add -A
if git diff --cached --quiet; then
  echo "No changes to commit"
  exit 0
fi

git commit -m "Auto backup: $(date -Iseconds)"

git pull --rebase origin "$BRANCH"
git push origin "$BRANCH"

echo "Backup push completed"
