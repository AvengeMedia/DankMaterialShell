import QtQuick
import qs.Common
import qs.Modules.Settings

FocusScope {
    id: root

    property int currentIndex: 0
    property var parentModal: null

    focus: true

    Rectangle {
        anchors.fill: parent
        anchors.leftMargin: Theme.spacingS
        anchors.rightMargin: (parentModal && parentModal.isCompactMode) ? Theme.spacingS : (32 + Theme.spacingS)
        anchors.bottomMargin: 0
        anchors.topMargin: 0
        color: "transparent"

        Loader {
            id: wallpaperLoader
            anchors.fill: parent
            active: root.currentIndex === 0
            visible: active
            focus: active

            sourceComponent: Component {
                WallpaperTab {
                    parentModal: root.parentModal
                }
            }

            onActiveChanged: {
                if (active && item) {
                    Qt.callLater(() => item.forceActiveFocus());
                }
            }
        }

        Loader {
            id: timeWeatherLoader
            anchors.fill: parent
            active: root.currentIndex === 1
            visible: active
            focus: active

            sourceComponent: TimeWeatherTab {}

            onActiveChanged: {
                if (active && item) {
                    Qt.callLater(() => item.forceActiveFocus());
                }
            }
        }

        Loader {
            id: keybindsLoader
            anchors.fill: parent
            active: root.currentIndex === 2
            visible: active
            focus: active

            sourceComponent: KeybindsTab {
                parentModal: root.parentModal
            }

            onActiveChanged: {
                if (active && item) {
                    Qt.callLater(() => item.forceActiveFocus());
                }
            }
        }

        Loader {
            id: topBarLoader
            anchors.fill: parent
            active: root.currentIndex === 3
            visible: active
            focus: active

            sourceComponent: DankBarTab {
                parentModal: root.parentModal
            }

            onActiveChanged: {
                if (active && item) {
                    Qt.callLater(() => item.forceActiveFocus());
                }
            }
        }

        Loader {
            id: workspacesLoader
            anchors.fill: parent
            active: root.currentIndex === 4
            visible: active
            focus: active

            sourceComponent: WorkspacesTab {}

            onActiveChanged: {
                if (active && item) {
                    Qt.callLater(() => item.forceActiveFocus());
                }
            }
        }

        Loader {
            id: dockLoader
            anchors.fill: parent
            active: root.currentIndex === 5
            visible: active
            focus: active

            sourceComponent: Component {
                DockTab {}
            }

            onActiveChanged: {
                if (active && item) {
                    Qt.callLater(() => item.forceActiveFocus());
                }
            }
        }

        Loader {
            id: displaysLoader
            anchors.fill: parent
            active: root.currentIndex === 6
            visible: active
            focus: active

            sourceComponent: DisplaysTab {}

            onActiveChanged: {
                if (active && item) {
                    Qt.callLater(() => item.forceActiveFocus());
                }
            }
        }

        Loader {
            id: networkLoader
            anchors.fill: parent
            active: root.currentIndex === 7
            visible: active
            focus: active

            sourceComponent: NetworkTab {}

            onActiveChanged: {
                if (active && item) {
                    Qt.callLater(() => item.forceActiveFocus());
                }
            }
        }

        Loader {
            id: printerLoader
            anchors.fill: parent
            active: root.currentIndex === 8
            visible: active
            focus: active

            sourceComponent: PrinterTab {}

            onActiveChanged: {
                if (active && item) {
                    Qt.callLater(() => item.forceActiveFocus());
                }
            }
        }

        Loader {
            id: launcherLoader
            anchors.fill: parent
            active: root.currentIndex === 9
            visible: active
            focus: active

            sourceComponent: LauncherTab {}

            onActiveChanged: {
                if (active && item) {
                    Qt.callLater(() => item.forceActiveFocus());
                }
            }
        }

        Loader {
            id: themeColorsLoader
            anchors.fill: parent
            active: root.currentIndex === 10
            visible: active
            focus: active

            sourceComponent: ThemeColorsTab {}

            onActiveChanged: {
                if (active && item) {
                    Qt.callLater(() => item.forceActiveFocus());
                }
            }
        }

        Loader {
            id: lockScreenLoader
            anchors.fill: parent
            active: root.currentIndex === 11
            visible: active
            focus: active

            sourceComponent: LockScreenTab {}

            onActiveChanged: {
                if (active && item) {
                    Qt.callLater(() => item.forceActiveFocus());
                }
            }
        }

        Loader {
            id: pluginsLoader
            anchors.fill: parent
            active: root.currentIndex === 12
            visible: active
            focus: active

            sourceComponent: PluginsTab {
                parentModal: root.parentModal
            }

            onActiveChanged: {
                if (active && item) {
                    Qt.callLater(() => item.forceActiveFocus());
                }
            }
        }

        Loader {
            id: aboutLoader
            anchors.fill: parent
            active: root.currentIndex === 13
            visible: active
            focus: active

            sourceComponent: AboutTab {}

            onActiveChanged: {
                if (active && item) {
                    Qt.callLater(() => item.forceActiveFocus());
                }
            }
        }

        Loader {
            id: typographyMotionLoader
            anchors.fill: parent
            active: root.currentIndex === 14
            visible: active
            focus: active

            sourceComponent: TypographyMotionTab {}

            onActiveChanged: {
                if (active && item) {
                    Qt.callLater(() => item.forceActiveFocus());
                }
            }
        }

        Loader {
            id: soundsLoader
            anchors.fill: parent
            active: root.currentIndex === 15
            visible: active
            focus: active

            sourceComponent: SoundsTab {}

            onActiveChanged: {
                if (active && item) {
                    Qt.callLater(() => item.forceActiveFocus());
                }
            }
        }

        Loader {
            id: mediaPlayerLoader
            anchors.fill: parent
            active: root.currentIndex === 16
            visible: active
            focus: active

            sourceComponent: MediaPlayerTab {}

            onActiveChanged: {
                if (active && item) {
                    Qt.callLater(() => item.forceActiveFocus());
                }
            }
        }

        Loader {
            id: notificationsLoader
            anchors.fill: parent
            active: root.currentIndex === 17
            visible: active
            focus: active

            sourceComponent: NotificationsTab {}

            onActiveChanged: {
                if (active && item) {
                    Qt.callLater(() => item.forceActiveFocus());
                }
            }
        }

        Loader {
            id: osdLoader
            anchors.fill: parent
            active: root.currentIndex === 18
            visible: active
            focus: active

            sourceComponent: OSDTab {}

            onActiveChanged: {
                if (active && item) {
                    Qt.callLater(() => item.forceActiveFocus());
                }
            }
        }

        Loader {
            id: runningAppsLoader
            anchors.fill: parent
            active: root.currentIndex === 19
            visible: active
            focus: active

            sourceComponent: RunningAppsTab {}

            onActiveChanged: {
                if (active && item) {
                    Qt.callLater(() => item.forceActiveFocus());
                }
            }
        }

        Loader {
            id: systemUpdaterLoader
            anchors.fill: parent
            active: root.currentIndex === 20
            visible: active
            focus: active

            sourceComponent: SystemUpdaterTab {}

            onActiveChanged: {
                if (active && item) {
                    Qt.callLater(() => item.forceActiveFocus());
                }
            }
        }

        Loader {
            id: powerSleepLoader
            anchors.fill: parent
            active: root.currentIndex === 21
            visible: active
            focus: active

            sourceComponent: PowerSleepTab {}

            onActiveChanged: {
                if (active && item) {
                    Qt.callLater(() => item.forceActiveFocus());
                }
            }
        }

        Loader {
            id: widgetsLoader
            anchors.fill: parent
            active: root.currentIndex === 22
            visible: active
            focus: active

            sourceComponent: WidgetsTab {
                parentModal: root.parentModal
            }

            onActiveChanged: {
                if (active && item) {
                    Qt.callLater(() => item.forceActiveFocus());
                }
            }
        }
    }
}
