FROM node:22-slim
# OpenAI publishes no image with the CLI (ghcr.io/openai/codex-universal is
# the cloud environment base without it), so it is installed from npm like
# Claude Code in claude.Dockerfile.
RUN npm install -g @openai/codex

RUN apt-get update \
    && apt-get install -y --no-install-recommends \
        ca-certificates \
        curl \
        git \
        gnupg \
        openssh-client \
    && install -m 0755 -d /etc/apt/keyrings \
    && curl -fsSL https://download.docker.com/linux/debian/gpg \
        -o /etc/apt/keyrings/docker.asc \
    && chmod a+r /etc/apt/keyrings/docker.asc \
    && echo "deb [arch=$(dpkg --print-architecture) signed-by=/etc/apt/keyrings/docker.asc] https://download.docker.com/linux/debian $(. /etc/os-release && echo "$VERSION_CODENAME") stable" \
        > /etc/apt/sources.list.d/docker.list \
    && apt-get update \
    && apt-get install -y --no-install-recommends \
        docker-ce-cli \
        docker-buildx-plugin \
        docker-compose-plugin \
    && rm -rf /var/lib/apt/lists/*

# Trust GitHub's SSH host keys system-wide so git over ssh works without a
# known_hosts prompt (the launcher forwards only the ssh-agent socket, not
# ~/.ssh). Same pinned keys as claude.Dockerfile; refresh both from
# https://api.github.com/meta if GitHub rotates a key. SHA256 fingerprints:
#   ED25519 +DiY3wvvV6TuJJhbpZisF/zLDA0zPMSvHdkr4UvCOqU
#   ECDSA   p2QAMXNIC1TJYWeIOttrVc98/R1BUFWu3/LiyKgUfQM
#   RSA     uNiVztksCsDhcc0u9e8BujQXVUpKZIDTMczCvj3tD2s
# The trailing ssh-keygen parses the file so a malformed key fails the build.
RUN printf '%s\n' \
    'github.com ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIOMqqnkVzrm0SdG6UOoqKLsabgH5C9okWi0dh2l9GKJl' \
    'github.com ecdsa-sha2-nistp256 AAAAE2VjZHNhLXNoYTItbmlzdHAyNTYAAAAIbmlzdHAyNTYAAABBBEmKSENjQEezOmxkZMy7opKgwFB9nkt5YRrYMjNuG5N87uRgg6CLrbo5wAdT/y6v0mKV0U2w0WZ2YB/++Tpockg=' \
    'github.com ssh-rsa AAAAB3NzaC1yc2EAAAADAQABAAABgQCj7ndNxQowgcQnjshcLrqPEiiphnt+VTTvDP6mHBL9j1aNUkY4Ue1gvwnGLVlOhGeYrnZaMgRK6+PKCUXaDbC7qtbW8gIkhL7aGCsOr/C56SJMy/BCZfxd1nWzAOxSDPgVsmerOBYfNqltV9/hWCqBywINIR+5dIg6JTJ72pcEpEjcYgXkE2YEFXV1JHnsKgbLWNlhScqb2UmyRkQyytRLtL+38TGxkxCflmO+5Z8CSSNY7GidjMIZ7Q4zMjA2n1nGrlTDkzwDCsw+wqFPGQA179cnfGWOWRVruj16z6XyvxvjJwbz0wQZ75XK5tKSb7FNyeIEs4TT4jk+S4dhPeAUC5y+bDYirYgM4GC7uEnztnZyaVWQ7B381AK4Qdrwt51ZqExKbQpTUNn+EjqoTwvqNj4kqx5QUCI0ThS/YkOxJCXmPUWZbhjpCg56i+2aB6CmK2JGhn57K5mj0MNdBXA4/WnwH6XoPWJzK5Nyu2zB3nAZp+S5hpQs+p1vN1/wsjk=' \
    > /etc/ssh/ssh_known_hosts \
    && ssh-keygen -lf /etc/ssh/ssh_known_hosts

# The launcher runs the container as the host user, not root, so files it
# writes to /workspace keep host ownership. build.sh passes the host ids:
# `node` is remapped to the host uid/gid, and a `docker` group with the host
# socket's gid lets the docker CLI reach the daemon.
ARG HOST_UID=1000
ARG HOST_GID=1000
ARG DOCKER_GID=999
RUN groupmod -o -g "${HOST_GID}" node \
    && usermod -o -u "${HOST_UID}" -g "${HOST_GID}" node \
    && chown -R "${HOST_UID}:${HOST_GID}" /home/node \
    && install -d -o node -g node -m 700 /home/node/.ssh \
    && (getent group docker >/dev/null || groupadd -o -g "${DOCKER_GID}" docker) \
    && usermod -aG docker node

# Codex's own Linux sandbox is bubblewrap, which needs user namespaces; the
# docker default seccomp profile denies those, so no bubblewrap is installed
# here and the launcher runs Codex with sandbox_mode=danger-full-access: the
# container is the sandbox.

WORKDIR /workspace
ENTRYPOINT ["codex"]
