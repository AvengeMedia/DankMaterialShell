import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import qs.Common
import qs.Modals.Common
import qs.Services
import qs.Widgets

DankModal {
    id: root

    property var allPlugins: []
    property string searchQuery: ""
    property var filteredPlugins: []
    property int selectedIndex: -1
    property bool keyboardNavigationActive: false
    property bool isLoading: false
    property var parentModal: null

    width: 600
    height: 650
    allowStacking: true
    backgroundOpacity: 0
    closeOnEscapeKey: false

    function updateFilteredPlugins() {
        var filtered = []
        var query = searchQuery ? searchQuery.toLowerCase() : ""

        for (var i = 0; i < allPlugins.length; i++) {
            var plugin = allPlugins[i]
            var isFirstParty = plugin.firstParty || false

            if (!SessionData.showThirdPartyPlugins && !isFirstParty) {
                continue
            }

            if (query.length > 0) {
                var name = plugin.name ? plugin.name.toLowerCase() : ""
                var description = plugin.description ? plugin.description.toLowerCase() : ""
                var author = plugin.author ? plugin.author.toLowerCase() : ""

                if (name.indexOf(query) !== -1 ||
                    description.indexOf(query) !== -1 ||
                    author.indexOf(query) !== -1) {
                    filtered.push(plugin)
                }
            } else {
                filtered.push(plugin)
            }
        }

        filteredPlugins = filtered
        selectedIndex = -1
        keyboardNavigationActive = false
    }

    function selectNext() {
        if (filteredPlugins.length === 0) return
        keyboardNavigationActive = true
        selectedIndex = Math.min(selectedIndex + 1, filteredPlugins.length - 1)
    }

    function selectPrevious() {
        if (filteredPlugins.length === 0) return
        keyboardNavigationActive = true
        selectedIndex = Math.max(selectedIndex - 1, -1)
        if (selectedIndex === -1) {
            keyboardNavigationActive = false
        }
    }

    function installPlugin(pluginName) {
        ToastService.showInfo("Installing plugin: " + pluginName)
        DMSService.install(pluginName, response => {
            if (response.error) {
                ToastService.showError("Install failed: " + response.error)
            } else {
                ToastService.showInfo("Plugin installed: " + pluginName)
                PluginService.scanPlugins()
                refreshPlugins()
            }
        })
    }

    function refreshPlugins() {
        isLoading = true
        DMSService.listPlugins()
        if (DMSService.apiVersion >= 8) {
            DMSService.listInstalled()
        }
    }

    function show() {
        if (parentModal) {
            parentModal.shouldHaveFocus = false
        }
        open()
        Qt.callLater(() => {
            if (contentLoader.item && contentLoader.item.searchField) {
                contentLoader.item.searchField.forceActiveFocus()
            }
        })
    }

    function hide() {
        close()
        if (parentModal) {
            parentModal.shouldHaveFocus = Qt.binding(() => {
                return parentModal.shouldBeVisible
            })
        }
    }

    onOpened: {
        refreshPlugins()
    }

    onDialogClosed: () => {
        allPlugins = []
        searchQuery = ""
        filteredPlugins = []
        selectedIndex = -1
        keyboardNavigationActive = false
        isLoading = false
    }

    onBackgroundClicked: () => {
        hide()
    }

    content: Component {
        FocusScope {
            id: browserKeyHandler
            property alias searchField: browserSearchField

            anchors.fill: parent
            focus: true

            Keys.onPressed: event => {
                if (event.key === Qt.Key_Escape) {
                    root.close()
                    event.accepted = true
                } else if (event.key === Qt.Key_Down) {
                    root.selectNext()
                    event.accepted = true
                } else if (event.key === Qt.Key_Up) {
                    root.selectPrevious()
                    event.accepted = true
                }
            }

            Item {
                id: browserContent
                anchors.fill: parent
                anchors.margins: Theme.spacingL

                Item {
                    id: headerArea
                    anchors.left: parent.left
                    anchors.right: parent.right
                    anchors.top: parent.top
                    height: Math.max(headerIcon.height, headerText.height, refreshButton.height, closeButton.height)

                    DankIcon {
                        id: headerIcon
                        name: "store"
                        size: Theme.iconSize
                        color: Theme.primary
                        anchors.left: parent.left
                        anchors.verticalCenter: parent.verticalCenter
                    }

                    StyledText {
                        id: headerText
                        text: I18n.tr("Browse Plugins")
                        font.pixelSize: Theme.fontSizeLarge
                        font.weight: Font.Medium
                        color: Theme.surfaceText
                        anchors.left: headerIcon.right
                        anchors.leftMargin: Theme.spacingM
                        anchors.verticalCenter: parent.verticalCenter
                    }

                    Row {
                        anchors.right: parent.right
                        anchors.verticalCenter: parent.verticalCenter
                        spacing: Theme.spacingXS

                        DankButton {
                            id: thirdPartyButton
                            text: SessionData.showThirdPartyPlugins ? "Hide 3rd Party" : "Show 3rd Party"
                            iconName: SessionData.showThirdPartyPlugins ? "visibility_off" : "visibility"
                            height: 28
                            onClicked: {
                                if (SessionData.showThirdPartyPlugins) {
                                    SessionData.setShowThirdPartyPlugins(false)
                                    root.updateFilteredPlugins()
                                } else {
                                    thirdPartyConfirmModal.open()
                                }
                            }
                        }

                        DankActionButton {
                            id: refreshButton
                            iconName: "refresh"
                            iconSize: 18
                            iconColor: Theme.primary
                            visible: !root.isLoading
                            onClicked: root.refreshPlugins()
                        }

                        DankActionButton {
                            id: closeButton
                            iconName: "close"
                            iconSize: Theme.iconSize - 2
                            iconColor: Theme.outline
                            onClicked: root.close()
                        }
                    }
                }

                StyledText {
                    id: descriptionText
                    anchors.left: parent.left
                    anchors.right: parent.right
                    anchors.top: headerArea.bottom
                    anchors.topMargin: Theme.spacingM
                    text: I18n.tr("Install plugins from the DMS plugin registry")
                    font.pixelSize: Theme.fontSizeSmall
                    color: Theme.outline
                    wrapMode: Text.WordWrap
                }

                DankTextField {
                    id: browserSearchField
                    anchors.left: parent.left
                    anchors.right: parent.right
                    anchors.top: descriptionText.bottom
                    anchors.topMargin: Theme.spacingM
                    height: 48
                    cornerRadius: Theme.cornerRadius
                    backgroundColor: Theme.withAlpha(Theme.surfaceContainerHigh, Theme.popupTransparency)
                    normalBorderColor: Theme.outlineMedium
                    focusedBorderColor: Theme.primary
                    leftIconName: "search"
                    leftIconSize: Theme.iconSize
                    leftIconColor: Theme.surfaceVariantText
                    leftIconFocusedColor: Theme.primary
                    showClearButton: true
                    textColor: Theme.surfaceText
                    font.pixelSize: Theme.fontSizeMedium
                    placeholderText: I18n.tr("Search plugins...")
                    text: root.searchQuery
                    focus: true
                    ignoreLeftRightKeys: true
                    keyForwardTargets: [browserKeyHandler]
                    onTextEdited: {
                        root.searchQuery = text
                        root.updateFilteredPlugins()
                    }
                }

                Item {
                    id: listArea
                    anchors.left: parent.left
                    anchors.right: parent.right
                    anchors.top: browserSearchField.bottom
                    anchors.topMargin: Theme.spacingM
                    anchors.bottom: parent.bottom
                    anchors.bottomMargin: Theme.spacingM

                    Item {
                        anchors.fill: parent
                        visible: root.isLoading

                        Column {
                            anchors.centerIn: parent
                            spacing: Theme.spacingM

                            DankIcon {
                                name: "sync"
                                size: 48
                                color: Theme.primary
                                anchors.horizontalCenter: parent.horizontalCenter

                                RotationAnimator on rotation {
                                    from: 0
                                    to: 360
                                    duration: 1000
                                    loops: Animation.Infinite
                                    running: root.isLoading
                                }
                            }

                            StyledText {
                                text: I18n.tr("Loading plugins...")
                                font.pixelSize: Theme.fontSizeMedium
                                color: Theme.surfaceVariantText
                                anchors.horizontalCenter: parent.horizontalCenter
                            }
                        }
                    }

                    DankListView {
                        id: pluginBrowserList

                        anchors.fill: parent
                        anchors.leftMargin: Theme.spacingM
                        anchors.rightMargin: Theme.spacingM
                        anchors.topMargin: Theme.spacingS
                        anchors.bottomMargin: Theme.spacingS
                        spacing: Theme.spacingS
                        model: root.filteredPlugins
                        clip: true
                        visible: !root.isLoading

                        ScrollBar.vertical: DankScrollbar {
                            id: browserScrollbar
                        }

                        delegate: Rectangle {
                            width: pluginBrowserList.width
                            height: pluginDelegateColumn.implicitHeight + Theme.spacingM * 2
                            radius: Theme.cornerRadius
                            property bool isSelected: root.keyboardNavigationActive && index === root.selectedIndex
                            property bool isInstalled: modelData.installed || false
                            property bool isFirstParty: modelData.firstParty || false
                            color: isSelected ? Theme.primarySelected :
                                   Qt.rgba(Theme.surfaceVariant.r,
                                           Theme.surfaceVariant.g,
                                           Theme.surfaceVariant.b,
                                           0.3)
                            border.color: isSelected ? Theme.primary : Qt.rgba(Theme.outline.r, Theme.outline.g,
                                            Theme.outline.b, 0.2)
                            border.width: isSelected ? 2 : 1

                            Column {
                                id: pluginDelegateColumn
                                anchors.fill: parent
                                anchors.margins: Theme.spacingM
                                spacing: Theme.spacingXS

                                Row {
                                    width: parent.width
                                    spacing: Theme.spacingM

                                    DankIcon {
                                        name: modelData.icon || "extension"
                                        size: Theme.iconSize
                                        color: Theme.primary
                                        anchors.verticalCenter: parent.verticalCenter
                                    }

                                    Column {
                                        width: parent.width - Theme.iconSize - Theme.spacingM - installButton.width - Theme.spacingM
                                        spacing: 2

                                        Row {
                                            spacing: Theme.spacingXS

                                            StyledText {
                                                text: modelData.name
                                                font.pixelSize: Theme.fontSizeMedium
                                                font.weight: Font.Medium
                                                color: Theme.surfaceText
                                                elide: Text.ElideRight
                                                anchors.verticalCenter: parent.verticalCenter
                                            }

                                            Rectangle {
                                                height: 16
                                                width: firstPartyText.implicitWidth + Theme.spacingXS * 2
                                                radius: 8
                                                color: Qt.rgba(Theme.primary.r, Theme.primary.g, Theme.primary.b, 0.15)
                                                border.color: Qt.rgba(Theme.primary.r, Theme.primary.g, Theme.primary.b, 0.4)
                                                border.width: 1
                                                visible: isFirstParty
                                                anchors.verticalCenter: parent.verticalCenter

                                                StyledText {
                                                    id: firstPartyText
                                                    anchors.centerIn: parent
                                                    text: I18n.tr("official")
                                                    font.pixelSize: Theme.fontSizeSmall - 2
                                                    color: Theme.primary
                                                    font.weight: Font.Medium
                                                }
                                            }

                                            Rectangle {
                                                height: 16
                                                width: thirdPartyText.implicitWidth + Theme.spacingXS * 2
                                                radius: 8
                                                color: Qt.rgba(Theme.warning.r, Theme.warning.g, Theme.warning.b, 0.15)
                                                border.color: Qt.rgba(Theme.warning.r, Theme.warning.g, Theme.warning.b, 0.4)
                                                border.width: 1
                                                visible: !isFirstParty
                                                anchors.verticalCenter: parent.verticalCenter

                                                StyledText {
                                                    id: thirdPartyText
                                                    anchors.centerIn: parent
                                                    text: I18n.tr("3rd party")
                                                    font.pixelSize: Theme.fontSizeSmall - 2
                                                    color: Theme.warning
                                                    font.weight: Font.Medium
                                                }
                                            }
                                        }

                                        StyledText {
                                            text: {
                                                const author = "by " + (modelData.author || "Unknown")
                                                const source = modelData.repo ? ` • <a href="${modelData.repo}" style="text-decoration:none; color:${Theme.primary};">source</a>` : ""
                                                return author + source
                                            }
                                            font.pixelSize: Theme.fontSizeSmall
                                            color: Theme.outline
                                            linkColor: Theme.primary
                                            textFormat: Text.RichText
                                            elide: Text.ElideRight
                                            width: parent.width
                                            onLinkActivated: url => Qt.openUrlExternally(url)

                                            MouseArea {
                                                anchors.fill: parent
                                                cursorShape: parent.hoveredLink ? Qt.PointingHandCursor : Qt.ArrowCursor
                                                acceptedButtons: Qt.NoButton
                                                propagateComposedEvents: true
                                            }
                                        }
                                    }

                                    Rectangle {
                                        id: installButton
                                        width: 80
                                        height: 32
                                        radius: Theme.cornerRadius
                                        anchors.verticalCenter: parent.verticalCenter
                                        color: isInstalled ? Theme.surfaceVariant : Theme.primary
                                        opacity: isInstalled ? 1 : (installMouseArea.containsMouse ? 0.9 : 1)
                                        border.width: isInstalled ? 1 : 0
                                        border.color: Theme.outline

                                        Behavior on opacity {
                                            NumberAnimation {
                                                duration: Theme.shortDuration
                                                easing.type: Theme.standardEasing
                                            }
                                        }

                                        Row {
                                            anchors.centerIn: parent
                                            spacing: Theme.spacingXS

                                            DankIcon {
                                                name: isInstalled ? "check" : "download"
                                                size: 14
                                                color: isInstalled ? Theme.surfaceText : Theme.surface
                                                anchors.verticalCenter: parent.verticalCenter
                                            }

                                            StyledText {
                                                text: isInstalled ? "Installed" : "Install"
                                                font.pixelSize: Theme.fontSizeSmall
                                                font.weight: Font.Medium
                                                color: isInstalled ? Theme.surfaceText : Theme.surface
                                                anchors.verticalCenter: parent.verticalCenter
                                            }
                                        }

                                        MouseArea {
                                            id: installMouseArea
                                            anchors.fill: parent
                                            hoverEnabled: true
                                            cursorShape: isInstalled ? Qt.ArrowCursor : Qt.PointingHandCursor
                                            enabled: !isInstalled
                                            onClicked: {
                                                if (!isInstalled) {
                                                    root.installPlugin(modelData.name)
                                                }
                                            }
                                        }
                                    }
                                }

                                StyledText {
                                    text: modelData.description || ""
                                    font.pixelSize: Theme.fontSizeSmall
                                    color: Theme.outline
                                    width: parent.width
                                    wrapMode: Text.WordWrap
                                    visible: modelData.description && modelData.description.length > 0
                                }

                                Flow {
                                    width: parent.width
                                    spacing: Theme.spacingXS
                                    visible: modelData.capabilities && modelData.capabilities.length > 0

                                    Repeater {
                                        model: modelData.capabilities || []

                                        Rectangle {
                                            height: 18
                                            width: capabilityText.implicitWidth + Theme.spacingXS * 2
                                            radius: 9
                                            color: Qt.rgba(Theme.primary.r, Theme.primary.g, Theme.primary.b, 0.1)
                                            border.color: Qt.rgba(Theme.primary.r, Theme.primary.g, Theme.primary.b, 0.3)
                                            border.width: 1

                                            StyledText {
                                                id: capabilityText
                                                anchors.centerIn: parent
                                                text: modelData
                                                font.pixelSize: Theme.fontSizeSmall - 2
                                                color: Theme.primary
                                            }
                                        }
                                    }
                                }
                            }
                        }
                    }

                    StyledText {
                        anchors.centerIn: listArea
                        text: I18n.tr("No plugins found")
                        font.pixelSize: Theme.fontSizeMedium
                        color: Theme.surfaceVariantText
                        visible: !root.isLoading && root.filteredPlugins.length === 0
                    }
                }
            }
        }
    }

    DankModal {
        id: thirdPartyConfirmModal

        width: 500
        height: 300
        allowStacking: true
        backgroundOpacity: 0.4
        closeOnEscapeKey: true

        content: Component {
            FocusScope {
                anchors.fill: parent
                focus: true

                Keys.onPressed: event => {
                    if (event.key === Qt.Key_Escape) {
                        thirdPartyConfirmModal.close()
                        event.accepted = true
                    }
                }

                Column {
                    anchors.fill: parent
                    anchors.margins: Theme.spacingL
                    spacing: Theme.spacingL

                    Row {
                        width: parent.width
                        spacing: Theme.spacingM

                        DankIcon {
                            name: "warning"
                            size: Theme.iconSize
                            color: Theme.warning
                            anchors.verticalCenter: parent.verticalCenter
                        }

                        StyledText {
                            text: I18n.tr("Third-Party Plugin Warning")
                            font.pixelSize: Theme.fontSizeLarge
                            font.weight: Font.Medium
                            color: Theme.surfaceText
                            anchors.verticalCenter: parent.verticalCenter
                        }
                    }

                    StyledText {
                        width: parent.width
                        text: I18n.tr("Third-party plugins are created by the community and are not officially supported by DankMaterialShell.\n\nThese plugins may pose security and privacy risks - install at your own risk.")
                        font.pixelSize: Theme.fontSizeMedium
                        color: Theme.surfaceText
                        wrapMode: Text.WordWrap
                    }

                    Column {
                        width: parent.width
                        spacing: Theme.spacingS

                        StyledText {
                            text: I18n.tr("• Plugins may contain bugs or security issues")
                            font.pixelSize: Theme.fontSizeSmall
                            color: Theme.surfaceVariantText
                        }

                        StyledText {
                            text: I18n.tr("• Review code before installation when possible")
                            font.pixelSize: Theme.fontSizeSmall
                            color: Theme.surfaceVariantText
                        }

                        StyledText {
                            text: I18n.tr("• Install only from trusted sources")
                            font.pixelSize: Theme.fontSizeSmall
                            color: Theme.surfaceVariantText
                        }
                    }

                    Item {
                        width: parent.width
                        height: parent.height - parent.spacing * 3 - y
                    }

                    Row {
                        anchors.right: parent.right
                        spacing: Theme.spacingM

                        DankButton {
                            text: I18n.tr("Cancel")
                            iconName: "close"
                            onClicked: thirdPartyConfirmModal.close()
                        }

                        DankButton {
                            text: I18n.tr("I Understand")
                            iconName: "check"
                            onClicked: {
                                SessionData.setShowThirdPartyPlugins(true)
                                root.updateFilteredPlugins()
                                thirdPartyConfirmModal.close()
                            }
                        }
                    }
                }
            }
        }
    }
}
