#!/usr/bin/env bash
# Rotate AUTOMERGE_PAT secret across repositories matching optional pattern.
# Requirements: gh authenticated. Provide new PAT at prompt or via env NEW_AUTOMERGE_PAT.

set -euo pipefail

MATCH_PATTERNS=()
REPOS_FILE="../repos.txt"
DRY_RUN=0
QUIET=0
LIST_ONLY=0
GH_USER=""

usage() {
  cat <<'EOF'
Usage: rotate-automerge-secret.sh [options]

Options:
  --match <substring>     Substring filter (repeatable). Any match passes.
  --repos-file <path>     File with explicit repo names (one per line). Overrides gh list.
  --dry-run               Show target repos without rotating.
  --list                  List target repos only (implies --dry-run, terse output).
  --quiet                 Suppress per-repo output.
  -h, --help              Help.

Environment:
  NEW_AUTOMERGE_PAT       Provide new PAT non-interactively.

Repo file format: same as seed script (ignores blank + # lines). Accepts owner/repo or repo.

Examples:
  ./rotate-automerge-secret.sh --match lib --match core
  ./rotate-automerge-secret.sh --repos-file repo-list.txt --dry-run
  NEW_AUTOMERGE_PAT=ghp_XXXX ./rotate-automerge-secret.sh --quiet
EOF
}

while [[ $# -gt 0 ]]; do
  case "$1" in
    --match) MATCH_PATTERNS+=("$2"); shift 2;;
    --repos-file) REPOS_FILE="$2"; shift 2;;
    --dry-run) DRY_RUN=1; shift;;
    --list) LIST_ONLY=1; DRY_RUN=1; QUIET=1; shift;;
    --quiet) QUIET=1; shift;;
    -h|--help) usage; exit 0;;
    *) echo "Unknown arg: $1" >&2; usage; exit 1;;
  esac
done

if ! GH_USER=$(gh api user -q '.login' 2>/dev/null); then
  echo "ERROR: gh not authenticated (gh auth login)." >&2
  exit 1
fi

if [[ -z "${NEW_AUTOMERGE_PAT:-}" ]]; then
  read -r -s -p "Enter NEW AUTOMERGE PAT: " NEW_AUTOMERGE_PAT
  echo
fi

if [[ -z "$NEW_AUTOMERGE_PAT" ]]; then
  echo "ERROR: No new PAT supplied." >&2
  exit 1
fi

if [[ ! "$NEW_AUTOMERGE_PAT" =~ ^gh[pus]_[A-Za-z0-9]{20,}$ ]]; then
  echo "WARNING: Token format unexpected; continuing." >&2
fi

if [[ -n "$REPOS_FILE" ]]; then
  if [[ ! -f "$REPOS_FILE" ]]; then
    echo "ERROR: --repos-file '$REPOS_FILE' not found" >&2
    exit 1
  fi
  mapfile -t REPO_LINES <"$REPOS_FILE"
  REPOS=()
  for line in "${REPO_LINES[@]}"; do
    line="${line%%$'\r'}"
    [[ -z "$line" || "$line" =~ ^# ]] && continue
    if [[ "$line" == */* ]]; then
      REPOS+=("${line##*/}")
    else
      REPOS+=("$line")
    fi
  done
  echo "Loaded ${#REPOS[@]} repos from file '$REPOS_FILE'" >&2
else
  echo "Rotating secret across user repos for: $GH_USER" >&2
  REPOS=$(gh repo list "$GH_USER" --limit 500 --json name --jq '.[].name')
fi
TARGET=0
ROTATED=0

for repo in ${REPOS[@]}; do
  if [[ ${#MATCH_PATTERNS[@]} -gt 0 ]]; then
    pass=0
    for pat in "${MATCH_PATTERNS[@]}"; do
      if [[ "$repo" == *"$pat"* ]]; then
        pass=1; break
      fi
    done
    [[ $pass -eq 0 ]] && continue
  fi
  TARGET=$((TARGET+1))
  if [[ $DRY_RUN -eq 1 ]]; then
    if [[ $LIST_ONLY -eq 1 ]]; then
      echo "$repo"
    else
      [[ $QUIET -eq 0 ]] && echo "[DRY] Would rotate secret on $repo"
    fi
    continue
  fi
  if printf '%s' "$NEW_AUTOMERGE_PAT" | gh secret set AUTOMERGE_PAT --repo "$GH_USER/$repo" --body - >/dev/null 2>&1; then
    ROTATED=$((ROTATED+1))
    [[ $QUIET -eq 0 ]] && echo "[OK] Rotated AUTOMERGE_PAT on $repo"
  else
    echo "[ERR] Failed rotate on $repo" >&2
  fi
  sleep 0.2
done

if [[ $DRY_RUN -eq 1 ]]; then
  echo "Dry run complete. Target repos: $TARGET"
else
  echo "Rotation complete. Rotated $ROTATED / $TARGET repos.";
fi
