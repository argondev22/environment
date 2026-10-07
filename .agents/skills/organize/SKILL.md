---
name: organize
description: PC 環境（Environment・homedir・agent-plugins の3リポジトリ）の整備をする。ツールの追加、プラグイン・マーケットプレイスの追加/削除、スキルの追加（自作・他人のもの）、エージェントの追加、ドットファイルの追加などを、変更先のリポジトリを判断したうえで作法どおりに行う。「プラグインを追加したい」「スキルを追加したい」「ツールを入れたい」「環境を整備したい」などで起動。
---

# organize — PC 環境の整備

ユーザーの依頼を「どのリポジトリのどこを変えるか」に振り分け、作法どおりに変更する。毎回状況を説明してもらわなくてよいようにするのが目的。

## 1. 3リポジトリの役割と編集する場所

| リポジトリ | 役割 | 編集する場所 |
|---|---|---|
| Environment（argondev22/environment） | PC 構築の入口。Ansible playbook（`pc/`）で Homebrew / asdf / chezmoi / zsh / age を入れ、chezmoi で homedir を展開する。外部スキルの導入（`pc/bin/manual/skills.sh`）も持つ | このリポジトリ |
| homedir（argondev22/homedir） | chezmoi のソース。`~` 配下のドットファイル・エージェント設定の正 | `chezmoi source-path` が示す実 clone。chezmoi が無い・失敗するならオペレーターに場所を確認する |
| agent-plugins（argondev22/agent-plugins） | 自作の汎用スキル・プラグイン（どの環境でも使えるもの） | `~/Source/agent-plugins` の実 clone。無ければオペレーターに確認する |

**Environment 内のサブモジュール（`homedir/`, `agent-plugins/`）は把握用。直接編集しない。** 変更は必ず上表の実 clone で行う。

実際の `~` 配下（`~/.claude`, `~/.codex`, `~/.agents` など）は chezmoi の展開結果なので、直接書き換えない。

## 2. 振り分け表

| やりたいこと | 変更先 |
|---|---|
| Homebrew で入れるツール | homedir の `dot_Brewfile` |
| asdf で入れるツール | homedir の `dot_tool-versions` |
| 上記どちらでも入らないツール | Environment の `pc/bin/`（冪等・非対話）。対話が必要なら `pc/bin/manual/` |
| 他人のスキル（SKILL.md だけのリポジトリ） | Environment の `pc/bin/manual/skills.sh` に `npx skills add <repo> --skill <name> -g -a claude-code -a codex` を追記。**実行はオペレーター自身の端末で** |
| 他人のプラグイン（マーケットプレイスとして配布） | homedir で登録・有効化（`references/homedir.md`） |
| 自作スキル・プラグインで、どの環境でも使える | agent-plugins |
| 自作スキルで、個人 PC に依存する | homedir の `dot_agents/skills/` |
| ドットファイル | homedir |
| 新しいエージェントに対応 | homedir（グローバル指示・スキル・プラグイン設定）＋ Environment の `skills.sh` の `-a` ＋ agent-plugins のマニフェスト |

迷ったとき（汎用か個人 PC 依存か、など）は推測せずオペレーターに確認する。

## 3. homedir の作業

具体的な手順は `references/homedir.md` を読む。

## 4. agent-plugins の作業

規約はここに複製しない。実 clone の `README.md` と `AGENTS.md` を読み、その指示に従う（バージョンの更新箇所、CI の有無など）。

## 5. 仕上げ

1. 変更したリポジトリごとに、main のままコミットする（ブランチは切らない）。Conventional Commits・日本語。
2. push はオペレーターに確認してから行う。homedir は Claude の設定や指示ファイルを含むため自動承認されないことがある。その場合はオペレーターが自分の端末で push する。
3. push 後、Environment のサブモジュールが指すコミットを最新に上げるかをオペレーターに提案する。承認されたら次を実行してコミットする（履歴に `chore: bump homedir submodule to latest` がある）。未初期化なら先に `git submodule update --init <name>`。
   ```sh
   git submodule update --remote <name>
   ```
