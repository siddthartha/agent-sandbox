# TODO

## One launcher script for all agents

- De-duplicate `claude`, `opencode` and `codex`: the optional-mount guards, the ssh-agent switch and the `docker run`
  skeleton are identical, only the image, the home mounts and the agent-specific flags differ. Keep one script and
  select the agent from the name it was called by (`$0`), with `claude`, `opencode` and `codex` as symlinks to it.

## qwen: same sandbox setup as claude and opencode

- `qwen.Dockerfile` on `ghcr.io/qwenlm/qwen-code` with git, ssh client, docker
  CLI and compose plugin, the pinned GitHub host keys, a user with the host
  uid/gid in the docker group, and the `~/.qwen` and XDG dirs pre-created.
  Image name `qwen-sandbox`, built by `build.sh`.
- Rewrite the `qwen` launcher in the claude/opencode style: `--user`,
  `--group-add docker`, project at `/workspace`, `~/.qwen` mounted, gitconfig
  read-only, ssh-agent socket, guarded known_hosts mount, arguments passed
  through to the qwen CLI.
- Decide what happens to the old `--provider` / `--model` options
  (`README-qwen-old.md`): keep them as env passthrough or drop them in favour
  of Qwen Code's own settings.
- Update `README.md` and `AGENTS.md`, delete `README-qwen-old.md`.

## Shared agent config

- Confirm OpenCode, Codex and Qwen Code list `sandbox-rebuild`,
  `containered-agent` and `launcher-reviewer` from the `.agents/` tree; only
  Claude Code is verified so far.
