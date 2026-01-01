#!/bin/sh

export XDG_SESSION_TYPE=wayland
export QT_QPA_PLATFORM=wayland
export QT_WAYLAND_DISABLE_WINDOWDECORATION=1
export EGL_PLATFORM=gbm
if command -v start-hyprland >/dev/null 2>&1; then
    exec start-hyprland -- -c /etc/greetd/dms-hypr.conf
else
    exec Hyprland -c /etc/greetd/dms-hypr.conf
fi
