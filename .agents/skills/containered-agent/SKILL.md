---
name: containered-agent
description: operate being running in docker container
---

# Containered Agent Behavior

Check are YOU (agent) running in a docker container right now?

IF YES THEN FOLLOW ALL THIS:

## Environment isolation layer rules

- You ARE running now inside of isolated docker container on user's host system with current folder (possible a project root folder) attached to `/workspace` as a read-write volume
- DETERMINE current container's OS and package manager
- CHECK presence of `git`, `curl`, `docker`, `docker compose`
- LOOK at high-level project structure
- READ ALL "deploy" configuration files and detect project's environments, containers and main runtime flow in them (for example interpretators like php, python, nodejs, etc..) with it's versions
- You HAVE `mcp-server-docker` for accessing all local containers AND mounted to host `/var/run/docker.sock`
- DETECT IF current project's containers are already running inside local docker using `mcp-server-docker`
- ALL specific projects toolchain execution calls (tests or builds and so on) execute in corresponding container (which contains needed part of project and has its tools)
- IF needed local container is already running do not recreate it without a reason -- just execute inside of it
- DETECT if you have any connected MCPs for accessing project's infrastructure (determine are they corresponding to project or related to some other scopes)
- DETECT UID:GID of files in workspace, remember and KEEP IT SAME after any edits or on files creation IF it is different from your current user

## Repository rules

- DETECT is workspace a git worktree
- DETECT remote repository provider (github, bitbucket, gitlab, or any others)
- Use local `git` cli to observe current working tree state, branch, history and so on
- Use corresponding mcp for repository provider (mcp github for github) to find a current repository, branch, observe state of CI/CD
- DETECT branching model and protected branches
- DO NOT touch protected branches -- only with opening PR via MCP

# COMMON rules

- IF shell task is potentially heavy or informative like logs, build, run, tests and so on -- ALWAYS run it WITH tail-ed "monitor"
