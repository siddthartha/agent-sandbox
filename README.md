# agent-sandbox

> Agents must **always** run in an isolated environment. // (c) me

Run a coding agent in a throwaway docker container against the current directory.

- The agent runs in a docker container, isolated by _Linux namespaces_ and _cgroups_, so it only sees the directory
  you start it from, mounted at **the same absolute path it has on the host**, so absolute paths mean the same thing
  on both sides
- Its _config_, _auth_, _sessions_ and _memory_ -- **come from your home directory** on the host system (for example
  `~/.claude` or `~/.opencode`)
- **Rootless** and aligned with your host user: the images are built with your _uid_/_gid_, so every file the agent
  writes is owned by you
- It can freely drive any container on the host: the docker socket is mounted and the container user is in a `docker`
  group with the same _gid_ as on the host
- It reaches every container on the host by name: the launcher joins the sandbox to all user-defined docker networks
  present at start, and the agent joins networks created later itself, see the `containered-agent` skill
- It can use SSH for any tool, `git` included, without seeing your keys: only the `ssh-agent` socket is forwarded
- All command-line arguments pass through the launcher script to the agent's CLI in the container unchanged

## Build

`build.sh` builds the images from scratch:

- installs the tools the agent needs:
  - `git`
  - `curl`
  - `ssh`
  - `docker` CLI with `buildx` and `compose`
  - `gh`, the GitHub CLI
- installs the latest version of the agent's CLI

The script builds all targets or just one:

```bash
./build.sh            # claude-sandbox, opencode-sandbox, codex-sandbox and the docker MCP image
./build.sh opencode   # just one target
```

## Agents

Copy the launchers (`claude`, `opencode`, `codex`) to `~/bin` or any other directory on `PATH`.

### Usage

```bash
cd ~/workspace/some-project

claude                    # interactive TUI session
claude --continue         # pick up the last session here
claude --resume <id>      # a specific one
claude -p "what does build.sh do"

opencode run "add a make target that runs the tests"
opencode --model openai/gpt-5.1-codex

codex exec "add a make target that runs the tests"
codex --model gpt-5.1-codex
```

### Claude Code

Config, sessions and memory come from `~/.claude` and `~/.claude.json`.

### OpenCode

Config comes from `~/.opencode`, auth and sessions from `~/.local/share/opencode`.

### Codex

Config, auth and sessions come from `~/.codex`.

> Codex's own Linux sandbox (bubblewrap) needs user namespaces, which docker's default seccomp profile denies inside
> the container. The launcher therefore starts Codex with `-c sandbox_mode=danger-full-access`: the container is the
> sandbox. Your own `--sandbox`, `--full-auto` or `--dangerously-bypass-approvals-and-sandbox` flags still win, and the
> approval policy is untouched.

## What the container gets

| Host | Container | Mode |
|---|---|---|
| current directory | the same absolute path | RW |
| `~/.gitconfig` | `~/.gitconfig` | RO, only if it exists |
| ssh-agent socket | `/tmp/ssh-agent.sock` | no keys are copied, only if an agent runs |
| `~/.ssh/known_hosts` | `~/.ssh/known_hosts` | RO, only if it exists |
| `~/.config/gh` | `~/.config/gh` | RO, only if it exists |
| `/var/run/docker.sock` | `/var/run/docker.sock` | docker CLI and compose |
| every user-defined network | joined at start | container names resolve; networks created later are joined at runtime |

The project keeps the path it has on the host, `/home/you/work/project` inside the container as well as outside, rather
than a fixed `/workspace`. The mounted docker socket is what makes this worth doing: the daemon resolves every
bind-mount source on the host, so a compose file or a `docker run -v "$PWD/data:/data"` started from inside the sandbox
names a directory that really exists. With a fixed mount point the same command would point at a path the host does not
have, and docker would create it there as an empty root-owned directory. Absolute paths in configs and `includeIf
gitdir:` rules in `~/.gitconfig` line up for the same reason.

GitHub's ssh host keys are pinned in the images, so `git push` works without a known_hosts prompt. The GitHub CLI is
installed and takes the host's login from `~/.config/gh`, so `gh pr` works from the sandbox and Claude Code's footer
shows the PR badge for the current branch. The token has to be in that directory: on a desktop `gh auth login` puts it
into the OS keyring, which the container cannot reach, so log in with `gh auth login --insecure-storage`. The directory
is mounted read-only, the sandbox cannot change or drop the login.

The launchers and the Playwright server join every user-defined bridge network, compose or hand-made, so a container
started with `--network <name>` resolves by name from inside the sandbox. Only the default `bridge` is skipped: it has
no name resolution, and docker refuses to combine it with user-defined networks. A container started without
`--network` lands there and stays invisible, so give it a network:

```bash
docker network create mcp
docker run -d --name fly-mcp-server --network mcp flyio/flyctl mcp server --bind-addr 0.0.0.0 --port 9090 --stream
```

## macOS

Works with Docker Desktop or OrbStack. Four things differ from Linux, and the scripts handle them:

- the docker socket is proxied into the VM and is `root:root` inside containers, so `build.sh` bakes gid 0 instead of
  the host socket's group (`DOCKER_GID=<gid> ./build.sh` overrides that for other runtimes)
- a host Unix socket cannot be bind-mounted across the VM, so the launchers forward the ssh agent through
  `/run/host-services/ssh-auth.sock`, which both runtimes provide
- ownership of bind-mounted files is mapped by the VM's file sharing, so the uid/gid baked into the images changes
  nothing there, and does no harm
- the project path has to be on the runtime's file-sharing list, which matters more now that it is the mount point as
  well as the source; `/Users` is shared out of the box by both runtimes, a project kept on another volume needs adding

On Apple Silicon every image is pulled or built as arm64.

## The containered-agent skill

The **containered-agent** skill (`.agents/skills/containered-agent`) tells an agent how to work from inside the sandbox
container, alongside whatever other environments it finds in the project's configuration: compose stacks, their
runtimes and tools.

Use it at the start of a session:

```
/containered-agent      # Claude Code; other agents load it by description or on request
```

In this repo it is picked up automatically. For other projects, copy or link it to `~/.claude/skills/` (Claude Code)
or `~/.agents/skills/` (OpenCode, Codex); both are read from your home in every project.

## Pre-configured MCP servers

`.mcp.json` registers a few MCP servers for Claude Code; the other agents have their own format for that, see
`unified-agents-directory-structure.md`. All of them run as throwaway containers through the mounted docker socket:

- **Docker MCP** (`mcp-server-docker`) with the same socket mounted, so the agent lists, starts and inspects
  containers through tools instead of the shell. `./build.sh` builds that image too, from
  `github.com/ckreiling/mcp-server-docker`, since there is no official one
- **Playwright MCP** (`playwright`) from `mcr.microsoft.com/playwright/mcp`, a _headless browser_ the agent drives to
  open pages, click and _take screenshots_. The image is pulled on first use. A small `sh -c` wrapper joins the
  container to every user-defined bridge network present at start, so the agent reaches running stacks by service
  name through docker's DNS

> Claude Code asks once per project before using servers from `.mcp.json`.

## One deduplicated folder structure for all agents

Instructions, subagents and skills exist once and reach every agent through symlinks, so nothing is copied per tool:

```
AGENTS.md                         instructions, the only real copy
CLAUDE.md -> AGENTS.md            Claude Code
QWEN.md   -> AGENTS.md            Qwen Code
.agents/agents/<name>.md          subagents
.agents/skills/<name>/SKILL.md    skills
.claude/{agents,skills}   -> ../.agents/...
.opencode/agents          -> ../.agents/agents
.qwen/{agents,skills}     -> ../.agents/...
```

OpenCode and Codex read `AGENTS.md` and `.agents/skills` natively, so they need no links for those.

> Agent-specific or model-dependent files are the exception to this shared layout and go into that agent's own
> directory.

To add a skill or subagent, create it under `.agents/` with **only** `name` and `description` in the frontmatter; the
`tools` and `model` fields differ per agent and belong in each agent's own config. Per-agent table and rationale:
`unified-agents-directory-structure.md`.
