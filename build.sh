#!/bin/bash
set -e

# Bake the host user into the sandbox images (see the Dockerfiles): host
# uid/gid so files written to /workspace keep host ownership, and the docker
# socket's gid so the docker CLI and the docker MCP keep working as that user.
# On Linux that gid is the socket file's group. On macOS the socket is proxied
# into the Docker Desktop or OrbStack VM and shows up inside containers as
# root:root, so the group is 0. DOCKER_GID in the environment overrides both.
case "$(uname -s)" in
  Darwin) docker_gid=0 ;;
  *) docker_gid="$(stat -c %g /var/run/docker.sock)" ;;
esac
args=(
  --build-arg HOST_UID="$(id -u)"
  --build-arg HOST_GID="$(id -g)"
  --build-arg DOCKER_GID="${DOCKER_GID:-$docker_gid}"
)

build() {
  case "$1" in
    claude|opencode|codex)
      docker build --file "$1.Dockerfile" -t "$1-sandbox" "${args[@]}" .
      ;;
    mcp-server-docker)
      # The docker MCP server registered in .mcp.json: upstream image, no
      # host ids needed, it only talks to the mounted socket.
      docker build -t mcp-server-docker https://github.com/ckreiling/mcp-server-docker.git#main
      ;;
    *)
      echo "unknown target: $1 (claude, opencode, codex, mcp-server-docker)" >&2
      exit 1
      ;;
  esac
}

# ./build.sh                    builds everything
# ./build.sh opencode           builds only the named targets
targets=("$@")
if [ ${#targets[@]} -eq 0 ]; then
  targets=(claude opencode codex mcp-server-docker)
fi

for target in "${targets[@]}"; do
  build "$target"
done
