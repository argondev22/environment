#!/usr/bin/env bash
# defaults で書けない設定は pc/README.md の「手動で行う初期設定」に載せている。
set -euo pipefail

case "${1:-}" in
    '') mode=apply ;;
    --check) mode=check ;;
    *) echo "Usage: $0 [--check]" >&2; exit 2 ;;
esac

write_defaults() {
    if [ "$mode" = check ]; then
        printf 'defaults'
        printf ' %q' "$@"
        printf '\n'
    else
        defaults "$@"
    fi
}

# スクリーンショットはファイルにせずクリップボードへ入れる
write_defaults write com.apple.screencapture target -string clipboard

# スペースを2回押してもピリオドを入れない
write_defaults write NSGlobalDomain NSAutomaticPeriodSubstitutionEnabled -bool false

# ダークモード
write_defaults write NSGlobalDomain AppleInterfaceStyle -string Dark

# F1〜F12 を標準のファンクションキーとして使う（Fn 単押しの動作は何もしない）
write_defaults write NSGlobalDomain com.apple.keyboard.fnState -bool true
write_defaults write com.apple.HIToolbox AppleFnUsageType -int 0

# 右下のホットコーナー（既定ではクイックメモ）を無効にする
write_defaults write com.apple.dock wvous-br-corner -int 1
write_defaults write com.apple.dock wvous-br-modifier -int 0

# Dock
write_defaults write com.apple.dock orientation -string left
write_defaults write com.apple.dock tilesize -int 89
write_defaults write com.apple.dock show-recents -bool false

# macOS 27 で読み取ったキーだけを指定し、認証情報を含む plist 全体は取り込まない。
write_defaults write com.apple.controlcenter 'NSStatusItem VisibleCC Battery' -bool true
write_defaults write com.apple.controlcenter 'NSStatusItem VisibleCC WiFi' -bool true
write_defaults write com.apple.controlcenter 'NSStatusItem VisibleCC Clock' -bool true
write_defaults write com.apple.controlcenter 'NSStatusItem VisibleCC BentoBox-0' -bool true
write_defaults write com.apple.controlcenter 'NSStatusItem Visible BentoBox' -bool true
write_defaults write com.apple.controlcenter 'NSStatusItem Visible Shortcuts' -bool false
write_defaults -currentHost write com.apple.controlcenter BatteryShowPercentage -bool true
write_defaults -currentHost write com.apple.controlcenter Siri -int 8
write_defaults -currentHost write com.apple.controlcenter Spotlight -int 8
write_defaults -currentHost write com.apple.controlcenter VoiceControl -int 8
write_defaults -currentHost write com.apple.controlcenter Display -int 24
write_defaults -currentHost write com.apple.controlcenter Battery -int 2
write_defaults -currentHost write com.apple.controlcenter FocusModes -int 2
write_defaults -currentHost write com.apple.controlcenter ScreenMirroring -int 2
write_defaults -currentHost write com.apple.controlcenter Sound -int 2
write_defaults -currentHost write com.apple.controlcenter NowPlaying -int 2

write_defaults write com.apple.controlcenter 'NSStatusItem Preferred Position Battery' -float 239
write_defaults write com.apple.controlcenter 'NSStatusItem Preferred Position WiFi' -float 201
write_defaults write com.apple.controlcenter 'NSStatusItem Preferred Position BentoBox' -float 135
write_defaults write com.apple.controlcenter 'NSStatusItem Preferred Position BentoBox-0' -float 231
write_defaults write com.apple.TextInputMenuAgent 'NSStatusItem VisibleCC Item-0' -bool true
write_defaults write com.apple.TextInputMenuAgent 'NSStatusItem Preferred Position Item-0' -float 281
write_defaults write notion.id 'NSStatusItem Preferred Position Item-0' -float 404
write_defaults write com.raycast.macos 'NSStatusItem VisibleCC raycastIcon' -bool true
write_defaults write com.cmuxterm.app 'NSStatusItem VisibleCC Item-1' -bool false
write_defaults write com.kyome.Neo.RunCat 'NSStatusItem VisibleCC Item-1' -bool false

# アプリ単位の表示許可は個別アイコンの VisibleCC とは別に保存される。
python3 - "$mode" <<'PYTHON'
import plistlib
from pathlib import Path
import subprocess
import sys

allowed_apps = {
    "com.1password.1password": False,
    "com.electron.aqua-voice": False,
    "com.anthropic.claudefordesktop": False,
    "com.cmuxterm.app": False,
    "com.docker.docker": False,
    "com.google.drivefs": False,
    "com.amazon.codewhisperer": False,
    "notion.id": False,
    "com.cron.electron": True,
    "com.raycast.macos": False,
    "com.kyome.Neo.RunCat": True,
    "com.apple.ScriptMonitor": False,
    "cc.ffitch.shottr": False,
}
preferences = (
    Path.home() / "Library/Group Containers/group.com.apple.controlcenter"
    / "Library/Preferences/group.com.apple.controlcenter.plist"
)
if preferences.exists():
    exported = subprocess.run(
        ["defaults", "export", str(preferences), "-"],
        check=True, capture_output=True,
    )
    current = plistlib.loads(exported.stdout)
else:
    current = {}
tracked = plistlib.loads(current["trackedApplications"]) if "trackedApplications" in current else []
if not isinstance(tracked, list) or len(tracked) % 2:
    raise ValueError("Unsupported Control Center trackedApplications format")

entries = {}
for index in range(0, len(tracked), 2):
    location, entry = tracked[index:index + 2]
    if not isinstance(location, dict) or not isinstance(entry, dict):
        raise ValueError("Unsupported Control Center application entry")
    bundle_id = location.get("bundle", {}).get("_0")
    if bundle_id:
        entries[bundle_id] = entry

changed = False
for bundle_id, allowed in allowed_apps.items():
    entry = entries.get(bundle_id)
    if entry is None or entry.get("isAllowed") != allowed:
        print(f"Menu bar permission: {bundle_id} -> {allowed}")
        if entry is None:
            location = {"bundle": {"_0": bundle_id}}
            item_bundle = "com.electron.dockerdesktop" if bundle_id == "com.docker.docker" else bundle_id
            entry = {"location": location, "menuItemLocations": [{"bundle": {"_0": item_bundle}}]}
            tracked.extend([location, entry])
        entry["isAllowed"] = allowed
        changed = True

if changed and sys.argv[1] == "apply":
    data = plistlib.dumps(tracked, fmt=plistlib.FMT_BINARY, sort_keys=False)
    subprocess.run(
        ["defaults", "write", str(preferences), "trackedApplications", "-data", data.hex()],
        check=True,
    )
else:
    print("Menu bar application permissions: " + ("changes required" if changed else "already match"))
PYTHON

# hidutil の設定は再起動で消えるため、homedir が配置する LaunchAgent でも再適用する。
label="com.hyogamurase22.capslock-to-control"
plist="$HOME/Library/LaunchAgents/$label.plist"
# 0x700000039 = CapsLock, 0x7000000E0 = 左 Control
mapping='{"UserKeyMapping":[{"HIDKeyboardModifierMappingSrc":0x700000039,"HIDKeyboardModifierMappingDst":0x7000000E0}]}'

if [ "$mode" = apply ]; then
    hidutil property --set "$mapping" >/dev/null

    # plist や GUI セッションが無い場合は登録できないが、次回ログインで読み込まれる。
    launchctl bootout "gui/$(id -u)/$label" 2>/dev/null || true
    launchctl bootstrap "gui/$(id -u)" "$plist" 2>/dev/null || true
else
    printf 'CapsLock -> Control; register LaunchAgent: %s\n' "$label"
fi

# 未導入のアプリはスキップし、次の実行で再確認する。
osascript - "$mode" <<'APPLESCRIPT'
on run argv
    set applyChanges to (item 1 of argv is "apply")
    set managedApps to {¬
        {"Raycast", true}, ¬
        {"Aqua Voice", true}, ¬
        {"RunCatNeo", true}, ¬
        {"Google Drive", true}, ¬
        {"Shottr", true}, ¬
        {"Notion", true}, ¬
        {"1Password", false}, ¬
        {"Docker", false}, ¬
        {"Kiro CLI", false}, ¬
        {"Notion Calendar", false}, ¬
        {"Xcode", false}, ¬
        {"cmux", false}, ¬
        {"draw.io", false}}

    tell application "System Events"
        repeat with appSetting in managedApps
            set appName to item 1 of appSetting
            set startAtLogin to item 2 of appSetting
            set appPath to "/Applications/" & appName & ".app"
            set matchingItems to every login item whose path is appPath
            if startAtLogin then
                if not (exists disk item appPath) then
                    log "Not installed: " & appName
                else if (count matchingItems) is 0 then
                    log "Add login item: " & appName
                    if applyChanges then
                        make new login item at end of login items with properties {path:appPath, hidden:false}
                    end if
                else
                    log "Already enabled: " & appName
                end if
            else
                if (count matchingItems) > 0 then
                    log "Remove login item: " & appName
                    if applyChanges then delete (every login item whose path is appPath)
                else
                    log "Already disabled: " & appName
                end if
            end if
        end repeat
    end tell
end run
APPLESCRIPT

if [ "$mode" = apply ]; then
    killall Dock SystemUIServer 2>/dev/null || true
fi
