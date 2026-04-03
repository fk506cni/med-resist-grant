#!/bin/bash

# message.md を使ってコミットし、プッシュする

set -e

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
PROJECT_ROOT="$(dirname "$SCRIPT_DIR")"

cd "$PROJECT_ROOT"

if [ ! -f "message.md" ]; then
    echo "エラー: message.md が存在しません"
    exit 1
fi

git commit -F message.md
git push
