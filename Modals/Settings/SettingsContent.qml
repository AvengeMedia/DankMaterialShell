import QtQuick
import qs.Common
import qs.Modules.Settings

Item {
    id: root

    property int currentIndex: 0
    property var parentModal: null

    Rectangle {
        anchors.fill: parent
        anchors.leftMargin: 0
        anchors.rightMargin: Theme.spacingS
        anchors.bottomMargin: Theme.spacingM
        anchors.topMargin: 0
        color: "transparent"

        Loader {
            id: personalizationLoader

            anchors.fill: parent
            active: root.currentIndex === 0
            visible: active
            asynchronous: true

            sourceComponent: Component {
                PersonalizationTab {
                    parentModal: root.parentModal
                }

            }

        }

        Loader {
            id: timeLoader

            anchors.fill: parent
            active: root.currentIndex === 1
            visible: active
            asynchronous: true

            sourceComponent: TimeTab {
            }

        }

        Loader {
            id: weatherLoader

            anchors.fill: parent
            active: root.currentIndex === 2
            visible: active
            asynchronous: true

            sourceComponent: WeatherTab {
            }

        }

        Loader {
            id: topBarLoader

            anchors.fill: parent
            active: root.currentIndex === 3
            visible: active
            asynchronous: true

            sourceComponent: TopBarTab {
            }

        }

        Loader {
            id: widgetsLoader

            anchors.fill: parent
            active: root.currentIndex === 4
            visible: active
            asynchronous: true

            sourceComponent: WidgetTweaksTab {
            }

        }

        Loader {
            id: dockLoader

            anchors.fill: parent
            active: root.currentIndex === 5
            visible: active
            asynchronous: true

            sourceComponent: Component {
                DockTab {
                }

            }

        }

        Loader {
            id: displaysLoader

            anchors.fill: parent
            active: root.currentIndex === 6
            visible: active
            asynchronous: true

            sourceComponent: DisplaysTab {
            }

        }

        Loader {
            id: recentAppsLoader

            anchors.fill: parent
            active: root.currentIndex === 7
            visible: active
            asynchronous: true

            sourceComponent: RecentAppsTab {
            }

        }

        Loader {
            id: themeColorsLoader

            anchors.fill: parent
            active: root.currentIndex === 8
            visible: active
            asynchronous: true

            sourceComponent: ThemeColorsTab {
            }

        }

        Loader {
            id: aboutLoader

            anchors.fill: parent
            active: root.currentIndex === 9
            visible: active
            asynchronous: true

            sourceComponent: AboutTab {
            }

        }

    }

}
