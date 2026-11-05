#!/usr/bin/env bash
# Official RealWorld API spec (Hurl) against the backend *image*: what is
# tested is exactly what gets deployed.
#
#   .github/scripts/api-tests.sh <backend-image> <path-to-realworld-specs/api>
set -euo pipefail
source "$(dirname "$0")/stack.sh"

IMAGE="$1"
SPECS="$(cd "$2" && pwd)"
HURL_IMAGE="ghcr.io/orange-opensource/hurl:8.1.0"

stack_up "$IMAGE"

mapfile -t FILES < <(cd "$SPECS/hurl" && ls ./*.hurl | sed 's#^\./#/specs/hurl/#')
docker run --rm --network "$NET" -v "$SPECS:/specs:ro" --entrypoint hurl "$HURL_IMAGE" \
  --test --jobs 1 \
  --variable "host=http://$BACKEND:8000" \
  --variable "uid=$(date +%s)" \
  "${FILES[@]}"
