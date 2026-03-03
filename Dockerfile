# Builds a complete Fluxer server image from source.
# Build context must be the fluxer repo root.
#
# Usage: docker build -t fluxer-server:local -f /path/to/nevi/e2e/Dockerfile.fluxer /path/to/fluxer

# ── Stage 1: Build the Erlang gateway ────────────────────────────────
FROM erlang:28-slim AS gateway-build

ARG LOGGER_LEVEL=info

WORKDIR /usr/src/app/gateway

RUN apt-get update && apt-get install -y --no-install-recommends \
	git curl make gcc g++ libc6-dev ca-certificates gettext-base \
	&& rm -rf /var/lib/apt/lists/*

RUN curl -fsSL https://github.com/erlang/rebar3/releases/download/3.24.0/rebar3 \
	-o /usr/local/bin/rebar3 && chmod +x /usr/local/bin/rebar3

COPY fluxer_gateway/rebar.config fluxer_gateway/rebar.lock* ./
RUN rebar3 compile --deps_only

COPY fluxer_gateway/. ./fluxer_gateway
RUN LOGGER_LEVEL=${LOGGER_LEVEL} envsubst '${LOGGER_LEVEL}' \
	< fluxer_gateway/config/vm.args.template > fluxer_gateway/config/vm.args && \
	LOGGER_LEVEL=${LOGGER_LEVEL} envsubst '${LOGGER_LEVEL}' \
	< fluxer_gateway/config/sys.config.template > fluxer_gateway/config/sys.config && \
	(cd fluxer_gateway && rebar3 as prod release)

# ── Stage 2: Install deps + copy server code ────────────────────────
FROM node:24-trixie-slim AS server

WORKDIR /usr/src/app

RUN corepack enable && corepack prepare pnpm@10.26.0 --activate

RUN apt-get update && apt-get install -y --no-install-recommends \
	curl python3 make g++ ca-certificates ffmpeg \
	&& rm -rf /var/lib/apt/lists/*

# Copy the gateway binary
COPY --from=gateway-build /usr/src/app/gateway/fluxer_gateway/_build/prod/rel/fluxer_gateway /opt/fluxer_gateway

# Install node dependencies
COPY pnpm-workspace.yaml pnpm-lock.yaml package.json ./
COPY patches/ ./patches/

# Copy all package.json files for workspace resolution
COPY packages/ ./packages/
COPY fluxer_server/package.json ./fluxer_server/

RUN pnpm install --frozen-lockfile || pnpm install
RUN pnpm approve-builds msgpackr-extract@3.0.3 @parcel/watcher@2.5.6 2>/dev/null || true
RUN pnpm rebuild msgpackr-extract @parcel/watcher 2>/dev/null || true

# Generate config schema
RUN pnpm --filter @fluxer/config generate 2>/dev/null || true

# Copy server source
COPY fluxer_server/ ./fluxer_server/
COPY tsconfigs/ ./tsconfigs/

# Create required directories
RUN mkdir -p /usr/src/app/data/storage /usr/src/app/data/db /opt/data /data/s3 /data/sqlite /data/queue

# Copy NSFW model (required by media proxy init)
COPY fluxer_media_proxy/data/model.onnx /opt/data/model.onnx
# Place in fluxer_server/data/ where the server looks for it
# (remove any dangling symlink first, then copy)
RUN rm -f /usr/src/app/fluxer_server/data/model.onnx && \
	mkdir -p /usr/src/app/fluxer_server/data && \
	cp /opt/data/model.onnx /usr/src/app/fluxer_server/data/model.onnx

EXPOSE 8080

ENV NODE_ENV=development
ENV FLUXER_SERVER_HOST=0.0.0.0
ENV FLUXER_SERVER_PORT=8080
ENV FLUXER_GATEWAY_HOST=127.0.0.1
ENV FLUXER_GATEWAY_PORT=8082

HEALTHCHECK --interval=10s --timeout=5s --retries=10 \
	CMD curl -fsS http://localhost:8080/_health || exit 1

WORKDIR /usr/src/app/fluxer_server
ENTRYPOINT ["pnpm", "start"]
