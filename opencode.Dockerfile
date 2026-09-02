FROM ghcr.io/anomalyco/opencode:latest

# Same toolchain as claude.Dockerfile, on Alpine: git and ssh for the repo,
# the docker CLI and compose plugin for the host socket.
RUN apk add --no-cache \
        ca-certificates \
        curl \
        git \
        openssh-client \
        docker-cli \
        docker-cli-buildx \
        docker-cli-compose

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
# writes to /workspace keep host ownership. build.sh passes the host ids: the
# base image has no non-root account, so an `opencode` user is created with
# the host uid/gid, plus a `docker` group with the host socket's gid so the
# docker CLI reaches the daemon. The shadow tools allow duplicate ids (-o),
# which busybox adduser/addgroup refuse; they are removed again afterwards.
# The XDG tree is pre-created and owned by the user: the launcher bind-mounts
# into ~/.config and ~/.local/share, and docker would create any missing
# parent as root, leaving OpenCode unable to mkdir ~/.local/state next to it.
ARG HOST_UID=1000
ARG HOST_GID=1000
ARG DOCKER_GID=999
RUN apk add --no-cache --virtual .idtools shadow \
    && groupadd -o -g "${HOST_GID}" opencode \
    && useradd -o -m -u "${HOST_UID}" -g "${HOST_GID}" -d /home/opencode -s /bin/sh opencode \
    && install -d -m 700 /home/opencode/.ssh \
    && mkdir -p /home/opencode/.config/opencode /home/opencode/.local/share/opencode \
        /home/opencode/.local/state /home/opencode/.cache \
    && chown -R opencode:opencode /home/opencode \
    && groupadd -o -g "${DOCKER_GID}" docker \
    && usermod -aG docker opencode \
    && apk del .idtools

# The container is ephemeral (--rm): updates come from rebuilding the image,
# not from the in-app update check.
ENV OPENCODE_DISABLE_AUTOUPDATE=1

WORKDIR /workspace
ENTRYPOINT ["opencode"]
