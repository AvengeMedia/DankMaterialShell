#!/usr/bin/env bash

# Find and format all QML files, then fix pragma ComponentBehavior
find . -name "*.qml" -exec sh -c '
    qmlfmt -t 4 -i 4 -b 250 -w "$1"
    sed -i "s/pragma ComponentBehavior$/pragma ComponentBehavior: Bound/g" "$1"
' _ {} \;
