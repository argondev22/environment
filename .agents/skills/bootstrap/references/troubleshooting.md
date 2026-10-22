# 症状と対処

playbook の実行で詰まったときに、症状から探す。確認済みの事実と、原因が未確認の推測は分けて書く。原因を断定できないときは、断定せず「未確認」と伝える。

## 止まる・進まない

| 症状 | 対処 |
|---|---|
| sudo を要るタスク（`/etc/shells` の登録など）で止まる | 実行している**同じ端末**で `sudo -v` を実行してから、再実行する。別のシェルで認証しても進まなかった。原因は未確認 |
| `Apply homedir` で止まる | `--no-tty` と 300 秒の打ち切りが入っているので、止まらず失敗として理由が出る。理由を貼ってもらう。端末で直接 `chezmoi apply` を実行すれば、対話の内容が見える |
| `make check` では `chezmoi apply` や `brew bundle` が実行されない | `command` のタスクは `--check` では実行されない。これらの確認は、本実行でしかできない |

## 失敗する

| 症状 | 対処 |
|---|---|
| `brew bundle` が「Xcode … is too outdated」で失敗する | Xcode 本体を更新する。更新後に `sudo xcodebuild -license accept`（オペレーターの端末）。Command Line Tools は別物 |
| `You have not agreed to the Xcode license` | `sudo xcodebuild -license accept`（オペレーターの端末） |
| vault の復号に失敗する | パスワードの違いか、失われている。過去のリビジョンでも失敗するなら、失われている。作り直すときは、オペレーターの端末だけで行う（下記） |
| mise で「postinstall script was not run」 | 該当パッケージだけ、mise の設定で `allow_builds` に指定して、`mise install --force` |
| Codex の marketplace で認証に失敗する（非公開リポジトリ） | ソースを SSH の URL にする |
| Claude Code の marketplace が「added but ignored」 | `sync` スキルの「プラグインの取得・更新」に従う |

## vault を作り直すとき

- **オペレーターの端末だけで行う。** パスワードと秘密鍵を、チャットとエージェントの出力に出さない。
- 鍵の中身は、表示・加工（`sed` でのマスクなど）をしない。マスクが失敗すると、そのまま表示される。
- `pc/group_vars/all.yml` に入れるのは、`pc/playbook.yml` が参照する変数だけ。何が要るかは、`playbook.yml` を見て確認する。
- 作り直したら、新しいパスワードをパスワードマネージャに保存する。`pc/.vault_pass` にしか無い状態にしない。
