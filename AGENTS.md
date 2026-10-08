# AGENTS.md

- このリポジトリの規約は `README.md` と `pc/README.md` に書いてある。作業前に読むこと。
- スキルは `.agents/skills/` にある（`.claude/skills` はそこへのシンボリックリンク）。
  - `organize`: PC 環境（Environment・homedir・agent-plugins）の整備。変更先リポジトリを判断して作法どおりに変更する。
- `homedir/`・`agent-plugins/`（サブモジュール）はこの中で直接作業する。作業の前後に `.agents/skills/organize/scripts/sync-submodules.sh` を実行する（詳細は `organize` スキル）。
