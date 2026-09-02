#!/bin/bash
set -e

# Bake the host user into the sandbox images (see the Dockerfiles): host
# uid/gid so files written to /workspace keep host ownership, and the docker
# socket's gid so the docker CLI and the docker MCP keep working as that user.
args=(
  --build-arg HOST_UID="$(id -u)"
  --build-arg HOST_GID="$(id -g)"
  --build-arg DOCKER_GID="$(stat -c %g /var/run/docker.sock)"
)

build() {
  case "$1" in
    claude|opencode)
      docker build --file "$1.Dockerfile" -t "$1-sandbox" "${args[@]}" .
      ;;
    mcp-server-docker)
      # The docker MCP server registered in .mcp.json: upstream image, no
      # host ids needed, it only talks to the mounted socket.
      docker build -t mcp-server-docker https://github.com/ckreiling/mcp-server-docker.git#main
      ;;
    *)
      echo "unknown target: $1 (claude, opencode, mcp-server-docker)" >&2
      exit 1
      ;;
  esac
}

# ./build.sh                    builds everything
# ./build.sh opencode           builds only the named targets
targets=("$@")
if [ ${#targets[@]} -eq 0 ]; then
  targets=(claude opencode mcp-server-docker)
fi

for target in "${targets[@]}"; do
  build "$target"
done
