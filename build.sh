#!/bin/bash
set -e

# Bake the host user into the images (see the Dockerfiles): host uid/gid so
# files written to /workspace keep host ownership, and the docker socket's gid
# so the docker CLI and the docker MCP keep working as that user.
args=(
  --build-arg HOST_UID="$(id -u)"
  --build-arg HOST_GID="$(id -g)"
  --build-arg DOCKER_GID="$(stat -c %g /var/run/docker.sock)"
)

# ./build.sh             builds every sandbox image
# ./build.sh opencode    builds only the named ones
agents=("$@")
if [ ${#agents[@]} -eq 0 ]; then
  agents=(claude opencode)
fi

for agent in "${agents[@]}"; do
  docker build --file "$agent.Dockerfile" -t "$agent-sandbox" "${args[@]}" .
done
