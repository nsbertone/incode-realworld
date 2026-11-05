# syntax=docker/dockerfile:1
# Build stage: compiles psycopg2 against libpq, installs deps into a venv.
FROM python:3.12-slim-bookworm AS build
RUN apt-get update \
    && apt-get install -y --no-install-recommends gcc libc6-dev libpq-dev \
    && rm -rf /var/lib/apt/lists/*
RUN python -m venv /venv
ENV PATH=/venv/bin:$PATH
WORKDIR /src
COPY pyproject.toml ./
RUN pip install --no-cache-dir --upgrade pip && pip install --no-cache-dir . \
    # Drop the installer from the venv *here*: deleting it in the final stage
    # would only hide it in a new layer, the bytes would stay in the image.
    && pip uninstall -y pip setuptools wheel || true

# Runtime stage: no compiler, no build headers, non-root, read-only friendly.
FROM python:3.12-slim-bookworm
RUN apt-get update \
    && apt-get install -y --no-install-recommends libpq5 \
    && apt-get upgrade -y \
    && rm -rf /var/lib/apt/lists/* \
    # No package installer at runtime: removes pip/setuptools (and their
    # vendored libraries) from the attack surface and from CVE scan noise.
    && python -m pip uninstall -y pip setuptools wheel \
    && groupadd --gid 10001 app \
    && useradd --uid 10001 --gid app --no-create-home --shell /usr/sbin/nologin app
COPY --from=build /venv /venv
WORKDIR /app
COPY --chown=root:root apps ./apps
COPY --chown=root:root config ./config
COPY --chown=root:root helpers ./helpers
COPY --chown=root:root manage.py ./
ENV PATH=/venv/bin:$PATH \
    PYTHONDONTWRITEBYTECODE=1 \
    PYTHONUNBUFFERED=1 \
    DJANGO_SETTINGS_MODULE=config.settings
USER 10001:10001
EXPOSE 8000
# Gunicorn instead of runserver. Workers/threads are tuned via
# GUNICORN_CMD_ARGS in the Helm values; the heartbeat file lives in /tmp
# (an emptyDir, since the root filesystem is read-only in the cluster).
CMD ["gunicorn", "config.wsgi:application", \
     "--bind", "0.0.0.0:8000", \
     "--workers", "2", "--threads", "4", \
     "--worker-tmp-dir", "/tmp", \
     "--access-logfile", "-", \
     "--graceful-timeout", "20"]
