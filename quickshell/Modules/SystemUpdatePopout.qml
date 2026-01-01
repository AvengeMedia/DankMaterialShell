import QtQuick
import qs.Common
import qs.Services
import qs.Widgets

DankPopout {
    id: systemUpdatePopout

    layerNamespace: "dms:system-update"

    property var parentWidget: null
    property var triggerScreen: null

    Ref {
        service: SystemUpdateService
    }

    popupWidth: 400
    popupHeight: 500
    triggerWidth: 55
    positioning: ""
    screen: triggerScreen
    shouldBeVisible: false

    onBackgroundClicked: close()

    onShouldBeVisibleChanged: {
        if (shouldBeVisible) {
            if (SystemUpdateService.updateCount === 0 && !SystemUpdateService.isChecking) {
                SystemUpdateService.checkForUpdates();
            }
        }
    }

    content: Component {
        Rectangle {
            id: updaterPanel

            property bool newsExpanded: false

            color: "transparent"
            radius: Theme.cornerRadius
            antialiasing: true
            smooth: true

            Repeater {
                model: [
                    {
                        "margin": -3,
                        "color": Qt.rgba(0, 0, 0, 0.05),
                        "z": -3
                    },
                    {
                        "margin": -2,
                        "color": Qt.rgba(0, 0, 0, 0.08),
                        "z": -2
                    },
                    {
                        "margin": 0,
                        "color": Qt.rgba(Theme.outline.r, Theme.outline.g, Theme.outline.b, 0.12),
                        "z": -1
                    }
                ]
                Rectangle {
                    anchors.fill: parent
                    anchors.margins: modelData.margin
                    color: "transparent"
                    radius: parent.radius + Math.abs(modelData.margin)
                    border.color: modelData.color
                    border.width: 0
                    z: modelData.z
                }
            }

            Column {
                width: parent.width - Theme.spacingL * 2
                height: parent.height - Theme.spacingL * 2
                x: Theme.spacingL
                y: Theme.spacingL
                spacing: Theme.spacingL

                Item {
                    width: parent.width
                    height: 40

                    StyledText {
                        text: updaterPanel.newsExpanded ? I18n.tr("Latest News") : I18n.tr("System Updates")
                        font.pixelSize: Theme.fontSizeLarge
                        color: Theme.surfaceText
                        font.weight: Font.Medium
                        anchors.left: parent.left
                        anchors.verticalCenter: parent.verticalCenter

                        Behavior on text {
                            SequentialAnimation {
                                NumberAnimation {
                                    target: parent
                                    property: "opacity"
                                    to: 0
                                    duration: Theme.shortDuration / 2
                                }
                                PropertyAction {}
                                NumberAnimation {
                                    target: parent
                                    property: "opacity"
                                    to: 1
                                    duration: Theme.shortDuration / 2
                                }
                            }
                        }
                    }

                    Row {
                        anchors.right: parent.right
                        anchors.verticalCenter: parent.verticalCenter
                        spacing: Theme.spacingXS

                        DankActionButton {
                            id: backToUpdatesButton
                            visible: updaterPanel.newsExpanded
                            opacity: visible ? 1.0 : 0.0
                            buttonSize: 28
                            iconName: "arrow_back"
                            iconSize: 18
                            iconColor: Theme.primary
                            onClicked: {
                                updaterPanel.newsExpanded = false
                            }

                            Behavior on opacity {
                                NumberAnimation { duration: Theme.shortDuration }
                            }
                        }

                        StyledText {
                            anchors.verticalCenter: parent.verticalCenter
                            visible: !updaterPanel.newsExpanded
                            opacity: visible ? 1.0 : 0.0
                            text: {
                                if (SystemUpdateService.isChecking)
                                    return "Checking...";
                                if (SystemUpdateService.hasError)
                                    return "Error";
                                if (SystemUpdateService.updateCount === 0)
                                    return "Up to date";
                                return SystemUpdateService.updateCount + " updates";
                            }
                            font.pixelSize: Theme.fontSizeMedium
                            color: {
                                if (SystemUpdateService.hasError)
                                    return Theme.error;
                                return Theme.surfaceText;
                            }

                            Behavior on opacity {
                                NumberAnimation { duration: Theme.shortDuration }
                            }
                        }

                        DankActionButton {
                            id: checkForUpdatesButton
                            visible: !updaterPanel.newsExpanded
                            // opacity: visible ? 1.0 : 0.0
                            buttonSize: 28
                            iconName: "refresh"
                            iconSize: 18
                            z: 15
                            iconColor: Theme.surfaceText
                            enabled: !SystemUpdateService.isChecking
                            onClicked: {
                                SystemUpdateService.checkForUpdates();
                            }

                            Behavior on opacity {
                                NumberAnimation { duration: Theme.shortDuration }
                            }

                            RotationAnimation {
                                target: checkForUpdatesButton
                                property: "rotation"
                                from: 0
                                to: 360
                                duration: 1000
                                running: SystemUpdateService.isChecking
                                loops: Animation.Infinite

                                onRunningChanged: {
                                    if (!running) {
                                        checkForUpdatesButton.rotation = 0;
                                    }
                                }
                            }
                        }
                    }
                }

                Rectangle {
                    width: parent.width
                    height: {
                        let usedHeight = 40 + Theme.spacingL;
                        usedHeight += 48 + Theme.spacingL;
                        usedHeight += latestNewsTicker.visible ? latestNewsTicker.height + Theme.spacingS : 0;
                        return parent.height - usedHeight;
                    }
                    radius: Theme.cornerRadius
                    color: Qt.rgba(Theme.surfaceVariant.r, Theme.surfaceVariant.g, Theme.surfaceVariant.b, 0.1)
                    border.color: Qt.rgba(Theme.outline.r, Theme.outline.g, Theme.outline.b, 0.05)
                    border.width: 0

                    // Updates view
                    Column {
                        anchors.fill: parent
                        anchors.margins: Theme.spacingM
                        anchors.rightMargin: 0
                        opacity: updaterPanel.newsExpanded ? 0 : 1
                        visible: opacity > 0

                        Behavior on opacity {
                            NumberAnimation { duration: Theme.shortDuration * 2 }
                        }

                        StyledText {
                            id: statusText
                            width: parent.width
                            text: {
                                if (SystemUpdateService.hasError) {
                                    return "Failed to check for updates:\n" + SystemUpdateService.errorMessage;
                                }
                                if (!SystemUpdateService.helperAvailable) {
                                    return "No package manager found. Please install 'paru' or 'yay' on Arch-based systems to check for updates.";
                                }
                                if (SystemUpdateService.isChecking) {
                                    return "Checking for updates...";
                                }
                                if (SystemUpdateService.updateCount === 0) {
                                    return "Your system is up to date!";
                                }
                                return `Found ${SystemUpdateService.updateCount} packages to update:`;
                            }
                            font.pixelSize: Theme.fontSizeMedium
                            color: {
                                if (SystemUpdateService.hasError)
                                    return Theme.errorText;
                                return Theme.surfaceText;
                            }
                            wrapMode: Text.WordWrap
                            visible: SystemUpdateService.updateCount === 0 || SystemUpdateService.hasError || SystemUpdateService.isChecking
                        }

                        DankListView {
                            id: packagesList

                            width: parent.width
                            height: parent.height - (SystemUpdateService.updateCount === 0 || SystemUpdateService.hasError || SystemUpdateService.isChecking ? statusText.height + Theme.spacingM : 0)
                            visible: SystemUpdateService.updateCount > 0 && !SystemUpdateService.isChecking && !SystemUpdateService.hasError
                            clip: true
                            spacing: Theme.spacingXS

                            model: SystemUpdateService.availableUpdates

                            delegate: Rectangle {
                                width: ListView.view.width - Theme.spacingM
                                height: 48
                                radius: Theme.cornerRadius
                                color: packageMouseArea.containsMouse ? Theme.primaryHoverLight : "transparent"
                                border.color: Theme.outlineLight
                                border.width: 0

                                Row {
                                    anchors.fill: parent
                                    anchors.margins: Theme.spacingM
                                    spacing: Theme.spacingM

                                    Column {
                                        anchors.verticalCenter: parent.verticalCenter
                                        width: parent.width - Theme.spacingM
                                        spacing: 2

                                        StyledText {
                                            width: parent.width
                                            text: modelData.name || ""
                                            font.pixelSize: Theme.fontSizeMedium
                                            color: Theme.surfaceText
                                            font.weight: Font.Medium
                                            elide: Text.ElideRight
                                        }

                                        StyledText {
                                            width: parent.width
                                            text: `${modelData.currentVersion} → ${modelData.newVersion}`
                                            font.pixelSize: Theme.fontSizeSmall
                                            color: Theme.surfaceVariantText
                                            elide: Text.ElideRight
                                        }
                                    }
                                }

                                Behavior on color {
                                    ColorAnimation {
                                        duration: Theme.shortDuration
                                    }
                                }

                                MouseArea {
                                    id: packageMouseArea

                                    anchors.fill: parent
                                    hoverEnabled: true
                                    cursorShape: Qt.PointingHandCursor
                                }
                            }
                        }
                    }

                    // Latest news view
                    Column {
                        anchors.fill: parent
                        anchors.margins: Theme.spacingS
                        anchors.rightMargin: 0
                        opacity: updaterPanel.newsExpanded ? 1 : 0
                        visible: opacity > 0

                        Behavior on opacity {
                            NumberAnimation { duration: Theme.shortDuration * 2 }
                        }

                        DankListView {
                            id: expandedNewsList
                            width: parent.width
                            height: parent.height
                            clip: true
                            spacing: Theme.spacingM
                            model: SystemUpdateService.latestNews
                            boundsBehavior: Flickable.StopAtBounds

                            delegate: Rectangle {
                                id: newsItem
                                width: ListView.view.width - Theme.spacingS
                                radius: Theme.cornerRadius
                                color: newsMouseArea.containsMouse ? Qt.rgba(Theme.surfaceVariant.r, Theme.surfaceVariant.g, Theme.surfaceVariant.b, 0.3) : Qt.rgba(Theme.surfaceVariant.r, Theme.surfaceVariant.g, Theme.surfaceVariant.b, 0.15)
                                border.color: newsItem.expanded ? Qt.rgba(Theme.primary.r, Theme.primary.g, Theme.primary.b, 0.2) : Qt.rgba(Theme.outline.r, Theme.outline.g, Theme.outline.b, 0.08)
                                border.width: 1

                                property bool expanded: false

                                height: newsContentColumn.height + Theme.spacingS * 2

                                Behavior on height {
                                    NumberAnimation {
                                        duration: Theme.mediumDuration
                                        easing.type: Easing.OutCubic
                                    }
                                }

                                Behavior on color {
                                    ColorAnimation {
                                        duration: Theme.shortDuration
                                    }
                                }

                                Behavior on border.color {
                                    ColorAnimation {
                                        duration: Theme.shortDuration
                                    }
                                }

                                Column {
                                    id: newsContentColumn
                                    anchors.left: parent.left
                                    anchors.right: parent.right
                                    anchors.top: parent.top
                                    anchors.margins: Theme.spacingS
                                    spacing: Theme.spacingXS

                                    // Header row with title and expand icon
                                    Row {
                                        width: parent.width
                                        spacing: Theme.spacingS

                                        Column {
                                            width: parent.width - expandIndicator.width
                                            spacing: 2

                                            StyledText {
                                                width: parent.width
                                                text: modelData.title || ""
                                                font.pixelSize: Theme.fontSizeMedium
                                                color: Theme.surfaceText
                                                font.weight: Font.Medium
                                                wrapMode: Text.WordWrap
                                            }

                                            StyledText {
                                                width: parent.width
                                                text: modelData.pubDate || ""
                                                opacity: 0.7
                                                font.pixelSize: Theme.fontSizeSmall
                                                color: Theme.surfaceVariantText
                                                visible: modelData.pubDate && modelData.pubDate.length > 0
                                                wrapMode: Text.WordWrap
                                            }
                                        }

                                        // Expand/collapse indicator
                                        Item {
                                            id: expandIndicator
                                            visible: modelData.description && modelData.description.length > 0
                                            width: visible ? expandIcon.width : 0
                                            height: visible ? expandIcon.height : 0
                                            anchors.verticalCenter: parent.verticalCenter

                                            DankIcon {
                                                id: expandIcon
                                                name: newsItem.expanded ? "expand_less" : "expand_more"
                                                size: Theme.iconSizeSmall
                                                opacity: 0.7
                                            }
                                        }
                                    }

                                    // Separator between header and description
                                    Rectangle {
                                        width: parent.width
                                        height: 1
                                        color: Qt.rgba(Theme.outline.r, Theme.outline.g, Theme.outline.b, 0.15)
                                        visible: newsItem.expanded && modelData.description && modelData.description.length > 0
                                        opacity: newsItem.expanded ? 1 : 0

                                        Behavior on opacity {
                                            NumberAnimation {
                                                duration: Theme.mediumDuration
                                                easing.type: Easing.InOutQuad
                                            }
                                        }
                                    }

                                    // Description
                                    StyledText {
                                        width: parent.width
                                        text: modelData.description || ""
                                        font.pixelSize: Theme.fontSizeSmall
                                        color: Theme.surfaceVariantText
                                        wrapMode: Text.WordWrap
                                        visible: modelData.description && modelData.description.length > 0 && newsItem.expanded
                                        opacity: newsItem.expanded ? 1 : 0

                                        Behavior on opacity {
                                            NumberAnimation {
                                                duration: Theme.mediumDuration
                                                easing.type: Easing.InOutQuad
                                            }
                                        }
                                    }

                                    // Footer with external link
                                    Item {
                                        width: parent.width
                                        visible: newsItem.expanded && modelData.link
                                        // spacing: Theme.spacingS
                                        height: externalLinkButton.height

                                        // External link button (shown when expanded and link exists)
                                        DankActionButton {
                                            id: externalLinkButton
                                            visible: modelData.link && newsItem.expanded
                                            opacity: visible ? 1 : 0
                                            anchors.verticalCenter: parent.verticalCenter
                                            anchors.right: parent.right
                                            buttonSize: 28
                                            iconName: "open_in_new"
                                            iconSize: 14
                                            iconColor: Theme.primary
                                            z: 100
                                            onClicked: {
                                                Qt.openUrlExternally(modelData.link)
                                            }

                                            Behavior on opacity {
                                                NumberAnimation {
                                                    duration: Theme.mediumDuration
                                                    easing.type: Easing.InOutQuad
                                                }
                                            }
                                        }

                                    }
                                }

                                MouseArea {
                                    id: newsMouseArea
                                    anchors.fill: parent
                                    anchors.rightMargin: newsItem.expanded && externalLinkButton.visible ? externalLinkButton.width + Theme.spacingS : 0
                                    hoverEnabled: true
                                    cursorShape: modelData.description && modelData.description.length > 0 ? Qt.PointingHandCursor : Qt.ArrowCursor
                                    enabled: modelData.description && modelData.description.length > 0
                                    onClicked: {
                                        newsItem.expanded = !newsItem.expanded
                                    }
                                }
                            }
                        }
                    }
                }

                // News ticker
                Item {
                    id: latestNewsTicker
                    width: parent.width
                    height: 16
                    visible: SettingsData.updaterShowLatestNews && !updaterPanel.newsExpanded && SystemUpdateService.latestNews && SystemUpdateService.latestNews.length > 0
                    opacity: 0.7

                    Behavior on opacity {
                        NumberAnimation { duration: Theme.shortDuration }
                    }

                    MouseArea {
                        id: tickerMouseArea
                        anchors.fill: parent
                        hoverEnabled: true
                        cursorShape: Qt.PointingHandCursor
                        onClicked: {
                            updaterPanel.newsExpanded = true
                        }
                    }

                    Item {
                        width: parent.width - Theme.spacingM * 2
                        height: parent.height
                        anchors.centerIn: parent

                        Row {
                            width: parent.width
                            height: parent.height
                            spacing: Theme.spacingS

                            StyledText {
                                width: parent.width - extendNewsIcon.width - Theme.spacingS
                                height: parent.height
                                text: SystemUpdateService.latestNews && SystemUpdateService.latestNews.length > 0 ? SystemUpdateService.latestNews[0].title : ""
                                font.pixelSize: Theme.fontSizeSmall
                                color: Theme.surfaceText
                                opacity: tickerMouseArea.containsMouse ? 1.0 : 0.7
                                verticalAlignment: Text.AlignVCenter
                                elide: Text.ElideRight

                                Behavior on opacity {
                                    NumberAnimation { duration: Theme.shortDuration }
                                }
                            }

                            DankIcon {
                                id: extendNewsIcon
                                height: parent.height
                                width: height
                                name: "arrow_forward"
                                size: Theme.iconSizeSmall
                                color: Theme.primary
                                opacity: tickerMouseArea.containsMouse ? 1.0 : 0.7

                                Behavior on opacity {
                                    NumberAnimation { duration: Theme.shortDuration }
                                }
                            }
                        }
                    }
                }

                Row {
                    width: parent.width
                    height: 48
                    spacing: Theme.spacingM

                    Rectangle {
                        width: (parent.width - Theme.spacingM) / 2
                        height: parent.height
                        radius: Theme.cornerRadius
                        color: updateMouseArea.containsMouse ? Theme.primaryHover : Theme.secondaryHover
                        opacity: SystemUpdateService.updateCount > 0 ? 1.0 : 0.5

                        Behavior on color {
                            ColorAnimation {
                                duration: Theme.shortDuration
                            }
                        }

                        Row {
                            anchors.centerIn: parent
                            spacing: Theme.spacingS

                            DankIcon {
                                name: "system_update_alt"
                                size: Theme.iconSize
                                color: Theme.primary
                                anchors.verticalCenter: parent.verticalCenter
                            }

                            StyledText {
                                text: I18n.tr("Update All")
                                font.pixelSize: Theme.fontSizeMedium
                                font.weight: Font.Medium
                                color: Theme.primary
                                anchors.verticalCenter: parent.verticalCenter
                            }
                        }

                        MouseArea {
                            id: updateMouseArea
                            anchors.fill: parent
                            hoverEnabled: true
                            cursorShape: Qt.PointingHandCursor
                            enabled: SystemUpdateService.updateCount > 0
                            onClicked: {
                                SystemUpdateService.runUpdates();
                                systemUpdatePopout.close();
                            }
                        }
                    }

                    Rectangle {
                        width: (parent.width - Theme.spacingM) / 2
                        height: parent.height
                        radius: Theme.cornerRadius
                        color: closeMouseArea.containsMouse ? Theme.errorPressed : Theme.secondaryHover

                        Behavior on color {
                            ColorAnimation {
                                duration: Theme.shortDuration
                            }
                        }

                        Row {
                            anchors.centerIn: parent
                            spacing: Theme.spacingS

                            DankIcon {
                                name: "close"
                                size: Theme.iconSize
                                color: Theme.surfaceText
                                anchors.verticalCenter: parent.verticalCenter
                            }

                            StyledText {
                                text: I18n.tr("Close")
                                font.pixelSize: Theme.fontSizeMedium
                                font.weight: Font.Medium
                                color: Theme.surfaceText
                                anchors.verticalCenter: parent.verticalCenter
                            }
                        }

                        MouseArea {
                            id: closeMouseArea
                            anchors.fill: parent
                            hoverEnabled: true
                            cursorShape: Qt.PointingHandCursor
                            onClicked: {
                                systemUpdatePopout.close();
                            }
                        }
                    }
                }
            }
        }
    }
}
