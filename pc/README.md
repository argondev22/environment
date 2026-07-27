# Ansible による統一ユーザー空間の自動構築

## 目次

- [主なコンポーネント](#主なコンポーネント)
- [動作確認済みの Ansible バージョン](#動作確認済みの-ansible-バージョン)
- [対応プラットフォーム](#対応プラットフォーム)
- [運用ルール](#運用ルール)
- [注意事項](#注意事項)
- [トラブルシューティング](#トラブルシューティング)
- [よく用いるコマンド集](#よく用いるコマンド集)
- [初回セットアップ](#初回セットアップ)

## 主なコンポーネント

- **[Ansible](https://www.ansible.com/)**: 構成管理（初期構築・全体リコンサイル）
- **[Homebrew](https://brew.sh/)**: パッケージ管理
- **[asdf](https://asdf-vm.com/)**: 各ツールおよびバージョンを統一管理
- **[chezmoi](https://www.chezmoi.io/)**: dotfile の管理
- **[zsh](https://www.zsh.org/)**: デフォルトシェル
- **[age](https://age-encryption.org/)**: 機密性の高い dotfiles を暗号化して安全に管理

## 動作確認済みの Ansible バージョン

| バージョン | 対応状況 | 備考         |
|-----------|---------|-------------|
| 2.18.x    | ✅      | 推奨バージョン |

## 対応プラットフォーム

| OS              | アーキテクチャ                | ステータス |
|-----------------|---------------------------|----------|
| macOS           | Apple Silicon (M1/M2/M3)  | ✅       |
| macOS           | Intel x64                 | ✅       |

## 運用ルール

### 管理対象

- パッケージ/ツール
- homedir

### 管理方針

#### パッケージ/ツール

1. 原則 asdf で管理
2. asdf で管理できないパッケージ/ツールは homebrew で管理
3. 上記で対応できない場合は、[`bin/`](bin/) にカスタムのインストールスクリプトを作成
   - `bin/` 直下: playbook が自動実行する。**冪等かつ非対話**が前提（確認プロンプトを出すコマンドを置かない）。
   - `bin/manual/`: 対話確認が必要なスクリプトはここに置く。playbook からは実行されず、オペレーターが自分の端末で直接実行する（`bootstrap` スキルが実行タイミングを案内する）。

**概略図**:

```text
(デフォルトのパッケージマネージャー)
└── ansible

brew
├── asdf
|	└── .tool-versions # 1. 原則ここで管理
└── ... # 2. asdf が対応していないパッケージは brew で管理

(カスタムスクリプト) # 3. 上記で対応できない場合は、カスタムスクリプトを作成
```

#### homedir

- chezmoi で全て管理

### playbook（`make apply`）の位置づけ

`playbook.yml` は **新しいマシンの初期構築** と、**実機を宣言状態へ揃え直す全体リコンサイル**（任意）に使う。冪等なのでいつ実行しても安全。

一方、**日々のパッケージ/dotfiles の追加・変更に playbook は不要**。各ツール（chezmoi / asdf / Homebrew）のネイティブコマンドで完結する（下記「運用フロー」）。

### 運用フロー

いずれも共通の型で行う：**① chezmoi ソースを編集して適用 → ②（必要なら）実機へインストール → ③ push → ④ 他マシンへ同期**。dotfiles/asdf/Brewfile は chezmoi のソース（`~/.local/share/chezmoi/`）を「唯一の真実」とし、`~/` 配下は直接編集しない。

#### homedir（chezmoi）

1. 編集して適用する

   ```sh
   chezmoi edit --apply .your-dotfile # ソースの dot_your-dotfile を編集し、~/ まで反映
   ```

   ※ 直接 `~/.your-dotfile` を編集しないこと

2. push する

   ```sh
   chezmoi git add .
   chezmoi git commit -m "コミットメッセージ"
   chezmoi git push origin main
   ```

3. 他のマシンへ同期する

   ```sh
   chezmoi update
   ```

#### asdf

1. `.tool-versions` を編集して適用する

   ```sh
   chezmoi edit --apply .tool-versions # 例: terraform 1.10.3 を追記
   ```

   ※ 直接 `~/.tool-versions` を編集しないこと

2. 実機にインストールする

   ```sh
   asdf plugin add terraform # 新規プラグインのときだけ
   asdf install              # .tool-versions を読んで入れる
   ```

3. push する

   ```sh
   chezmoi git add .
   chezmoi git commit -m "コミットメッセージ"
   chezmoi git push origin main
   ```

4. 他のマシンへ同期する

   ```sh
   chezmoi update
   asdf install # 新規プラグインがあれば asdf plugin add も
   ```

#### Homebrew

1. `.Brewfile` を編集して適用する

   ```sh
   chezmoi edit --apply .Brewfile # 例: brew "ripgrep" を追記
   ```

   ※ `brew install` は使わない（Brewfile を唯一の真実とし、二重管理・ドリフトを避ける）
   ※ 直接 `~/.Brewfile` を編集しないこと

2. 実機にインストールする

   ```sh
   brew bundle --file=~/.Brewfile
   # Brewfile から削除したものを実機からも消す場合（確認後 --force）:
   brew bundle cleanup --file=~/.Brewfile
   ```

3. push する

   ```sh
   chezmoi git add .
   chezmoi git commit -m "コミットメッセージ"
   chezmoi git push origin main
   ```

4. 他のマシンへ同期する

   ```sh
   chezmoi update
   brew bundle --file=~/.Brewfile
   ```

## 注意事項

- ホームディレクトリ配下の dotfiles を直接修正しない。修正する際は必ず `~/.local/share/chezmoi/` 配下を修正し、`chezmoi apply`（または `chezmoi edit --apply`）で反映させる。
- 機密情報を平文のままリモートリポジトリにプッシュしない。chezmoi や ansible の暗号化機能を活用する。
- playbook.yml の追加実装や修正を行う際は、`make check` でテスト・デバッグしながら進める（いきなり `make apply` を行わない）。ただし `make check` と `make apply` で一部挙動が変わるため、`make apply` でないと確認できないタスクも存在する。

## トラブルシューティング

### ansible

- **Register zsh in /etc/shells タスクで実行が停止してしまう**:</br>
    管理者権限昇格に必要なパスワード（`--ask-become-pass`）が正しいかどうか確認する

### chezmoi

- **初期化に失敗する**:</br>
    下記を実行して確認する

    ```sh
    chezmoi doctor  # 設定確認
    ls -la ~/.config/age/age.key  # 鍵の存在・権限確認
    ```

### シェル

- **zsh に切り替わらない**:</br>
    下記を実行して確認後、新しいターミナルを開く、またはログインし直す

    ```sh
    echo $SHELL
    ```

## よく用いるコマンド集

### Ansible

```sh
# すべて ~/Environment/pc/ で実行

# 暗号化した変数ファイルを編集（例: chezmoi_repo_url を変更）
ansible-vault edit group_vars/all.yml

# 暗号化ファイルの中身を閲覧（編集しない）
ansible-vault view group_vars/all.yml

# ファイルを暗号化 / 復号
ansible-vault encrypt group_vars/all.yml
ansible-vault decrypt group_vars/all.yml

# vault パスワードを変更
ansible-vault rekey group_vars/all.yml

# 構文チェック
ansible-playbook --syntax-check -i inventory.ini playbook.yml

# ドライラン（差分表示のみ・実機は変更しない）
ansible-playbook -i inventory.ini playbook.yml --check --diff --ask-vault-pass --ask-become-pass

# 本実行（環境を構築・更新）
ansible-playbook -i inventory.ini playbook.yml --ask-vault-pass --ask-become-pass
```

### asdf

```sh
# プラグインを追加
asdf plugin add terraform

# ツールをインストール（.tool-versions を読む）
asdf install
```

### chezmoi

```sh
# 新しい dotfiles を追加
chezmoi add ~/.tool-versions

# 機密性の高い dotfiles を追加
chezmoi add --encrypt ~/.aws/credentials

# .your-dotfile を編集して変更を適用
chezmoi edit --apply .your-dotfile

# 変更を適用
chezmoi apply

# リモートリポジトリから最新の変更を取得して適用
chezmoi update
```

### Homebrew

```sh
# Brewfile の内容を実機に反映
brew bundle --file=~/.Brewfile

# Brewfile に無いものを実機から削除（確認後 --force）
brew bundle cleanup --file=~/.Brewfile
```

### Git Submodule

```sh
# サブモジュールを初期化・更新
git submodule update --init --recursive

# サブモジュールを最新の状態に更新
git submodule update --remote --merge
```

## 初回セットアップ

### 0. 前提条件

- GitHub に SSH 公開鍵を登録済みで、このリポジトリ（サブモジュール含む）を SSH でクローンできること。
  - ※ この手順を経ることで GitHub の SSH ホスト鍵が `~/.ssh/known_hosts` に登録される。これが無い状態で `chezmoi init`/`chezmoi apply`（`.chezmoiexternal.toml` の Vault/Memory clone を含む）が自動実行されると、初回接続の鍵確認プロンプトに応答できず失敗しうる（playbook 側でも `known_hosts` タスクとして担保しているが、根本はこの手動クローンで解消される）。
- Xcode Command Line Tools がインストール済みであること（`xcode-select -p` で確認）。未導入の場合、`ansible_python_interpreter` が指す `/usr/bin/python3` の初回起動時に GUI のインストールダイアログが出る。これは ansible の gather_facts より前に起きるため、自動化では検知・応答できない。無ければ `xcode-select --install` を先に実行しておく。
- Python インタプリタがインストールされていること（[Ansible のインストール](#1-ansible-のインストール)で必要。上記 Xcode Command Line Tools を導入すれば通常はこれも揃う）。

### 1. Ansible のインストール

```sh
python3 -m pip install --user pipx   # pipx が未導入の場合
python3 -m pipx ensurepath           # pipx / ansible に PATH を通す（新しいシェルで有効化）
pipx install ansible                 # フル版（playbook が使う community.general を含む）
```

※ `ansible-core` ではなく **`ansible`（フル）** を入れる（playbook が `community.general.homebrew` モジュールを使うため）。
※ macOS / Python のバージョンにより挙動が変わりうる（`externally-managed-environment` 等）。初回は実機で通ることを確認すること。

### 2. 環境の準備

```sh
# リポジトリクローン
git clone --recurse-submodules git@github.com:argondev22/environment.git
cd environment/pc
```

### 3. `.vault_pass`ファイルの配置

```sh
echo "your-vault-pass" > .vault_pass
```

※ `.vault_pass`は`./group_vars/all.yml`の Ansible Vault を復号するためのパスワード

### 4. セットアップ実行

```sh
# 事前確認（推奨）
ansible-playbook -i inventory.ini playbook.yml --check --diff --vault-password-file .vault_pass

# 本実行
## sudoパスワードなし環境
ansible-playbook -i inventory.ini playbook.yml --vault-password-file .vault_pass
## sudoパスワードあり環境（実行時にパスワードを入力）
ansible-playbook -i inventory.ini playbook.yml --vault-password-file .vault_pass --ask-become-pass
```

### 5. セットアップ後の確認

```sh
# 環境の読み込み
source ~/.zprofile

# 各ツールの確認
chezmoi status          # homedir状態
asdf current            # インストール済みパッケージ/ツール
echo $SHELL             # デフォルトシェル
age-keygen -y ~/.config/age/age.key  # age公開鍵
```
