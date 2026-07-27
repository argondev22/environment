#!/usr/bin/env zsh
# 1Password CLI の shell plugin を初期化する。
#
# 注意: `op plugin init` は資格情報の選択とスコープ(セッション限り/
#       ディレクトリ単位/グローバル)を必ず対話で確認させるコマンドで、
#       非対話モードのフラグは存在しない(`op plugin init --help` 参照)。
#       そのためオペレーター自身の端末で直接実行すること。playbook から
#       は実行しない（bin/ ではなく bin/manual/ に置いているのはそのため）。

op plugin init aws
op plugin init claude
op plugin init opencode
