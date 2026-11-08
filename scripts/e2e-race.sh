#!/bin/sh
# Two players race over real Bonjour (_notchdino._tcp) on this Mac: two full island models in one test process.
set -e
cd "$(dirname "$0")/.."
echo "Racing two players over real Bonjour on this Mac."
echo "Note: the first run may make macOS ask for Local Network access for your terminal. Allow it, then run again."
NOTCHDINO_E2E=1 swift test --filter RaceE2E "$@"
