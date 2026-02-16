#!/bin/bash
set -e
cd /config
git add -A
if git diff --cached --quiet; then
  exit 0
fi
git commit -m "Auto backup: $(date -Iseconds)"
git push
