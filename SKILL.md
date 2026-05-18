---
name: chatium-sync
description: Synchronize the current working directory with a Chatium account. Supports pull, push, sync, status, upload single files, delete, and rename operations.
user_invocable: true
command: chatium-sync
arguments: "[command] [options] - commands: init, pull, push, sync, status, upload <file>, delete <file>, rename <old> <new>"
---

# Chatium Sync Skill

Synchronize a local folder with a Chatium account using the Chatium entity API.

## Overview

This skill wraps `chatium-sync.sh` (located alongside this SKILL.md) to sync files between the local filesystem and a Chatium account. It mirrors the behavior of the official VSCode chatium-sync extension.

## Setup

The sync script is at: `${SKILL_DIR}/chatium-sync.sh`

### First-time setup

If `.chatium/config.json` does not exist in the current working directory, run initialization:

```bash
${SKILL_DIR}/chatium-sync.sh init <accountKey> <apiToken>
```

- `accountKey` is the Chatium account domain (e.g., `myapp.chatium.com` or `some-org.chatium.com/subpath`)
- `apiToken` can be obtained by visiting `https://<accountKey>/s/login/extension/token` in a browser

If the user hasn't provided credentials, tell them to:
1. Visit `https://<their-account>/s/login/extension/token` in a browser
2. Copy the token shown on the page
3. Provide both the account address and token

### Configuration

Config is stored in `.chatium/config.json`:
```json
{
  "accountKey": "myapp.chatium.com",
  "apiToken": "..."
}
```

Tree state (file checksums, sync metadata) is stored in `.chatium/tree.json`.

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

- **"sync my project with chatium"** → Run `sync` (or `pull` then `push`)
- **"download my chatium project"** → Run `pull`
- **"upload my changes"** → Run `push`
- **"upload this file"** → Run `upload <path>`
- **"check what's changed"** → Run `status`
- **"connect to chatium"** → Run `init`
- **"save file X to chatium"** → Run `upload <path>` after confirming the file exists
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

For testing - you must set cookie __chtmPreviewMode__=1 to chrome