---
name: sandbox-rebuild
description: Rebuild a sandbox image (claude-sandbox, opencode-sandbox, codex-sandbox) with the host ids and verify the non-root container (docker access, git, file ownership). Use after editing a Dockerfile, build.sh or a launcher.
---

# Rebuild and verify a sandbox image

The steps below use `claude`; for OpenCode or Codex replace it with
`opencode` or `codex` (the Dockerfile, image name and CLI are named alike).

1. Build. On the host, `./build.sh [claude|opencode|codex]` reads the ids
   itself (on macOS it bakes `DOCKER_GID=0`, because the socket is root:root
   inside the VM). From inside a sandbox `id -u` is the container user, so
   pass the host ids explicitly and use a test tag:

   ```bash
   docker build -f claude.Dockerfile -t claude-sandbox:test \
     --build-arg HOST_UID=1000 --build-arg HOST_GID=1000 \
     --build-arg DOCKER_GID="$(stat -c %g /var/run/docker.sock)" .
   ```

2. Verify as the launcher would run it. The images set the agent CLI as the
   entrypoint, so override it for a shell. Bind-mount sources are host paths,
   because the docker daemon resolves them, not the container:

   ```bash
   docker run --rm --entrypoint sh --user 1000:1000 --group-add docker \
     -v /var/run/docker.sock:/var/run/docker.sock \
     -v <repo path on the host>:/workspace -w /workspace \
     claude-sandbox:test -c 'id; docker ps -q | head -1; git status -sb;
       touch .t && ls -ln .t && rm .t; claude --version'
   ```

   Expected: `uid=1000` with a `docker` group, a container id from `docker ps`,
   `git status` without a dubious-ownership error, `.t` owned `1000 1000`, and
   the CLI version.

3. Remove the test tag: `docker rmi claude-sandbox:test`. The real image is
   rebuilt by the user with `./build.sh` on the host.
