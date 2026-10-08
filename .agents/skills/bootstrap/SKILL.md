---
name: bootstrap
description: このリポジトリ(Environment)の pc/ にある Ansible playbook（Homebrew / mise / chezmoi / zsh のマシンセットアップ）を、前提チェック → dry-run → 本実行 → 事後確認までまとめて進める。vault パスワードや sudo 認証など対話で答えられない秘密情報はチャット上で扱わず、欠けていれば安全に停止して案内する。「初期セットアップして」「playbook実行して」「マシンをセットアップし直して」「環境を最新状態に揃えて」「bootstrap」などで起動。
disable-model-invocation: true
---

# bootstrap — マシンセットアップ(Ansible playbook)の実行

`pc/playbook.yml` を安全に実行し、新しいマシンの初期構築・既存マシンの宣言状態への揃え直しを行う。
このスキルはこのリポジトリ(Environment)専用のプロジェクトスキル。

**オペレーターが明示的に呼んだときだけ実行する。会話の流れから自動で実行しない。**

実行してよいのは、本文の手順に出てくる読み取り系の確認コマンド（`uname` / `xcode-select -p` / `ansible --version` / `test` / `sudo -n true` / `chezmoi` / `mise` / `dscl` / `brew bundle check` / `find` / `ls` と `verify.sh`）と、`ansible-playbook`（dry-run と本実行）のみ。それ以外のコマンドは実行しない。`pc/.vault_pass` は存在確認のみで、中身を表示・送信・書き込みしない。
仕様の正は常に `pc/README.md` と `pc/playbook.yml` そのもの。この SKILL.md と食い違う場合は実物を優先する。

## このスキルが自動化しないこと(重要)

Ansible の `command`/`shell` タスクも、エージェントのシェル実行も、**実行中のプロセスへ人間のキー入力をリアルタイムでリレーする経路を持たない**。stdin は繋がらず即座に EOF が渡るだけなので、「対話プロンプトが出たら途中で答える」という運用は成立しない。この前提から、以下は明確にスコープ外として扱い、黙って成功したことにしない。

- **`pc/.vault_pass`(ansible-vault のパスワード)**: 値をチャットで受け取ったり、こちらから書き込んだりしない。存在確認のみ行う。
- **sudo (become) パスワード**: `--ask-become-pass` のプロンプトには答えられない。`sudo -n true` で自動実行可否を判定するだけに留める。
- **`pc/bin/manual/` 配下のスクリプト**: 対話確認をあえて残したいスクリプト（例: `skills.sh` の `npx skills add` 確認プロンプト）はここに置かれ、playbook からは実行されない(`pc/playbook.yml` の `Discover custom scripts` タスクは `pc/bin/` 直下のみを非再帰で見る設計)。このスキルはここを自動実行せず、オペレーター自身の端末での手動実行を案内する。

## playbook のタスク順

Homebrew 本体 → コアパッケージ(chezmoi・age・zsh) → zsh の設定 → chezmoi(homedir の用意・age 鍵・`chezmoi.toml`・apply) → `brew bundle`(`~/.Brewfile`。mise 本体もここで入る) → `mise install` → `pc/bin/` のカスタムスクリプト。

## 手順

### 1. 前提チェック

- OS: `uname -s` が `Darwin` であること(playbook 自体も macOS 以外は `fail` する)。
- Xcode Command Line Tools: `xcode-select -p` が通ること。
  - `pc/inventory.ini` は `ansible_python_interpreter=/usr/bin/python3` を指定しており、CLT 未導入の真っさらな Mac では **この python3 の初回起動時に「コマンドラインデベロッパツールをインストールしますか」という GUI ダイアログが出る**。これは ansible が gather_facts で最初に踏む一歩なので、ansible 側のどのタスクよりも前に起きる。GUI ダイアログはこのスキルからは応答できないので、ansible を呼ぶ前にここで検出して止める。
  - 無ければ停止し、オペレーターに **自分の端末で** `xcode-select --install` を実行してダイアログの案内に従いインストールを完了してから、再度このスキルを呼ぶよう案内する。
- Ansible: `ansible --version` が通ること。通らなければ「補足」の `pipx install ansible` を案内して停止。
- vault パスワード: `test -f pc/.vault_pass` で存在確認のみ行う(中身は読まない/表示しない)。
  - 無ければ停止し、オペレーターに **自分の端末で** 以下を実行してから再度このスキルを呼ぶよう案内する:

    ```sh
    echo "your-vault-pass" > pc/.vault_pass
    ```

- homedir サブモジュール: `test -e homedir/.git`。無ければ、Environment を `git clone --recurse-submodules` し直すか、オペレーターの端末で `git submodule update --init homedir` を実行するよう案内する（playbook も init を試みるが GitHub への SSH 認証が要る）。chezmoi のソースは `~/Environment/homedir`。

いずれかが欠けている場合はここで止め、以降のタスクは実行しない。

### 2. sudo 状態チェック

```sh
sudo -n true
```

- **成功**(パスワードレス sudo 設定済み): `--ask-become-pass` を付けずに 4. の本実行までそのまま自動で進めてよい。
- **失敗**: このスキルはここで停止する。オペレーターに次のいずれかを案内する:
  - その場しのぎ: **自分の端末で** `sudo -v` を実行して sudo 認証をキャッシュし(通常 5〜15 分有効)、キャッシュが切れる前にこのスキルを再度呼ぶ。
  - 恒久対応(提案のみ、こちらからは実施しない): 特定コマンドに限定した NOPASSWD sudoers エントリを `visudo` で追加する。セキュリティに関わる変更なので、提案に留めオペレーターの判断に委ねる。

### 3. dry-run で差分確認

```sh
ansible-playbook -i pc/inventory.ini pc/playbook.yml \
  --check --diff --vault-password-file pc/.vault_pass
```

(sudo がキャッシュ済み/パスワードレスでない場合は 2. で既に停止しているはずなので、ここに到達する時点で `--ask-become-pass` は不要)

差分の概要をオペレーターに提示する。

### 4. 本実行

dry-run の内容に問題なければ本実行する:

```sh
ansible-playbook -i pc/inventory.ini pc/playbook.yml \
  --vault-password-file pc/.vault_pass
```

- オペレーターが引数で `apply` を明示した場合、または dry-run の差分をオペレーターが確認済みの場合はここまで自動で進めてよい。
- それ以外(引数省略時。引数は `check` / `apply`、省略時は check → 差分確認の上オペレーターに続行可否を尋ねてから apply)は、3. の差分を見せた上で「このまま apply していいか」を一度確認してから実行する。

### 5. 事後確認

`chezmoi` / `mise` / ログインシェル / Brewfile / age の状態を、表示するだけでなく期待値と突き合わせて OK/NG を判定する。単なる `chezmoi status`/`mise ls --current`/`echo $SHELL` の出力表示では「差分ゼロ=成功」「mise のグローバル既定ツールが入っているか」「シェルが本当に切り替わったか」を自動判定できない(`$SHELL` は現在のプロセスの環境変数で、ログインシェル変更の反映を見るには不向き)ため、これらを判定するスクリプトを用意している:

```sh
bash .agents/skills/bootstrap/scripts/verify.sh
```

このスクリプトが行う判定:

- **chezmoi**: `chezmoi source-path` が Environment の `homedir/`（サブモジュール）を指しているか、`chezmoi status` の出力が空かどうかを判定
- **mise**: `~/.config/mise/config.toml` があれば、`mise ls --missing` が空かどうかで未インストールのツールを判定し、あれば名指しする
- **shell**: `$SHELL` ではなく `dscl . -read /Users/<user> UserShell` で実際のログインシェル設定を確認する
- **Brewfile**: `brew bundle check --file=~/.Brewfile` で差分の有無を判定
- **age**: 秘密鍵から公開鍵を抽出できるかを確認

exit code が非0、または出力末尾の「総合判定: NG」があれば、どの項目がNGだったかをそのままオペレーターに提示する(握りつぶさない)。

### 6. 手動フォローアップの案内(必須)

`pc/bin/manual/` 配下のスクリプトを列挙し(`find pc/bin/manual -name "*.sh"`)、実行結果に関わらず必ず次を明示する(黙って省略しない):

> 以下は対話確認ありで実行したい工程のため自動実行の対象外です。自分の端末で直接実行してください:
>
> - `pc/bin/manual/skills.sh`
> - `pc/bin/manual/1password.sh`
>
> （`find` の実行結果に基づいて列挙する。`pc/bin/manual/` の中身は増減するので、決め打ちにせず毎回動的に確認する）

## 補足（pc/ の Makefile と vault）

- `pc/Makefile`（`pc/` で実行。いずれも `--ask-become-pass` 付きで、このスキルからは使えない。オペレーターの端末用）: `make syntax`（構文チェック）、`make check`（dry-run）、`make apply`（本実行）、`make debug`（`-vvv` の dry-run）、`make clean`（`.vault_pass` を削除）。playbook を修正するときは、いきなり `make apply` せず `make check` で確認する（`check` と `apply` で挙動が変わるタスクもある）。
- vault: `pc/group_vars/all.yml` が Ansible Vault で暗号化されている。復号パスワードは `pc/.vault_pass`（gitignore 済み。平文でコミットしない）。中身の確認・編集はオペレーターの端末で `ansible-vault view|edit group_vars/all.yml`（`pc/` で実行）。
- 初回の Ansible は `pipx install ansible`（`ansible-core` ではなくフル版。playbook が `community.general.homebrew` を使う）。

## 報告フォーマット

```text
=== bootstrap 実行結果 ===
前提チェック   : OK / NG(理由)
sudo           : パスワードレス / キャッシュ利用 / 未認証(停止)
dry-run 差分   : <changed/ok の概要>
本実行         : 実行した / スキップした(理由)
事後確認       : verify.sh 総合判定 OK / NG(NG項目を列挙)
手動フォロー   : pc/bin/manual/ 配下は自分の端末で実行してください(一覧)
```

停止した場合は、上記のうち到達した項目まで埋めた上で、次にオペレーターが取るべきアクションを明記して終える。
