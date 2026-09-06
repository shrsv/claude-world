.PHONY: help block allow reset

help:
	@echo "make block   - open a PR that should be BLOCKED (SQL injection)"
	@echo "make allow   - open a PR that should be ALLOWED (harmless change)"
	@echo "make reset   - close all demo PRs/branches, ready for another take"

block:
	@cicd-demo/make_blocked_pr.sh --wait

allow:
	@cicd-demo/make_allowed_pr.sh --wait

reset:
	@cicd-demo/reset_demo.sh
