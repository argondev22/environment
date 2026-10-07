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
  chezmoi_diff="$(chezmoi status 2>&1)"
  if [ -z "$chezmoi_diff" ]; then
    echo "chezmoi: OK (clean)"
  else
    echo "chezmoi: NG (差分あり)"
    echo "$chezmoi_diff"
    status=1
  fi
fi

echo "--- asdf ---"
tool_versions="$HOME/.tool-versions"
if ! command -v asdf >/dev/null 2>&1; then
  echo "asdf: NG (asdf コマンドが見つかりません)"
  status=1
elif [ -f "$tool_versions" ]; then
  while read -r name version _rest; do
    [ -z "${name:-}" ] && continue
    case "$name" in \#*) continue ;; esac

    if [ "$version" = "system" ]; then
      echo "asdf $name: OK (system 指定のためスキップ)"
      continue
    fi

    if asdf list "$name" 2>/dev/null | tr -d ' ' | grep -qx "$version"; then
      echo "asdf $name $version: OK"
    else
      echo "asdf $name $version: NG (未インストール)"
      status=1
    fi
  done < "$tool_versions"
else
  echo "asdf: $tool_versions が見つかりません(スキップ)"
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
