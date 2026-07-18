# @chatium/skill

Installs the **Chatium Sync** skill for AI coding agents — [Claude Code](https://claude.com/claude-code) and [Codex CLI](https://developers.openai.com/codex). The skill syncs your local folder with a Chatium account: pull, upload, status, static files, and more.

## Install

```bash
npx @chatium/skill
```

Or globally:

```bash
npm install -g @chatium/skill
```

The installer downloads the skill files from [github.com/timurkar/claude-skill](https://github.com/timurkar/claude-skill) and installs them for every agent found on your machine:

- Claude Code → `~/.claude/skills/chatium-sync/`
- Codex CLI → `~/.codex/skills/chatium-sync/`

After install, **restart your agent** — the `chatium-sync` skill activates automatically (in Claude Code it is also available as the `/chatium-sync` slash command).

## Quick start

```bash
# 1. cd into your Chatium project folder
cd ~/projects/my-chatium-app

# 2. Ask the agent to connect the folder to your Chatium account,
#    or in Claude Code:
/chatium-sync init <account> <token>
/chatium-sync pull --force
```

Get your API token at `https://<your-account>/s/login/external-tool/token`.

The server is always the source of truth: the local folder is a working cache for searching and editing. The skill refreshes it with `pull --force` and uploads each changed file back with `upload` right after editing.

## What it includes

- `SKILL.md` — skill definition (SKILL.md standard, works in Claude Code and Codex CLI)
- `chatium-sync.sh` — sync engine (init, pull, push, sync, status, upload, upload-static, typings, delete, rename)
- Documentation modules: `coding.md`, `heap.md`, `heap-filter.md`, `auth.md`, `routing.md`, `storage.md`

## Commands

| Command | Description |
| --- | --- |
| `init <account> <token>` | Configure your Chatium account |
| `status` | Show sync status and local changes |
| `pull [--force]` | Download files from server |
| `push [--force]` | Upload changed files to server |
| `sync [--force]` | Typings + pull + push (full sync) |
| `typings` | Download TypeScript typings |
| `upload <path>` | Upload a single code file |
| `upload-static <path>` | Upload binary/image, get hash + URLs |
| `delete <path>` | Delete a file on the server |
| `rename <old> <new>` | Rename a file on the server |

## Requirements

- Node.js 18+ (for the installer)
- `bash`, `curl`, `jq`, `shasum` for the skill script (preinstalled on macOS/Linux; on Windows use Git Bash or WSL)

## Custom branch

Install from a different branch:

```bash
CHATIUM_SKILL_BRANCH=dev npx @chatium/skill
```

## License

MIT
