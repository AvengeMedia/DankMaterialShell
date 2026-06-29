import QtQuick
import QtQuick.Layouts
import qs.Common
import qs.Services
import qs.Widgets

Item {
    id: root

    LayoutMirroring.enabled: I18n.isRtl
    LayoutMirroring.childrenInherit: true

    property bool expanded: false
    property int maxExpandedHeight: 400
    property bool autoLoginVisible: false
    property bool autoLoginChecked: false
    property bool manualEntryVisible: false

    signal userSelected(string username)
    signal toggleRequested
    signal autoLoginToggled
    signal manualEntryRequested

    readonly property int rowHeight: 52
    readonly property int collapsedBarHeight: 36
    readonly property int actionRowHeight: 44

    readonly property int userListFullHeight: {
        const count = GreeterUsersService.users.length;
        if (count === 0)
            return 0;
        return count * rowHeight + Math.max(0, count - 1) * Theme.spacingXS;
    }
    readonly property int manualEntryBlockHeight: manualEntryVisible ? actionRowHeight + Theme.spacingXS : 0
    readonly property int autoLoginBlockHeight: autoLoginVisible ? actionRowHeight + Theme.spacingXS : 0
    readonly property int expandedContentHeight: {
        if (!expanded)
            return 0;
        if (GreeterUsersService.users.length === 0 && !autoLoginVisible && !manualEntryVisible)
            return 0;
        return Math.min(maxExpandedHeight, userListFullHeight + manualEntryBlockHeight + autoLoginBlockHeight);
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

    implicitHeight: expanded ? expandedContentHeight : collapsedBarHeight
    implicitWidth: parent ? parent.width : 320

    Item {
        anchors.left: parent.left
        anchors.right: parent.right
        anchors.verticalCenter: parent.verticalCenter
        height: collapsedBarHeight
        visible: !expanded

        RowLayout {
            anchors.fill: parent
            spacing: Theme.spacingM

            StyledText {
                Layout.fillWidth: true
                text: GreeterState.username ? GreeterUsersService.optionLabel(GreeterState.username) : I18n.tr("Select user...", "greeter user picker placeholder")
                color: GreeterState.username ? Theme.surfaceText : Theme.surfaceVariantText
                font.pixelSize: Theme.fontSizeMedium
                elide: Text.ElideRight
            }

            DankIcon {
                Layout.alignment: Qt.AlignVCenter
                name: "expand_more"
                size: 20
                color: Theme.surfaceVariantText
            }
        }

        MouseArea {
            anchors.fill: parent
            cursorShape: Qt.PointingHandCursor
            onClicked: root.toggleRequested()
        }
    }

    Column {
        anchors.left: parent.left
        anchors.right: parent.right
        anchors.top: parent.top
        height: root.expandedContentHeight
        visible: expanded
        spacing: Theme.spacingXS

        DankListView {
            id: userListView

            width: parent.width
            height: parent.height - root.manualEntryBlockHeight - root.autoLoginBlockHeight
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
                color: userRowMouse.containsMouse ? Theme.surfacePressed : Theme.withAlpha(Theme.surfacePressed, 0)
                border.color: GreeterState.username === userRow.modelData.username ? Theme.primary : Theme.withAlpha(Theme.primary, 0)
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

        Rectangle {
            width: parent.width
            height: root.actionRowHeight
            visible: root.manualEntryVisible
            radius: Theme.cornerRadius
            color: manualEntryRowMouse.containsMouse ? Theme.surfacePressed : Theme.withAlpha(Theme.surfacePressed, 0)

            RowLayout {
                anchors.fill: parent
                anchors.leftMargin: Theme.spacingS
                anchors.rightMargin: Theme.spacingS
                spacing: Theme.spacingM

                DankIcon {
                    Layout.alignment: Qt.AlignVCenter
                    name: "person_add"
                    size: 20
                    color: Theme.surfaceVariantText
                }

                StyledText {
                    Layout.fillWidth: true
                    text: I18n.tr("Not listed?", "greeter link to switch to manual username entry")
                    color: Theme.surfaceText
                    font.pixelSize: Theme.fontSizeMedium
                    elide: Text.ElideRight
                }
            }

            MouseArea {
                id: manualEntryRowMouse

                anchors.fill: parent
                hoverEnabled: true
                cursorShape: Qt.PointingHandCursor
                onClicked: root.manualEntryRequested()
            }
        }

        Rectangle {
            width: parent.width
            height: root.actionRowHeight
            visible: root.autoLoginVisible
            radius: Theme.cornerRadius
            color: autoLoginRowMouse.containsMouse ? Theme.surfacePressed : Theme.withAlpha(Theme.surfacePressed, 0)

            RowLayout {
                anchors.fill: parent
                anchors.leftMargin: Theme.spacingS
                anchors.rightMargin: Theme.spacingS
                spacing: Theme.spacingM

                DankIcon {
                    Layout.alignment: Qt.AlignVCenter
                    name: root.autoLoginChecked ? "check_box" : "check_box_outline_blank"
                    size: 20
                    color: root.autoLoginChecked ? Theme.primary : Theme.surfaceVariantText
                }

                StyledText {
                    Layout.fillWidth: true
                    text: I18n.tr("Auto-login")
                    color: Theme.surfaceText
                    font.pixelSize: Theme.fontSizeMedium
                    elide: Text.ElideRight
                }
            }

            MouseArea {
                id: autoLoginRowMouse

                anchors.fill: parent
                hoverEnabled: true
                cursorShape: Qt.PointingHandCursor
                onClicked: root.autoLoginToggled()
            }
        }
    }
}
