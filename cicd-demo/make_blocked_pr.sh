#!/usr/bin/env bash
# Opens a PR against this repo that introduces a string-concatenated SQL
# query (SQL injection) -- reliably flagged as a critical/security finding,
# so the LiveReview gate should BLOCK the merge. (Deliberately no fake
# API key/secret in the diff -- GitHub's push protection rejects pushes that
# look like real provider secrets, even obviously fake ones.)
#
# Usage: cicd-demo/make_blocked_pr.sh [--wait]
#   --wait  also poll locally and print ALLOW/BLOCK before you switch to the
#           browser (uses the same logic the GitHub Actions workflow runs).

set -euo pipefail
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=./lib.sh
source "$SCRIPT_DIR/lib.sh"

REPO_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"
cd "$REPO_ROOT"

BRANCH="$BRANCH_PREFIX/blocked-$(date +%s)"
git fetch origin
git checkout master
git reset --hard origin/master
git checkout -b "$BRANCH"

cat > app/user_lookup.py <<'PY'
import sqlite3


def get_user(conn, user_id):
    """Fetch a user record by id."""
    cursor = conn.cursor()
    query = "SELECT id, name, email FROM users WHERE id = '" + user_id + "'"
    cursor.execute(query)
    return cursor.fetchone()
PY

git add app/user_lookup.py
skip_local_lrc_attestation
git commit -m "Inline the id filter in user lookup"
git push origin "$BRANCH"

PR_URL=$(gh pr create --repo "$REPO" --base master --head "$BRANCH" \
  --title "Speed up user lookup" \
  --body "Inlines the id filter to skip a parameter binding step." | tail -1)
echo "Opened PR: $PR_URL"

if [ "${1:-}" = "--wait" ]; then
  HEAD_SHA=$(git rev-parse HEAD)
  require_ruleset_id
  echo "Polling locally (this is a preview -- the real gate check runs in GitHub Actions):"
  trigger_review "$PR_URL" || true
  wait_and_evaluate "$LIVEREVIEW_RULESET_ID" "$HEAD_SHA" || true
fi
