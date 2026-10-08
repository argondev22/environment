.PHONY: lint fix

# zsh スクリプト（pc/bin/manual/）は shellcheck 非対応なので対象外
SHELL_FILES := $(shell git ls-files '*.sh' ':!:pc/bin/manual')

lint:
	npx -y markdownlint-cli2
	@if command -v shellcheck >/dev/null; then shellcheck $(SHELL_FILES); \
	else echo "shellcheck が無いのでスキップ（brew install shellcheck）"; fi

fix:
	npx -y markdownlint-cli2 --fix
