#!/usr/bin/env bash
# CapsLock キーを Control に割り当てる（冪等・非対話）。
# hidutil の設定は再起動で消えるため、ログイン時に再適用する LaunchAgent も置く。

label="com.argondev22.capslock-to-control"
plist="$HOME/Library/LaunchAgents/$label.plist"
# 0x700000039 = CapsLock, 0x7000000E0 = 左 Control
mapping='{"UserKeyMapping":[{"HIDKeyboardModifierMappingSrc":0x700000039,"HIDKeyboardModifierMappingDst":0x7000000E0}]}'

hidutil property --set "$mapping" >/dev/null

mkdir -p "$(dirname "$plist")"
cat > "$plist" <<EOF
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
    <key>Label</key>
    <string>$label</string>
    <key>ProgramArguments</key>
    <array>
        <string>/usr/bin/hidutil</string>
        <string>property</string>
        <string>--set</string>
        <string>$mapping</string>
    </array>
    <key>RunAtLoad</key>
    <true/>
</dict>
</plist>
EOF

# GUI セッションが無い環境（SSH 実行など）では登録に失敗するが、次回ログインで読み込まれる
launchctl bootout "gui/$(id -u)/$label" 2>/dev/null || true
launchctl bootstrap "gui/$(id -u)" "$plist" 2>/dev/null || true
