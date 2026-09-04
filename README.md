# agent-sandbox

Run a coding agent in a throwaway docker container against the current
directory, as your own user, with git, ssh and docker available inside.

- The agent only sees the directory you start it from (mounted at
  `/workspace`) and its own config from your home.
- Files it writes are owned by you: the images are built with your uid/gid.
- It can drive project containers through the host docker socket.
- Nothing is installed on the host except docker.

## Build

```bash
./build.sh            # claude-sandbox, opencode-sandbox, codex-sandbox and the docker MCP image
./build.sh opencode   # just one target
```

Rebuild after any change to a Dockerfile or a launcher.

## Claude Code

```bash
cd ~/work/some-project
~/work/agent-sandbox/claude                    # interactive session
~/work/agent-sandbox/claude --continue         # pick up the last session here
~/work/agent-sandbox/claude --resume <id>      # a specific one
~/work/agent-sandbox/claude -p "what does build.sh do"
```

Config, sessions and memory come from `~/.claude` and `~/.claude.json`.

## OpenCode

```bash
cd ~/work/some-project
~/work/agent-sandbox/opencode                  # interactive TUI
~/work/agent-sandbox/opencode run "add a make target that runs the tests"
~/work/agent-sandbox/opencode --model openai/gpt-5.1-codex
```

Config comes from `~/.opencode`, auth and sessions from
`~/.local/share/opencode`.

## Codex

```bash
cd ~/work/some-project
~/work/agent-sandbox/codex                     # interactive TUI
~/work/agent-sandbox/codex exec "add a make target that runs the tests"
~/work/agent-sandbox/codex --model gpt-5.1-codex
```

Config, auth and sessions come from `~/.codex`. OpenAI publishes no image
with the CLI (`ghcr.io/openai/codex-universal` is the cloud environment base
without it), so `codex.Dockerfile` installs it from npm on `node:22-slim`,
like Claude Code.

Codex's own Linux sandbox is bubblewrap, which needs user namespaces; the
docker default seccomp profile denies those inside the container. The
launcher therefore starts Codex with `-c sandbox_mode=danger-full-access`:
the container is the sandbox. Your own `--sandbox`, `--full-auto` or
`--dangerously-bypass-approvals-and-sandbox` flags still win, and the
approval policy is untouched.

Every argument goes to the agent CLI unchanged. Put this directory on `PATH`
to call them as `claude`, `opencode` and `codex`.

## What the container gets

| Host | Container | Mode |
|---|---|---|
| current directory | `/workspace` | rw |
| `~/.gitconfig` | `~/.gitconfig` | ro |
| ssh-agent socket | `/tmp/ssh-agent.sock` | no keys are copied |
| `~/.ssh/known_hosts` | `~/.ssh/known_hosts` | ro, only if it exists |
| `/var/run/docker.sock` | same path | docker CLI and compose |

GitHub's ssh host keys are pinned in the images, so `git push` works without
a known_hosts prompt.

`.mcp.json` registers two MCP servers for Claude Code, both run as throwaway
containers through the mounted socket:

- `mcp-server-docker` with the socket mounted, so the agent lists, starts and
  inspects containers through tools instead of shell. `./build.sh` builds that
  image too, from `github.com/ckreiling/mcp-server-docker`.
- `playwright` from `mcr.microsoft.com/playwright/mcp`, a headless browser the
  agent drives to open pages, click and take screenshots. The image is pulled
  on first use. A small `sh -c` wrapper joins the container to every compose
  network present at start (`docker network ls` filtered by the
  `com.docker.compose.network` label), so the agent reaches running stacks by
  service name. A stack started later is picked up after restarting the
  server with `/mcp`.

Claude Code asks once per project before using servers from `.mcp.json`.

## Qwen Code

`qwen` is the older wrapper around `ghcr.io/qwenlm/qwen-code`, documented in
`README-qwen-old.md`. Moving it to the same setup is in `TODO.md`.

## Agent configuration: one AGENTS.md for all

Instructions, subagents and skills exist once and reach every agent through
symlinks, so nothing is copied per tool:

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

OpenCode and Codex read `AGENTS.md` and `.agents/skills` natively, so they
need no links for those. To add a skill or subagent, create it under
`.agents/` with only `name` and `description` in the frontmatter; the `tools`
and `model` fields differ per agent and belong in each agent's own config.
Per-agent table and rationale: `unified-agents-directory-structure.md`.

## The containered-agent skill

`.agents/skills/containered-agent` tells an agent how to work from inside the
sandbox: recognise that it runs in a container, learn the project's layout and
deploy files, find the project's own containers through the docker socket and
run builds and tests in those rather than in the sandbox, keep file ownership
as it found it, and touch protected branches only through a pull request.

Use it at the start of a session:

```
/containered-agent      # Claude Code; other agents load it by description or on request
```

In this repo it is picked up automatically. For other projects, copy or link
it to `~/.claude/skills/` (Claude Code) or `~/.agents/skills/` (OpenCode,
Codex); both are read from your home in every project.
