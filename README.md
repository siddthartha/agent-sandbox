# agent-sandbox

> Agents must **always** run in an isolated environment.

Run a coding agent in a throwaway docker container against the current directory.

- The agent runs in a docker container, isolated by _Linux namespaces_ and _cgroups_, so it only sees the directory
  you start it from, mounted as a volume at `/workspace`
- Its config, auth, sessions and memory **come from your home directory** on the host (for example `~/.claude` or
  `~/.opencode`)
- **Rootless** and aligned with your host user: the images are built with your _uid_/_gid_, so every file the agent
  writes is owned by you
- It can freely drive any container on the host: the docker socket is mounted and the container user is in a `docker`
  group with the same _gid_ as on the host
- It can use SSH for any tool, `git` included, without seeing your keys: only the `ssh-agent` socket is forwarded
- All command-line arguments pass through the launcher script to the agent's CLI in the container unchanged

## Build

`build.sh` builds the images from scratch:

- installs the tools the agent needs:
  - `git`
  - `curl`
  - `ssh`
  - `docker` CLI with `buildx` and `compose`
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
| current directory | `/workspace` | RW |
| `~/.gitconfig` | `~/.gitconfig` | RO |
| ssh-agent socket | `/tmp/ssh-agent.sock` | no keys are copied |
| `~/.ssh/known_hosts` | `~/.ssh/known_hosts` | RO, only if it exists |
| `/var/run/docker.sock` | `/var/run/docker.sock` | docker CLI and compose |

GitHub's ssh host keys are pinned in the images, so `git push` works without a known_hosts prompt.

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
  container to every compose network present at start, so the agent reaches running stacks by service name through
  docker's DNS

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
