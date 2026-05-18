# @chatium/claude-skill

Installs the **Chatium Sync** skill for [Claude Code](https://claude.com/claude-code) — a slash command that synchronizes your local folder with a Chatium account.

## Install

```bash
npx @chatium/claude-skill
```

Or globally:

```bash
npm install -g @chatium/claude-skill
```

This downloads the skill files from [github.com/timurkar/claude-skill](https://github.com/timurkar/claude-skill) into `~/.claude/skills/chatium-sync/`.

After install, **restart Claude Code** — `/chatium-sync` will appear as a slash command.

## Quick start

```bash
# 1. cd into your Chatium project folder
cd ~/projects/my-chatium-app

# 2. In Claude Code:
/chatium-sync init <account> <token>
/chatium-sync sync
```

Get your API token at `https://<your-account>/s/login/extension/token`.

## What it includes

- `SKILL.md` — Claude Code skill definition (`/chatium-sync` command)
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
CHATIUM_SKILL_BRANCH=dev npx @chatium/claude-skill
```

## License

MIT
