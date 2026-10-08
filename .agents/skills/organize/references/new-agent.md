# 新しいエージェントに対応する

3リポジトリ（Environment・homedir・agent-plugins）を横断して、`<agent>` を既存のエージェントと同じ扱いにする。各手順の詳細は、リンク先のレシピと各リポジトリの README / AGENTS.md に従う。

## 0. 公式ドキュメントで確認する（推測しない）

次を確認する。分からなければオペレーターに聞く。

- グローバル指示ファイルの場所と、`@` インポートができるか
- リポジトリ内の指示ファイルの名前と、`AGENTS.md` を読むか
- ユーザースキル・リポジトリ内スキルの読み場所
- プラグイン（マーケットプレイス）の形式（マニフェスト、marketplace ファイル）と設定ファイルの場所
- `npx skills` の `-a` に渡す名前

## 1. homedir（`references/homedir.md` のレシピ）

- グローバル指示：`~/.agents/AGENTS.md` を参照させる（`@` 参照できればその1行、できなければ `dot_<agent>/symlink_<指示ファイル名>.tmpl`）。
- ユーザースキルの読み場所が `~/.agents/skills/` 以外なら、スキルごとの symlink テンプレート（個人スキルの追加・削除手順にもその置き場所を足す）。
- プラグイン設定：マーケットプレイスの登録と有効化を、既存のエージェントと同じプラグインで揃える。

## 2. 各リポジトリのリポジトリ内指示（Environment・homedir・agent-plugins）

- `<agent>` がリポジトリの `AGENTS.md` を読まないなら、既存の `.claude/CLAUDE.md`（`@../AGENTS.md`）と同じ要領で参照を置く。
- `<agent>` がリポジトリ内スキル（`.agents/skills/`）を読まないなら、既存の `.claude/skills` → `../.agents/skills` と同じ要領でリンクを置く。

## 3. agent-plugins

agent-plugins の README と AGENTS.md の規約に従い、次を揃える。

- 各プラグインに `<agent>` のマニフェスト（version は上げる）
- `<agent>` の marketplace ファイル
- `.github/scripts/validate.py` の `TOOLS` に1エントリ（marketplace のエントリ形式が違えば小さな関数を足す）
- README の対応エージェント表に1行

## 4. Environment

`pc/bin/manual/skills.sh` の各行に `-a <名前>` を追加する。実行はオペレーターの端末で。

## 5. 動作確認

オペレーターと一緒に `<agent>` を実際に起動し、グローバル指示・スキル・プラグインが見えるかを確認する。見えないものがあれば、0 の確認に戻る。
