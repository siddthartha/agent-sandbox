# Unified agent configuration

One instructions file and one set of subagent and skill definitions, shared by
several coding agents through symlinks instead of copies.

## Concept

```
project/
├── AGENTS.md
├── CLAUDE.md  ──────> AGENTS.md
├── GEMINI.md  ──────> AGENTS.md
├── .mcp.json
├── llms.txt
├── .agents/
│   ├── agents/
│   └── skills/
├── .claude/ ───────> ../.agents/
├── .opencode/
│   └── agents ───────> ../.agents/agents
├── .grok/
│   └── skills ───────> ../.agents/skills
└── .kimi-code/
    └── skills ───────> ../.agents/skills
```

## Adopted in this repo: Claude Code, OpenCode, Codex, Qwen Code

```
project/
├── AGENTS.md                      instructions, the only real copy
├── CLAUDE.md  -> AGENTS.md        Claude Code
├── QWEN.md    -> AGENTS.md        Qwen Code
├── .mcp.json                      MCP servers, Claude Code format
├── .agents/
│   ├── agents/<name>.md           subagents, one file each
│   └── skills/<name>/SKILL.md     skills, one directory each
├── .claude/
│   ├── agents -> ../.agents/agents
│   └── skills -> ../.agents/skills
├── .opencode/
│   └── agents -> ../.agents/agents   skills need no link, see below
└── .qwen/
    ├── agents -> ../.agents/agents
    └── skills -> ../.agents/skills
```

Every agent directory links only `agents` and `skills`, so each agent's own
files (for Claude Code: `settings.json`, `settings.local.json`, `commands/`,
`hooks/`) stay in its own directory and out of the shared store. There is no
`.codex/` directory: Codex reads `AGENTS.md` and `.agents/skills` natively and
has no markdown subagents. `llms.txt` is omitted; `AGENTS.md` is the project
summary here.

## Who reads what

Verified against each project's documentation on 2026-09-02.

| Agent | Instructions | Subagents | Skills | MCP servers |
|---|---|---|---|---|
| Claude Code | `CLAUDE.md` (link) | `.claude/agents` (link) | `.claude/skills` (link) | `.mcp.json` |
| OpenCode | `AGENTS.md` (native, `CLAUDE.md` also read) | `.opencode/agents` (link) | `.agents/skills` (native, `.claude/skills` also scanned) | `opencode.json`, key `mcp` |
| Codex | `AGENTS.md` (native) | none | `.agents/skills` (native) | `.codex/config.toml` or `~/.codex/config.toml`, table `mcp_servers` |
| Qwen Code | `QWEN.md` (link) | `.qwen/agents` (link) | `.qwen/skills` (link) | `.qwen/settings.json`, key `mcpServers` |

MCP server definitions cannot be shared: every agent has its own file format.
`.mcp.json` is Claude Code's; add the others next to it when needed.

## Rules for shared definitions

- Frontmatter carries only `name` and `description`. `tools` is a string for
  Claude Code, a list for Qwen Code and a map for OpenCode, and `model` ids
  differ as well. Agent-specific settings go into that agent's own config, not
  into the shared file.
- A skill's directory name equals the `name` in its `SKILL.md`.
- OpenCode discovers each skill twice, through `.claude/skills` and
  `.agents/skills`; both paths resolve to the same file.
- Symlinks are relative, so the tree works from any checkout path and inside
  the sandbox containers.

## Checking

Each agent's skills and agents listing should show `sandbox-rebuild` and
`launcher-reviewer`. In Claude Code that is `/skills` and `/agents`.
