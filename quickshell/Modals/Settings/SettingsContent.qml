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
        anchors.rightMargin: 0
        anchors.bottomMargin: 0
        anchors.topMargin: 0
        color: "transparent"

        Loader {
            id: personalizationLoader

            anchors.fill: parent
            active: root.currentIndex === 0
            visible: active
            focus: active

            sourceComponent: Component {
                PersonalizationTab {
                    parentModal: root.parentModal
                }

            }

            onActiveChanged: {
                if (active && item) {
                    Qt.callLater(() => item.forceActiveFocus())
                }
            }

        }

        Loader {
            id: timeWeatherLoader

            anchors.fill: parent
            active: root.currentIndex === 1
            visible: active
            focus: active

            sourceComponent: TimeWeatherTab {
            }

            onActiveChanged: {
                if (active && item) {
                    Qt.callLater(() => item.forceActiveFocus())
                }
            }

        }

        Loader {
            id: topBarLoader

            anchors.fill: parent
            active: root.currentIndex === 2
            visible: active
            focus: active

            sourceComponent: DankBarTab {
                parentModal: root.parentModal
            }

            onActiveChanged: {
                if (active && item) {
                    Qt.callLater(() => item.forceActiveFocus())
                }
            }

        }

        Loader {
            id: widgetsLoader

            anchors.fill: parent
            active: root.currentIndex === 3
            visible: active
            focus: active

            sourceComponent: WidgetTweaksTab {
            }

            onActiveChanged: {
                if (active && item) {
                    Qt.callLater(() => item.forceActiveFocus())
                }
            }

        }

        Loader {
            id: dockLoader

            anchors.fill: parent
            active: root.currentIndex === 4
            visible: active
            focus: active

            sourceComponent: Component {
                DockTab {
                }

            }

            onActiveChanged: {
                if (active && item) {
                    Qt.callLater(() => item.forceActiveFocus())
                }
            }

        }

        Loader {
            id: displaysLoader

            anchors.fill: parent
            active: root.currentIndex === 5
            visible: active
            focus: active

            sourceComponent: DisplaysTab {
            }

            onActiveChanged: {
                if (active && item) {
                    Qt.callLater(() => item.forceActiveFocus())
                }
            }

        }

        Loader {
            id: launcherLoader

            anchors.fill: parent
            active: root.currentIndex === 6
            visible: active
            focus: active

            sourceComponent: LauncherTab {
            }

            onActiveChanged: {
                if (active && item) {
                    Qt.callLater(() => item.forceActiveFocus())
                }
            }

        }

        Loader {
            id: themeColorsLoader

            anchors.fill: parent
            active: root.currentIndex === 7
            visible: active
            focus: active

            sourceComponent: ThemeColorsTab {
            }

            onActiveChanged: {
                if (active && item) {
                    Qt.callLater(() => item.forceActiveFocus())
                }
            }

        }

        Loader {
            id: powerLoader

            anchors.fill: parent
            active: root.currentIndex === 8
            visible: active
            focus: active

            sourceComponent: PowerSettings {
            }

            onActiveChanged: {
                if (active && item) {
                    Qt.callLater(() => item.forceActiveFocus())
                }
            }

        }

        Loader {
            id: pluginsLoader

            anchors.fill: parent
            active: root.currentIndex === 9
            visible: active
            focus: active

            sourceComponent: PluginsTab {
                parentModal: root.parentModal
            }

            onActiveChanged: {
                if (active && item) {
                    Qt.callLater(() => item.forceActiveFocus())
                }
            }

        }

        Loader {
            id: aboutLoader

            anchors.fill: parent
            active: root.currentIndex === 10
            visible: active
            focus: active

            sourceComponent: AboutTab {
            }

            onActiveChanged: {
                if (active && item) {
                    Qt.callLater(() => item.forceActiveFocus())
                }
            }

        }

    }

}
