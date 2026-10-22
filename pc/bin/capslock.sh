#!/usr/bin/env bash
# CapsLock キーを Control に割り当てて、ログイン時に再適用する LaunchAgent を登録する（冪等・非対話）。
# hidutil の設定は再起動で消える。LaunchAgent の plist は chezmoi が配置する
# （homedir の Library/LaunchAgents/）ので、ここでは即時反映と登録だけを行う。

label="com.hyogamurase22.capslock-to-control"
plist="$HOME/Library/LaunchAgents/$label.plist"
# 0x700000039 = CapsLock, 0x7000000E0 = 左 Control
mapping='{"UserKeyMapping":[{"HIDKeyboardModifierMappingSrc":0x700000039,"HIDKeyboardModifierMappingDst":0x7000000E0}]}'

hidutil property --set "$mapping" >/dev/null

# plist が無い（chezmoi apply 前）、または GUI セッションが無い環境では登録に失敗するが、
# 次回ログインで読み込まれる
launchctl bootout "gui/$(id -u)/$label" 2>/dev/null || true
launchctl bootstrap "gui/$(id -u)" "$plist" 2>/dev/null || true
