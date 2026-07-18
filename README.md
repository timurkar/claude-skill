# Chatium Sync — Claude Code Skill

A skill for AI coding agents — [Claude Code](https://claude.com/claude-code) and [Codex CLI](https://developers.openai.com/codex) — that synchronizes a local folder with a [Chatium](https://chatium.com) account. Ported from the official VSCode chatium-sync extension.

## Install

The easiest way is via npm:

```bash
npx @chatium/skill
```

This downloads the skill files into `~/.claude/skills/chatium-sync/` (Claude Code) and `~/.codex/skills/chatium-sync/` (Codex CLI) — whichever agents are present. Restart the agent → the `chatium-sync` skill is active (in Claude Code also as the `/chatium-sync` slash command).

### Manual install

Clone or download this repo, then copy the files into your Claude Code skills directory:

```bash
mkdir -p ~/.claude/skills/chatium-sync
cp SKILL.md chatium-sync.sh *.md ~/.claude/skills/chatium-sync/
chmod +x ~/.claude/skills/chatium-sync/chatium-sync.sh
```

## Quick start

```
# In Claude Code, from your Chatium project folder:
/chatium-sync init <account> <token>
/chatium-sync pull --force
```

Get your API token at `https://<your-account>/s/login/external-tool/token`.

The server is always the source of truth: the local folder is a working cache for searching and editing. The skill refreshes it with `pull --force` and uploads each changed file back with `upload` right after editing.

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

## Repository structure

- `SKILL.md` — Claude Code skill definition
- `chatium-sync.sh` — sync engine (bash)
- `coding.md`, `heap.md`, `heap-filter.md`, `auth.md`, `routing.md`, `storage.md` — domain docs loaded by the skill
- `npm-package/` — source of the `@chatium/claude-skill` npm installer

## Requirements

- macOS/Linux, or Git Bash/WSL on Windows
- `bash`, `curl`, `jq`, `shasum`, `file` (preinstalled on macOS/Linux)

## License

MIT
