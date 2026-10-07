# homedir のレシピ

## 前提

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

1. `~/.agents/AGENTS.md` を参照させる（`@` 参照できるならその1行、できなければ `dot_<agent>/symlink_<指示ファイル名>.tmpl`）。
2. スキルの読み場所が `~/.agents/skills/` 以外なら、スキルごとに symlink テンプレートを置く。
3. プラグイン設定があれば既存プラグインを揃える。

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
- chezmoi があればスクラッチに展開して確認する：`--source <homedir> --destination <scratch>/home --config <scratch>/chezmoi.toml --cache <scratch>/cache --exclude externals,encrypted`。`~` には書き込まない。

## git

main で作業しブランチを切らない。コミットは Conventional Commits・日本語。push はオペレーターが行うことがある。
