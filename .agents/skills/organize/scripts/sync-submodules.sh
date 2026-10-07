#!/usr/bin/env bash
# Environment のサブモジュールを、追跡ブランチの最新に上げてコミットする。
#
#   sync-submodules.sh            初期化 → 最新へ更新 → 変わったものだけ Environment にコミット
#   sync-submodules.sh --dry-run  更新・コミットせず、何が何に上がるかだけ表示（-n でも可）
#
# - サブモジュール内に未コミットの変更やローカルコミットがあれば、何も変えずに中止する。
# - push はしない。
set -euo pipefail

DRY_RUN=0
case "${1:-}" in
  "") ;;
  -n|--dry-run) DRY_RUN=1 ;;
  -h|--help) sed -n '2,8p' "${BASH_SOURCE[0]}" | sed 's/^# \{0,1\}//'; exit 0 ;;
  *) echo "使い方: $0 [--dry-run|-n]" >&2; exit 2 ;;
esac

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")" && git rev-parse --show-toplevel)"
cd "$ROOT"

LOG_MAX=5

if [ ! -f .gitmodules ]; then
  echo "サブモジュールがありません（.gitmodules なし）。"
  exit 0
fi

# .gitmodules からサブモジュールの name と path を列挙する
NAMES=()
PATHS=()
while IFS= read -r line; do
  key="${line%% *}"
  name="${key#submodule.}"; name="${name%.path}"
  NAMES+=("$name")
  PATHS+=("${line#* }")
done < <(git config -f .gitmodules --get-regexp '^submodule\..*\.path$')

short() { echo "${1:0:7}"; }

# --- 1. 事前チェック: 初期化済みのサブモジュール内に変更がないか（何も変えずに中止） ---
problems=""
for i in "${!NAMES[@]}"; do
  p="${PATHS[$i]}"
  # 未初期化（.git が無い）ならチェック不要
  [ -e "$p/.git" ] || continue
  detail=""
  status="$(git -C "$p" status --porcelain)"
  if [ -n "$status" ]; then
    detail+="  未コミットの変更:"$'\n'"$(echo "$status" | sed 's/^/    /')"$'\n'
  fi
  # リモートのどのブランチにも無いコミット = ローカルコミット
  local_commits="$(git -C "$p" log --oneline HEAD --not --remotes)"
  if [ -n "$local_commits" ]; then
    detail+="  ローカルコミット（リモートに無いコミット）:"$'\n'"$(echo "$local_commits" | sed 's/^/    /')"$'\n'
  fi
  if [ -n "$detail" ]; then
    problems+="[$p]"$'\n'"$detail"
  fi
done

if [ -n "$problems" ]; then
  {
    echo "中止しました。サブモジュール内に変更があります（何も変更していません）。"
    echo
    printf '%s' "$problems"
    echo
    echo "サブモジュール内は直接編集しない方針です。変更は実 clone 側で行ってください。"
    echo "この変更を実 clone に移すか、破棄するかを決めてから、もう一度実行してください。"
  } >&2
  exit 1
fi

# --- 2. 初期化・更新 ---
old_shas=()
new_shas=()
changed=()

for i in "${!NAMES[@]}"; do
  name="${NAMES[$i]}"
  p="${PATHS[$i]}"
  old="$(git rev-parse "HEAD:$p")"

  # 追跡ブランチ（未指定ならリモートの既定ブランチ）
  branch="$(git config -f .gitmodules "submodule.$name.branch" || true)"

  if [ "$DRY_RUN" = 1 ]; then
    if [ -e "$p/.git" ]; then
      url="$(git -C "$p" remote get-url origin)"
    else
      url="$(git config "submodule.$name.url" || git config -f .gitmodules "submodule.$name.url")"
    fi
    if [ -n "$branch" ] && [ "$branch" != "." ]; then ref="refs/heads/$branch"; else ref="HEAD"; fi
    new="$(git ls-remote "$url" "$ref" | awk 'NR==1{print $1}')"
    if [ -z "$new" ]; then
      echo "エラー: $p の最新コミットを取得できません（$url $ref）" >&2
      exit 1
    fi
  else
    if [ ! -e "$p/.git" ]; then
      git submodule update --init -- "$p" >/dev/null
    fi
    git submodule update --remote -- "$p" >/dev/null
    new="$(git -C "$p" rev-parse HEAD)"
  fi

  old_shas+=("$old")
  new_shas+=("$new")
  if [ "$old" != "$new" ]; then changed+=("$i"); fi
done

# --- 3. 結果の一覧 ---
if [ "$DRY_RUN" = 1 ]; then echo "[dry-run] 更新・コミットはしません。"; fi
for i in "${!NAMES[@]}"; do
  name="${NAMES[$i]}"; p="${PATHS[$i]}"; old="${old_shas[$i]}"; new="${new_shas[$i]}"
  if [ "$old" = "$new" ]; then
    echo "$name: $(short "$old") (up-to-date)"
    continue
  fi
  echo "$name: $(short "$old") → $(short "$new")"
  log=""
  if [ -e "$p/.git" ] && git -C "$p" cat-file -e "$new^{commit}" 2>/dev/null \
     && git -C "$p" cat-file -e "$old^{commit}" 2>/dev/null; then
    log="$(git -C "$p" log --oneline "$old..$new")"
  fi
  if [ -n "$log" ]; then
    total="$(echo "$log" | wc -l | tr -d ' ')"
    echo "$log" | head -n "$LOG_MAX" | sed 's/^/  /'
    if [ "$total" -gt "$LOG_MAX" ]; then
      echo "  ...ほか $((total - LOG_MAX)) 件（計 $total 件）"
    fi
  elif [ "$DRY_RUN" = 1 ]; then
    echo "  （コミット一覧は更新時に表示）"
  fi
done

if [ "${#changed[@]}" -eq 0 ]; then
  echo "すべて最新です。コミットはありません。"
  exit 0
fi

if [ "$DRY_RUN" = 1 ]; then
  exit 0
fi

# --- 4. Environment 側で、該当パスだけをコミット（他の変更は巻き込まない） ---
summary=""
paths=()
for i in "${changed[@]}"; do
  [ -n "$summary" ] && summary+=", "
  summary+="${NAMES[$i]}: $(short "${old_shas[$i]}")→$(short "${new_shas[$i]}")"
  paths+=("${PATHS[$i]}")
done
git add -- "${paths[@]}"
git commit -q -m "chore: サブモジュールを最新に上げる（${summary}）" -- "${paths[@]}"
echo "Environment にコミットしました: $(git log -1 --oneline)"
echo "push はしていません。"
