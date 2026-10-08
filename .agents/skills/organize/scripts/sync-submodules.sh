#!/usr/bin/env bash
# Environment のサブモジュール（homedir・agent-plugins など）を main に載せて最新化し、
# ポインタの変化を Environment にコミットする。作業の前後で同じコマンドを実行する。
#
#   sync-submodules.sh            初期化 → main に載せる → 最新化 → ポインタをコミット
#   sync-submodules.sh --dry-run  何も変更せず、何が起きるかだけ表示（-n でも可）
#
# サブモジュールごとの動き（.gitmodules から列挙。追跡ブランチは branch、未指定なら main）:
#   - 未初期化なら init する。
#   - detached HEAD などは、HEAD が origin/main に含まれていれば main に切り替える。
#     含まれないコミットがあれば中止して報告する（勝手に捨てない）。
#   - main がクリーンで origin より遅れているだけなら fast-forward で更新する。
#   - 未コミットの変更・未 push のコミット・履歴の分岐があれば、何も変えずに報告する。
#   - 以上が問題なければ、ポインタが変わったサブモジュールのパスだけを Environment にコミットする。
#     Environment の他の変更は巻き込まない。push はしない。
# 1つでも報告が出たら、最後に終了コード 1 で終わる（他のサブモジュールの処理は続ける）。
set -euo pipefail

DRY_RUN=0
case "${1:-}" in
  "") ;;
  -n|--dry-run) DRY_RUN=1 ;;
  -h|--help) sed -n '2,15p' "${BASH_SOURCE[0]}" | sed 's/^# \{0,1\}//'; exit 0 ;;
  *) echo "使い方: $0 [--dry-run|-n]" >&2; exit 2 ;;
esac

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")" && git rev-parse --show-toplevel)"
cd "$ROOT"

LOG_MAX=5

if [ ! -f .gitmodules ]; then
  echo "サブモジュールがありません（.gitmodules なし）。"
  exit 0
fi

NAMES=()
PATHS=()
while IFS= read -r line; do
  key="${line%% *}"
  name="${key#submodule.}"; name="${name%.path}"
  NAMES+=("$name")
  PATHS+=("${line#* }")
done < <(git config -f .gitmodules --get-regexp '^submodule\..*\.path$')

short() { echo "${1:0:7}"; }
indent() { sed 's/^/    /'; }

# 結果（サブモジュールごと）
# OK: 1=問題なし（ポインタを進めてよい） 0=報告あり s=dry-run で未初期化
OK=()
NEWSHA=()
NG_COUNT=0

# 一行ログを LOG_MAX 件まで表示する（引数: サブモジュールのパス, 範囲）
show_log() {
  local p="$1" range="$2" log total
  log="$(git -C "$p" log --oneline "$range" 2>/dev/null || true)"
  [ -n "$log" ] || return 0
  total="$(echo "$log" | wc -l | tr -d ' ')"
  echo "$log" | head -n "$LOG_MAX" | indent
  if [ "$total" -gt "$LOG_MAX" ]; then
    echo "    ...ほか $((total - LOG_MAX)) 件（計 $total 件）"
  fi
}

# サブモジュール1つを処理する。結果は OK[i] / NEWSHA[i] に入れる。
process() {
  local i="$1" name="${NAMES[$1]}" p="${PATHS[$1]}"
  local branch cur dirty lref ahead behind remote_sha ok_switch

  OK[$i]=0
  NEWSHA[$i]=""

  if [ ! -e "$p/.git" ]; then
    if [ "$DRY_RUN" = 1 ]; then
      echo "$name: 未初期化（実行すると init して main に載せます）"
      OK[$i]=s
      return 0
    fi
    git submodule update --init -q -- "$p"
    echo "$name: 未初期化だったので init しました"
  fi

  branch="$(git config -f .gitmodules "submodule.$name.branch" || true)"
  if [ -z "$branch" ] || [ "$branch" = "." ]; then branch=main; fi

  # 未コミットの変更（何も変えずに報告）
  dirty="$(git -C "$p" status --porcelain)"
  if [ -n "$dirty" ]; then
    echo "$name: 作業中（未コミットの変更があります）。何も変更していません。"
    echo "$dirty" | indent
    return 0
  fi

  if ! git -C "$p" fetch -q origin 2>/dev/null; then
    echo "$name: origin から取得できません（ネットワークか SSH 認証を確認してください）。何も変更していません。"
    return 0
  fi
  if ! git -C "$p" rev-parse -q --verify "refs/remotes/origin/$branch" >/dev/null; then
    echo "$name: origin/$branch が見つかりません。何も変更していません。"
    return 0
  fi
  remote_sha="$(git -C "$p" rev-parse "origin/$branch")"

  # main に載せる
  cur="$(git -C "$p" symbolic-ref -q --short HEAD || true)"
  if [ "$cur" != "$branch" ]; then
    ok_switch=0
    if git -C "$p" merge-base --is-ancestor HEAD "origin/$branch"; then
      ok_switch=1
    elif git -C "$p" rev-parse -q --verify "refs/heads/$branch" >/dev/null \
         && git -C "$p" merge-base --is-ancestor HEAD "refs/heads/$branch"; then
      ok_switch=1
    fi
    if [ "$ok_switch" = 0 ]; then
      echo "$name: 中止。${cur:-detached HEAD} に、origin/$branch に含まれないコミットがあります（どのブランチにも無い可能性があります）。何も変更していません。"
      git -C "$p" log --oneline HEAD --not "origin/$branch" | head -n 10 | indent
      return 0
    fi
    if [ "$DRY_RUN" = 1 ]; then
      echo "$name: ${cur:-detached HEAD} から $branch に切り替えます（dry-run）"
    else
      if git -C "$p" rev-parse -q --verify "refs/heads/$branch" >/dev/null; then
        git -C "$p" switch -q "$branch"
      else
        git -C "$p" switch -q -c "$branch" --track "origin/$branch"
      fi
      echo "$name: ${cur:-detached HEAD} から $branch に切り替えました"
    fi
  fi

  # origin との関係
  if git -C "$p" rev-parse -q --verify "refs/heads/$branch" >/dev/null; then
    lref="refs/heads/$branch"
  else
    lref="origin/$branch"
  fi
  read -r ahead behind < <(git -C "$p" rev-list --left-right --count "$lref...origin/$branch")

  if [ "$ahead" -gt 0 ] && [ "$behind" -gt 0 ]; then
    echo "$name: 履歴が分岐しています（手元 $ahead 件・origin 側 $behind 件）。何も変更していません。"
    echo "  手元だけにあるコミット:"
    git -C "$p" log --oneline "origin/$branch..$lref" | head -n 10 | indent
    return 0
  fi
  if [ "$ahead" -gt 0 ]; then
    echo "$name: 未 push のコミットがあります（$ahead 件）。push してからもう一度実行してください。"
    echo "  push すべきコミット:"
    git -C "$p" log --oneline "origin/$branch..$lref" | head -n 10 | indent
    return 0
  fi

  if [ "$behind" -gt 0 ]; then
    if [ "$DRY_RUN" = 1 ]; then
      echo "$name: $branch は origin より $behind 件遅れています。更新します（dry-run）"
    else
      git -C "$p" merge -q --ff-only "origin/$branch"
      echo "$name: $branch を origin に追いつかせました（$behind 件）"
    fi
  else
    echo "$name: $branch は origin と一致しています"
  fi

  if [ "$DRY_RUN" = 0 ]; then
    # 素の git push が通るように追跡先を設定しておく
    if ! git -C "$p" rev-parse -q --verify "$branch@{upstream}" >/dev/null 2>&1; then
      git -C "$p" branch -q --set-upstream-to="origin/$branch" "$branch"
    fi
    NEWSHA[$i]="$(git -C "$p" rev-parse HEAD)"
  else
    NEWSHA[$i]="$remote_sha"
  fi
  OK[$i]=1
}

if [ "$DRY_RUN" = 1 ]; then echo "[dry-run] 何も変更しません（fetch のみ行います）。"; fi

for i in "${!NAMES[@]}"; do
  process "$i"
  if [ "${OK[$i]}" = 0 ]; then NG_COUNT=$((NG_COUNT + 1)); fi
done

# --- Environment 側のポインタ ---
echo
changed=()
summary=""
paths=()
for i in "${!NAMES[@]}"; do
  [ "${OK[$i]}" = 1 ] || continue
  p="${PATHS[$i]}"
  old="$(git rev-parse "HEAD:$p")"
  new="${NEWSHA[$i]}"
  [ "$old" != "$new" ] || continue
  changed+=("$i")
  echo "${NAMES[$i]}: ポインタ $(short "$old") → $(short "$new")"
  show_log "$p" "$old..$new"
  [ -n "$summary" ] && summary+=", "
  summary+="${NAMES[$i]}: $(short "$old")→$(short "$new")"
  paths+=("$p")
done

if [ "${#changed[@]}" -eq 0 ]; then
  echo "Environment のポインタに変更はありません。"
elif [ "$DRY_RUN" = 1 ]; then
  echo "[dry-run] Environment にコミットする予定です。"
else
  git add -- "${paths[@]}"
  git commit -q -m "chore: サブモジュールを最新に上げる（${summary}）" -- "${paths[@]}"
  echo "Environment にコミットしました: $(git log -1 --oneline)"
  echo "（Environment の push はしていません）"
fi

if [ "$NG_COUNT" -gt 0 ]; then
  echo
  echo "報告のあったサブモジュールが $NG_COUNT 件あります。内容を確認して対処してから、もう一度実行してください。" >&2
  exit 1
fi
