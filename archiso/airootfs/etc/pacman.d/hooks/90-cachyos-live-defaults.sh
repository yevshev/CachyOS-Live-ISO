#!/usr/bin/env bash
# remove from airootfs!
set -euo pipefail

SKEL_CONFIG="${1:-/etc/skel/.config}"
JAY_CFG="${SKEL_CONFIG}/jay/config.toml"
NOCTALIA_CFG="${SKEL_CONFIG}/noctalia/config.toml"
KDEGLOBALS="${SKEL_CONFIG}/kdeglobals"

# 1. Jay compositor live ISO defaults
if [[ -f "$JAY_CFG" ]]; then
    # Start HDR auto-enable helper on graphics init alongside Noctalia
    sed -i '/"noctalia", "--daemon"/a\    { type = "exec", exec = "/usr/local/bin/enable-hdr" },' "$JAY_CFG"

    # Disable compositor idle timeout in RAM-only live session
    sed -i '/^idle = {/,/^}/ { s/minutes = [0-9]\+/minutes = 0/; s/seconds = [0-9]\+/seconds = 0/; }' "$JAY_CFG"

    # Enable AMD Radeon 780M hardware HDR plane color pipelines (also provides required match field)
    sed -i '/^\[\[drm-devices\]\]/,/^$/ c\
[[drm-devices]]\
match = { pci-vendor = 0x1002 }\
plane-color-pipelines = true\
' "$JAY_CFG"

    # Replace upstream placeholder [[outputs]] block (invalid empty `width = ,`) with 2x HiDPI scaling
    sed -i '/^\[\[outputs\]\]/,/^$/ c\
[[outputs]]\
match = {}\
scale = 2.0\
' "$JAY_CFG"

    # Disable XWayland (pure Wayland) and enable Wayland color-management protocol for HDR
    sed -i '/^\[color-management\]/ i\
[xwayland]\
enabled = false\
' "$JAY_CFG"
    sed -i '/^\[color-management\]/,/^$/ s/^# enabled = true/enabled = true/' "$JAY_CFG"

    # Export Wayland-only + qt6ct environment variables to all spawned clients
    sed -i '/^\[env\]/,/^$/ {
        s/^# GTK_THEME = /GTK_THEME = /
        s/^# QT_QPA_PLATFORM = /QT_QPA_PLATFORM = /
        s/^# QT_QPA_PLATFORMTHEME = /QT_QPA_PLATFORMTHEME = /
    }' "$JAY_CFG"
    sed -i '/^QT_QPA_PLATFORMTHEME = / a\
GDK_BACKEND = "wayland"\
SDL_VIDEODRIVER = "wayland"\
SDL_VIDEO_DRIVER = "wayland"\
ELECTRON_OZONE_PLATFORM_HINT = "wayland"' "$JAY_CFG"

    # Fix upstream duplicate `logo-v` keybind, switch terminal to Ghostty, and add Brave Origin shortcut
    sed -i 's/^logo-v = "split-vertical"/logo-shift-d = "split-vertical"/' "$JAY_CFG"
    sed -i 's/exec = "alacritty"/exec = "ghostty"/' "$JAY_CFG"
    sed -i '/^logo-e = / a\logo-b = { type = "exec", exec = "brave-origin" }' "$JAY_CFG"
fi

# 2. Noctalia shell live ISO defaults
if [[ -f "$NOCTALIA_CFG" ]]; then
    # Remove unused Bluetooth and Battery widgets on wired-only desktop
    sed -i '/^[[:space:]]*"bluetooth",$/d; /^[[:space:]]*"battery",$/d' "$NOCTALIA_CFG"

    # Prevent screen lock (empty liveuser password) and auto-suspend in RAM-only live session
    sed -i '/^[[:space:]]*\[idle\.behavior\.lock\]/,/^$/ s/enabled = true/enabled = false/' "$NOCTALIA_CFG"
    sed -i '/^[[:space:]]*\[idle\.behavior\.lock-and-suspend\]/,/^$/ s/enabled = true/enabled = false/' "$NOCTALIA_CFG"
fi

# 3. Set Ghostty as default terminal for Dolphin ("Open Terminal Here")
if [[ -f "$KDEGLOBALS" ]]; then
    sed -i 's/^TerminalApplication=alacritty$/TerminalApplication=ghostty/' "$KDEGLOBALS"
fi
