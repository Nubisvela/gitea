set shell := ["bash", "-euo", "pipefail", "-c"]

# List available recipes
default:
  just --list

# Initialize project
init:
  cd src/backend && go mod download
  cd src/frontend && pnpm install

# Start a Gitea development server. Available tags: bindata, pam. See `docs/build-source.md#Build`
dev tags='':
  just build-backend {{ tags }}
  ./gitea

# Build and run Gitea with bindata enabled
run:
  just build-frontend
  just generate-backend bindata
  just build-backend bindata
  ./gitea

# Build frontend
build-frontend:
  cd src/frontend && pnpm exec vite build

# Generate backend. Available tags: bindata, pam. See `docs/build-source.md#Build`
generate-backend tags='':
  cd src/backend && CC= GOOS= GOARCH= CGO_ENABLED=0 go generate -tags '{{ tags }}' ./...

# Build backend. Available tags: bindata, pam. See `docs/build-source.md#Build`
[no-exit-message]
build-backend tags='':
  #!/usr/bin/env bash
  if [[ "{{ tags }}" =~ "bindata" ]]; then
    modules=(migration options public templates)
    for m in "${modules[@]}"; do
      f="./src/backend/modules/$m/bindata.dat"
      if [ ! -f "$f" ]; then
        just no_bindata_err $m; exit 1
      fi
    done
  fi
  CGO_ENABLED='0' go build -C ./src/backend -v -tags '{{ tags }}' -ldflags '-s -w' -o ../../gitea .

# Build backend with CGO enabled. Available tags: bindata, pam. See `docs/build-source.md#Build`
[no-exit-message]
build-backend-cgo cgo_cflags='' tags='':
  #!/usr/bin/env bash
  if [[ "{{ tags }}" =~ "bindata" ]]; then
    modules=(migration options public templates)
    for m in "${modules[@]}"; do
      f="./src/backend/modules/$m/bindata.dat"
      if [ ! -f "$f" ]; then
        just no_bindata_err $m; exit 1
      fi
    done
  fi
  CGO_ENABLED='1' CGO_CFLAGS='{{ cgo_cflags }}' go build -C ./src/backend -v -tags '{{ tags }}' -ldflags '-s -w' -o ../../gitea .

# Build Docker image
docker-build tag='master-test':
  docker build -t nubisvela/gitea:{{ tag }} .

# Clean up dependencies, build artifacts, generated files and runtime data
clean:
  rm -rf gitea data custom/conf/app.ini
  rm -rf src/frontend/node_modules
  rm -rf src/backend/modules/{migration,options,public,templates}/bindata.dat

[private]
no_bindata_err +module:
  @printf "\033[1;31merror\033[0m: bindata file for \033[1;33m{{ module }}\033[0m not found, please run '\033[1;34mjust generate-backend bindata\033[0m' first\n" >&2
