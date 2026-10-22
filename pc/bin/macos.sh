#!/usr/bin/env bash
# macOS のシステム設定を defaults で宣言状態へ揃える（冪等・非対話）。
# defaults で書けない設定は pc/README.md の「手動で行う初期設定」に載せている。

# スクリーンショットはファイルにせずクリップボードへ入れる
defaults write com.apple.screencapture target -string clipboard

# スペースを2回押してもピリオドを入れない
defaults write NSGlobalDomain NSAutomaticPeriodSubstitutionEnabled -bool false

# ダークモード
defaults write NSGlobalDomain AppleInterfaceStyle -string Dark

# F1〜F12 を標準のファンクションキーとして使う（Fn 単押しの動作は何もしない）
defaults write NSGlobalDomain com.apple.keyboard.fnState -bool true
defaults write com.apple.HIToolbox AppleFnUsageType -int 0

# 右下のホットコーナー（既定ではクイックメモ）を無効にする
defaults write com.apple.dock wvous-br-corner -int 1
defaults write com.apple.dock wvous-br-modifier -int 0

# Dock
defaults write com.apple.dock orientation -string left
defaults write com.apple.dock tilesize -int 89
defaults write com.apple.dock show-recents -bool false

killall Dock SystemUIServer 2>/dev/null || true
