#!/usr/bin/env bash
# Shared config for the CI/CD Gate demo scripts. Source this, don't run it.
#
# Credentials (never hardcoded/committed here) are read from cicd-demo/.env
# if it exists (gitignored -- see .env.example), otherwise from whatever's
# already exported in your shell:
#   LIVEREVIEW_API_KEY    - an owner-role API key for the org
#   LIVEREVIEW_ORG_ID     - that org's id
#   LIVEREVIEW_RULESET_ID - the "Block on Critical or Security" ruleset's id
#
# make_blocked_pr.sh / make_allowed_pr.sh / reset_demo.sh also need `gh`
# authenticated against this repo.

set -euo pipefail

BASE_URL="https://manual-talent2.apps.hexmos.com"
BRANCH_PREFIX="demo"

SCRIPT_DIR_CONFIG="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "$SCRIPT_DIR_CONFIG/.." && pwd)"
REPO="$(git -C "$REPO_ROOT" remote get-url origin | sed -E 's#\.git$##; s#.*[:/]([^/]+/[^/]+)$#\1#')"

if [ -f "$SCRIPT_DIR_CONFIG/.env" ]; then
  set -a
  # shellcheck source=./.env
  source "$SCRIPT_DIR_CONFIG/.env"
  set +a
fi

: "${LIVEREVIEW_API_KEY:=}"
: "${LIVEREVIEW_ORG_ID:=}"
: "${LIVEREVIEW_RULESET_ID:=}"

require_api_key() {
  if [ -z "$LIVEREVIEW_API_KEY" ] || [ -z "$LIVEREVIEW_ORG_ID" ]; then
    echo "Set LIVEREVIEW_API_KEY and LIVEREVIEW_ORG_ID -- copy cicd-demo/.env.example to cicd-demo/.env and fill them in (see README.md)." >&2
    exit 1
  fi
}

require_ruleset_id() {
  if [ -z "$LIVEREVIEW_RULESET_ID" ]; then
    echo "Set LIVEREVIEW_RULESET_ID in cicd-demo/.env (see README.md)." >&2
    exit 1
  fi
}

lr_curl() {
  # lr_curl <method> <path> [json-body]
  local method="$1" path="$2" body="${3:-}"
  if [ -n "$body" ]; then
    curl -sS -w '\n%{http_code}' -X "$method" \
      -H "X-API-Key: $LIVEREVIEW_API_KEY" -H "X-Org-Context: $LIVEREVIEW_ORG_ID" \
      -H "Content-Type: application/json" -d "$body" \
      "$BASE_URL/api/v1$path"
  else
    curl -sS -w '\n%{http_code}' -X "$method" \
      -H "X-API-Key: $LIVEREVIEW_API_KEY" -H "X-Org-Context: $LIVEREVIEW_ORG_ID" \
      "$BASE_URL/api/v1$path"
  fi
}
