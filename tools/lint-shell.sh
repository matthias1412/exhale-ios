#!/usr/bin/env bash
#
# Catches, locally and for free, the mistakes that otherwise cost a 10x-billed
# CI run to discover.
#
# macOS ships **bash 3.2** as /bin/bash (GPLv3 licensing), so anything from
# bash 4+ explodes with "command not found" on the runner even though it works
# fine in this repo's dev shell, which is bash 5.
set -uo pipefail

FAIL=0
SCRIPTS=(.github/scripts/*.sh)   # this linter itself is dev-only, never runs on the runner

note() { printf '  %-28s %s\n' "$1" "$2"; }

echo "Checking $(echo "${SCRIPTS[@]}" | wc -w | tr -d ' ') shell scripts"

for f in "${SCRIPTS[@]}"; do
  [ -f "$f" ] || continue
  echo "$f"

  if ! bash -n "$f" 2>/dev/null; then
    note "syntax" "FAILED"; bash -n "$f"; FAIL=1
  fi

  # bash 4+ builtins and syntax that macOS /bin/bash 3.2 does not have.
  while IFS=: read -r line _; do
    [ -n "$line" ] && { note "bash4 mapfile/readarray" "line $line"; FAIL=1; }
  done < <(grep -nE '\b(mapfile|readarray)\b' "$f" | grep -v '^[0-9]*:[[:space:]]*#' | cut -d: -f1)

  while IFS=: read -r line _; do
    [ -n "$line" ] && { note "bash4 negative index" "line $line"; FAIL=1; }
  done < <(grep -nE '\$\{[A-Za-z_][A-Za-z_0-9]*\[-[0-9]' "$f" | cut -d: -f1)

  while IFS=: read -r line _; do
    [ -n "$line" ] && { note "bash4 assoc array" "line $line"; FAIL=1; }
  done < <(grep -nE 'declare -A|local -A' "$f" | cut -d: -f1)

  while IFS=: read -r line _; do
    [ -n "$line" ] && { note "bash4 case conversion" "line $line"; FAIL=1; }
  done < <(grep -nE '\$\{[A-Za-z_][A-Za-z_0-9]*(\[[^]]*\])?(,,|\^\^)' "$f" | cut -d: -f1)

  # GNU-only flags that BSD userland on macOS rejects.
  while IFS=: read -r line _; do
    [ -n "$line" ] && { note "GNU-only 'stat -c'" "line $line"; FAIL=1; }
  done < <(grep -n 'stat -c' "$f" | cut -d: -f1)

  # BSD find wants -maxdepth before the primaries.
  while IFS=: read -r line _; do
    [ -n "$line" ] && { note "find: -maxdepth after -name" "line $line"; FAIL=1; }
  done < <(grep -nE 'find .*-name .*-maxdepth' "$f" | cut -d: -f1)
done

if [ "$FAIL" -eq 0 ]; then
  echo "OK — nothing bash-3.2-incompatible found"
else
  echo "Problems found. macOS /bin/bash is 3.2; keep these scripts compatible."
fi
exit "$FAIL"
