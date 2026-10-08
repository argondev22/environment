# homedir のレシピ

## 前提

- 編集先は `~/Environment/homedir`（Environment のサブモジュール = chezmoi のソース。`chezmoi source-path` で確認できる）。この中で直接編集・commit・push する。作業の前後に `scripts/sync-submodules.sh` を実行する（SKILL.md 第5・6節）。
- 作業前に `~/Environment/homedir` の `README.md` と `AGENTS.md`（あれば）を読む。

- `~/.agents/` がエージェント共通の正。`~/.agents/AGENTS.md`（グローバル指示）と `~/.agents/skills/`（スキル）。
- 各エージェントはそれを参照する。Claude は `dot_claude/CLAUDE.md` の `@~/.agents/AGENTS.md`、Codex は `dot_codex/symlink_AGENTS.md.tmpl`。
- 汎用スキルは homedir ではなく agent-plugins（マーケットプレイス名 `my-plugins`）に置く。homedir に置くのは個人 PC 依存のものだけ。
- 他人のスキル（SKILL.md だけのリポジトリ）は取り込まない。Environment の `pc/bin/manual/skills.sh`（npx skills）の担当。
- 秘密情報（トークン等）は書かない。ホームのパスは `{{ .chezmoi.homeDir }}` か `~` で表す。
- `dot_codex/config.toml` は通常ファイルとして全体を管理する（modify テンプレートではない）。
- ソース直下の `.` 始まり（`.chezmoi*` 以外）は展開されない。人向けファイル（README.md 等）は `.chezmoiignore` に入れる。
- README は短く保つ。

## レシピ

### プラグインを有効化する（マーケットプレイス登録済み）

Claude と Codex の両方を揃える（Codex 非対応のマーケットプレイスは Claude のみ）。

- `dot_claude/settings.json` の `enabledPlugins` に `"<plugin>@<marketplace>": true`
- `dot_codex/config.toml` に `[plugins."<plugin>@<marketplace>"]` と `enabled = true`

### 外部マーケットプレイスを追加する

- Claude: `dot_claude/settings.json` の `extraKnownMarketplaces` に `<name>: { source: { source: "github", repo: "<owner>/<repo>" }, autoUpdate: true }`
- Codex: `dot_codex/config.toml` に `[marketplaces.<name>]`、`source_type = "git"`、`source = "https://github.com/<owner>/<repo>.git"`
- Codex は新しい PC で初回に `codex plugin marketplace upgrade` が必要（オペレーターに案内する）。

### プラグインを無効化・削除する

有効化・登録の記述を Claude と Codex の両方から消す。

### 個人スキルを追加する

1. `dot_agents/skills/<name>/SKILL.md`。frontmatter は `name` と `description` のみ。特定エージェント固有の項目やツール名に依存しない。
2. 処理が決定的ならスクリプトにする：`dot_agents/skills/<name>/scripts/executable_<name>.sh`、SKILL.md から呼ぶ。
3. Claude から読めるよう `dot_claude/skills/symlink_<name>.tmpl`（中身は `{{ .chezmoi.homeDir }}/.agents/skills/<name>`、末尾改行なし）。`~/.claude/skills` 自体は丸ごとリンクにしない。

### 個人スキルを削除する

`dot_agents/skills/<name>/` と `dot_claude/skills/symlink_<name>.tmpl` を削除する。展開済み PC の `~` 側の残骸は手動削除をオペレーターに案内する。

### 新しいエージェントに対応する

3リポジトリ横断の作業なので `references/new-agent.md` に従う（homedir の分は同ファイルの 1）。

### ツールを追加する

- 日常的にグローバルで使うツール（CLI・アプリ）: `dot_Brewfile` に `brew "<formula>"` / `cask "<cask>"` を足す。
- プロジェクトごとにバージョンを変えたい開発ツール: グローバル既定は `dot_config/mise/config.toml` の `[tools]` に足す（ツール名は mise の registry で確認する）。プロジェクト固有のバージョンはそのリポジトリの `mise.toml` に書く（homedir ではない）。
- ソース（`dot_Brewfile`・`dot_config/mise/config.toml`）が唯一の真実。`brew install`・`mise use -g` や `~` 側の直接編集はしない。
- 実機への反映はオペレーターの端末で `chezmoi apply` のあと `brew bundle --file=~/.Brewfile` / `mise install`。Brewfile から消したものを実機からも消すなら `brew bundle cleanup --file=~/.Brewfile`（確認後 `--force`）。
- 他のマシンへは、Environment で `git pull` → `scripts/sync-submodules.sh` → `chezmoi apply`（→ 上記の反映）。

### ドットファイルを追加する

- `~/.foo` は `dot_foo`。実行ファイルは `executable_`、権限を絞るなら `private_`、リンクは `symlink_`、環境依存は `.tmpl`。
- 秘密を含むものは `encrypted_`（age）。
- 外部リポジトリの clone は `.chezmoiexternal.toml`。

## 確認

- JSON/TOML の妥当性：

  ```sh
  python3 -m json.tool dot_claude/settings.json
  python3 -c 'import tomllib,sys; tomllib.load(open(sys.argv[1],"rb"))' dot_codex/config.toml
  ```

- chezmoi があればスクラッチに展開して確認する：`--source ~/Environment/homedir --destination <scratch>/home --config <scratch>/chezmoi.toml --cache <scratch>/cache --exclude externals,encrypted`。`~` には書き込まない。

## git

`~/Environment/homedir` の中で main のまま作業し、ブランチは切らない。コミットは Conventional Commits・日本語。push はオペレーターが確認のうえ行う（自動承認されないときは、オペレーターが `cd ~/Environment/homedir && git push` を実行する）。push 後は `scripts/sync-submodules.sh` で Environment にポインタをコミットする。
