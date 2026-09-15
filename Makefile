.PHONY: test test-unit test-integration lint security coverage verify
test: test-unit test-integration
test-unit:
	@tests/run unit
test-integration:
	@tests/run integration
lint:
	@shellcheck -x -s sh tmux-awesome-sidebar.tmux scripts/action scripts/sidebar-view scripts/discover-worktrees scripts/doctor scripts/lib/*.sh tests/*.sh tests/unit/*.sh tests/integration/*.sh
security:
	@! rg -n 'eval|capture-pane|show-environment|kill-server' tmux-awesome-sidebar.tmux scripts
coverage:
	@tests/run coverage
	@command -v kcov >/dev/null 2>&1 || echo 'coverage unavailable: kcov not installed'
verify: lint test security
