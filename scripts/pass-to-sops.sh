#!/usr/bin/env bash
set -euo pipefail

log() {
  printf '%s\n' "$*" >&2
}

debug_flag="${DEBUG_PASS_TO_SOPS:-}"

debug() {
  if [[ -n "$debug_flag" ]]; then
    log "$@"
  fi
}

for cmd in pass sops jq; do
  if ! command -v "$cmd" >/dev/null 2>&1; then
    log "$cmd not found"
    exit 1
  fi
done

sops_file="${SOPS_FILE:-secrets/secrets.yaml}"

if [[ -n "${SOPS_FILE:-}" ]]; then
  if [[ ! -f "$sops_file" ]]; then
    log "sops file $sops_file not found"
    exit 1
  fi
else
  if [[ ! -f "$sops_file" ]]; then
    log "default sops file $sops_file not found; set SOPS_FILE or create it"
    exit 1
  fi
fi

password_store="${PASSWORD_STORE_DIR:-$HOME/.password-store}"

if [[ -n "${PASSWORD_STORE_DIR:-}" ]]; then
  if [[ ! -d "$password_store" ]]; then
    log "password store $password_store not found"
    exit 1
  fi
else
  if [[ ! -d "$password_store" ]]; then
    log "default password store $password_store not found; set PASSWORD_STORE_DIR or create it"
    exit 1
  fi
fi

debug "using sops file: $sops_file"
debug "using password store: $password_store"

updated=0

while IFS= read -r -d '' file; do
  entry="${file#$password_store/}"
  entry="${entry%.gpg}"
  IFS='/' read -r -a parts <<< "$entry"
  path=""
  for part in "${parts[@]}"; do
    encoded="$(printf '%s' "$part" | jq -Rr @json)"
    path+="[${encoded}]"
  done
  value_json="$(pass show "$entry" | jq -Rs .)"
  debug "updating $path from pass entry $entry"
  sops set "$sops_file" "$path" "$value_json"
  updated=$((updated + 1))
done < <(find -L "$password_store" -type f -name '*.gpg' -print0 | sort -z)

if (( updated == 0 )); then
  log "no pass entries found under $password_store"
else
  log "updated $updated entr$( [[ $updated -eq 1 ]] && printf 'y' || printf 'ies')"
fi
