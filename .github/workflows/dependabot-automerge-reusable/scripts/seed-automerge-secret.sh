#!/usr/bin/env bash
# Bulk seed AUTOMERGE_PAT secret into all (or matching) user repositories.
# Requirements: GitHub CLI (gh) authenticated (`gh auth login`).
# PAT is prompted securely; never written to disk.

set -euo pipefail

MATCH_PATTERNS=()
REPOS_FILE="../repos.txt"
DRY_RUN=0
QUIET=0
LIST_ONLY=0
GH_USER=""

usage() {
  cat <<'EOF'
Usage: seed-automerge-secret.sh [options]

Options:
  --match <substring>     Substring filter (can repeat). Any match passes.
  --repos-file <path>     File with explicit repo names (one per line). Overrides gh list.
  --dry-run               Show target repos without setting the secret.
  --list                  List target repos only (implies --dry-run, terse output).
  --quiet                 Suppress per-repo output (only summary).
  -h, --help              Show help.

File format for --repos-file:
  Lines: repo-name OR owner/repo (owner ignored, current user enforced)
  Blank lines and lines starting with # are skipped.

Examples:
  ./seed-automerge-secret.sh --match backend --match lib
  ./seed-automerge-secret.sh --repos-file repo-list.txt
  ./seed-automerge-secret.sh --match core --dry-run
  ./seed-automerge-secret.sh --list --match api
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

# Resolve current authenticated user
if ! GH_USER=$(gh api user -q '.login' 2>/dev/null); then
  echo "ERROR: GitHub CLI not authenticated. Run: gh auth login" >&2
  exit 1
fi

# Prompt for PAT (hidden). Accept from env AUTOMERGE_PAT_VALUE if set.
if [[ -z "${AUTOMERGE_PAT_VALUE:-}" ]]; then
  read -r -s -p "Enter AUTOMERGE PAT (repo scope): " AUTOMERGE_PAT_VALUE
  echo
fi

if [[ -z "$AUTOMERGE_PAT_VALUE" ]]; then
  echo "ERROR: No PAT provided." >&2
  exit 1
fi

# Basic sanity check: length and prefix
if [[ ! "$AUTOMERGE_PAT_VALUE" =~ ^gh[pus]_[A-Za-z0-9]{20,}$ ]]; then
  echo "WARNING: Token does not look like a classic PAT (continuing anyway)." >&2
fi

if [[ -n "$REPOS_FILE" ]]; then
  if [[ ! -f "$REPOS_FILE" ]]; then
    echo "ERROR: --repos-file '$REPOS_FILE' not found" >&2
    exit 1
  fi
  mapfile -t REPO_LINES <"$REPOS_FILE"
  REPOS=()
  for line in "${REPO_LINES[@]}"; do
    line="${line%%$'\r'}" # strip CR if present
    [[ -z "$line" || "$line" =~ ^# ]] && continue
    # Allow owner/repo or just repo
    if [[ "$line" == */* ]]; then
      repo_part="${line##*/}"
      REPOS+=("$repo_part")
    else
      REPOS+=("$line")
    fi
  done
  echo "Loaded ${#REPOS[@]} repos from file '$REPOS_FILE'" >&2
else
  echo "Fetching repositories for user: $GH_USER" >&2
  REPOS=$(gh repo list "$GH_USER" --limit 500 --json name --jq '.[].name')
fi
TARGET_COUNT=0
UPDATED=0

for repo in ${REPOS[@]}; do
  # Pattern filtering: pass if no patterns OR any substring matches
  if [[ ${#MATCH_PATTERNS[@]} -gt 0 ]]; then
    pass=0
    for pat in "${MATCH_PATTERNS[@]}"; do
      if [[ "$repo" == *"$pat"* ]]; then
        pass=1; break
      fi
    done
    [[ $pass -eq 0 ]] && continue
  fi
  TARGET_COUNT=$((TARGET_COUNT+1))
  if [[ $DRY_RUN -eq 1 ]]; then
    if [[ $LIST_ONLY -eq 1 ]]; then
      echo "$repo"
    else
      [[ $QUIET -eq 0 ]] && echo "[DRY] Would set secret on $repo"
    fi
    continue
  fi
  if printf '%s' "$AUTOMERGE_PAT_VALUE" | gh secret set AUTOMERGE_PAT --repo "$GH_USER/$repo" --body - >/dev/null 2>&1; then
    UPDATED=$((UPDATED+1))
    [[ $QUIET -eq 0 ]] && echo "[OK] Set AUTOMERGE_PAT on $repo"
  else
    echo "[ERR] Failed on $repo" >&2
  fi
  # Brief sleep to avoid API rate bursts
  sleep 0.2
done

if [[ $DRY_RUN -eq 1 ]]; then
  echo "Dry run complete. Target repos: $TARGET_COUNT"
else
  echo "Completed. Secret applied to $UPDATED / $TARGET_COUNT target repos.";
fi
