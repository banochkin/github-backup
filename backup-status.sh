#!/usr/bin/env bash
# Show the state of all backed-up mirrors: when each was last fetched and the
# latest commit it holds, sorted newest-fetch first. Read-only, safe to run anytime.
#
# Usage: ./backup-status.sh [DATA_ROOT]   (default /data)
set -uo pipefail

DATA_ROOT="${1:-/data}"
TRASH_ROOT="${DATA_ROOT}/_trash"

mtime() { stat -c '%Y' "$1" 2>/dev/null; }

printf 'Backup status @ %s\n' "$(date '+%Y-%m-%d %H:%M:%S %z')"
printf 'Root: %s\n\n' "$DATA_ROOT"

# Collect "<fetch-epoch>\t<repo-dir>" for every bare mirror, excluding trash.
rows=$(
  while IFS= read -r head; do
    repo="${head%/HEAD}"
    [ -d "${repo}/objects" ] || continue          # skip logs/HEAD etc.
    [[ "$repo" == "${TRASH_ROOT}"/* ]] && continue
    if [ -f "${repo}/FETCH_HEAD" ]; then
      ep="$(mtime "${repo}/FETCH_HEAD")"
    else
      ep="$(mtime "$repo")"
    fi
    printf '%s\t%s\n' "${ep:-0}" "$repo"
  done < <(find "$DATA_ROOT" -type f -name HEAD 2>/dev/null)
)

total=$(printf '%s' "$rows" | grep -c .)
printf 'Mirrors: %s\n\n' "$total"

printf '%-19s  %-19s  %s\n' 'LAST FETCH' 'LAST COMMIT' 'REPO'
printf '%-19s  %-19s  %s\n' '-------------------' '-------------------' '----'
printf '%s\n' "$rows" | sort -rn | while IFS="$(printf '\t')" read -r ep repo; do
  [ -z "$repo" ] && continue
  ft="$(date -d "@${ep}" '+%Y-%m-%d %H:%M:%S' 2>/dev/null || echo '?')"
  ci="$(git -C "$repo" for-each-ref --sort=-committerdate --count=1 \
        --format='%(committerdate:format:%Y-%m-%d %H:%M:%S)' refs/heads/ 2>/dev/null)"
  [ -z "$ci" ] && ci='(no commits)'
  printf '%-19s  %-19s  %s\n' "$ft" "$ci" "${repo#${DATA_ROOT}/}"
done

if [ -d "$TRASH_ROOT" ]; then
  tcount=$(find "$TRASH_ROOT" -type f -name HEAD 2>/dev/null | grep -c . || true)
  printf '\nTrashed mirrors: %s (under %s)\n' "${tcount:-0}" "$TRASH_ROOT"
fi

printf '\nTotal size: %s\n' "$(du -sh "$DATA_ROOT" 2>/dev/null | cut -f1)"
