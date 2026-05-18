#!/usr/bin/env bash
set -euo pipefail

# Chatium Sync - CLI tool for syncing local folder with Chatium account
# Ported from the VSCode chatium-sync extension

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
CONFIG_DIR=".chatium"
CONFIG_FILE="$CONFIG_DIR/config.json"
TREE_FILE="$CONFIG_DIR/tree.json"

# System paths to exclude from sync (matching VSCode extension)
SYSTEM_PATHS=(".chatium" ".vscode" ".git" "tsconfig.json" ".gitignore" "node_modules" "package.json" ".DS_Store" ".claude")

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

log_info()  { echo -e "${BLUE}[INFO]${NC} $*"; }
log_ok()    { echo -e "${GREEN}[OK]${NC} $*"; }
log_warn()  { echo -e "${YELLOW}[WARN]${NC} $*"; }
log_error() { echo -e "${RED}[ERROR]${NC} $*" >&2; }

# Check dependencies
check_deps() {
  for cmd in curl jq shasum; do
    if ! command -v "$cmd" &>/dev/null; then
      log_error "Required command '$cmd' not found"
      exit 1
    fi
  done
}

# Get config value
get_config() {
  local key="$1"
  if [[ -f "$CONFIG_FILE" ]]; then
    jq -r ".$key // empty" "$CONFIG_FILE" 2>/dev/null
  fi
}

# Save config
save_config() {
  local account_key="$1"
  local api_token="$2"
  mkdir -p "$CONFIG_DIR"
  jq -n --arg ak "$account_key" --arg at "$api_token" \
    '{accountKey: $ak, apiToken: $at}' > "$CONFIG_FILE"
  log_ok "Config saved to $CONFIG_FILE"
}

# Check if path is a system path that should be excluded
is_system_path() {
  local path="$1"
  for prefix in "${SYSTEM_PATHS[@]}"; do
    if [[ "$path" == "$prefix" || "$path" == "$prefix"/* ]]; then
      return 0
    fi
  done
  if [[ "$path" == *".DS_Store" ]]; then
    return 0
  fi
  return 1
}

# Compute SHA1 checksum of file content (read as utf-8 text)
file_checksum() {
  local filepath="$1"
  shasum -a 1 "$filepath" | awk '{print $1}'
}

# Make API request to Chatium
api_request() {
  local method="$1"
  local path="$2"
  local account_key api_token
  account_key="$(get_config accountKey)"
  api_token="$(get_config apiToken)"

  if [[ -z "$account_key" || -z "$api_token" ]]; then
    log_error "Not configured. Run: chatium-sync.sh init"
    exit 1
  fi

  local url="https://${account_key}/${path#/}"
  shift 2

  curl -s -k \
    -X "$method" \
    -H "Cookie: apiToken=${api_token}" \
    -H "Content-Type: application/json" \
    "$@" \
    "$url"
}

# Initialize / configure account
cmd_init() {
  local account_key="${1:-}"
  local api_token="${2:-}"

  if [[ -z "$account_key" ]]; then
    echo -n "Enter Chatium account address (e.g. myapp.chatium.com): "
    read -r account_key
  fi
  if [[ -z "$api_token" ]]; then
    echo ""
    echo "To get your API token, visit:"
    echo "  https://${account_key}/s/login/extension/token"
    echo ""
    echo -n "Enter API token: "
    read -r api_token
  fi

  if [[ -z "$account_key" || -z "$api_token" ]]; then
    log_error "Account key and API token are required"
    exit 1
  fi

  save_config "$account_key" "$api_token"

  # Test connection
  log_info "Testing connection..."
  local response
  response="$(api_request GET /s/entity/get-tree)"
  local success
  success="$(echo "$response" | jq -r '.success // false')"

  if [[ "$success" == "true" ]]; then
    local item_count
    item_count="$(echo "$response" | jq '.items | length')"
    log_ok "Connected! Found $item_count files on server."
  else
    log_error "Connection failed. Check your account key and token."
    echo "$response" | jq . 2>/dev/null || echo "$response"
    exit 1
  fi
}

# Load tree state from local cache
load_tree() {
  if [[ -f "$TREE_FILE" ]]; then
    cat "$TREE_FILE"
  else
    echo '{}'
  fi
}

# Save tree state (accepts data via stdin or as $1 argument)
save_tree() {
  mkdir -p "$CONFIG_DIR"
  if [[ $# -gt 0 ]]; then
    printf '%s' "$1" | jq . > "$TREE_FILE"
  else
    jq . > "$TREE_FILE"
  fi
}

# Get the remote file tree
get_remote_tree() {
  api_request GET /s/entity/get-tree
}

# Download a single file by entity ID
download_file() {
  local entity_id="$1"
  local target_path="$2"

  local response
  response="$(api_request GET "/s/entity/get-code/${entity_id}")"
  local source
  source="$(echo "$response" | jq -r '.source // empty')"

  if [[ -n "$source" ]]; then
    local dir
    dir="$(dirname "$target_path")"
    mkdir -p "$dir"
    # Use printf to handle special characters properly
    printf '%s' "$source" > "$target_path"
    return 0
  else
    return 1
  fi
}

# Upload a single file
upload_file() {
  local file_path="$1"
  local remote_path="$2"
  local checksum="${3:-}"
  local overwrite="${4:-false}"

  local content
  content="$(cat "$file_path")"

  local json_payload
  json_payload="$(jq -n \
    --arg path "$remote_path" \
    --arg source "$content" \
    --arg checksum "$checksum" \
    --argjson overwrite "$overwrite" \
    '{path: $path, source: $source, checksum: $checksum, overwrite: $overwrite}')"

  local response
  response="$(api_request POST /s/entity/update-code -d "$json_payload")"
  echo "$response"
}

# Pull: download files from server
cmd_pull() {
  local force="${1:-}"
  log_info "Fetching file tree from server..."

  local response
  response="$(get_remote_tree)"
  local success
  success="$(echo "$response" | jq -r '.success // false')"

  if [[ "$success" != "true" ]]; then
    log_error "Failed to fetch file tree"
    echo "$response" | jq . 2>/dev/null || echo "$response"
    exit 1
  fi

  local tree_state
  tree_state="$(load_tree)"
  local items_json
  items_json="$(echo "$response" | jq -r '.items')"
  local file_put_url
  file_put_url="$(echo "$response" | jq -r '.filePutUrl // empty')"

  local total
  total="$(echo "$items_json" | jq 'length')"
  log_info "Server has $total items"

  local downloaded=0
  local skipped=0
  local up_to_date=0

  # Process each item
  echo "$items_json" | jq -c '.[]' | while IFS= read -r item; do
    local path id checksum is_dir entity_type
    path="$(echo "$item" | jq -r '.path')"
    id="$(echo "$item" | jq -r '.id')"
    checksum="$(echo "$item" | jq -r '.checksum')"
    is_dir="$(echo "$item" | jq -r '.isDirectory')"

    # Skip system paths
    if is_system_path "$path"; then
      continue
    fi

    if [[ "$is_dir" == "true" ]]; then
      # Create directory if needed
      if [[ ! -d "$path" ]]; then
        mkdir -p "$path"
        log_info "Created directory: $path"
      fi
      continue
    fi

    # Check if we need to download
    local need_download=false
    if [[ ! -f "$path" ]]; then
      need_download=true
    elif [[ "$force" == "--force" ]]; then
      need_download=true
    else
      # Compare checksums
      local local_checksum
      local_checksum="$(file_checksum "$path" 2>/dev/null || echo "")"
      local synced_checksum
      synced_checksum="$(echo "$tree_state" | jq -r ".items[\"$path\"].syncedChecksum // empty" 2>/dev/null)"

      if [[ "$local_checksum" == "$checksum" ]]; then
        # Already up to date
        continue
      elif [[ -n "$synced_checksum" && "$synced_checksum" == "$local_checksum" ]]; then
        # Server changed, local unchanged - safe to download
        need_download=true
      elif [[ -n "$synced_checksum" && "$synced_checksum" == "$checksum" ]]; then
        # Local changed, server unchanged - skip (will be pushed)
        log_warn "Skipping $path (locally modified)"
        continue
      elif [[ -z "$synced_checksum" ]]; then
        # No synced checksum - first sync, download if file doesn't differ
        need_download=true
      else
        # Both changed - conflict
        log_warn "CONFLICT: $path (both local and server changed)"
        continue
      fi
    fi

    if [[ "$need_download" == "true" ]]; then
      if download_file "$id" "$path"; then
        log_ok "Downloaded: $path"
      else
        log_error "Failed to download: $path"
      fi
    fi
  done

  # Update tree state with current server state
  # Build tree data using pipes instead of --argjson to avoid arg length limits on Windows
  local tree_data
  tree_data="$(echo "$items_json" | jq -c \
    --arg filePutUrl "$file_put_url" \
    --argjson savedAt "$(date +%s)000" \
    --argjson lastSyncedAt "$(date +%s)000" \
    '{
      items: (reduce .[] as $item ({};
        . + {($item.path): {
          id: $item.id,
          path: $item.path,
          checksum: $item.checksum,
          isDirectory: $item.isDirectory,
          entityType: $item.entityType,
          syncedChecksum: $item.checksum,
          state: "synced"
        }}
      )),
      filePutUrl: $filePutUrl,
      savedAt: $savedAt,
      lastSyncedAt: $lastSyncedAt
    }')"
  printf '%s' "$tree_data" | save_tree

  log_ok "Pull complete"
}

# Push: upload local files to server
cmd_push() {
  local overwrite="${1:-}"
  local ow_flag="false"
  [[ "$overwrite" == "--force" ]] && ow_flag="true"

  log_info "Scanning local files... (overwrite=$ow_flag)"
  log_info "Working directory: $(pwd)"

  local tree_state
  tree_state="$(load_tree)"
  log_info "Tree state loaded, items count: $(echo "$tree_state" | jq '.items | length // 0' 2>/dev/null || echo 'PARSE_ERROR')"

  local account_key api_token
  account_key="$(get_config accountKey)"
  api_token="$(get_config apiToken)"
  log_info "Account: $account_key, token length: ${#api_token}"

  local pushed=0
  local failed=0
  local skipped=0
  local file_count=0

  log_info "Running find command..."
  local find_output
  find_output="$(find . -not -path './.chatium/*' -not -path './.vscode/*' -not -path './.git/*' -not -path './node_modules/*' -not -path './.claude/*' -print0 | xargs -0 -n1 echo 2>/dev/null || true)"
  log_info "Find found $(echo "$find_output" | grep -c . || echo 0) entries"
  echo "$find_output" | head -20
  echo "..."

  # Walk local directory
  while IFS= read -r -d '' filepath; do
    local rel_path="${filepath#./}"
    ((file_count++)) || true

    # Skip system paths
    if is_system_path "$rel_path"; then
      log_info "  [SKIP:system] $rel_path"
      continue
    fi

    # Skip directories
    if [[ -d "$filepath" ]]; then
      log_info "  [SKIP:dir] $rel_path"
      continue
    fi

    # Check if file is UTF-8 text (skip binary files for now)
    local mime_enc
    mime_enc="$(file -b --mime-encoding "$filepath" 2>&1)"
    log_info "  [MIME] $rel_path -> $mime_enc"
    if ! echo "$mime_enc" | grep -qi 'utf-8\|ascii\|us-ascii'; then
      log_warn "  [SKIP:binary] $rel_path (encoding: $mime_enc)"
      continue
    fi

    # Compare with tree state
    local local_checksum
    local_checksum="$(file_checksum "$filepath")"
    local synced_checksum
    synced_checksum="$(echo "$tree_state" | jq -r ".items[\"$rel_path\"].syncedChecksum // empty" 2>/dev/null)"
    local remote_checksum
    remote_checksum="$(echo "$tree_state" | jq -r ".items[\"$rel_path\"].checksum // empty" 2>/dev/null)"

    log_info "  [CHECKSUM] $rel_path: local=$local_checksum synced=$synced_checksum remote=$remote_checksum"

    # Skip if unchanged since last sync
    if [[ -n "$synced_checksum" && "$local_checksum" == "$synced_checksum" && "$ow_flag" == "false" ]]; then
      log_info "  [SKIP:unchanged] $rel_path (matches synced checksum)"
      ((skipped++)) || true
      continue
    fi

    # Skip if already matches server
    if [[ -n "$remote_checksum" && "$local_checksum" == "$remote_checksum" && "$ow_flag" == "false" ]]; then
      log_info "  [SKIP:matches-server] $rel_path (matches remote checksum)"
      ((skipped++)) || true
      continue
    fi

    log_info "  [UPLOAD] $rel_path (will upload now)"

    # Build the JSON payload
    local content
    content="$(cat "$filepath")"
    log_info "  [UPLOAD] File size: ${#content} bytes, checksum for request: '$synced_checksum'"

    local json_payload
    json_payload="$(jq -n \
      --arg path "$rel_path" \
      --arg source "$content" \
      --arg checksum "$synced_checksum" \
      --argjson overwrite "$ow_flag" \
      '{path: $path, source: $source, checksum: $checksum, overwrite: $overwrite}')"
    log_info "  [UPLOAD] JSON payload length: ${#json_payload}"

    local url="https://${account_key}/s/entity/update-code"
    log_info "  [UPLOAD] POST $url"

    local response http_code
    response="$(curl -s -k -w '\n%{http_code}' \
      -X POST \
      -H "Cookie: apiToken=${api_token}" \
      -H "Content-Type: application/json" \
      -d "$json_payload" \
      "$url")"

    http_code="$(echo "$response" | tail -1)"
    response="$(echo "$response" | sed '$d')"

    log_info "  [UPLOAD] HTTP status: $http_code"
    log_info "  [UPLOAD] Response (first 500 chars): ${response:0:500}"

    local success
    success="$(echo "$response" | jq -r '.success // false' 2>/dev/null || echo 'JSON_PARSE_ERROR')"
    log_info "  [UPLOAD] success=$success"

    if [[ "$success" == "true" ]]; then
      local new_checksum
      new_checksum="$(echo "$response" | jq -r '.entity.checksum // empty')"
      log_info "  [UPLOAD] New checksum: $new_checksum"
      # Update tree state for this file
      tree_state="$(echo "$tree_state" | jq \
        --arg path "$rel_path" \
        --arg checksum "$new_checksum" \
        '.items[$path].checksum = $checksum | .items[$path].syncedChecksum = $checksum | .items[$path].state = "synced"')"

      local build_status
      build_status="$(echo "$response" | jq -r '.buildStatus // empty')"
      if [[ -n "$build_status" && "$build_status" != "Success" && "$build_status" != "null" ]]; then
        log_warn "Uploaded $rel_path (build: $build_status)"
      else
        log_ok "Uploaded: $rel_path"
      fi
      ((pushed++)) || true

      # If server returned transformed source, write it back
      local returned_source
      returned_source="$(echo "$response" | jq -r '.source // empty')"
      if [[ -n "$returned_source" ]]; then
        log_info "  [UPLOAD] Server returned transformed source, writing back"
        printf '%s' "$returned_source" > "$filepath"
      fi
    else
      local another_version
      another_version="$(echo "$response" | jq -r '.anotherVersion // false' 2>/dev/null || echo 'false')"
      if [[ "$another_version" == "true" ]]; then
        log_error "Conflict on $rel_path - server has a different version. Use --force to overwrite."
      else
        local message
        message="$(echo "$response" | jq -r '.message // "Unknown error"' 2>/dev/null || echo 'Unknown error')"
        log_error "Failed to upload $rel_path: $message"
      fi
      ((failed++)) || true
    fi
  done < <(find . -not -path './.chatium/*' -not -path './.vscode/*' -not -path './.git/*' -not -path './node_modules/*' -not -path './.claude/*' -print0)

  log_info "Total entries from find: $file_count, pushed: $pushed, failed: $failed, skipped: $skipped"
  printf '%s' "$tree_state" | save_tree
  log_ok "Push complete. Uploaded: $pushed, Failed: $failed, Skipped: $skipped"
}

# Typings: download TypeScript typings from server
cmd_typings() {
  local account_key api_token
  account_key="$(get_config accountKey)"
  api_token="$(get_config apiToken)"

  if [[ -z "$account_key" || -z "$api_token" ]]; then
    log_error "Not configured. Run: chatium-sync.sh init"
    exit 1
  fi

  log_info "Fetching typings from $account_key..."

  local url="https://${account_key}/s/entity/monaco-get-all-builtin-content"
  log_info "GET $url"

  local response
  response="$(curl -s -k -w '\n%{http_code}' "$url")"
  local http_code
  http_code="$(echo "$response" | tail -1)"
  response="$(echo "$response" | sed '$d')"

  log_info "HTTP status: $http_code"

  if [[ "$http_code" != "200" ]]; then
    log_error "Failed to fetch typings (HTTP $http_code)"
    echo "${response:0:500}"
    return 1
  fi

  # Check if response is valid JSON
  if ! echo "$response" | jq empty 2>/dev/null; then
    log_error "Invalid JSON response"
    echo "${response:0:500}"
    return 1
  fi

  # Clean and recreate node_modules
  log_info "Cleaning node_modules..."
  rm -rf node_modules

  # Write dependency typings
  local dep_count=0
  local deps_keys
  deps_keys="$(echo "$response" | jq -r '.deps // {} | keys[]' 2>/dev/null)"

  while IFS= read -r key; do
    [[ -z "$key" ]] && continue

    local file_path
    if [[ "$key" == *.d.ts ]]; then
      file_path="node_modules/${key}"
    else
      file_path="node_modules/${key}/index.d.ts"
    fi

    local dir
    dir="$(dirname "$file_path")"
    mkdir -p "$dir"

    echo "$response" | jq -r ".deps[\"$key\"].content // empty" > "$file_path"
    ((dep_count++)) || true
    log_info "  Written: $file_path"
  done <<< "$deps_keys"

  log_info "Written $dep_count typing files"

  # Write tsconfig.json if provided
  local tsconfig
  tsconfig="$(echo "$response" | jq -r '.tsconfigJsonContent // empty')"
  if [[ -n "$tsconfig" ]]; then
    echo "$tsconfig" > tsconfig.json
    log_ok "Written tsconfig.json"
  fi

  # Write package.json if provided
  local packagejson
  packagejson="$(echo "$response" | jq -r '.packageJsonContent // empty')"
  if [[ -n "$packagejson" ]]; then
    echo "$packagejson" > package.json
    log_ok "Written package.json"
  fi

  log_ok "Typings sync complete ($dep_count deps)"
}

# Sync: typings + pull + push
cmd_sync() {
  cmd_typings
  cmd_pull "$@"
  cmd_push "$@"
}

# Status: show what's changed
cmd_status() {
  local account_key
  account_key="$(get_config accountKey)"

  if [[ -z "$account_key" ]]; then
    log_error "Not configured. Run: chatium-sync.sh init"
    exit 1
  fi

  log_info "Account: $account_key"

  local tree_state
  tree_state="$(load_tree)"
  local last_synced
  last_synced="$(echo "$tree_state" | jq -r '.lastSyncedAt // empty')"

  if [[ -n "$last_synced" ]]; then
    if [[ "$(uname)" == "Darwin" ]]; then
      local ts=$((last_synced / 1000))
      log_info "Last synced: $(date -r "$ts" '+%Y-%m-%d %H:%M:%S')"
    else
      log_info "Last synced: $(date -d "@$((last_synced / 1000))" '+%Y-%m-%d %H:%M:%S')"
    fi
  else
    log_info "Never synced"
  fi

  # Check for local changes
  local locally_modified=()
  local locally_new=()

  while IFS= read -r -d '' filepath; do
    local rel_path="${filepath#./}"

    if is_system_path "$rel_path"; then
      continue
    fi
    if [[ -d "$filepath" ]]; then
      continue
    fi
    if ! file -b --mime-encoding "$filepath" | grep -qi 'utf-8\|ascii\|us-ascii'; then
      continue
    fi

    local local_checksum
    local_checksum="$(file_checksum "$filepath")"
    local synced_checksum
    synced_checksum="$(echo "$tree_state" | jq -r ".items[\"$rel_path\"].syncedChecksum // empty" 2>/dev/null)"

    if [[ -z "$synced_checksum" ]]; then
      locally_new+=("$rel_path")
    elif [[ "$local_checksum" != "$synced_checksum" ]]; then
      locally_modified+=("$rel_path")
    fi
  done < <(find . -not -path './.chatium/*' -not -path './.vscode/*' -not -path './.git/*' -not -path './node_modules/*' -not -path './.claude/*' -type f -print0)

  if [[ ${#locally_modified[@]} -gt 0 ]]; then
    echo ""
    echo -e "${YELLOW}Modified files:${NC}"
    for f in "${locally_modified[@]}"; do
      echo "  M $f"
    done
  fi

  if [[ ${#locally_new[@]} -gt 0 ]]; then
    echo ""
    echo -e "${GREEN}New local files (not on server):${NC}"
    for f in "${locally_new[@]}"; do
      echo "  + $f"
    done
  fi

  if [[ ${#locally_modified[@]} -eq 0 && ${#locally_new[@]} -eq 0 ]]; then
    log_ok "Everything is up to date"
  fi
}

# Delete a file on the server
cmd_delete() {
  local file_path="$1"
  if [[ -z "$file_path" ]]; then
    log_error "Usage: chatium-sync.sh delete <path>"
    exit 1
  fi

  log_info "Deleting on server: $file_path"
  local response
  response="$(api_request POST /s/entity/delete -d "$(jq -n --arg path "$file_path" '{files: [{path: $path}]}')")"
  local success
  success="$(echo "$response" | jq -r '.success // false')"
  if [[ "$success" == "true" ]]; then
    log_ok "Deleted: $file_path"
  else
    log_error "Failed to delete: $file_path"
    echo "$response" | jq . 2>/dev/null || echo "$response"
  fi
}

# Rename a file on the server
cmd_rename() {
  local old_path="$1"
  local new_path="$2"
  if [[ -z "$old_path" || -z "$new_path" ]]; then
    log_error "Usage: chatium-sync.sh rename <old-path> <new-path>"
    exit 1
  fi

  log_info "Renaming on server: $old_path -> $new_path"
  local response
  response="$(api_request POST /s/entity/rename -d "$(jq -n --arg op "$old_path" --arg np "$new_path" '{files: [{oldPath: $op, newPath: $np}]}')")"
  local success
  success="$(echo "$response" | jq -r '.success // false')"
  if [[ "$success" == "true" ]]; then
    log_ok "Renamed: $old_path -> $new_path"
  else
    log_error "Failed to rename"
    echo "$response" | jq . 2>/dev/null || echo "$response"
  fi
}

# Upload a single specific file
cmd_upload_file() {
  local file_path="$1"
  local overwrite="${2:-false}"
  if [[ -z "$file_path" ]]; then
    log_error "Usage: chatium-sync.sh upload <path> [--force]"
    exit 1
  fi
  [[ "$overwrite" == "--force" ]] && overwrite="true"

  if [[ ! -f "$file_path" ]]; then
    log_error "File not found: $file_path"
    exit 1
  fi

  local tree_state
  tree_state="$(load_tree)"
  local synced_checksum
  synced_checksum="$(echo "$tree_state" | jq -r ".items[\"$file_path\"].syncedChecksum // empty" 2>/dev/null)"

  log_info "Uploading: $file_path"
  local response
  response="$(upload_file "$file_path" "$file_path" "$synced_checksum" "$overwrite")"
  local success
  success="$(echo "$response" | jq -r '.success // false')"

  if [[ "$success" == "true" ]]; then
    local build_status
    build_status="$(echo "$response" | jq -r '.buildStatus // empty')"
    if [[ -n "$build_status" && "$build_status" != "Success" && "$build_status" != "null" ]]; then
      log_warn "Uploaded $file_path (build: $build_status)"
    else
      log_ok "Uploaded: $file_path"
    fi
    echo "$response" | jq '{success, buildStatus, entity: {id: .entity.id, path: .entity.path, checksum: .entity.checksum}}' 2>/dev/null
  else
    log_error "Upload failed"
    echo "$response" | jq . 2>/dev/null || echo "$response"
  fi
}

# Upload a binary/static file to Chatium file service and return its hash and URLs
cmd_upload_static() {
  local file_path="$1"
  if [[ -z "$file_path" ]]; then
    log_error "Usage: chatium-sync.sh upload-static <path>"
    exit 1
  fi

  if [[ ! -f "$file_path" ]]; then
    log_error "File not found: $file_path"
    exit 1
  fi

  # Get filePutUrl from tree.json or fetch it
  local file_put_url
  file_put_url="$(load_tree | jq -r '.filePutUrl // empty' 2>/dev/null)"

  if [[ -z "$file_put_url" ]]; then
    log_info "No filePutUrl cached, fetching from server..."
    local tree_response
    tree_response="$(get_remote_tree)"
    file_put_url="$(echo "$tree_response" | jq -r '.filePutUrl // empty')"
    if [[ -z "$file_put_url" ]]; then
      log_error "Could not get file upload URL from server"
      exit 1
    fi
  fi

  local filename
  filename="$(basename "$file_path")"

  log_info "Uploading static file: $file_path"
  log_info "Upload URL: $file_put_url"

  local response http_code
  response="$(curl -s -k -w '\n%{http_code}' \
    -X POST \
    -F "Filedata=@${file_path}" \
    "$file_put_url")"

  http_code="$(echo "$response" | tail -1)"
  response="$(echo "$response" | sed '$d')"

  log_info "HTTP status: $http_code"

  if [[ "$http_code" != "200" ]]; then
    log_error "Upload failed (HTTP $http_code)"
    echo "$response"
    exit 1
  fi

  local file_hash="$response"
  log_info "File hash: $file_hash"

  # Build URLs
  local full_url="https://fs.chatium.ru/get/${file_hash}"
  local thumb_800="https://fs.chatium.ru/thumbnail/${file_hash}/s/800x"
  local thumb_400="https://fs.chatium.ru/thumbnail/${file_hash}/s/400x"

  echo ""
  log_ok "File uploaded successfully!"
  echo ""
  echo "Hash:          $file_hash"
  echo "Full URL:      $full_url"
  echo "Thumbnail 800: $thumb_800"
  echo "Thumbnail 400: $thumb_400"
  echo ""
  echo "Use in code:"
  echo "  import { getThumbnailUrl } from \"@app/storage\""
  echo "  getThumbnailUrl(\"${file_hash}\", 800, undefined)"
}

# Main
check_deps

case "${1:-help}" in
  init)
    cmd_init "${2:-}" "${3:-}"
    ;;
  pull)
    cmd_pull "${2:-}"
    ;;
  push)
    cmd_push "${2:-}"
    ;;
  sync)
    cmd_sync "${2:-}"
    ;;
  typings)
    cmd_typings
    ;;
  status)
    cmd_status
    ;;
  upload)
    cmd_upload_file "${2:-}" "${3:-}"
    ;;
  upload-static)
    cmd_upload_static "${2:-}"
    ;;
  delete)
    cmd_delete "${2:-}"
    ;;
  rename)
    cmd_rename "${2:-}" "${3:-}"
    ;;
  help|--help|-h)
    echo "Chatium Sync - Synchronize local folder with Chatium account"
    echo ""
    echo "Usage: chatium-sync.sh <command> [options]"
    echo ""
    echo "Commands:"
    echo "  init [account] [token]  Configure Chatium account"
    echo "  pull [--force]          Download files from server"
    echo "  push [--force]          Upload changed files to server"
    echo "  sync [--force]          Typings + pull + push (full sync)"
    echo "  typings                 Download TypeScript typings from server"
    echo "  status                  Show sync status and local changes"
    echo "  upload <path> [--force] Upload a single code file"
    echo "  upload-static <path>    Upload binary/image to file service, get hash & URLs"
    echo "  delete <path>           Delete a file on the server"
    echo "  rename <old> <new>      Rename a file on the server"
    echo "  help                    Show this help"
    ;;
  *)
    log_error "Unknown command: $1"
    echo "Run 'chatium-sync.sh help' for usage"
    exit 1
    ;;
esac
