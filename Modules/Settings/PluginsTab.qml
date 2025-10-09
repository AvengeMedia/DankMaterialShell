import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import qs.Common
import qs.Modals.Common
import qs.Services
import qs.Widgets

FocusScope {
    id: pluginsTab

    property string expandedPluginId: ""
    property bool isRefreshingPlugins: false
    property var parentModal: null
    focus: true


    DankFlickable {
        anchors.fill: parent
        anchors.topMargin: Theme.spacingL
        clip: true
        contentHeight: mainColumn.height
        contentWidth: width

        Column {
            id: mainColumn

            width: parent.width
            spacing: Theme.spacingXL

            StyledRect {
                width: parent.width
                height: headerColumn.implicitHeight + Theme.spacingL * 2
                radius: Theme.cornerRadius
                color: Theme.surfaceContainerHigh
                border.width: 0

                Column {
                    id: headerColumn

                    anchors.fill: parent
                    anchors.margins: Theme.spacingL
                    spacing: Theme.spacingM

                    Row {
                        width: parent.width
                        spacing: Theme.spacingM

                        DankIcon {
                            name: "extension"
                            size: Theme.iconSize
                            color: Theme.primary
                            anchors.verticalCenter: parent.verticalCenter
                        }

                        Column {
                            anchors.verticalCenter: parent.verticalCenter
                            spacing: Theme.spacingXS

                            StyledText {
                                text: I18n.tr("Plugin Management")
                                font.pixelSize: Theme.fontSizeLarge
                                color: Theme.surfaceText
                                font.weight: Font.Medium
                            }

                            StyledText {
                                text: I18n.tr("Manage and configure plugins for extending DMS functionality")
                                font.pixelSize: Theme.fontSizeSmall
                                color: Theme.surfaceVariantText
                            }
                        }
                    }

                    StyledRect {
                        width: parent.width
                        height: dmsWarningColumn.implicitHeight + Theme.spacingM * 2
                        radius: Theme.cornerRadius
                        color: Qt.rgba(Theme.warning.r, Theme.warning.g, Theme.warning.b, 0.1)
                        border.color: Theme.warning
                        border.width: 1
                        visible: !DMSService.dmsAvailable

                        Column {
                            id: dmsWarningColumn
                            anchors.fill: parent
                            anchors.margins: Theme.spacingM
                            spacing: Theme.spacingXS

                            Row {
                                spacing: Theme.spacingXS

                                DankIcon {
                                    name: "warning"
                                    size: 16
                                    color: Theme.warning
                                    anchors.verticalCenter: parent.verticalCenter
                                }

                                StyledText {
                                    text: I18n.tr("DMS Plugin Manager Unavailable")
                                    font.pixelSize: Theme.fontSizeSmall
                                    color: Theme.warning
                                    font.weight: Font.Medium
                                    anchors.verticalCenter: parent.verticalCenter
                                }
                            }

                            StyledText {
                                text: I18n.tr("The DMS_SOCKET environment variable is not set or the socket is unavailable. Automated plugin management requires the DMS_SOCKET.")
                                font.pixelSize: Theme.fontSizeSmall - 1
                                color: Theme.surfaceVariantText
                                wrapMode: Text.WordWrap
                                width: parent.width
                            }
                        }
                    }

                    Flow {
                        width: parent.width
                        spacing: Theme.spacingM

                        DankButton {
                            text: I18n.tr("Browse")
                            iconName: "store"
                            enabled: DMSService.dmsAvailable
                            onClicked: {
                                pluginBrowserModal.show()
                            }
                        }

                        DankButton {
                            text: I18n.tr("Scan")
                            iconName: "refresh"
                            onClicked: {
                                pluginsTab.isRefreshingPlugins = true
                                PluginService.scanPlugins()
                                if (DMSService.dmsAvailable) {
                                    DMSService.listInstalled()
                                }
                                pluginsTab.refreshPluginList()
                            }
                        }

                        DankButton {
                            text: I18n.tr("Create Dir")
                            iconName: "create_new_folder"
                            onClicked: {
                                PluginService.createPluginDirectory()
                                ToastService.showInfo("Created plugin directory: " + PluginService.pluginDirectory)
                            }
                        }
                    }
                }
            }

            StyledRect {
                width: parent.width
                height: directoryColumn.implicitHeight + Theme.spacingL * 2
                radius: Theme.cornerRadius
                color: Theme.surfaceContainerHigh
                border.width: 0

                Column {
                    id: directoryColumn

                    anchors.fill: parent
                    anchors.margins: Theme.spacingL
                    spacing: Theme.spacingM

                    StyledText {
                        text: I18n.tr("Plugin Directory")
                        font.pixelSize: Theme.fontSizeLarge
                        color: Theme.surfaceText
                        font.weight: Font.Medium
                    }

                    StyledText {
                        text: PluginService.pluginDirectory
                        font.pixelSize: Theme.fontSizeSmall
                        color: Theme.surfaceVariantText
                        font.family: "monospace"
                    }

                    StyledText {
                        text: I18n.tr("Place plugin directories here. Each plugin should have a plugin.json manifest file.")
                        font.pixelSize: Theme.fontSizeSmall
                        color: Theme.surfaceVariantText
                        wrapMode: Text.WordWrap
                        width: parent.width
                    }
                }
            }

            StyledRect {
                width: parent.width
                height: Math.max(200, availableColumn.implicitHeight + Theme.spacingL * 2)
                radius: Theme.cornerRadius
                color: Theme.surfaceContainerHigh
                border.width: 0

                Column {
                    id: availableColumn

                    anchors.fill: parent
                    anchors.margins: Theme.spacingL
                    spacing: Theme.spacingM

                    StyledText {
                        text: I18n.tr("Available Plugins")
                        font.pixelSize: Theme.fontSizeLarge
                        color: Theme.surfaceText
                        font.weight: Font.Medium
                    }

                    Column {
                        width: parent.width
                        spacing: Theme.spacingM

                        Repeater {
                            id: pluginRepeater
                            model: PluginService.getAvailablePlugins()

                            StyledRect {
                                id: pluginDelegate
                                width: parent.width
                                height: pluginItemColumn.implicitHeight + Theme.spacingM * 2 + settingsContainer.height
                                radius: Theme.cornerRadius

                                property var pluginData: modelData
                                property string pluginId: pluginData ? pluginData.id : ""
                                property string pluginDirectoryName: {
                                    if (pluginData && pluginData.pluginDirectory) {
                                        var path = pluginData.pluginDirectory
                                        return path.substring(path.lastIndexOf('/') + 1)
                                    }
                                    return pluginId
                                }
                                property string pluginName: pluginData ? (pluginData.name || pluginData.id) : ""
                                property string pluginVersion: pluginData ? (pluginData.version || "1.0.0") : ""
                                property string pluginAuthor: pluginData ? (pluginData.author || "Unknown") : ""
                                property string pluginDescription: pluginData ? (pluginData.description || "") : ""
                                property string pluginIcon: pluginData ? (pluginData.icon || "extension") : "extension"
                                property string pluginSettingsPath: pluginData ? (pluginData.settingsPath || "") : ""
                                property var pluginPermissions: pluginData ? (pluginData.permissions || []) : []
                                property bool hasSettings: pluginData && pluginData.settings !== undefined && pluginData.settings !== ""
                                property bool isExpanded: pluginsTab.expandedPluginId === pluginId


                                color: pluginMouseArea.containsMouse ? Theme.surfacePressed : (isExpanded ? Theme.surfaceContainerHighest : Theme.surfaceContainerHigh)
                                border.width: 0

                                MouseArea {
                                    id: pluginMouseArea
                                    anchors.fill: parent
                                    anchors.bottomMargin: pluginDelegate.isExpanded ? settingsContainer.height : 0
                                    hoverEnabled: true
                                    cursorShape: pluginDelegate.hasSettings ? Qt.PointingHandCursor : Qt.ArrowCursor
                                    onClicked: {
                                        if (pluginDelegate.hasSettings) {
                                            pluginsTab.expandedPluginId = pluginsTab.expandedPluginId === pluginDelegate.pluginId ? "" : pluginDelegate.pluginId
                                        }
                                    }
                                }

                                Column {
                                    id: pluginItemColumn
                                    width: parent.width
                                    anchors.top: parent.top
                                    anchors.left: parent.left
                                    anchors.right: parent.right
                                    anchors.margins: Theme.spacingM
                                    spacing: Theme.spacingM

                                    Row {
                                        width: parent.width
                                        spacing: Theme.spacingM

                                        DankIcon {
                                            name: pluginDelegate.pluginIcon
                                            size: Theme.iconSize
                                            color: PluginService.isPluginLoaded(pluginDelegate.pluginId) ? Theme.primary : Theme.surfaceVariantText
                                            anchors.verticalCenter: parent.verticalCenter
                                        }

                                        Column {
                                            width: parent.width - Theme.iconSize - Theme.spacingM - toggleRow.width - Theme.spacingM
                                            spacing: Theme.spacingXS
                                            anchors.verticalCenter: parent.verticalCenter

                                            Row {
                                                spacing: Theme.spacingXS
                                                width: parent.width

                                                StyledText {
                                                    text: pluginDelegate.pluginName
                                                    font.pixelSize: Theme.fontSizeLarge
                                                    color: Theme.surfaceText
                                                    font.weight: Font.Medium
                                                    anchors.verticalCenter: parent.verticalCenter
                                                }

                                                DankIcon {
                                                    name: pluginDelegate.hasSettings ? (pluginDelegate.isExpanded ? "expand_less" : "expand_more") : ""
                                                    size: 16
                                                    color: pluginDelegate.hasSettings ? Theme.primary : "transparent"
                                                    anchors.verticalCenter: parent.verticalCenter
                                                    visible: pluginDelegate.hasSettings
                                                }
                                            }

                                            StyledText {
                                                text: "v" + pluginDelegate.pluginVersion + " by " + pluginDelegate.pluginAuthor
                                                font.pixelSize: Theme.fontSizeSmall
                                                color: Theme.surfaceVariantText
                                                width: parent.width
                                            }
                                        }

                                        Row {
                                            id: toggleRow
                                            anchors.verticalCenter: parent.verticalCenter
                                            spacing: Theme.spacingXS

                                            Rectangle {
                                                width: 28
                                                height: 28
                                                radius: 14
                                                color: updateArea.containsMouse ? Theme.surfaceContainerHighest : "transparent"
                                                visible: DMSService.dmsAvailable && PluginService.isPluginLoaded(pluginDelegate.pluginId)

                                                DankIcon {
                                                    anchors.centerIn: parent
                                                    name: "download"
                                                    size: 16
                                                    color: updateArea.containsMouse ? Theme.primary : Theme.surfaceVariantText
                                                }

                                                MouseArea {
                                                    id: updateArea
                                                    anchors.fill: parent
                                                    hoverEnabled: true
                                                    cursorShape: Qt.PointingHandCursor
                                                    onClicked: {
                                                        const currentPluginDirName = pluginDelegate.pluginDirectoryName
                                                        const currentPluginName = pluginDelegate.pluginName
                                                        DMSService.update(currentPluginDirName, response => {
                                                            if (response.error) {
                                                                ToastService.showError("Update failed: " + response.error)
                                                            } else {
                                                                ToastService.showInfo("Plugin updated: " + currentPluginName)
                                                                PluginService.scanPlugins()
                                                            }
                                                        })
                                                    }
                                                }
                                            }

                                            Rectangle {
                                                width: 28
                                                height: 28
                                                radius: 14
                                                color: uninstallArea.containsMouse ? Theme.surfaceContainerHighest : "transparent"
                                                visible: DMSService.dmsAvailable

                                                DankIcon {
                                                    anchors.centerIn: parent
                                                    name: "delete"
                                                    size: 16
                                                    color: uninstallArea.containsMouse ? Theme.error : Theme.surfaceVariantText
                                                }

                                                MouseArea {
                                                    id: uninstallArea
                                                    anchors.fill: parent
                                                    hoverEnabled: true
                                                    cursorShape: Qt.PointingHandCursor
                                                    onClicked: {
                                                        const currentPluginDirName = pluginDelegate.pluginDirectoryName
                                                        const currentPluginName = pluginDelegate.pluginName
                                                        DMSService.uninstall(currentPluginDirName, response => {
                                                            if (response.error) {
                                                                ToastService.showError("Uninstall failed: " + response.error)
                                                            } else {
                                                                ToastService.showInfo("Plugin uninstalled: " + currentPluginName)
                                                                PluginService.scanPlugins()
                                                                if (pluginDelegate.isExpanded) {
                                                                    pluginsTab.expandedPluginId = ""
                                                                }
                                                            }
                                                        })
                                                    }
                                                }
                                            }

                                            Rectangle {
                                                width: 28
                                                height: 28
                                                radius: 14
                                                color: reloadArea.containsMouse ? Theme.surfaceContainerHighest : "transparent"
                                                visible: PluginService.isPluginLoaded(pluginDelegate.pluginId)

                                                DankIcon {
                                                    anchors.centerIn: parent
                                                    name: "refresh"
                                                    size: 16
                                                    color: reloadArea.containsMouse ? Theme.primary : Theme.surfaceVariantText
                                                }

                                                MouseArea {
                                                    id: reloadArea
                                                    anchors.fill: parent
                                                    hoverEnabled: true
                                                    cursorShape: Qt.PointingHandCursor
                                                    onClicked: {
                                                        const currentPluginId = pluginDelegate.pluginId
                                                        const currentPluginName = pluginDelegate.pluginName
                                                        pluginsTab.isReloading = true
                                                        if (PluginService.reloadPlugin(currentPluginId)) {
                                                            ToastService.showInfo("Plugin reloaded: " + currentPluginName)
                                                        } else {
                                                            ToastService.showError("Failed to reload plugin: " + currentPluginName)
                                                            pluginsTab.isReloading = false
                                                        }
                                                    }
                                                }
                                            }

                                            DankToggle {
                                                id: pluginToggle
                                                anchors.verticalCenter: parent.verticalCenter
                                                checked: PluginService.isPluginLoaded(pluginDelegate.pluginId)
                                                onToggled: isChecked => {
                                                    const currentPluginId = pluginDelegate.pluginId
                                                    const currentPluginName = pluginDelegate.pluginName

                                                    if (isChecked) {
                                                        if (PluginService.enablePlugin(currentPluginId)) {
                                                            ToastService.showInfo("Plugin enabled: " + currentPluginName)
                                                        } else {
                                                            ToastService.showError("Failed to enable plugin: " + currentPluginName)
                                                            checked = false
                                                        }
                                                    } else {
                                                        if (PluginService.disablePlugin(currentPluginId)) {
                                                            ToastService.showInfo("Plugin disabled: " + currentPluginName)
                                                            if (pluginDelegate.isExpanded) {
                                                                pluginsTab.expandedPluginId = ""
                                                            }
                                                        } else {
                                                            ToastService.showError("Failed to disable plugin: " + currentPluginName)
                                                            checked = true
                                                        }
                                                    }
                                                }
                                            }
                                        }
                                    }

                                    StyledText {
                                        width: parent.width
                                        text: pluginDelegate.pluginDescription
                                        font.pixelSize: Theme.fontSizeSmall
                                        color: Theme.surfaceVariantText
                                        wrapMode: Text.WordWrap
                                        visible: pluginDelegate.pluginDescription !== ""
                                    }

                                    Flow {
                                        width: parent.width
                                        spacing: Theme.spacingXS
                                        visible: pluginDelegate.pluginPermissions && Array.isArray(pluginDelegate.pluginPermissions) && pluginDelegate.pluginPermissions.length > 0

                                        Repeater {
                                            model: pluginDelegate.pluginPermissions

                                            Rectangle {
                                                height: 20
                                                width: permissionText.implicitWidth + Theme.spacingXS * 2
                                                radius: 10
                                                color: Qt.rgba(Theme.primary.r, Theme.primary.g, Theme.primary.b, 0.1)
                                                border.color: Qt.rgba(Theme.primary.r, Theme.primary.g, Theme.primary.b, 0.3)
                                                border.width: 1

                                                StyledText {
                                                    id: permissionText
                                                    anchors.centerIn: parent
                                                    text: modelData
                                                    font.pixelSize: Theme.fontSizeSmall - 1
                                                    color: Theme.primary
                                                }
                                            }
                                        }
                                    }
                                }

                                // Settings container
                                FocusScope {
                                    id: settingsContainer
                                    anchors.bottom: parent.bottom
                                    anchors.left: parent.left
                                    anchors.right: parent.right
                                    height: pluginDelegate.isExpanded && pluginDelegate.hasSettings ? (settingsLoader.item ? settingsLoader.item.implicitHeight + Theme.spacingL * 2 : 0) : 0
                                    clip: true
                                    focus: pluginDelegate.isExpanded && pluginDelegate.hasSettings

                                    Rectangle {
                                        anchors.fill: parent
                                        color: Theme.surfaceContainerHighest
                                        radius: Theme.cornerRadius
                                        anchors.topMargin: Theme.spacingXS
                                        border.width: 0
                                    }

                                    Loader {
                                        id: settingsLoader
                                        anchors.fill: parent
                                        anchors.margins: Theme.spacingL
                                        active: pluginDelegate.isExpanded && pluginDelegate.hasSettings && PluginService.isPluginLoaded(pluginDelegate.pluginId)
                                        asynchronous: false

                                        source: {
                                            if (active && pluginDelegate.pluginSettingsPath) {
                                                var path = pluginDelegate.pluginSettingsPath
                                                if (!path.startsWith("file://")) {
                                                    path = "file://" + path
                                                }
                                                return path
                                            }
                                            return ""
                                        }

                                        onLoaded: {
                                            if (item && typeof PluginService !== "undefined") {
                                                item.pluginService = PluginService
                                            }
                                            if (item && typeof PopoutService !== "undefined" && "popoutService" in item) {
                                                item.popoutService = PopoutService
                                            }
                                            if (item) {
                                                Qt.callLater(() => {
                                                    settingsContainer.focus = true
                                                    item.forceActiveFocus()
                                                })
                                            }
                                        }
                                    }

                                    StyledText {
                                        anchors.centerIn: parent
                                        text: !PluginService.isPluginLoaded(pluginDelegate.pluginId) ?
                                              "Enable plugin to access settings" :
                                              (settingsLoader.status === Loader.Error ?
                                               "Failed to load settings" :
                                               "No configurable settings")
                                        font.pixelSize: Theme.fontSizeSmall
                                        color: Theme.surfaceVariantText
                                        visible: pluginDelegate.isExpanded && (!settingsLoader.active || settingsLoader.status === Loader.Error)
                                    }
                                }
                            }
                        }

                        StyledText {
                            width: parent.width
                            text: I18n.tr("No plugins found.") + "\n" + I18n.tr("Place plugins in") + " " + PluginService.pluginDirectory
                            font.pixelSize: Theme.fontSizeMedium
                            color: Theme.surfaceVariantText
                            horizontalAlignment: Text.AlignHCenter
                            visible: pluginRepeater.model && pluginRepeater.model.length === 0
                        }
                    }
                }
            }
        }
    }

    property bool isReloading: false

    function refreshPluginList() {
        Qt.callLater(() => {
            var plugins = PluginService.getAvailablePlugins()
            pluginRepeater.model = null
            pluginRepeater.model = plugins
            pluginsTab.isRefreshingPlugins = false
        })
    }

    Connections {
        target: PluginService
        function onPluginLoaded() {
            refreshPluginList()
            if (isReloading) {
                isReloading = false
            }
        }
        function onPluginUnloaded() {
            refreshPluginList()
            if (!isReloading && pluginsTab.expandedPluginId !== "" && !PluginService.isPluginLoaded(pluginsTab.expandedPluginId)) {
                pluginsTab.expandedPluginId = ""
            }
        }
    }

    Connections {
        target: DMSService
        function onPluginsListReceived(plugins) {
            pluginBrowserModal.isLoading = false
            pluginBrowserModal.allPlugins = plugins
            pluginBrowserModal.updateFilteredPlugins()
        }
        function onOperationSuccess(message) {
            ToastService.showInfo(message)
        }
        function onOperationError(error) {
            ToastService.showError(error)
        }
    }

    Component.onCompleted: {
        pluginBrowserModal.parentModal = pluginsTab.parentModal
    }

    DankModal {
        id: pluginBrowserModal

        property var allPlugins: []
        property string searchQuery: ""
        property var filteredPlugins: []
        property int selectedIndex: -1
        property bool keyboardNavigationActive: false
        property bool isLoading: false
        property var parentModal: null

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
                    pluginBrowserModal.refreshPlugins()
                }
            })
        }

        function refreshPlugins() {
            isLoading = true
            DMSService.listPlugins()
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

        width: 600
        height: 650
        allowStacking: true
        backgroundOpacity: 0
        closeOnEscapeKey: false
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
                        pluginBrowserModal.close()
                        event.accepted = true
                    } else if (event.key === Qt.Key_Down) {
                        pluginBrowserModal.selectNext()
                        event.accepted = true
                    } else if (event.key === Qt.Key_Up) {
                        pluginBrowserModal.selectPrevious()
                        event.accepted = true
                    }
                }

                Column {
                    id: browserContent

                    spacing: Theme.spacingM
                    anchors.fill: parent
                    anchors.margins: Theme.spacingL

                    Item {
                        width: parent.width
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
                                        pluginBrowserModal.updateFilteredPlugins()
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
                                visible: !pluginBrowserModal.isLoading
                                onClicked: pluginBrowserModal.refreshPlugins()
                            }

                            DankActionButton {
                                id: closeButton
                                iconName: "close"
                                iconSize: Theme.iconSize - 2
                                iconColor: Theme.outline
                                onClicked: pluginBrowserModal.close()
                            }
                        }
                    }

                    StyledText {
                        text: I18n.tr("Install plugins from the DMS plugin registry")
                        font.pixelSize: Theme.fontSizeSmall
                        color: Theme.outline
                        width: parent.width
                        wrapMode: Text.WordWrap
                    }

                    DankTextField {
                        id: browserSearchField
                        width: parent.width
                        height: 48
                        cornerRadius: Theme.cornerRadius
                        backgroundColor: Theme.surfaceContainerHigh
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
                        text: pluginBrowserModal.searchQuery
                        focus: true
                        ignoreLeftRightKeys: true
                        keyForwardTargets: [browserKeyHandler]
                        onTextEdited: {
                            pluginBrowserModal.searchQuery = text
                            pluginBrowserModal.updateFilteredPlugins()
                        }
                    }

                    Item {
                        width: parent.width
                        height: parent.height - y
                        visible: pluginBrowserModal.isLoading

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
                                    running: pluginBrowserModal.isLoading
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

                        width: parent.width
                        height: parent.height - y
                        spacing: Theme.spacingS
                        model: pluginBrowserModal.filteredPlugins
                        clip: true
                        visible: !pluginBrowserModal.isLoading

                        delegate: Rectangle {
                            width: pluginBrowserList.width
                            height: pluginDelegateColumn.implicitHeight + Theme.spacingM * 2
                            radius: Theme.cornerRadius
                            property bool isSelected: pluginBrowserModal.keyboardNavigationActive && index === pluginBrowserModal.selectedIndex
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
                                                    pluginBrowserModal.installPlugin(modelData.name)
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
                        text: I18n.tr("No plugins found")
                        font.pixelSize: Theme.fontSizeMedium
                        color: Theme.surfaceVariantText
                        anchors.horizontalCenter: parent.horizontalCenter
                        visible: !pluginBrowserModal.isLoading && pluginBrowserModal.filteredPlugins.length === 0
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
                                pluginBrowserModal.updateFilteredPlugins()
                                thirdPartyConfirmModal.close()
                            }
                        }
                    }
                }
            }
        }
    }
}