---
name: sync
description: 他の PC で更新した Environment・homedir・agent-plugins をこの PC に取り込んで反映し、あわせてツール・アプリ・プラグインを更新する。pull → サブモジュール同期 → chezmoi の差分確認と apply → 必要な brew bundle / mise install / プラグイン取得 → 事後確認までを、確認を挟みながら進める。「他の PC の変更を取り込んで」「最新にして」「同期して」「ツールを更新して」「アップデートして」「sync」などで起動。新規セットアップは bootstrap、設定の追加・変更は organize を使う。
---

# sync — 取り込みと更新

他の PC での変更をこの PC に揃え、ツール類を更新する。すでに動いている PC の日常運用向けで、sudo を要する playbook は走らせない（それは `bootstrap`）。設定の追加・変更は `organize`。

仕様の正は `README.md` と `pc/README.md`、`organize` スキルの `references/homedir.md`。食い違う場合は実物を優先する。

## 守ること

- Homebrew の操作（`brew bundle` / `brew upgrade` など）と push は、実行前にオペレーターへ確認する。
- `pc/.vault_pass` と age の秘密鍵は、中身を表示・送信しない。存在確認と、公開鍵の導出だけにする。
- `~` 配下は直接書き換えない。ソース（`~/Environment/homedir`）を直して `chezmoi apply` で反映する。
- 差分は省略せず全部見せる（途中で切らない）。
- 勝手に捨てない。未コミットの変更や未 push のコミットがあれば、何も変えずに報告して確認する。

## 1. 取り込み

1. 状況を読み取りで確認する。`git fetch` のあと、Environment が origin より何件遅れているか、手元に未 push のコミットがないかを見る。
   ```sh
   cd ~/Environment && git fetch -q origin && git status -sb
   ```
2. 遅れているだけなら fast-forward で更新する。履歴が分岐していたら中止して報告する。
   ```sh
   git pull --ff-only
   ```
3. サブモジュールを最新にする。先に `--dry-run` で何が起きるかを見る。
   ```sh
   .agents/skills/organize/scripts/sync-submodules.sh --dry-run
   .agents/skills/organize/scripts/sync-submodules.sh
   ```
   報告が出たサブモジュールの扱いは、`organize` スキルの第6節に従う。
4. ポインタが進んで Environment にコミットが作られていたら、push してよいかを確認してから push する。

## 2. 反映（chezmoi）

1. 差分を全部見せる。向きは **`-` が今のファイル、`+` が apply で書かれる内容**。
   ```sh
   chezmoi diff
   ```
2. ファイルごとに「何が変わるか」「反映後に何が起きるか」（プラグインの有効化、Brewfile の追加など）を平易にまとめる。
3. 想定外の差分（この PC のファイルをアプリが書き換えた結果、`-` 側に新しい内容があるなど）があれば、apply の前に止めて確認する。この PC の変更を取り込みたいなら `chezmoi re-add`（これもソースを書き換えるので確認）、捨ててよいなら apply。
4. オペレーターの了解を得てから適用する。
   ```sh
   chezmoi apply --no-tty
   ```
   対話の入力待ちで止まったら、オペレーターに自分の端末で `chezmoi apply` を実行してもらう。
5. `chezmoi diff` が空になったことを確認する。

## 3. 反映後の導入

差分に応じて、必要なものだけ案内・実行する。

| 差分の内容 | すること |
|---|---|
| `.Brewfile` に追加・変更 | `brew bundle check --file=~/.Brewfile` で未導入を確認。導入は `brew bundle --file=~/.Brewfile`（Homebrew 操作なので確認。後述の注意あり） |
| `dot_config/mise/config.toml` の変更 | `mise ls --missing` で未導入を確認し、`mise install` |
| プラグイン・マーケットプレイスの変更 | 第5節 |
| Brewfile から消したもの | 実機からも消すなら `brew bundle cleanup --file=~/.Brewfile`（一覧を見せ、確認後に `--force`） |

## 4. 更新（ツール・アプリ）

1. まず読み取りで何が古いかを見る。
   ```sh
   brew outdated --cask
   brew outdated --formula
   mise outdated
   ```
2. 更新してよいものをオペレーターに確認する。`brew bundle` は Brewfile に書かれたものを更新する。書かれていないものは更新しない。
3. **アプリ（cask）の更新は、実行中のアプリを入れ替える。** cmux のように、今動いているターミナルやエージェントの実体が含まれていることがある。その場合は、オペレーターに、**別のターミナル（更新対象でないもの）で自分で実行してもらう**。実行前に、保存していない作業を閉じるよう伝える。
4. アプリ自身が更新機能を持つもの（Notion など）は、アプリ側で更新してよい。`brew bundle` の出力で `Using <name>` と出たものは、更新されていない。
5. **Xcode**: Homebrew は、Xcode 本体が入っていると、そのバージョンも確認する。古いと `brew bundle` が「too outdated」で止まる。Xcode は Brewfile では管理していない。更新後は、ライセンスの同意が必要になる。
   ```sh
   sudo xcodebuild -license accept
   ```
   sudo のパスワードが要るので、オペレーターの端末で実行してもらう。Command Line Tools は別物なので、`xcode-select -p` と `softwareupdate` の案内も合わせて確認する。
6. 外部スキル（`npx skills` で入れたもの）は、オペレーターの端末で `npx skills update -g`。

## 5. プラグインの取得・更新

設定（`enabledPlugins` など）を変えただけでは、実体は入らない。

- **Claude Code**: `/plugin` で marketplace を更新し、プラグインを入れる。反映にはセッションの再起動が要ることがある。
  - 「added but ignored」と出るときは、登録されているソースと設定のソースが食い違っている。`/plugin` で marketplace を削除してから、設定どおりに追加し直す。
- **Codex**: `codex plugin marketplace upgrade`。非公開リポジトリは、SSH の URL（`git@github.com:<owner>/<repo>.git`）でないと認証が通らない。
- MCP が接続できないときは、そのサーバーが起動に必要なもの（Docker など）が動いているかを確認する。原因は推測で断定せず、確かめてから報告する。

## 6. 事後確認

```sh
bash .agents/skills/bootstrap/scripts/verify.sh
.agents/skills/organize/scripts/sync-submodules.sh --dry-run
```

3 つのリポジトリ（`~/Environment`、`~/Environment/homedir`、`~/Environment/agent-plugins`）が、origin と一致していることも `git status -sb` で確認する。NG があれば、握りつぶさずそのまま見せる。

## 報告フォーマット

```text
=== sync 実行結果 ===
取り込み   : Environment N件 / homedir N件 / agent-plugins N件（なし / 取り込んだ）
chezmoi    : 反映した（ファイル一覧）/ 差分なし / 保留（理由）
導入       : brew bundle / mise install / プラグイン（実行した / 案内した / 不要）
更新       : 更新した一覧 / 見送った一覧
事後確認   : verify.sh 総合判定 OK / NG（項目）、3リポジトリ origin と一致 / 未 push あり
オペレーターに残るもの: （push、sudo が要る作業、再起動、手動実行の一覧）
```
