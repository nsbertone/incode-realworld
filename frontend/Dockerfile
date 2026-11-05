# syntax=docker/dockerfile:1
# Build stage: bun with the committed lockfile (frozen = reproducible).
FROM oven/bun:1.3-alpine AS build
WORKDIR /src
COPY package.json bun.lock ./
RUN bun install --frozen-lockfile --ignore-scripts
COPY . .
RUN bun run build

# Runtime stage: static files only, nginx as non-root (uid 101) on 8080.
FROM nginxinc/nginx-unprivileged:1.29-alpine
# Pick up Alpine security fixes released after the base image was built.
USER root
RUN apk upgrade --no-cache
COPY docker/nginx.conf /etc/nginx/conf.d/default.conf
COPY --from=build /src/dist/angular-conduit/browser /usr/share/nginx/html
USER 101
EXPOSE 8080
