---
name: organize
description: PC 環境（Environment・homedir・agent-plugins の3リポジトリ）の整備をする。ツールの追加、プラグイン・マーケットプレイスの追加/削除、スキルの追加（自作・他人のもの）、エージェントの追加、ドットファイルの追加などを、変更先のリポジトリを判断したうえで作法どおりに行う。「プラグインを追加したい」「スキルを追加したい」「ツールを入れたい」「環境を整備したい」などで起動。
---

# organize — PC 環境の整備

ユーザーの依頼を「どのリポジトリのどこを変えるか」に振り分け、作法どおりに変更する。毎回状況を説明してもらわなくてよいようにするのが目的。

## 1. 3リポジトリの役割と編集する場所

| リポジトリ | 役割 | 編集する場所 |
|---|---|---|
| Environment（argondev22/environment） | PC 構築の入口。Ansible playbook（`pc/`）で Homebrew / asdf / chezmoi / zsh / age を入れ、chezmoi で homedir を展開する。外部スキルの導入（`pc/bin/manual/skills.sh`）も持つ | このリポジトリ（`~/Environment`） |
| homedir（argondev22/homedir） | chezmoi のソース。`~` 配下のドットファイル・エージェント設定の正 | `~/Environment/homedir`（サブモジュール = chezmoi のソース。`chezmoi source-path` で確認できる） |
| agent-plugins（argondev22/agent-plugins） | 自作の汎用スキル・プラグイン（どの環境でも使えるもの） | `~/Environment/agent-plugins`（サブモジュール） |

**`homedir/` と `agent-plugins/` は Environment のサブモジュールだが、その中で直接作業する**（編集・commit・push もサブモジュールの中で行う）。実 clone（`~/Source/…`）は使わない。サブモジュールの git 操作は `scripts/sync-submodules.sh` が面倒を見る（第6節）。

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

規約はここに複製しない。`~/Environment/agent-plugins` の `README.md` と `AGENTS.md` を読み、その指示に従う（バージョンの更新箇所、CI の有無など）。

## 5. 作業の流れ（サブモジュールを変更するとき）

1. 作業前: `scripts/sync-submodules.sh` を実行する。サブモジュールを main に載せて最新化する。止まったら第6節に従う。
2. 対象サブモジュールの `README.md` / `AGENTS.md` を読んでから、サブモジュールの中（`~/Environment/homedir` など）で作業する。
3. サブモジュールの中で、main のままコミットする（ブランチは切らない）。Conventional Commits・日本語。
4. push する。オペレーターに確認してから行う。homedir は Claude の設定や指示ファイルを含むため自動承認されないことがある。その場合は、オペレーターに自分の端末で `cd ~/Environment/homedir && git push` を実行してもらう。
5. 作業後: もう一度 `scripts/sync-submodules.sh` を実行する。Environment にサブモジュールのポインタ更新がコミットされる（提案不要・自動で行う）。
6. Environment の push をオペレーターに確認する。

Environment 自体の変更も、main のままコミット・push する（push はオペレーターに確認）。

## 6. サブモジュールの扱い（AI が全部やる）

オペレーターはサブモジュールの操作を知らなくてよい前提で、AI が `scripts/sync-submodules.sh`（作業の前後で同じコマンド）で面倒を見る。`--dry-run`（`-n`）なら何が起きるかだけ見られる。

- 未初期化なら init し、main に載せて（detached でも、HEAD が origin/main に含まれていれば main に切り替える）、origin に追いつかせる。すべて origin と一致したサブモジュールについて、ポインタが変わっていれば Environment にコミットする（push はしない。Environment の他の変更は巻き込まない）。
- Environment を clone した直後の初期化にも使える。
- 「サブモジュールを更新して」「最新にして」と頼まれたときもこのスクリプトを使う。
- 次の場合、そのサブモジュールは何も変えずに報告され、スクリプトは終了コード 1 で終わる（他のサブモジュールの処理は続く）。**勝手に捨てない。** 内容を平易にオペレーターに説明し、どうするか確認する。
  - 作業中（未コミットの変更）: コミットするか、退避・破棄するかを確認する。
  - 未 push のコミット: スクリプトが出す一覧を見せ、push してよいか確認する（homedir は上記のとおりオペレーターの端末での push が必要なことがある）。
  - 履歴の分岐（手元と origin の両方に別のコミット）: 手元のコミットを見せ、取り込み方（rebase・merge など）を確認する。
  - origin/main に含まれないコミット（どのブランチにも無い）: 中止される。コミットの内容を見せ、どのブランチに残すか（または破棄してよいか）を確認する。
- 報告は git 用語を避けて平易にする。何がどのコミットに上がったか、どんな変更が入ったか（スクリプトの出力にある一行ログから要約する）。

## 7. 移行手順（個人 PC で一度だけ）

「chezmoi のソースを切り替えたい」と言われたら実行する。chezmoi のソースを旧 `~/.local/share/chezmoi` から `~/Environment/homedir`（サブモジュール）に切り替える。実際の `~` 配下や設定ファイルを変えるので、各ステップはオペレーターに確認しながら進める。

1. `~/Environment` を `git pull` し、`scripts/sync-submodules.sh` を実行する（homedir が main に載り、最新になる）。
2. `~/.config/chezmoi/chezmoi.toml` に `sourceDir`（`~/Environment/homedir` の絶対パス）が入っているか確認する。無ければ、playbook を再実行するか、`sourceDir = "<絶対パス>"` の行を先頭（テーブルより前）に足す。どちらにするかはオペレーターに確認する。
3. `chezmoi source-path` が `~/Environment/homedir` を指すことを確認する。
4. `chezmoi diff` が空（または想定内の差分）であることを、オペレーターと一緒に確認する。
5. 旧 `~/.local/share/chezmoi` に未 push の変更（未コミットの変更・push していないコミット）が無いことを確認する（`git -C ~/.local/share/chezmoi status` と `git -C ~/.local/share/chezmoi log --oneline @{u}..`）。無ければ、削除をオペレーターに提案する（勝手に消さない）。
6. 不要になった `~/Source/homedir`・`~/Source/agent-plugins` の clone も、同様に未コミット・未 push が無いことを確認してから、削除をオペレーターに提案する。
