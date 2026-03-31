pragma Singleton
pragma ComponentBehavior: Bound

import QtQuick
import Quickshell
import Quickshell.Io
import Quickshell.Services.SystemTray

Singleton {
    id: root

    // Re-run after resume from suspend
    Connections {
        target: SessionService
        function onSessionResumed() {
            resumeTimer.restart();
        }
    }

    Timer {
        id: resumeTimer
        interval: 3000
        repeat: false
        running: false
        onTriggered: root.recoverTrayItems()
    }

    Process {
        id: recoveryProcess
        running: false
        command: ["bash", "-c", `
            REGISTERED=$(dbus-send --session --print-reply \
                --dest=org.kde.StatusNotifierWatcher \
                /StatusNotifierWatcher \
                org.freedesktop.DBus.Properties.Get \
                string:org.kde.StatusNotifierWatcher \
                string:RegisteredStatusNotifierItems 2>/dev/null || echo "")

            # Single snapshot of all DBus names/connections (reused in both sections)
            BUSCTL_OUT=$(busctl --user list --no-legend 2>/dev/null)

            # Build the full set of effectively-registered connection IDs by resolving
            # every registered item (well-known name or :1.xxx) to its connection ID.
            # This prevents both directions of false-duplicate registration.
            REGISTERED_CONN_IDS=""
            for ITEM_PATH in $(echo "$REGISTERED" | grep -oP '"[^"]*"' | tr -d '"'); do
                ITEM_NAME=$(echo "$ITEM_PATH" | cut -d/ -f1)
                if [[ "$ITEM_NAME" == :1.* ]]; then
                    REGISTERED_CONN_IDS="$REGISTERED_CONN_IDS $ITEM_NAME"
                else
                    CONN=$(echo "$BUSCTL_OUT" | awk -v n="$ITEM_NAME" '$1==n {print $5; exit}')
                    [ -n "$CONN" ] && REGISTERED_CONN_IDS="$REGISTERED_CONN_IDS $CONN"
                fi
            done

            # === Well-known names (DinoX, nm-applet, etc.) ===
            NAMES=$(echo "$BUSCTL_OUT" | awk '$1 ~ /^[A-Za-z]/ {print $1}')

            for NAME in $NAMES; do
                echo "$REGISTERED" | grep -qF "$NAME" && continue

                # Also skip if this name's connection ID is already in the registered set
                # (handles the case where the app registered via connection ID instead)
                CONN_FOR_NAME=$(echo "$BUSCTL_OUT" | awk -v n="$NAME" '$1==n {print $5; exit}')
                [ -n "$CONN_FOR_NAME" ] && [[ " $REGISTERED_CONN_IDS " == *" $CONN_FOR_NAME "* ]] && continue

                case "$NAME" in
                    org.freedesktop.*|org.gnome.*|org.kde.StatusNotifier*) continue ;;
                    com.canonical.AppMenu*|org.mpris.*|org.pipewire.*) continue ;;
                    org.pulseaudio*|fi.epitaph*|quickshell*|org.kde.quickshell*) continue ;;
                esac

                SHORT=$(echo "$NAME" | awk -F. '{print $NF}')
                for OBJ_PATH in "/StatusNotifierItem" "/org/ayatana/NotificationItem/$SHORT"; do
                    if timeout 0.3 dbus-send --session --print-reply \
                        --dest="$NAME" "$OBJ_PATH" \
                        org.freedesktop.DBus.Properties.GetAll \
                        string:org.kde.StatusNotifierItem 2>/dev/null | grep -q 'string.*Id' ; then
                        dbus-send --session --type=method_call \
                            --dest=org.kde.StatusNotifierWatcher \
                            /StatusNotifierWatcher \
                            org.kde.StatusNotifierWatcher.RegisterStatusNotifierItem \
                            string:"$NAME"
                        echo "TrayRecovery: re-registered $NAME at $OBJ_PATH"
                        # Update set so the connection-ID section won't double-register this app
                        [ -n "$CONN_FOR_NAME" ] && REGISTERED_CONN_IDS="$REGISTERED_CONN_IDS $CONN_FOR_NAME"
                        break
                    fi
                done
            done

            # === Connection IDs (Vesktop, Electron apps, etc.) ===
            # Probe all :1.xxx connections in parallel with a short timeout.
            # Most non-SNI connections return an error instantly, so this is fast.
            CONN_IDS=$(echo "$BUSCTL_OUT" | awk '$1 ~ /^:1\./ {print $1}')

            BATCH=0
            for CONN in $CONN_IDS; do
                # Skip if this connection ID is already covered (directly or via well-known name)
                [[ " $REGISTERED_CONN_IDS " == *" $CONN "* ]] && continue
                (
                    SNI_ID=$(timeout 0.15 dbus-send --session --print-reply \
                        --dest="$CONN" /StatusNotifierItem \
                        org.freedesktop.DBus.Properties.Get \
                        string:org.kde.StatusNotifierItem string:Id 2>/dev/null \
                        | grep -oP '"[^"]+"' | tr -d '"')
                    [ -z "$SNI_ID" ] && exit
                    # Skip if an item with the same Id is already registered (case-insensitive)
                    echo "$REGISTERED" | grep -qiF "$SNI_ID" && exit
                    dbus-send --session --type=method_call \
                        --dest=org.kde.StatusNotifierWatcher \
                        /StatusNotifierWatcher \
                        org.kde.StatusNotifierWatcher.RegisterStatusNotifierItem \
                        string:"$CONN"
                    echo "TrayRecovery: re-registered $CONN (Id: $SNI_ID)"
                ) &
                BATCH=$((BATCH + 1))
                [ $((BATCH % 30)) -eq 0 ] && wait && BATCH=0
            done
            wait
        `]

        stdout: SplitParser {
            onRead: data => {
                if (data.trim().length > 0)
                    console.info(data.trim());
            }
        }

        stderr: SplitParser {
            onRead: data => {
                if (data.trim().length > 0)
                    console.warn("TrayRecoveryService:", data.trim());
            }
        }
    }

    function recoverTrayItems() {
        const count = SystemTray.items.values.length;
        console.info("TrayRecoveryService: scanning DBus for unregistered SNI items (" + count + " already registered)...");
        recoveryProcess.running = false;
        Qt.callLater(() => {
            recoveryProcess.running = true;
        });
    }
}
