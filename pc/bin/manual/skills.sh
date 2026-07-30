#!/usr/bin/env zsh
# AI エージェント用スキルを npx skills でインストールする
#   参考: https://github.com/vercel-labs/skills
#   前提: node / npm が使えること（.tool-versions の nodejs）
#
# 注意: 意図的に -y を付けず確認プロンプトを出す（対話的に内容を確認したい）。
#       npx の確認プロンプトに答える必要があるため、必ずこのスクリプトを
#       オペレーター自身の端末で直接実行すること。playbook からは実行しない
#       （bin/ ではなく bin/manual/ に置いているのはそのため）。
#
# フラグの意味:
#   --skill <name>  リポジトリ内の特定スキルだけを対象
#   -g              グローバル(~/.agents/skills)にインストール
#   -a claude-code  対象エージェントを claude-code に限定

set -e

# https://www.skills.sh/mattpocock/skills
npx skills add vercel-labs/skills --skill find-skills -g -a claude-code

# https://www.skills.sh/mattpocock/skills/grill-me
npx skills add mattpocock/skills --skill grill-me -g -a claude-code
