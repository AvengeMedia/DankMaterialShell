import QtQuick
import QtQuick.Controls
import qs.Common
import qs.Services
import qs.Widgets

Column {
    id: root

    property var contextMenu: null

    Component.onCompleted: {
        DgopService.addRef(["processes"]);
    }
    Component.onDestruction: {
        DgopService.removeRef(["processes"]);
    }

    Item {
        id: columnHeaders

        width: parent.width
        anchors.leftMargin: 8
        height: 24

        Rectangle {
            width: 60
            height: 20
            color: {
                if (DgopService.currentSort === "name") {
                    return Qt.rgba(Theme.primary.r, Theme.primary.g, Theme.primary.b, 0.12);
                }
                return processHeaderArea.containsMouse ? Qt.rgba(Theme.surfaceText.r, Theme.surfaceText.g, Theme.surfaceText.b, 0.08) : Theme.withAlpha(Theme.surfaceText, 0);
            }
            radius: Theme.cornerRadius
            anchors.left: parent.left
            anchors.leftMargin: 0
            anchors.verticalCenter: parent.verticalCenter

            StyledText {
                text: I18n.tr("Process")
                font.pixelSize: Theme.fontSizeSmall
                font.family: SettingsData.monoFontFamily
                font.weight: DgopService.currentSort === "name" ? Font.Bold : Font.Medium
                color: Theme.surfaceText
                opacity: DgopService.currentSort === "name" ? 1 : 0.7
                anchors.centerIn: parent
            }

            MouseArea {
                id: processHeaderArea

                anchors.fill: parent
                hoverEnabled: true
                cursorShape: Qt.PointingHandCursor
                onClicked: {
                    DgopService.setSortBy("name");
                }
            }

            Behavior on color {
                ColorAnimation {
                    duration: Theme.shortDuration
                }

            }

        }

        Rectangle {
            width: 80
            height: 20
            color: {
                if (DgopService.currentSort === "cpu") {
                    return Qt.rgba(Theme.primary.r, Theme.primary.g, Theme.primary.b, 0.12);
                }
                return cpuHeaderArea.containsMouse ? Qt.rgba(Theme.surfaceText.r, Theme.surfaceText.g, Theme.surfaceText.b, 0.08) : Theme.withAlpha(Theme.surfaceText, 0);
            }
            radius: Theme.cornerRadius
            anchors.right: parent.right
            anchors.rightMargin: 200
            anchors.verticalCenter: parent.verticalCenter

            StyledText {
                text: "CPU"
                font.pixelSize: Theme.fontSizeSmall
                font.family: SettingsData.monoFontFamily
                font.weight: DgopService.currentSort === "cpu" ? Font.Bold : Font.Medium
                color: Theme.surfaceText
                opacity: DgopService.currentSort === "cpu" ? 1 : 0.7
                anchors.centerIn: parent
            }

            MouseArea {
                id: cpuHeaderArea

                anchors.fill: parent
                hoverEnabled: true
                cursorShape: Qt.PointingHandCursor
                onClicked: {
                    DgopService.setSortBy("cpu");
                }
            }

            Behavior on color {
                ColorAnimation {
                    duration: Theme.shortDuration
                }

            }

        }

        Rectangle {
            width: 80
            height: 20
            color: {
                if (DgopService.currentSort === "memory") {
                    return Qt.rgba(Theme.primary.r, Theme.primary.g, Theme.primary.b, 0.12);
                }
                return memoryHeaderArea.containsMouse ? Qt.rgba(Theme.surfaceText.r, Theme.surfaceText.g, Theme.surfaceText.b, 0.08) : Theme.withAlpha(Theme.surfaceText, 0);
            }
            radius: Theme.cornerRadius
            anchors.right: parent.right
            anchors.rightMargin: 112
            anchors.verticalCenter: parent.verticalCenter

            StyledText {
                text: "RAM"
                font.pixelSize: Theme.fontSizeSmall
                font.family: SettingsData.monoFontFamily
                font.weight: DgopService.currentSort === "memory" ? Font.Bold : Font.Medium
                color: Theme.surfaceText
                opacity: DgopService.currentSort === "memory" ? 1 : 0.7
                anchors.centerIn: parent
            }

            MouseArea {
                id: memoryHeaderArea

                anchors.fill: parent
                hoverEnabled: true
                cursorShape: Qt.PointingHandCursor
                onClicked: {
                    DgopService.setSortBy("memory");
                }
            }

            Behavior on color {
                ColorAnimation {
                    duration: Theme.shortDuration
                }

            }

        }

        Rectangle {
            width: 50
            height: 20
            color: {
                if (DgopService.currentSort === "pid") {
                    return Qt.rgba(Theme.primary.r, Theme.primary.g, Theme.primary.b, 0.12);
                }
                return pidHeaderArea.containsMouse ? Qt.rgba(Theme.surfaceText.r, Theme.surfaceText.g, Theme.surfaceText.b, 0.08) : Theme.withAlpha(Theme.surfaceText, 0);
            }
            radius: Theme.cornerRadius
            anchors.right: parent.right
            anchors.rightMargin: 53
            anchors.verticalCenter: parent.verticalCenter

            StyledText {
                text: "PID"
                font.pixelSize: Theme.fontSizeSmall
                font.family: SettingsData.monoFontFamily
                font.weight: DgopService.currentSort === "pid" ? Font.Bold : Font.Medium
                color: Theme.surfaceText
                opacity: DgopService.currentSort === "pid" ? 1 : 0.7
                horizontalAlignment: Text.AlignHCenter
                anchors.centerIn: parent
            }

            MouseArea {
                id: pidHeaderArea

                anchors.fill: parent
                hoverEnabled: true
                cursorShape: Qt.PointingHandCursor
                onClicked: {
                    DgopService.setSortBy("pid");
                }
            }

            Behavior on color {
                ColorAnimation {
                    duration: Theme.shortDuration
                }

            }

        }

        Rectangle {
            width: 28
            height: 28
            radius: Theme.cornerRadius
            color: sortOrderArea.containsMouse ? Qt.rgba(Theme.surfaceText.r, Theme.surfaceText.g, Theme.surfaceText.b, 0.08) : Theme.withAlpha(Theme.surfaceText, 0)
            anchors.right: parent.right
            anchors.rightMargin: 8
            anchors.verticalCenter: parent.verticalCenter

            StyledText {
                text: DgopService.sortDescending ? "↓" : "↑"
                font.pixelSize: Theme.fontSizeMedium
                color: Theme.surfaceText
                anchors.centerIn: parent
            }

            MouseArea {
                // TODO: Re-implement sort order toggle

                id: sortOrderArea

                anchors.fill: parent
                hoverEnabled: true
                cursorShape: Qt.PointingHandCursor
                onClicked: {
                }
            }

            Behavior on color {
                ColorAnimation {
                    duration: Theme.shortDuration
                }

            }

        }

    }

    DankListView {
        id: processListView

        property string keyRoleName: "pid"

        width: parent.width
        height: parent.height - columnHeaders.height
        clip: true
        spacing: 4
        model: DgopService.processes

        delegate: ProcessListItem {
            process: modelData
            contextMenu: root.contextMenu
        }

    }

}
