#!/bin/sh

export XDG_SESSION_TYPE=wayland
export QT_QPA_PLATFORM=wayland
export EGL_PLATFORM=gbm

exec niri -c /etc/greetd/dms-niri.kdl
