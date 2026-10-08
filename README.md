# environment

PCの環境のIaCや各種設定ファイルをまとめたリポジトリ。

## ディレクトリ構成

```text
environment/
├── .agents/        # AIエージェント用スキル
├── agent-plugins/  # agent-plugins（サブモジュール。この中で作業する）
├── config/         # 設定ファイル
├── homedir/        # homedir（サブモジュール。chezmoi のソース。この中で作業する）
├── pc/             # Ansible
├── README.md       # 本ファイル
└── ...
```

## サブモジュール

`homedir/` と `agent-plugins/` はサブモジュールで、**この中で直接作業する**（編集・commit・push も `~/Environment/homedir` などの中で行う）。chezmoi のソースは `~/Environment/homedir`。

サブモジュールの操作は `.agents/skills/organize/scripts/sync-submodules.sh` に任せる。作業の前（main に載せて最新化）と後（Environment にポインタをコミット）の両方で同じコマンドを実行する。詳しくは `organize` スキルを参照。

## 初回セットアップ

サブモジュールごと clone してから playbook を実行する。手順は `pc/README.md` を参照。

```sh
git clone --recurse-submodules git@github.com:argondev22/environment.git ~/Environment
```
