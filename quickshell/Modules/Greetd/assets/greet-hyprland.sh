#!/bin/sh

export XDG_SESSION_TYPE=wayland
export QT_QPA_PLATFORM=wayland
export QT_WAYLAND_DISABLE_WINDOWDECORATION=1
export EGL_PLATFORM=gbm
CURRENT_VERSION=$(hyprland --version | grep "Tag:" | awk '{print $2}' | tr -d 'v,')

MINIMUM_VERSION="0.53.0"

if [ "$(printf '%s\n%s' "$MINIMUM_VERSION" "$CURRENT_VERSION" | sort -V | head -n1)" = "$MINIMUM_VERSION" ]; then
    exec start-hyprland -- -c /etc/greetd/dms-hypr.conf
else
    exec Hyprland -c /etc/greetd/dms-hypr.conf
fi
