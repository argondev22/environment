# pc

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

## macOS のシステム設定

`defaults` や `hidutil` で書ける設定は `bin/` のスクリプトが適用する。反映のため Dock と SystemUIServer を再起動する。

| 設定 | スクリプト |
|---|---|
| スクリーンショットの保存先（クリップボード）、スペース2回のピリオド無効化、ダークモード、F1〜F12 を標準のファンクションキーにする、右下のホットコーナー（クイックメモ）無効化、Dock、メニューバー、アプリ本体のログイン項目 | `bin/macos.sh` |
| CapsLock を Control にする（ログイン時に再適用する LaunchAgent の plist は `homedir` が配置し、スクリプトは即時反映と登録を行う） | `bin/macos.sh` |

### メニューバーと自動起動

設定は `bin/macos.sh` にまとめる。playbook の最後に実行されるほか、ログイン済みの端末で `bash pc/bin/macos.sh` を実行できる（リポジトリルートから）。`--check` を付けると、設定を書き換えずに defaults と CapsLock の実行予定を表示し、ログイン項目を照合する。Dock・SystemUIServer も再起動しない。

アプリ単位の「Allow in the Menu Bar」は `allowed_apps`、標準項目の表示と保存位置は `write_defaults` の呼び出しで管理する。共有設定の `trackedApplications` は既存の項目と対応関係を残して許可値だけ更新する。標準項目のうち、保存キーを特定できていない項目は含まない。OS・アプリの更新後は表示を確認する。保存位置は固定の順番を保証しない。反映されない場合はログアウト・ログインする。`Item-1` などは個別の項目を指し、アプリ全体の非表示を意味しない。

ログイン項目の一覧は `managedApps` に置き、`true` で登録、`false` で解除する。登録済みのパスは追加せず、未導入のアプリはスキップする。管理対象外の項目や、アプリ独自の起動用ヘルパー・アップデーター・バックグラウンド実行の許可は変更しない。アプリ側で自動起動を再登録する場合は、アプリ側の設定も確認する。

System Events の操作許可が未設定の場合、初回に macOS の確認が出ることがある。playbook で許可待ちになる場合は、同じ実行元の端末で先に確認モードを実行して許可する。GUI セッションのない環境では実行しない。

## 手動で行う初期設定

スクリプトにできない GUI の設定。`make apply` のあとに行う。

- [ ] 1Password を起動してサインインする。
- [ ] 1Password の設定の「開発者」で SSH エージェントを有効にする。`homedir` の `dot_ssh/config` がこのエージェントのソケットを指しているため、無効のままだと apply 後の GitHub への SSH（pull・push・サブモジュールの更新）が失敗する。[SSH エージェントの設定](https://developer.1password.com/docs/ssh/get-started/)
- [ ] Dock に並べるアプリを好みの順に配置する。位置・サイズ・最近使った項目の表示は `bin/macos.sh` が設定するが、並べるアプリと順番はスクリプトにしていない。
- [ ] システム設定 → ディスプレイ → Night Shift で、スケジュールを「カスタム」の 4:00〜3:59 にし、「明日までオンにする」を有効にする。色温度はスライダーを中央より少し暖かい側に置く。
- [ ] システム設定 → 外観で、Liquid Glass を「Clear」、アイコンとウィジェットのスタイルを「Dark」（「Always」）にする。ほかは既定のまま（カラーはマルチカラー、サイドバーのアイコンサイズは「大」）。
- [ ] システム設定 → キーボード → 音声入力で、ショートカットを「🌐キーを2回押す」にする。Fn（🌐）キー単押しの動作は `bin/macos.sh` が「何もしない」にしている。

修飾キーの割り当てを GUI で確認したいときは [Mac で修飾キーの動作を変更する](https://support.apple.com/ja-jp/guide/mac-help/mchlp1011/mac) を参照する。CapsLock は `bin/macos.sh` に任せているため、GUI で重ねて設定しない。

実行と事後確認は `bootstrap` スキルが案内する。ツール・設定の追加とサブモジュールの扱いは `organize` スキルを参照。
