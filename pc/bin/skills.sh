#!/usr/bin/env bash
set -e

# Ansible の作業ディレクトリに依存せず、ホームの mise 設定を使う。
cd "$HOME"

install_args=(-g -y -a opencode -a claude-code -a codex)

install_skill() {
  local repository="$1"
  local skill="$2"
  local shared="$HOME/.agents/skills/$skill"
  local claude="$HOME/.claude/skills/$skill"

  if [[ -f "$shared/SKILL.md" && -L "$claude" && "$claude/SKILL.md" -ef "$shared/SKILL.md" ]]; then
    return
  fi

  mise exec -- npx skills add "$repository" --skill "$skill" "${install_args[@]}"
}

install_skill vercel-labs/skills find-skills
install_skill mattpocock/skills grilling
install_skill nanaism/yomiyasu yomiyasu
