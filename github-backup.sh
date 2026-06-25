#!/usr/bin/env bash
set -uo pipefail

DATA_ROOT="/data"
TRASH_ROOT="${DATA_ROOT}/_trash"
ACCOUNTS_FILE="/root/github-backup/accounts.env"

source "$ACCOUNTS_FILE"

log() {
  printf '%s  %s\n' "$(date '+%Y-%m-%dT%H:%M:%S%z')" "$*"
}

# Stream a field from a paginated GitHub API endpoint.
# $1 token, $2 base url (must already contain a query string, e.g. "...?type=owner"),
# $3 jq field selector (default ".[].name"; orgs expose their slug as ".login").
# Returns non-zero if any request fails (so callers can skip pruning on errors).
gh_paginate() {
  local token="$1" base="$2" field="${3:-.[].name}" page=1 body names
  while :; do
    body=$(curl -fsS \
      -H "Authorization: Bearer ${token}" \
      -H "Accept: application/vnd.github+json" \
      -H "X-GitHub-Api-Version: 2022-11-28" \
      "${base}&per_page=100&page=${page}") || return 1
    names=$(printf '%s' "$body" | jq -r "$field")
    [ -z "$names" ] && break
    printf '%s\n' "$names"
    page=$((page + 1))
  done
}

list_member_orgs() {
  local token="$1"
  gh_paginate "$token" "https://api.github.com/user/orgs?dummy=1" '.[].login'
}

list_user_repos() {
  local token="$1"
  gh_paginate "$token" "https://api.github.com/user/repos?type=owner"
}

list_org_repos() {
  local token="$1" org="$2"
  gh_paginate "$token" "https://api.github.com/orgs/${org}/repos?type=all"
}

# Move local repo dirs that no longer exist remotely into the trash dir.
# $1 dir holding the cloned repos, $2 trash target dir, $3.. authoritative remote names.
reconcile_trash() {
  local repo_dir="$1" trash_dir="$2"
  shift 2
  [ -d "$repo_dir" ] || return 0

  local -A keep=()
  local n
  for n in "$@"; do
    keep["$(printf '%s' "$n" | tr '[:upper:]' '[:lower:]')"]=1
  done

  local ts path base key
  ts="$(date -u '+%Y%m%dT%H%M%SZ')"
  while IFS= read -r path; do
    base="$(basename "$path")"
    key="$(printf '%s' "$base" | tr '[:upper:]' '[:lower:]')"
    key="${key%.git}"   # backup mode may name mirrors "<repo>.git"; ".github" is unaffected
    if [ -z "${keep[$key]:-}" ]; then
      mkdir -p "$trash_dir"
      log "trash: ${path} -> ${trash_dir}/${base}__${ts}"
      mv "$path" "${trash_dir}/${base}__${ts}"
    fi
  done < <(find "$repo_dir" -mindepth 1 -maxdepth 1 -type d)
}

# Fetch the authoritative remote name list, then reconcile. Skips on fetch
# failure or an empty result so a bad token / network blip never trashes everything.
prune_to_trash() {
  local label="$1" repo_dir="$2" trash_dir="$3" names
  shift 3
  if ! names="$("$@")"; then
    log "trash skipped (${label}): repo list fetch failed"
    return
  fi
  if [ -z "$names" ]; then
    log "trash skipped (${label}): remote list empty (safety)"
    return
  fi
  local arr=()
  mapfile -t arr <<< "$names"
  reconcile_trash "$repo_dir" "$trash_dir" "${arr[@]}"
}

mirror_user_repos() {
  local account="$1" token="$2"
  log "user repos: ${account}"
  mkdir -p "${DATA_ROOT}/${account}"
  GHORG_GITHUB_TOKEN="$token" ghorg clone "$account" \
    --clone-type=user \
    --github-user-option=owner \
    --backup \
    --path="${DATA_ROOT}/${account}" \
    --output-dir=repos \
    || log "ghorg non-zero for user ${account} (continuing)"

  prune_to_trash "user ${account}" \
    "${DATA_ROOT}/${account}/repos" \
    "${TRASH_ROOT}/${account}/repos" \
    list_user_repos "$token"
}

mirror_org_repos() {
  local account="$1" org="$2" token="$3"
  log "org repos: ${account}/${org}"
  mkdir -p "${DATA_ROOT}/${account}/orgs"
  GHORG_GITHUB_TOKEN="$token" ghorg clone "$org" \
    --clone-type=org \
    --backup \
    --path="${DATA_ROOT}/${account}/orgs" \
    --output-dir="$org" \
    || log "ghorg non-zero for org ${org} (continuing)"

  prune_to_trash "org ${account}/${org}" \
    "${DATA_ROOT}/${account}/orgs/${org}" \
    "${TRASH_ROOT}/${account}/orgs/${org}" \
    list_org_repos "$token" "$org"
}

main() {
  local entry account token org
  for entry in "${ACCOUNTS[@]}"; do
    account="${entry%%:*}"
    token="${entry#*:}"

    mirror_user_repos "$account" "$token"

    while IFS= read -r org; do
      [ -n "$org" ] && mirror_org_repos "$account" "$org" "$token"
    done < <(list_member_orgs "$token")
  done
}

main "$@"
