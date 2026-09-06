# claude-world — LiveReview CI/CD Gate Demo

Proves LiveReview's **CI/CD Gates**: a PR gets its merge automatically
blocked when the AI review finds a critical or security issue, and
automatically allowed when it doesn't.

Gate rule in force: **"Block on Critical or Security"**
```
(.counts.by_severity.critical > 0) or (.counts.by_category.security > 0)
```

## Quickstart

```bash
make block   # opens a PR with a SQL injection -> gate BLOCKS the merge
make allow   # opens a PR with a harmless change -> gate ALLOWS the merge
make reset   # closes both PRs + deletes their branches, ready for another take
```

Each prints the PR URL immediately, then polls (~10–90s, real review time)
and prints `BLOCK` or `ALLOW`. Open the printed URL to show the check and
merge button matching what your terminal said.

## One-time setup

- `gh auth status` shows you logged in with `repo` scope.
- `cicd-demo/.env` (gitignored, never pushed) has `LIVEREVIEW_API_KEY`,
  `LIVEREVIEW_ORG_ID`, `LIVEREVIEW_RULESET_ID` — copy
  `cicd-demo/.env.example` on a new machine and fill these in.
- `jq` is installed.
- LiveReview must be reachable through its tunnel
  (`https://manual-talent2.apps.hexmos.com`) before running `make block`/
  `make allow` — check with:
  ```bash
  curl -s -o /dev/null -w '%{http_code}\n' https://manual-talent2.apps.hexmos.com/api/v1/ci-rulesets
  ```
  `401` = reachable (fine, you just didn't send auth). Anything else = the
  server/tunnel is down; get it back up first. It has been observed to drop
  intermittently, so re-check this whenever a run times out.

## How it works

Opening a PR runs `.github/workflows/livereview-gate.yml`, which calls
LiveReview directly (no inbound GitHub webhook) to trigger a review of the
PR, polls until it finishes, evaluates the ruleset above, and exits 0
(allow) or 1 (block). Branch protection on `master` requires this check, so
a failing gate genuinely disables the merge button — enforced even for
admins.

## Demo script for a live audience

```bash
make block
# switch to the browser: red X, disabled merge button. Explain the SQL injection.
make allow
# switch to the browser: green check, enabled merge button. Merge it if you like.
make reset
```

Want the reveal to happen live in GitHub's Actions tab instead of your
terminal? Run the underlying scripts without `--wait`:
`cicd-demo/make_blocked_pr.sh` / `cicd-demo/make_allowed_pr.sh`.

## Troubleshooting

- **Both `make block` and `make allow` print ALLOW**: the review itself
  probably failed (bad LLM key) rather than completing — a failed review
  has zero findings, which reads as an incorrect ALLOW. Fix LiveReview's AI
  provider key and re-run.
- **Ends in `TIMEOUT`**: LiveReview/the tunnel wasn't reachable. Check
  reachability (above), get it back up, `make reset`, then retry.
- **Push rejected for "secrets"**: GitHub's push protection blocks anything
  shaped like a real provider key — this demo never plants a fake key that
  looks real; the SQL injection alone is the finding.
- **Stale local state**: `make reset` does `git reset --hard
  origin/master` — commit/push anything you care about first.

## What's here

- `Makefile` — `block` / `allow` / `reset`, thin wrappers over `cicd-demo/`.
- `cicd-demo/.env` (gitignored) / `.env.example` — credentials + ruleset id.
- `cicd-demo/config.sh` / `lib.sh` — shared helpers: `.env` autoload, the
  API calls, and the same poll logic the GitHub Actions workflow runs.
- `cicd-demo/make_blocked_pr.sh` / `make_allowed_pr.sh` — open one demo PR
  each (`--wait` to also poll locally).
- `cicd-demo/reset_demo.sh` — cleans up demo PRs/branches.
