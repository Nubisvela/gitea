# syntax=docker/dockerfile:1

# ========== Builder Base Stage ==========
ARG BUILD_PLATFORM=linux/amd64
FROM --platform=${BUILD_PLATFORM} docker.io/library/golang:1.27-alpine3.24 AS builder-base

# Install build dependencies
RUN apk --no-cache upgrade && \
    apk --no-cache add nodejs pnpm


# ========== Frontend Builder Stage ==========
# Build frontend before backend to ensure frontend assets are available,
# those are used by backend and will be packaged into the bindata binary.
# Build frontend on the native platform to avoid QEMU-related issues with nodejs ecosystem.
FROM builder-base AS frontend-builder

# Copy frontend pnpm files
WORKDIR /src/frontend
COPY src/frontend/package.json src/frontend/pnpm-lock.yaml src/frontend/pnpm-workspace.yaml ./

# Install frontend dependencies with cache mount
RUN --mount=type=cache,target=/root/.local/share/pnpm/store \
    pnpm install --frozen-lockfile

# Copy frontend source code
COPY src/frontend/ ./

# Build frontend
RUN pnpm exec vite build


# ========== Backend Builder Stage ==========
# Cross-compile backend on the native platform.
FROM builder-base AS backend-builder

# Build arguments
ARG TAGS=""
ARG GOOS=linux
ARG GOARCH=amd64
ARG GOARM=0

# Set build tags
# bindata: Embed frontend assets into the binary.
# timetzdata: Embed time zone data into the binary.
# $TAGS: Additional tags from the build arguments.
ENV TAGS="bindata timetzdata $TAGS"

# Download backend dependencies
WORKDIR /src/backend
COPY src/backend/go.mod src/backend/go.sum ./
RUN go mod download

# Copy backend source code and static files
WORKDIR /src
COPY src/backend/ ./backend/
COPY src/static/ ./static/

# Copy frontend assets and built artifacts, then generate bindata binary
COPY src/frontend/assets ./frontend/assets/
COPY --from=frontend-builder /src/frontend/public/ ./frontend/public/
WORKDIR /src/backend/
RUN --mount=type=cache,target="/root/.cache/go-build" \
    GOOS=${GOOS} GOARCH=${GOARCH} \
    go generate -tags "$TAGS" ./...

# Prepare artifacts directory and copy runtime files
RUN mkdir -p /artifacts/usr/local/bin
COPY tools/docker-entrypoint.sh /artifacts/usr/local/bin/

# Build backend with cache mount
# ".git" directory is mounted for version data extraction.
RUN --mount=type=cache,target="/root/.cache/go-build" \
    --mount=type=bind,source=".git/",target=".git/" \
    GOOS=${GOOS} GOARCH=${GOARCH} GOARM=${GOARM#v} \
    go build -v -tags "$TAGS" -ldflags "-s -w" -o /artifacts/usr/local/bin/gitea .

# Set permissions for runtime files
# Protect Gitea binary by changing ownership to root:root
RUN chmod 755 /artifacts/usr/local/bin/* && \
    chown root:root /artifacts/usr/local/bin/gitea


# ========== Runtime Stage ==========
# Build runtime image with the built binary.
FROM docker.io/library/alpine:3.24 AS runtime

# Define environment variables
ENV GITEA_WORK_DIR=/var/lib/gitea
ENV GITEA_CUSTOM=/var/lib/gitea/custom
ENV GITEA_TEMP=/tmp/gitea
ENV GITEA_APP_INI=/etc/gitea/app.ini
ENV HOME=/var/lib/gitea/git
ENV TMPDIR=/tmp/gitea

# Install runtime dependencies
RUN apk --no-cache upgrade && \
    apk --no-cache add \
    ca-certificates \
    openssh-keygen \
    gettext \
    gnupg \
    dumb-init \
    bash \
    git \
    curl

# Create git group and user (1000:1000)
# This user is used to run Gitea.
RUN addgroup -S -g 1000 git && \
    adduser \
    -S -H -D \
    -h /var/lib/gitea/git \
    -s /bin/bash \
    -u 1000 \
    -G git \
    git

# Prepare runtime files
RUN mkdir -p /var/lib/gitea /etc/gitea && \
    chown git:git /var/lib/gitea /etc/gitea

# Copy artifacts
COPY --from=backend-builder /artifacts /

# Set volumes for persistent data
# "/var/lib/gitea": Gitea working directory
# "/etc/gitea": Gitea configuration directory
VOLUME ["/var/lib/gitea", "/etc/gitea"]

# Set container working directory
# This is also the Gitea working directory.
WORKDIR /var/lib/gitea

# Switch to git user (1000:1000)
USER 1000:1000

# Expose ports
# 2222: SSH port for Gitea server
# 8080: HTTP port for Gitea server
EXPOSE 2222 8080

# HINT: HEALTH-CHECK-ENDPOINT: don't use HEALTHCHECK, search this hint keyword for more information
ENTRYPOINT ["/usr/bin/dumb-init", "--", "/usr/local/bin/docker-entrypoint.sh"]
CMD []
