#!/usr/bin/env bash
# Runs the official RealWorld API spec (Hurl) against a backend *image*, the
# same artifact that gets deployed, hardened the same way as in Kubernetes
# (read-only root FS, no capabilities, non-root), with a real PostgreSQL.
#
#   .github/scripts/api-tests.sh <backend-image> <path-to-realworld-specs/api>
set -euo pipefail

IMAGE="$1"
SPECS="$(cd "$2" && pwd)"
NET="rw-apitest-$$"
PG_IMAGE="postgres:18-alpine"
HURL_IMAGE="ghcr.io/orange-opensource/hurl:8.1.0"

cleanup() {
  docker logs rw-be-$$ >"${RUNNER_TEMP:-/tmp}/backend.log" 2>&1 || true
  docker rm -f "rw-be-$$" "rw-db-$$" >/dev/null 2>&1 || true
  docker network rm "$NET" >/dev/null 2>&1 || true
}
trap cleanup EXIT

docker network create "$NET" >/dev/null
docker run -d --name "rw-db-$$" --network "$NET" \
  -e POSTGRES_PASSWORD=ci -e POSTGRES_DB=conduit "$PG_IMAGE" >/dev/null
for _ in $(seq 1 30); do
  docker exec "rw-db-$$" pg_isready -U postgres >/dev/null 2>&1 && break
  sleep 1
done

APP_ENV=(
  -e "DATABASE_URL=postgresql://postgres:ci@rw-db-$$:5432/conduit?sslmode=disable"
  -e "DJANGO_SECRET_KEY=ci-only-not-a-real-secret-0123456789abcdef"
  -e "ALLOWED_HOSTS=*"
  -e "DJANGO_LOG_FORMAT=json"
)
HARDENING=(--read-only --tmpfs /tmp --cap-drop ALL --security-opt no-new-privileges)

docker run --rm --network "$NET" "${HARDENING[@]}" "${APP_ENV[@]}" "$IMAGE" \
  python manage.py migrate --noinput
docker run -d --name "rw-be-$$" --network "$NET" "${HARDENING[@]}" "${APP_ENV[@]}" "$IMAGE" >/dev/null

ready=false
for _ in $(seq 1 30); do
  if docker exec "rw-be-$$" python -c \
    "import urllib.request; urllib.request.urlopen('http://127.0.0.1:8000/healthz', timeout=2)" 2>/dev/null; then
    ready=true; break
  fi
  sleep 1
done
$ready || { echo "backend did not become ready"; exit 1; }

mapfile -t FILES < <(cd "$SPECS/hurl" && ls ./*.hurl | sed 's#^\./#/specs/hurl/#')
docker run --rm --network "$NET" -v "$SPECS:/specs:ro" --entrypoint hurl "$HURL_IMAGE" \
  --test --jobs 1 \
  --variable "host=http://rw-be-$$:8000" \
  --variable "uid=$(date +%s)" \
  "${FILES[@]}"
