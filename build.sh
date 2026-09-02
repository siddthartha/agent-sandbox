#!/bin/bash

# Bake the host user into the image (see claude.Dockerfile): host uid/gid so
# files written to /workspace keep host ownership, and the docker socket's gid
# so the docker CLI and the docker MCP keep working as that user.
docker build --file claude.Dockerfile -t claude-sandbox \
  --build-arg HOST_UID="$(id -u)" \
  --build-arg HOST_GID="$(id -g)" \
  --build-arg DOCKER_GID="$(stat -c %g /var/run/docker.sock)" \
  .
