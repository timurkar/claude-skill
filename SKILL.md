---
name: chatium-sync
description: Synchronize the current working directory with a Chatium account. Supports pull, push, sync, status, upload single files, delete, and rename operations.
user_invocable: true
command: chatium-sync
arguments: "[command] [options] - commands: init, pull, push, sync, status, upload <file>, delete <file>, rename <old> <new>"
---

# Chatium Sync Skill

Synchronize a local folder with a Chatium account using the Chatium entity API.

## Language

ALWAYS communicate with the user in Russian: all messages, questions, status reports, and explanations must be in Russian. Code, file names, and commands stay as is.

## Overview

This skill wraps `chatium-sync.sh` (located alongside this SKILL.md) to sync files between the local filesystem and a Chatium account. It mirrors the behavior of the official VSCode chatium-sync extension.

## Setup

The sync script is at: `${SKILL_DIR}/chatium-sync.sh`

### First-time setup

If `.chatium/config.json` does not exist in the current working directory, run initialization:

```bash
${SKILL_DIR}/chatium-sync.sh init <accountKey> <apiToken>
```

- `accountKey` is the Chatium account domain (e.g., `myapp.chatium.ru` or `some-org.chatium.ru/subpath`)
- `apiToken` is a sync token issued at `https://<accountKey>/s/login/external-tool/token`

If the skill is started without account and token information, connect step by step — do NOT dump the whole instruction at once:
1. Say only that this directory is not yet synchronized with a Chatium account, and ask for the account address. Nothing else — no token instructions yet.
2. After the user provides the address, tell them to issue a sync token by visiting `https://<account-address>/s/login/external-tool/token` in a browser and paste the token into the chat.
3. Once the token is received, run `init` with both values yourself and continue working — don't ask the user to run anything.

### Configuration

Config is stored in `.chatium/config.json`:
```json
{
  "accountKey": "myapp.chatium.ru",
  "apiToken": "..."
}
```

Tree state (file checksums, sync metadata) is stored in `.chatium/tree.json`.

## Working model: the server is the source of truth

The authoritative, current version of every file is ALWAYS on the server. The local directory is only a working cache — convenient for searching and reading code, but never assumed to be up to date.

- A full `pull` is NOT mandatory. Accounts can be large, and downloading everything is often unnecessary — pull only when you actually need to read or search a lot of existing code locally. When the task only creates NEW files (a new feature in its own folder), skip the pull entirely and just upload.
- Before editing an EXISTING file, make sure you have its current server version (refresh with `pull --force` if the local copy may be stale).
- After changing or creating a file, immediately upload it: `upload <path> --force`. Never accumulate local changes for a later bulk push.
- To delete or rename files, use `delete` / `rename` — they act directly on the server.
- Don't use full `sync`/`push` flows as the default way of working; change files on the server one at a time via `upload`. `push` is a recovery tool, not a workflow.

## Creating new functionality: separate folder with .dir.json and .workspace.json

When you create new functionality (a new feature/app — any coherent set of new files), put it in its OWN folder at the account root. This folder is a workspace, visible in the Chatium dashboard. Along with the code, ALWAYS create and upload two service files in that folder:

`<folder>/.dir.json`:
```json
{
  "name": "<Человекочитаемое имя>",
  "params": { "startWorkspaceAppearance": "ai" }
}
```

`<folder>/.workspace.json` — always created EMPTY:
```json
{}
```

- `name` in `.dir.json` — the human-readable name shown in the dashboard (Russian is fine). The folder name itself is the URL slug: latin, kebab-case (the app is served at `https://<account>/<folder>`).
- Upload both files like any other: `upload <folder>/.dir.json --force`, `upload <folder>/.workspace.json --force`.
- The folder layout inside follows the usual conventions: `tables/*.table.ts`, `api/`, pages/components at the root of the folder.

## Commands

Run from the directory you want to sync:

### Check status
```bash
${SKILL_DIR}/chatium-sync.sh status
```
Shows account info, last sync time, and locally modified/new files.

### Pull (download from server)
```bash
${SKILL_DIR}/chatium-sync.sh pull
${SKILL_DIR}/chatium-sync.sh pull --force  # overwrite local files
```
Downloads new and server-changed files. Respects conflict detection — skips locally modified files unless `--force`.

### Push (upload to server)
```bash
${SKILL_DIR}/chatium-sync.sh push
${SKILL_DIR}/chatium-sync.sh push --force  # overwrite server files
```
Uploads locally modified and new files. If the server has a different version, use `--force` to overwrite.

### Full sync (pull + push)
```bash
${SKILL_DIR}/chatium-sync.sh sync
${SKILL_DIR}/chatium-sync.sh sync --force
```

### Upload a single file
```bash
${SKILL_DIR}/chatium-sync.sh upload <relative-path> [--force]
```

### Delete a file on server
```bash
${SKILL_DIR}/chatium-sync.sh delete <relative-path>
```

### Rename a file on server
```bash
${SKILL_DIR}/chatium-sync.sh rename <old-path> <new-path>
```

## Behavior details

### Excluded paths
These paths are never synced (matching the VSCode extension):
- `.chatium/`, `.vscode/`, `.git/`, `.claude/`, `node_modules/`
- `tsconfig.json`, `package.json`, `.gitignore`, `.DS_Store`

### Conflict detection
Uses the same 3-way checksum comparison as the VSCode extension:
- **syncedChecksum** = checksum at last sync
- **localChecksum** = current local file checksum (SHA1)
- **remoteChecksum** = server's current checksum

Logic:
- `localChecksum == remoteChecksum` → synced, no action
- `syncedChecksum == localChecksum` → server changed → download
- `syncedChecksum == remoteChecksum` → local changed → upload
- Neither matches → conflict (skip, warn user)

### Static/binary file uploads (images, etc.)
Use `upload-static` to upload images and other binary files to the Chatium file service:
```bash
${SKILL_DIR}/chatium-sync.sh upload-static <path-to-file>
```
This uploads the file and returns:
- **Hash** — the file identifier (e.g., `image_msk_Aq6e10pWWI.1280x958.jpeg`)
- **Full URL** — `https://fs.chatium.ru/get/<hash>` for the original file
- **Thumbnail URLs** — `https://fs.chatium.ru/thumbnail/<hash>/s/<width>x` for resized versions

URL patterns:
- Full file: `https://fs.chatium.ru/get/<hash>`
- Thumbnail with width: `https://fs.chatium.ru/thumbnail/<hash>/s/800x`
- Thumbnail with exact size: `https://fs.chatium.ru/thumbnail/<hash>/s/800x600`

In Chatium code, use the `@app/storage` library:
```ts
import { getThumbnailUrl } from "@app/storage"
getThumbnailUrl(hash, 800, undefined) // width 800, proportional height
```

**Workflow for static assets**: if the user has images/files in a local directory that need to be used in Chatium code:
1. Upload each file with `upload-static`
2. Get the returned hash
3. Use the hash in code via `getThumbnailUrl()` or construct URLs directly

### Build feedback
When uploading, the server may return a `buildStatus`. If it's not "Success", the skill reports the build status to the user.

## Handling common user requests

- **"change/fix something in my app"** → Refresh the affected files (`pull --force` if the local cache may be stale), edit locally, then `upload <path> --force` for each changed file
- **"add new functionality"** → No pull needed: create a new folder with `.dir.json` + `.workspace.json` + code, upload each file with `upload <path> --force`
- **"download my chatium project"** → Run `pull --force`
- **"sync my project with chatium"** → Run `pull --force` (the server is already the current version; local is just a cache)
- **"upload this file"** → Run `upload <path> --force`
- **"check what's changed"** → Run `status`
- **"connect to chatium"** → Run `init`
- **"save file X to chatium"** → Run `upload <path> --force` after confirming the file exists
- **"upload this image/file"** → Run `upload-static <path>`, return hash and URLs
- **"I have images in a folder, use them in code"** → Run `upload-static` for each file, collect hashes, insert into code via `getThumbnailUrl()`

## Troubleshooting

- **Auth errors**: Token may have expired. Re-run `init` with a fresh token.
- **SSL errors**: The script uses `-k` (insecure) flag for curl, matching the VSCode extension's `rejectUnauthorized: false`.
- **Conflicts**: Use `status` to see what's changed, then `push --force` or `pull --force` to resolve.

## Coding
If you write code for chatium - read first coding.md
database - heap.md
database queries - heap-filter.md
authentication - auth.md
routing - routing.md
file storage - storage.md

## Testing deployed endpoints

The sync script authenticates the **entity API** with `Cookie: apiToken=<token>`. To test or inspect actual **app routes** (`/app/...`, `/`, custom pages) **as the token's user**, you must use a different, account-scoped cookie. Do this:

1. **Get the numeric accountId first.** It is NOT the JWT `id` inside the token, and it is NOT stored in `.chatium/config.json`. Fetch it from the server (do this immediately, before testing any route):
   - From `GET /s/entity/get-tree` → the `filePutUrl` field contains `?accountId=<N>`.
   - Or from any app route requested with `Accept: application/chatium.v1+json` → `data.ctx.account.id`.

2. **Put the token in cookie `at-<accountId>`** (the name is account-specific, e.g. `at-12345`):
   - With it → HTTP 200, the page is served as the token's user (the account Owner).
   - Without it, or with a wrong cookie name → HTTP 302 redirect to `/s/auth/signin`.

3. **Get JSON instead of the HTML wrapper** by sending header `Accept: application/chatium.v1+json`. Response shape: `{success, data:{ctx, blocks, title, type, ...}}` — `data.ctx` holds account/user/session context (`ctx.account.id`, `ctx.user2[0]`, `ctx.authSession`, `ctx.parentEntryModule`), `data.blocks` is the rendered UI block tree. (`Accept: application/json` does NOT work — it still returns HTML.)

Verified one-liner (run from the synced dir; reads creds from `.chatium/config.json`):
```bash
ACCOUNT_KEY=$(jq -r .accountKey .chatium/config.json)
TOKEN=$(jq -r .apiToken .chatium/config.json)
# derive numeric accountId from the entity API
ACCOUNT_ID=$(curl -s -k -H "Cookie: apiToken=$TOKEN" \
  "https://$ACCOUNT_KEY/s/entity/get-tree" \
  | jq -r '.filePutUrl | split("accountId=")[1] | split("&")[0]')
# test an app route as the authed user, as JSON
curl -s -k -H "Cookie: at-$ACCOUNT_ID=$TOKEN" \
  -H "Accept: application/chatium.v1+json" \
  "https://$ACCOUNT_KEY/app/users/me" | jq .data.ctx.user2[0]
```

For browser-based testing in Chrome, additionally set cookie `__chtmPreviewMode__=1` (enables preview mode).

