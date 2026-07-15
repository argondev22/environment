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

- **[Ansible](https://www.ansible.com/)**: 構成管理
- **[Homebrew](https://brew.sh/)/[Linuxbrew](https://docs.brew.sh/Homebrew-on-Linux)**: パッケージ管理の統一
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
| Ubuntu 20.04+   | x64                       | ✅       |
| WSL2 (Ubuntu)   | x64                       | ✅       |

## 運用ルール

### 管理対象

- パッケージ/ツール
- dotfiles

### 管理方針

#### パッケージ/ツール

- 原則 asdf で管理
- asdf で管理できないパッケージ/ツールは homebrew(Linuxbrew) で管理
- 上記で対応できない場合は、[`bin/`](bin/) にカスタムのインストールスクリプトを作成

**概略図**:

```text
(デフォルトのパッケージマネージャー)
└── ansible

brew
├── asdf
|	└── .tool-versions # 原則ここで管理
└── ... # asdf が対応していないパッケージは brew で管理

(カスタムスクリプト) # 上記で対応できない場合は、カスタムスクリプトを作成
```

#### dotfiles

- chezmoi で全て管理

### 運用フロー

#### dotfiles（chezmoi）

1. `dot_your-dotfiles` を編集する

```sh
chezmoi edit .your-dotfiles # あるいは ~/.local/share/chezmoi 配下の dot_your-dotfiles を編集
```

※ 直接 `~/.your-dotefiles` を編集しないこと

2. ローカルマシンに反映させる

```sh
chezmoi apply
```

3. 変更をリモートリポジトリにプッシュ

```sh
chezmoi git add .
chezmoi git commit -m "コミットメッセージ"
chezmoi git push origin main
```

4. 別のマシンでも反映させる

```sh
chezmoi update
```


#### asdf

1. [`dot_tool-versions`](../dotfiles/dot_tool-versions) を編集する

```sh
chezmoi edit .tool-versions # あるいは ~/.local/share/chezmoi 配下の dot_tool-versions を編集
```

※ 直接 `~/.zshrc` を編集しないこと

2. ローカルマシンに反映させる

```sh
## sudoパスワードなし環境
ansible-playbook -i inventory.ini playbook.yml --vault-password-file .vault_pass
## sudoパスワードあり環境（実行時にパスワードを入力）
ansible-playbook -i inventory.ini playbook.yml --vault-password-file .vault_pass --ask-become-pass
```

3. 変更をリモートリポジトリにプッシュ

```sh
chezmoi git add .
chezmoi git commit -m "コミットメッセージ"
chezmoi git push origin main
```

4. 別のマシンでも反映させる

```sh
chezmoi update

## sudoパスワードなし環境
ansible-playbook -i inventory.ini playbook.yml --vault-password-file .vault_pass
## sudoパスワードあり環境（実行時にパスワードを入力）
ansible-playbook -i inventory.ini playbook.yml --vault-password-file .vault_pass --ask-become-pass
```

#### Homebrew (macOS) / Linuxbrew

1. ローカルマシンにパッケージをインストール

```sh
brew install <package-name>
```

2. [dot_Brewfile](../dotfiles/dot_Brewfile) を編集する

```sh
chezmoi edit .Brewfile # あるいは ~/.local/share/chezmoi 配下の dot_Brewfile を編集
```

※ 直接 `~/.Brewfile` を編集しないこと

3. 変更をリモートリポジトリにプッシュ

```sh
git add .
git commit -m "コミットメッセージ"
git push origin main
```

4. 別のマシンでも反映させる
```sh
git pull origin main

## sudoパスワードなし環境
ansible-playbook -i inventory.ini playbook.yml --vault-password-file .vault_pass
## sudoパスワードあり環境（実行時にパスワードを入力）
ansible-playbook -i inventory.ini playbook.yml --vault-password-file .vault_pass --ask-become-pass
```


## 注意事項

- ホームディレクトリ配下の dotfiles を直接修正しない。dotfiles を修正する際は必ず ~/.local/share/chezmoi/ 配下を修正し、`chezmoi apply` コマンドで反映させる。
- 機密情報を平文のままリモートリポジトリにプッシュしない。chezmoi や ansible の暗号化機能を活用する。
- playbook.yml の追加実装や修正を行う際は、`make check` コマンドでテスト・デバッグを行いながら進める（いきなり `make apply` を行わない）。ただし、`make check` と `make apply` で一部、挙動が変化してしまうため、`make apply` でないと確認できないタスクも存在する。

## トラブルシューティング

### ansible

- **Register zsh in /etc/shells タスクで実行が停止しまう**:</br>
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

## よく用いるコマンド

### asdf

```sh
# .tool-versions を編集
echo "terraform 1.10.3" >> ~/.tool-versions

# プラグインを追加
asdf plugin add terraform

# ツールをインストール
asdf install terraform 1.10.3
```

### chezmoi

```sh
# 新しい dotfiles を追加
chezmoi add ~/.tool-verions

# 機密性の高い dotfiles を追加
chezmoi add --encrypt ~/.aws/credentials

# 変更を適用
chezmoi apply

# リモートリポジトリから最新の変更を取得して適用
chezmoi update
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

- Python インタプリタがインストールされていること（[Ansible のインストール](#1-ansible-のインストール)で必要）。

### 1. Ansible のインストール

```sh
# macOS
brew install ansible

# Ubuntu/Debian/WSL
sudo apt update && sudo apt install -y ansible

# Arch Linux
sudo pacman -S ansible
```

※ Ansible は Python で動作するため、Python のインタプリタがインストールされている必要がある。　

### 2. 環境の準備

```sh
# リポジトリクローン
git clone --recurse-submodules git@github.com:argon/environments.git
cd environments/pc
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
chezmoi status          # dotfiles状態
asdf current           # インストール済みパッケージ/ツール
echo $SHELL            # デフォルトシェル
age-keygen -y ~/.config/age/age.key  # age公開鍵
```

