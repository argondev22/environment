#!/usr/bin/env bash
# provision-pc / bootstrap スキルの事後確認。
# README「5. セットアップ後の確認」の各コマンドを、表示するだけでなく
# 期待値と突き合わせて OK/NG を判定する。
set -u

status=0
tmp_file="$(mktemp)"
trap 'rm -f "$tmp_file"' EXIT

echo "--- chezmoi ---"
if ! command -v chezmoi >/dev/null 2>&1; then
  echo "chezmoi: NG (chezmoi コマンドが見つかりません)"
  status=1
else
  expected_source="$(cd "$(dirname "${BASH_SOURCE[0]}")/../../../.." && pwd)/homedir"
  actual_source="$(chezmoi source-path 2>/dev/null || true)"
  if [ "$actual_source" = "$expected_source" ]; then
    echo "chezmoi source: OK ($actual_source)"
  else
    echo "chezmoi source: NG (期待: $expected_source, 実際: ${actual_source:-不明})"
    status=1
  fi
  chezmoi_diff="$(chezmoi status 2>&1)"
  if [ -z "$chezmoi_diff" ]; then
    echo "chezmoi: OK (clean)"
  else
    echo "chezmoi: NG (差分あり)"
    echo "$chezmoi_diff"
    status=1
  fi
fi

echo "--- mise ---"
mise_config="$HOME/.config/mise/config.toml"
if ! command -v mise >/dev/null 2>&1; then
  echo "mise: NG (mise コマンドが見つかりません)"
  status=1
elif [ -f "$mise_config" ]; then
  missing="$(cd "$HOME" && mise ls --missing 2>&1)"
  if [ -z "$missing" ]; then
    echo "mise: OK (グローバル既定のツールはすべてインストール済み)"
  else
    echo "mise: NG (未インストールのツールがあります)"
    echo "$missing"
    status=1
  fi
else
  echo "mise: $mise_config が見つかりません(スキップ)"
fi

echo "--- shell ---"
actual_shell="$(dscl . -read "/Users/$(whoami)" UserShell 2>/dev/null | awk '{print $2}')"
if [ -n "$actual_shell" ] && [[ "$actual_shell" == */zsh ]]; then
  echo "shell: OK ($actual_shell)"
else
  echo "shell: NG (現在のログインシェル: ${actual_shell:-不明}, 期待: .../zsh)"
  status=1
fi

echo "--- Brewfile ---"
brewfile="$HOME/.Brewfile"
if ! command -v brew >/dev/null 2>&1; then
  echo "brewfile: NG (brew コマンドが見つかりません)"
  status=1
elif [ -f "$brewfile" ]; then
  if brew bundle check --file="$brewfile" >"$tmp_file" 2>&1; then
    echo "brewfile: OK"
  else
    echo "brewfile: NG (未インストール/差分あり)"
    cat "$tmp_file"
    status=1
  fi
else
  echo "brewfile: $brewfile が見つかりません(スキップ)"
fi

echo "--- age ---"
age_key="$HOME/.config/age/age.key"
if [ -f "$age_key" ]; then
  pub="$(age-keygen -y "$age_key" 2>/dev/null)"
  if [ -n "$pub" ]; then
    echo "age: OK ($pub)"
  else
    echo "age: NG (公開鍵を抽出できません)"
    status=1
  fi
else
  echo "age: NG (鍵ファイルが見つかりません: $age_key)"
  status=1
fi

echo "---"
if [ "$status" -eq 0 ]; then
  echo "総合判定: OK"
else
  echo "総合判定: NG (上記の NG 項目を確認してください)"
fi

exit "$status"
