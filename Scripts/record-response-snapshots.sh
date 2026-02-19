#!/usr/bin/env bash
set -euo pipefail

GIT_ROOT="$(git rev-parse --show-toplevel)"

if [[ -z "${OPENAI_API_KEY:-}" ]]; then
  echo "❌ OPENAI_API_KEY is required to record live response snapshots."
  exit 1
fi

echo "▶ Recording live response snapshots into test fixtures"
cd "$GIT_ROOT"
OPENAI_LIVE_SNAPSHOT=1 OPENAI_RECORD_SNAPSHOTS=1 swift test
echo "✅ Snapshot recording test run complete."
