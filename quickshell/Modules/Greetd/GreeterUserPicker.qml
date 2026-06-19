import QtQuick
import QtQuick.Layouts
import qs.Common
import qs.Services
import qs.Widgets

Item {
    id: root

    property bool expanded: false
    property int maxExpandedHeight: 400

    signal userSelected(string username)
    signal toggleRequested()

    readonly property int rowHeight: 52
    readonly property int collapsedBarHeight: 36
    readonly property int expandedListHeight: {
        if (!expanded)
            return 0;
        const count = GreeterUsersService.users.length;
        if (count === 0)
            return 0;
        const fullHeight = count * rowHeight + Math.max(0, count - 1) * Theme.spacingXS;
        return Math.min(maxExpandedHeight, fullHeight);
    }

    function encodeFileUrl(path) {
        if (!path)
            return "";
        return "file://" + path.split("/").map(s => encodeURIComponent(s)).join("/");
    }

    function profileImageSource(username) {
        const path = GreeterUsersService.profileImagePath(username);
        if (path)
            return encodeFileUrl(path);
        return "";
    }

    implicitHeight: expanded ? expandedListHeight : collapsedBarHeight
    implicitWidth: parent ? parent.width : 320

    RowLayout {
        anchors.left: parent.left
        anchors.right: parent.right
        anchors.verticalCenter: expanded ? undefined : parent.verticalCenter
        height: collapsedBarHeight
        visible: !expanded && !!GreeterState.username
        spacing: Theme.spacingM

        StyledText {
            Layout.fillWidth: true
            text: GreeterUsersService.optionLabel(GreeterState.username)
            color: Theme.surfaceText
            font.pixelSize: Theme.fontSizeMedium
            elide: Text.ElideRight
        }

        DankIcon {
            name: "expand_more"
            size: 20
            color: Theme.surfaceVariantText
        }

        MouseArea {
            anchors.fill: parent
            cursorShape: Qt.PointingHandCursor
            onClicked: root.toggleRequested()
        }
    }

    Item {
        anchors.left: parent.left
        anchors.right: parent.right
        height: collapsedBarHeight
        visible: !expanded && !GreeterState.username

        DankIcon {
            anchors.centerIn: parent
            name: "expand_more"
            size: 20
            color: Theme.surfaceVariantText
        }

        MouseArea {
            anchors.fill: parent
            cursorShape: Qt.PointingHandCursor
            onClicked: root.toggleRequested()
        }
    }

    DankListView {
        id: userListView

        anchors.left: parent.left
        anchors.right: parent.right
        anchors.top: parent.top
        height: expandedListHeight
        visible: expanded
        clip: true
        interactive: contentHeight > height
        spacing: Theme.spacingXS
        model: GreeterUsersService.users

        delegate: Rectangle {
            id: userRow

            required property var modelData
            required property int index

            width: userListView.width
            height: root.rowHeight
            radius: Theme.cornerRadius
            color: userRowMouse.containsMouse ? Theme.surfacePressed : "transparent"
            border.color: GreeterState.username === userRow.modelData.username ? Theme.primary : "transparent"
            border.width: GreeterState.username === userRow.modelData.username ? 1 : 0

            RowLayout {
                anchors.fill: parent
                anchors.leftMargin: Theme.spacingS
                anchors.rightMargin: Theme.spacingS
                spacing: Theme.spacingM

                Item {
                    Layout.preferredWidth: 36
                    Layout.preferredHeight: 36

                    DankCircularImage {
                        anchors.fill: parent
                        imageSource: root.profileImageSource(userRow.modelData.username)
                        fallbackIcon: "person"
                    }
                }

                StyledText {
                    Layout.fillWidth: true
                    text: GreeterUsersService.optionLabel(userRow.modelData.username)
                    color: Theme.surfaceText
                    font.pixelSize: Theme.fontSizeMedium
                    elide: Text.ElideRight
                }
            }

            MouseArea {
                id: userRowMouse

                anchors.fill: parent
                hoverEnabled: true
                cursorShape: Qt.PointingHandCursor
                onClicked: root.userSelected(userRow.modelData.username)
            }
        }
    }
}
