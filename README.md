# claude-world — LiveReview CI/CD Gate Demo

This repo demonstrates LiveReview's **CI/CD Gates**: a GitHub PR gets its
merge automatically blocked when LiveReview's AI review finds a critical or
security issue, and automatically allowed when it doesn't — no human has to
look at the check to decide.

The gate rule in force here: **"Block on Critical or Security"**
```
(.counts.by_severity.critical > 0) or (.counts.by_category.security > 0)
```

Everything needed to run the demo — scripts, credentials, this guide — lives
in `cicd-demo/`. This README is the step-by-step walkthrough.

## How it actually works

1. Opening (or updating) a PR triggers `.github/workflows/livereview-gate.yml`.
2. That workflow calls LiveReview's API (through a public tunnel at
   `https://manual-talent2.apps.hexmos.com`) to trigger a review of the PR
   directly — no inbound webhook from GitHub is involved.
3. It polls until the review finishes, then evaluates the
   "Block on Critical or Security" ruleset against the review's findings.
4. It exits 0 (allow) or 1 (block). Branch protection on `master` requires
   this check to pass, so a failing gate genuinely disables the merge
   button (enforced even for repo admins).

## Prerequisites (one-time, per machine)

1. **`gh` CLI authenticated** against this repo:
   ```bash
   gh auth status
   ```
   If not logged in: `gh auth login`.
2. **Credentials file**: copy `cicd-demo/.env.example` to `cicd-demo/.env`
   and fill in:
   - `LIVEREVIEW_API_KEY` — an owner-role LiveReview API key
     (LiveReview → Settings → API Keys)
   - `LIVEREVIEW_ORG_ID` — that org's id
   - `LIVEREVIEW_RULESET_ID` — the id of the "Block on Critical or Security"
     ruleset (LiveReview → CI/CD Gates page)

   `cicd-demo/.env` is gitignored — it never gets committed or pushed, even
   though this repo is public. Every script below sources it automatically,
   so once it's filled in you never type credentials again.
3. **LiveReview itself must be reachable** through the tunnel above. If
   you're running LiveReview locally, make sure the server and the tunnel
   are both up before running any command below:
   ```bash
   curl -s -o /dev/null -w '%{http_code}\n' https://manual-talent2.apps.hexmos.com/api/v1/ci-rulesets
   ```
   A `401` means it's reachable (you just didn't send auth) — that's fine.
   Anything else (connection refused, timeout, 5xx) means the server/tunnel
   is down; get it back up before continuing — the tunnel has been observed
   to drop intermittently, so re-check this any time a demo run times out.
4. **`jq` installed** (`apt install jq` / `brew install jq`) — the scripts
   use it to parse API responses.

## Demonstrating the BLOCKED case, step by step

1. From the repo root, run:
   ```bash
   cicd-demo/make_blocked_pr.sh --wait
   ```
2. What this does, in order:
   - Creates a fresh branch off `master` named `demo/blocked-<timestamp>`.
   - Rewrites `app/user_lookup.py` to build a SQL query by string
     concatenation instead of parameter binding — a textbook SQL injection.
   - Commits and pushes that branch.
   - Opens a PR via `gh pr create` and **prints the PR URL immediately** —
     copy this now if you want to have the browser tab ready.
   - Because of `--wait`, it also triggers a LiveReview review of that PR
     directly (the same call the GitHub Actions workflow makes) and polls
     every 10 seconds, printing progress like:
     ```
     [1/30] review 12345 still running, retrying in 10s...
     ```
   - This takes roughly 10–90 seconds in practice (LLM review time).
3. When it finishes, it prints one of:
   - `BLOCK (review 12345): {"block":true,"counts":{"by_severity":{"critical":1,...`
     — this is the expected, correct outcome.
   - `ALLOW (review ...): ...critical":0...` — if this happens, something's
     off (see Troubleshooting below); don't proceed to the browser yet.
   - `TIMEOUT: no allow/block result for <sha> after 300s` — the tunnel or
     server wasn't reachable; see Troubleshooting.
4. Open the PR URL printed in step 1 in a browser. You should see:
   - A red ✗ next to the `livereview-gate` check.
   - The merge button disabled/grayed out, with GitHub explicitly stating a
     required check hasn't passed.
5. **Narration tip**: while step 2's poll is running, this is the moment to
   explain to your audience what the SQL injection is and why it's
   dangerous — the wait is real review time, not a demo artifact, so use it.
6. Optionally, click into the failed "Details" link on the check to show
   the actual GitHub Actions log — it prints the same BLOCK JSON you saw
   locally, confirming the browser and your terminal agree.

## Demonstrating the ALLOWED case, step by step

1. From the repo root, run:
   ```bash
   cicd-demo/make_allowed_pr.sh --wait
   ```
2. What this does, in order (mirrors the blocked case exactly, different
   payload):
   - Creates a fresh branch `demo/allowed-<timestamp>` off `master`.
   - Rewrites `app/user_lookup.py` to add a harmless `logging.debug(...)`
     line, keeping the safe parameterized query untouched.
   - Commits, pushes, opens the PR, prints the PR URL.
   - Triggers the review and polls the same way.
3. Expected result: `ALLOW (review ...): {"block":false,"counts":{"by_severity":{"critical":0,...`
4. Open the PR URL. You should see:
   - A green ✓ next to `livereview-gate`.
   - The merge button enabled — you can actually click "Merge pull request"
     here for full effect if you want to show a real merge going through.

## Resetting between takes

Run this after each demo (or between audiences/recordings) so the repo is
always clean for the next run:
```bash
cicd-demo/reset_demo.sh
```
This closes every open PR whose branch starts with `demo/` and deletes
those branches both locally and on `origin`. It's safe to run even if
nothing is open — it just does nothing in that case.

**Warning**: this script does `git reset --hard origin/master` on your
current checkout. Commit and push any local changes you care about (like
edits to this README) *before* running any `cicd-demo/*.sh` script, or
they'll be silently discarded if they weren't pushed yet.

## Full script order for a live demo

```bash
cicd-demo/make_blocked_pr.sh --wait   # show the block
# ...switch to browser, show red X + disabled merge button...
cicd-demo/make_allowed_pr.sh --wait   # show the allow
# ...switch to browser, show green check + enabled merge button, merge it...
cicd-demo/reset_demo.sh               # clean up for next time
```

If you'd rather not have the terminal print ALLOW/BLOCK ahead of the
browser (e.g. you want the reveal to happen live in the GitHub UI), drop
`--wait` — the script still creates the branch, pushes, and opens the PR;
you just watch the Actions tab in the browser instead of your terminal.

## Troubleshooting

- **Both cases report ALLOW, even the "blocked" one**: the review itself
  likely failed (LLM call error) rather than completing — a failed review
  has zero findings, which reads as an incorrect ALLOW. Check whether
  LiveReview's configured AI provider key is valid; fix it and re-run.
- **`no review found yet for <sha>` forever, ends in TIMEOUT**: LiveReview
  (or the tunnel to it) isn't reachable. Re-run the reachability curl check
  from Prerequisites, get the server/tunnel back up, run
  `cicd-demo/reset_demo.sh` to clean up the timed-out PR, then re-run the
  make_*_pr script.
- **`gh` errors about auth/permissions**: `gh auth status` should show you
  logged in with `repo` scope for this account.
- **Push rejected for "secrets"**: GitHub's push protection blocks pushes
  that look like real provider API keys — this demo intentionally never
  hardcodes a fake key shaped like a real one (e.g. `sk_live_...`); the
  SQL injection alone is enough to demonstrate a blocked critical/security
  finding.
- **Stale/conflicting local branches**: `cicd-demo/reset_demo.sh` cleans up
  `demo/*` branches; if you have unrelated local changes, `git status`
  before running anything that resets to `origin/master`.

## What's in `cicd-demo/`

- `.env` (gitignored) / `.env.example` — credentials + ruleset id.
- `config.sh` — shared constants, the `lr_curl` helper, auto-detects this
  repo's `owner/repo` from `git remote`, auto-loads `.env`.
- `lib.sh` — `wait_and_evaluate` / `trigger_review` (same polling logic as
  the GitHub Actions workflow) and `skip_local_lrc_attestation` (bypasses a
  local `lrc` pre-commit hook some machines have, for these synthetic
  commits only — irrelevant to the real gate, which runs later via Actions).
- `make_blocked_pr.sh` / `make_allowed_pr.sh` — open one demo PR each.
- `reset_demo.sh` — cleans up demo PRs/branches for a re-take.
