# pc — Ansible による PC 環境の構築

新しいマシンの初期構築と、実機を宣言状態へ揃え直す全体リコンサイルに使う（冪等）。日々のツール・dotfiles の追加・変更に playbook は不要で、`organize` スキルの手順（chezmoi 経由）で行う。macOS（Apple Silicon / Intel）専用。Ansible は 2.18.x で確認済み。

## 管理方針

| 区分 | 管理先 |
|---|---|
| コア（zsh・chezmoi・age） | playbook が直接 Homebrew で入れる。Brewfile には書かない |
| 日常的にグローバルで使うツール | Homebrew（homedir の `dot_Brewfile`） |
| プロジェクトごとにバージョンを変えたい開発ツール | mise（グローバル既定は homedir の `dot_config/mise/config.toml`、プロジェクト固有は各リポジトリの `mise.toml`） |
| Homebrew に無いツール（npm・pipx・cargo・GitHub Releases などで配布） | mise のバックエンド（`npm:<pkg>` など。グローバル既定は `dot_config/mise/config.toml`） |
| 上記で入らないもの（インストールスクリプトでしか入らない等） | `bin/`（自動実行）・`bin/manual/`（手動実行） |
| dotfiles・上記の設定ファイル | chezmoi（ソースは `~/Environment/homedir` サブモジュール） |

機密性の高い dotfiles は age で暗号化する。`~` 配下は直接編集せず、ソースを編集して `chezmoi apply` で反映する。

## ディレクトリ構成

| パス | 内容 |
|---|---|
| `playbook.yml` | 本体 |
| `inventory.ini`・`group_vars/all.yml` | 対象ホストと変数（`all.yml` は Ansible Vault で暗号化） |
| `templates/` | 生成するファイルの雛形 |
| `bin/` | 直下の `*.sh` を playbook が自動実行する（冪等・非対話） |
| `bin/manual/` | 対話が必要なスクリプト。オペレータが自分の端末で実行する |
| `Makefile` | `make syntax` / `check` / `apply` / `debug` / `clean` |

## playbook のタスク順

1. Homebrew 本体
2. コアパッケージ（chezmoi・age・zsh）
3. zsh の設定（`/etc/shells` 登録・既定シェル化）
4. chezmoi（homedir の用意、age 鍵の配置、`chezmoi.toml` の生成、`chezmoi apply`）
5. `brew bundle`（`~/.Brewfile`。mise 本体もここで入る）
6. `mise install`（グローバル既定ツール）
7. `bin/` のカスタムスクリプト

## 初回セットアップ

前提: GitHub に SSH 公開鍵を登録済み、Xcode Command Line Tools 導入済み（無ければ `xcode-select --install`）。

```sh
pipx install ansible   # フル版（ansible-core ではない）
git clone --recurse-submodules git@github.com:argondev22/environment.git ~/Environment
cd ~/Environment/pc
echo "<vault のパスワード>" > .vault_pass   # all.yml の復号用（gitignore 済み）
make check   # dry-run
make apply   # 本実行
```

実行と事後確認は `bootstrap` スキルが案内する。ツール・設定の追加とサブモジュールの扱いは `organize` スキルを参照。
