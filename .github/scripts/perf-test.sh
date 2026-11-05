#!/usr/bin/env bash
# k6 load test against the backend *image* + PostgreSQL. Writes a JSON
# summary (p95 per endpoint) used for regression comparison with main.
#
#   .github/scripts/perf-test.sh <backend-image> <summary.json>
set -euo pipefail
source "$(dirname "$0")/stack.sh"

IMAGE="$1"
OUT="$(cd "$(dirname "$2")" && pwd)/$(basename "$2")"
K6_IMAGE="grafana/k6:2.3.0"
LOADTEST="$(cd "$(dirname "$0")/../../loadtest" && pwd)"

stack_up "$IMAGE"

docker run --rm --network "$NET" --user "$(id -u):$(id -g)" \
  -v "$LOADTEST:/scripts:ro" -v "$(dirname "$OUT"):/out" \
  -e "BASE_URL=http://$BACKEND:8000" \
  -e "SUMMARY_PATH=/out/$(basename "$OUT")" \
  -e "DURATION=${DURATION:-60s}" -e "VUS=${VUS:-20}" \
  "$K6_IMAGE" run --quiet /scripts/api.js
