# Chatium Sync — Claude Code Skill

A [Claude Code](https://claude.com/claude-code) skill that synchronizes a local folder with a [Chatium](https://chatium.com) account. Ported from the official VSCode chatium-sync extension.

## Install

The easiest way is via npm:

```bash
npx @chatium/claude-skill
```

This downloads the skill files into `~/.claude/skills/chatium-sync/`. Restart Claude Code → `/chatium-sync` will appear as a slash command.

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
/chatium-sync sync
```

Get your API token at `https://<your-account>/s/login/extension/token`.

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
