# Shared by api-tests.sh and perf-test.sh (source it, do not run it).
# Starts PostgreSQL + the backend *image* on a private Docker network,
# hardened like in Kubernetes (read-only root FS, no capabilities, non-root).
#   stack_up <backend-image>   -> sets NET and BACKEND (container name)
#   stack_down                 (registered as an EXIT trap by stack_up)

PG_IMAGE="postgres:18-alpine"

stack_down() {
  docker logs "$BACKEND" >"${RUNNER_TEMP:-/tmp}/backend.log" 2>&1 || true
  docker rm -f "$BACKEND" "rw-db-$$" >/dev/null 2>&1 || true
  docker network rm "$NET" >/dev/null 2>&1 || true
}

stack_up() {
  local image="$1"
  NET="rw-test-$$"
  BACKEND="rw-be-$$"
  trap stack_down EXIT

  docker network create "$NET" >/dev/null
  docker run -d --name "rw-db-$$" --network "$NET" \
    -e "POSTGRES_PASSWORD=c/i:p@ss%w+rd" -e POSTGRES_DB=conduit "$PG_IMAGE" >/dev/null
  for _ in $(seq 1 30); do
    docker exec "rw-db-$$" pg_isready -U postgres >/dev/null 2>&1 && break
    sleep 1
  done

  local env=(
    # Password with URL-special characters, percent-encoded like External
    # Secrets does for the RDS-generated password (regression test).
    -e "DATABASE_URL=postgresql://postgres:c%2Fi%3Ap%40ss%25w%2Brd@rw-db-$$:5432/conduit?sslmode=disable"
    -e "DJANGO_SECRET_KEY=ci-only-not-a-real-secret-0123456789abcdef"
    -e "ALLOWED_HOSTS=*"
    -e "DJANGO_LOG_FORMAT=json"
  )
  local hardening=(--read-only --tmpfs /tmp --cap-drop ALL --security-opt no-new-privileges)

  docker run --rm --network "$NET" "${hardening[@]}" "${env[@]}" "$image" \
    python manage.py migrate --noinput
  docker run -d --name "$BACKEND" --network "$NET" "${hardening[@]}" "${env[@]}" "$image" >/dev/null

  for _ in $(seq 1 30); do
    if docker exec "$BACKEND" python -c \
      "import urllib.request; urllib.request.urlopen('http://127.0.0.1:8000/healthz', timeout=2)" 2>/dev/null; then
      return 0
    fi
    sleep 1
  done
  echo "backend did not become ready" >&2
  return 1
}
