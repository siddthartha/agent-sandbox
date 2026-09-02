# agent-sandbox

Docker launchers that run coding agents against the directory they are started
from, mounted read-write into the container:

- `claude`, `build.sh`, `claude.Dockerfile`: Claude Code in the locally built
  `claude-sandbox` image, running as the host user with docker access.
- `opencode`: OpenCode from `ghcr.io/anomalyco/opencode`.
- `qwen`: Qwen Code from `ghcr.io/qwenlm/qwen-code`.

There is no application runtime, test suite or CI here. Everything is bash plus
one Dockerfile.

## Working here

- Keep the launchers thin: a `docker run` wrapper with the mounts and flags it
  needs, nothing else.
- Any change to `claude.Dockerfile`, `build.sh` or `claude` needs a rebuild and
  the check described in the `sandbox-rebuild` skill.
- Never put secrets into scripts or image layers. Credentials come from the
  mounted home files and the forwarded ssh-agent socket only.
- Quote every shell expansion. Guard optional bind mounts with a file test: a
  missing host path makes docker create a directory there.
- Everything in the repo is written in English. Commit messages are one short
  line.

## Agent configuration layout

`AGENTS.md` is the single instructions file; `CLAUDE.md` and `QWEN.md` are
symlinks to it. Subagents and skills live once under `.agents/`, which Codex
and OpenCode read natively; `.claude/`, `.opencode/` and `.qwen/` hold symlinks
into it. The per-agent table is in `unified-agents-directory-structure.md`.

Add a skill as `.agents/skills/<name>/SKILL.md` and a subagent as
`.agents/agents/<name>.md`. Keep the frontmatter to `name` and `description`:
the `tools` and `model` fields have a different shape in every agent.
