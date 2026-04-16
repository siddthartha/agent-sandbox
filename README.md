# Wrapper README

## Overview
The wrapper script simplifies running the Qwen Code Docker image (`ghcr.io/qwenlm/qwen-code:0.14.5`) with optional AI provider configuration (OpenAI or OpenRouter). It automatically handles Docker image pulling, environment variable setup, and volume mounting for the target folder.

## Prerequisites
- Docker service installed and running.
- (Optional) API keys for OpenAI or OpenRouter if you intend to use those providers.

## Usage
```bash
./qwen [folder] [--provider openai|openrouter] [--model model_name]
```

### Options
- `folder` – Path to the directory you want to mount inside the container (default: **current working directory**).
- `--provider openai|openrouter` – Choose the AI provider. If omitted, the container runs without provider-specific credentials.
- `--model model_name` – Override the default model for the chosen provider.

### Defaults
- **OpenAI model:** `gpt-5.1-codex` (can be overridden by `OPENAI_MODEL` env var)
- **OpenRouter model:** `openai/gpt-oss-120b:free` (can be overridden by `OPENROUTER_MODEL` env var)

## Environment Variables
Set the following variables before running the script if you use a provider:

| Variable | Description |
|----------|-------------|
| `OPENAI_API_KEY` | Your OpenAI API key (used for both OpenAI and OpenRouter when the respective provider is selected). |
| `OPENAI_BASE_URL` | Base URL for the OpenAI API (default: `https://api.openai.com/v1`). |
| `OPENAI_MODEL` | Model name for OpenAI (overridden by `--model`). |
| `OPENROUTER_API_KEY` | Your OpenRouter API key (same key as OpenAI). |
| `OPENROUTER_BASE_URL` | Base URL for OpenRouter API (default: `https://openrouter.ai/api/v1`). |
| `OPENROUTER_MODEL` | Model name for OpenRouter (overridden by `--model`). |

## Examples

### Run with default settings (no provider, current folder is a project root)
```bash
./qwen
```

### Run on a specific folder with OpenAI
```bash
export OPENAI_API_KEY="sk-..."
./qwen /path/to/project --provider openai
```

### Run with a custom OpenRouter model
```bash
export OPENROUTER_API_KEY="sk-..."
./qwen . --provider openrouter --model my/custom-model
```

## How It Works
1. **Argument parsing** – Determines the target folder, provider, and model.
2. **Model selection** – Uses provider‑specific defaults unless a model is explicitly supplied.
3. **Docker image handling** – Pulls `ghcr.io/qwenlm/qwen-code:0.14.5` if not already present.
4. **Container execution** – Runs the image with the appropriate environment variables and mounts the chosen folder at `/app` inside the container.

## License
This wrapper script is provided under the MIT License. See the LICENSE file for details.

---

Feel free to modify the script to suit your workflow or add additional provider support as needed.

