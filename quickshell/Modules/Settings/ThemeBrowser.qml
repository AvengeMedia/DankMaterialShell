import QtQuick
import QtQuick.Controls
import Quickshell
import qs.Common
import qs.Modals.Common
import qs.Services
import qs.Widgets

FloatingWindow {
    id: root

    property bool disablePopupTransparency: true
    property var allThemes: []
    property string searchQuery: ""
    property var filteredThemes: []
    property int selectedIndex: -1
    property bool keyboardNavigationActive: false
    property bool isLoading: false
    property var parentModal: null
    property bool pendingInstallHandled: false
    property string pendingApplyThemeId: ""

    function updateFilteredThemes() {
        var filtered = [];
        var query = searchQuery ? searchQuery.toLowerCase() : "";

        for (var i = 0; i < allThemes.length; i++) {
            var theme = allThemes[i];

            if (query.length === 0) {
                filtered.push(theme);
                continue;
            }

            var name = theme.name ? theme.name.toLowerCase() : "";
            var description = theme.description ? theme.description.toLowerCase() : "";
            var author = theme.author ? theme.author.toLowerCase() : "";

            if (name.indexOf(query) !== -1 || description.indexOf(query) !== -1 || author.indexOf(query) !== -1)
                filtered.push(theme);
        }

        filteredThemes = filtered;
        selectedIndex = -1;
        keyboardNavigationActive = false;
    }

    function selectNext() {
        if (filteredThemes.length === 0)
            return;
        keyboardNavigationActive = true;
        selectedIndex = Math.min(selectedIndex + 1, filteredThemes.length - 1);
    }

    function selectPrevious() {
        if (filteredThemes.length === 0)
            return;
        keyboardNavigationActive = true;
        selectedIndex = Math.max(selectedIndex - 1, -1);
        if (selectedIndex === -1)
            keyboardNavigationActive = false;
    }

    function installTheme(themeId, themeName, applyAfterInstall) {
        ToastService.showInfo(I18n.tr("Installing: %1", "installation progress").arg(themeName));
        DMSService.installTheme(themeId, response => {
            if (response.error) {
                ToastService.showError(I18n.tr("Install failed: %1", "installation error").arg(response.error));
                return;
            }
            ToastService.showInfo(I18n.tr("Installed: %1", "installation success").arg(themeName));
            if (applyAfterInstall)
                pendingApplyThemeId = themeId;
            refreshThemes();
        });
    }

    function applyInstalledTheme(themeId, installedThemes) {
        for (var i = 0; i < installedThemes.length; i++) {
            var theme = installedThemes[i];
            if (theme.id === themeId) {
                var sourceDir = theme.sourceDir || theme.id;
                var themePath = Quickshell.env("HOME") + "/.config/DankMaterialShell/themes/" + sourceDir + "/theme.json";
                SettingsData.set("customThemeFile", themePath);
                Theme.switchThemeCategory("registry", "custom");
                Theme.switchTheme("custom", true, true);
                hide();
                return;
            }
        }
    }

    function uninstallTheme(themeId, themeName) {
        ToastService.showInfo(I18n.tr("Uninstalling: %1", "uninstallation progress").arg(themeName));
        DMSService.uninstallTheme(themeId, response => {
            if (response.error) {
                ToastService.showError(I18n.tr("Uninstall failed: %1", "uninstallation error").arg(response.error));
                return;
            }
            ToastService.showInfo(I18n.tr("Uninstalled: %1", "uninstallation success").arg(themeName));
            refreshThemes();
        });
    }

    function refreshThemes() {
        isLoading = true;
        DMSService.listThemes();
        DMSService.listInstalledThemes();
    }

    function checkPendingInstall() {
        if (!PopoutService.pendingThemeInstall || pendingInstallHandled)
            return;
        pendingInstallHandled = true;
        var themeId = PopoutService.pendingThemeInstall;
        PopoutService.pendingThemeInstall = "";
        urlInstallConfirm.showWithOptions({
            "title": I18n.tr("Install Theme", "theme installation dialog title"),
            "message": I18n.tr("Install theme '%1' from the DMS registry?", "theme installation confirmation").arg(themeId),
            "confirmText": I18n.tr("Install", "install action button"),
            "cancelText": I18n.tr("Cancel"),
            "onConfirm": () => installTheme(themeId, themeId, true),
            "onCancel": () => hide()
        });
    }

    function show() {
        if (parentModal)
            parentModal.shouldHaveFocus = false;
        visible = true;
        Qt.callLater(() => browserSearchField.forceActiveFocus());
    }

    function hide() {
        visible = false;
        if (!parentModal)
            return;
        parentModal.shouldHaveFocus = Qt.binding(() => parentModal.shouldBeVisible);
        Qt.callLater(() => {
            if (parentModal.modalFocusScope)
                parentModal.modalFocusScope.forceActiveFocus();
        });
    }

    objectName: "themeBrowser"
    title: I18n.tr("Browse Themes", "theme browser window title")
    minimumSize: Qt.size(550, 450)
    implicitWidth: 700
    implicitHeight: 700
    color: Theme.surfaceContainer
    visible: false

    onVisibleChanged: {
        if (visible) {
            pendingInstallHandled = false;
            refreshThemes();
            Qt.callLater(() => {
                browserSearchField.forceActiveFocus();
                checkPendingInstall();
            });
            return;
        }
        allThemes = [];
        searchQuery = "";
        filteredThemes = [];
        selectedIndex = -1;
        keyboardNavigationActive = false;
        isLoading = false;
    }

    ConfirmModal {
        id: urlInstallConfirm
    }

    Connections {
        target: DMSService
        function onThemesListReceived(themes) {
            isLoading = false;
            allThemes = themes;
            updateFilteredThemes();
        }
        function onInstalledThemesReceived(themes) {
            if (!pendingApplyThemeId)
                return;
            var themeId = pendingApplyThemeId;
            pendingApplyThemeId = "";
            applyInstalledTheme(themeId, themes);
        }
    }

    FocusScope {
        id: browserKeyHandler

        anchors.fill: parent
        focus: true

        Keys.onPressed: event => {
            switch (event.key) {
            case Qt.Key_Escape:
                root.hide();
                event.accepted = true;
                return;
            case Qt.Key_Down:
                root.selectNext();
                event.accepted = true;
                return;
            case Qt.Key_Up:
                root.selectPrevious();
                event.accepted = true;
                return;
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

                MouseArea {
                    anchors.fill: parent
                    onPressed: windowControls.tryStartMove()
                    onDoubleClicked: windowControls.tryToggleMaximize()
                }

                DankIcon {
                    id: headerIcon
                    name: "palette"
                    size: Theme.iconSize
                    color: Theme.primary
                    anchors.left: parent.left
                    anchors.verticalCenter: parent.verticalCenter
                }

                StyledText {
                    id: headerText
                    text: I18n.tr("Browse Themes", "theme browser header")
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

                    DankActionButton {
                        id: refreshButton
                        iconName: "refresh"
                        iconSize: 18
                        iconColor: Theme.primary
                        visible: !root.isLoading
                        onClicked: root.refreshThemes()
                    }

                    DankActionButton {
                        visible: windowControls.supported
                        iconName: root.maximized ? "fullscreen_exit" : "fullscreen"
                        iconSize: Theme.iconSize - 2
                        iconColor: Theme.outline
                        onClicked: windowControls.tryToggleMaximize()
                    }

                    DankActionButton {
                        id: closeButton
                        iconName: "close"
                        iconSize: Theme.iconSize - 2
                        iconColor: Theme.outline
                        onClicked: root.hide()
                    }
                }
            }

            StyledText {
                id: descriptionText
                anchors.left: parent.left
                anchors.right: parent.right
                anchors.top: headerArea.bottom
                anchors.topMargin: Theme.spacingM
                text: I18n.tr("Install color themes from the DMS theme registry", "theme browser description")
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
                placeholderText: I18n.tr("Search themes...", "theme search placeholder")
                text: root.searchQuery
                focus: true
                ignoreLeftRightKeys: true
                keyForwardTargets: [browserKeyHandler]
                onTextEdited: {
                    root.searchQuery = text;
                    root.updateFilteredThemes();
                }
            }

            Item {
                id: listArea
                anchors.left: parent.left
                anchors.right: parent.right
                anchors.top: browserSearchField.bottom
                anchors.topMargin: Theme.spacingM
                anchors.bottom: parent.bottom

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
                            text: I18n.tr("Loading...", "loading indicator")
                            font.pixelSize: Theme.fontSizeMedium
                            color: Theme.surfaceVariantText
                            anchors.horizontalCenter: parent.horizontalCenter
                        }
                    }
                }

                DankListView {
                    id: themeBrowserList

                    anchors.fill: parent
                    spacing: Theme.spacingS
                    model: ScriptModel {
                        values: root.filteredThemes
                    }
                    clip: true
                    visible: !root.isLoading

                    ScrollBar.vertical: DankScrollbar {
                        id: browserScrollbar
                    }

                    delegate: Rectangle {
                        id: themeDelegate
                        width: themeBrowserList.width
                        height: hasPreview ? 140 : themeDelegateContent.implicitHeight + Theme.spacingM * 2
                        radius: Theme.cornerRadius
                        property bool isSelected: root.keyboardNavigationActive && index === root.selectedIndex
                        property bool isInstalled: modelData.installed || false
                        property bool isFirstParty: modelData.firstParty || false
                        property bool hasVariants: modelData.hasVariants || false
                        property var variants: modelData.variants || null
                        property string selectedVariantId: {
                            if (!hasVariants || !variants)
                                return "";
                            if (variants.type === "multi") {
                                const mode = Theme.isLightMode ? "light" : "dark";
                                const defaults = variants.defaults?.[mode] || variants.defaults?.dark || {};
                                return (defaults.flavor || "") + (defaults.accent ? "-" + defaults.accent : "");
                            }
                            return variants.default || (variants.options?.[0]?.id ?? "");
                        }
                        property string previewPath: {
                            const baseDir = "/tmp/dankdots-plugin-registry/themes/" + (modelData.sourceDir || modelData.id);
                            const mode = Theme.isLightMode ? "light" : "dark";
                            if (hasVariants && selectedVariantId) {
                                if (variants?.type === "multi")
                                    return baseDir + "/preview-" + selectedVariantId + ".svg";
                                return baseDir + "/preview-" + selectedVariantId + "-" + mode + ".svg";
                            }
                            return baseDir + "/preview-" + mode + ".svg";
                        }
                        property bool hasPreview: previewImage.status === Image.Ready
                        color: isSelected ? Theme.primarySelected : Qt.rgba(Theme.surfaceVariant.r, Theme.surfaceVariant.g, Theme.surfaceVariant.b, 0.3)
                        border.color: isSelected ? Theme.primary : Qt.rgba(Theme.outline.r, Theme.outline.g, Theme.outline.b, 0.2)
                        border.width: isSelected ? 2 : 1

                        Row {
                            id: themeDelegateContent
                            anchors.fill: parent
                            anchors.margins: Theme.spacingM
                            spacing: Theme.spacingM

                            Rectangle {
                                width: hasPreview ? 180 : 0
                                height: parent.height
                                radius: Theme.cornerRadius - 2
                                color: Theme.surfaceContainerHigh
                                visible: hasPreview

                                Image {
                                    id: previewImage
                                    anchors.fill: parent
                                    anchors.margins: 2
                                    source: "file://" + previewPath
                                    fillMode: Image.PreserveAspectFit
                                    smooth: true
                                    mipmap: true
                                }
                            }

                            DankIcon {
                                name: "palette"
                                size: 48
                                color: Theme.primary
                                anchors.verticalCenter: parent.verticalCenter
                                visible: !hasPreview
                            }

                            Column {
                                width: parent.width - (hasPreview ? 180 : 48) - Theme.spacingM - installButton.width - Theme.spacingM
                                spacing: 6
                                anchors.verticalCenter: parent.verticalCenter

                                Row {
                                    spacing: Theme.spacingXS
                                    width: parent.width

                                    StyledText {
                                        text: modelData.name
                                        font.pixelSize: Theme.fontSizeLarge
                                        font.weight: Font.Medium
                                        color: Theme.surfaceText
                                        elide: Text.ElideRight
                                        anchors.verticalCenter: parent.verticalCenter
                                    }

                                    Rectangle {
                                        height: 18
                                        width: versionText.implicitWidth + Theme.spacingS
                                        radius: 9
                                        color: Qt.rgba(Theme.outline.r, Theme.outline.g, Theme.outline.b, 0.15)
                                        anchors.verticalCenter: parent.verticalCenter

                                        StyledText {
                                            id: versionText
                                            anchors.centerIn: parent
                                            text: modelData.version || "1.0.0"
                                            font.pixelSize: Theme.fontSizeSmall
                                            color: Theme.outline
                                        }
                                    }

                                    Rectangle {
                                        height: 18
                                        width: firstPartyText.implicitWidth + Theme.spacingS
                                        radius: 9
                                        color: Qt.rgba(Theme.primary.r, Theme.primary.g, Theme.primary.b, 0.15)
                                        border.color: Qt.rgba(Theme.primary.r, Theme.primary.g, Theme.primary.b, 0.4)
                                        border.width: 1
                                        visible: isFirstParty
                                        anchors.verticalCenter: parent.verticalCenter

                                        StyledText {
                                            id: firstPartyText
                                            anchors.centerIn: parent
                                            text: I18n.tr("official")
                                            font.pixelSize: Theme.fontSizeSmall
                                            color: Theme.primary
                                            font.weight: Font.Medium
                                        }
                                    }

                                    Rectangle {
                                        height: 18
                                        width: variantsText.implicitWidth + Theme.spacingS
                                        radius: 9
                                        color: Qt.rgba(Theme.secondary.r, Theme.secondary.g, Theme.secondary.b, 0.15)
                                        border.color: Qt.rgba(Theme.secondary.r, Theme.secondary.g, Theme.secondary.b, 0.4)
                                        border.width: 1
                                        visible: themeDelegate.hasVariants
                                        anchors.verticalCenter: parent.verticalCenter

                                        StyledText {
                                            id: variantsText
                                            anchors.centerIn: parent
                                            text: {
                                                if (themeDelegate.variants?.type === "multi")
                                                    return I18n.tr("%1 variants").arg(themeDelegate.variants?.accents?.length ?? 0);
                                                return I18n.tr("%1 variants").arg(themeDelegate.variants?.options?.length ?? 0);
                                            }
                                            font.pixelSize: Theme.fontSizeSmall
                                            color: Theme.secondary
                                            font.weight: Font.Medium
                                        }
                                    }
                                }

                                StyledText {
                                    text: I18n.tr("by %1", "author attribution").arg(modelData.author || I18n.tr("Unknown", "unknown author"))
                                    font.pixelSize: Theme.fontSizeMedium
                                    color: Theme.outline
                                    elide: Text.ElideRight
                                    width: parent.width
                                }

                                StyledText {
                                    text: modelData.description || ""
                                    font.pixelSize: Theme.fontSizeSmall
                                    color: Theme.surfaceVariantText
                                    width: parent.width
                                    wrapMode: Text.WordWrap
                                    maximumLineCount: themeDelegate.hasVariants ? 2 : 3
                                    elide: Text.ElideRight
                                    visible: modelData.description && modelData.description.length > 0
                                }

                                Flow {
                                    width: parent.width
                                    spacing: Theme.spacingXS
                                    visible: themeDelegate.hasVariants && themeDelegate.variants?.type !== "multi"

                                    Repeater {
                                        model: themeDelegate.variants?.options ?? []

                                        Rectangle {
                                            property bool isActive: themeDelegate.selectedVariantId === modelData.id
                                            height: 22
                                            width: variantChipText.implicitWidth + Theme.spacingS * 2
                                            radius: 11
                                            color: isActive ? Theme.primary : Theme.surfaceContainerHigh
                                            border.color: isActive ? Theme.primary : Theme.outline
                                            border.width: 1

                                            StyledText {
                                                id: variantChipText
                                                anchors.centerIn: parent
                                                text: modelData.name
                                                font.pixelSize: Theme.fontSizeSmall
                                                color: isActive ? Theme.primaryText : Theme.surfaceText
                                            }

                                            MouseArea {
                                                anchors.fill: parent
                                                cursorShape: Qt.PointingHandCursor
                                                onClicked: themeDelegate.selectedVariantId = modelData.id
                                            }
                                        }
                                    }
                                }

                                Flow {
                                    width: parent.width
                                    spacing: Theme.spacingXS
                                    visible: themeDelegate.hasVariants && themeDelegate.variants?.type === "multi"

                                    Repeater {
                                        model: themeDelegate.variants?.accents ?? []

                                        Rectangle {
                                            width: 18
                                            height: 18
                                            radius: 9
                                            color: modelData.color || Theme.primary
                                            border.color: Theme.outline
                                            border.width: 1

                                            DankTooltipV2 {
                                                id: accentTooltip
                                            }

                                            MouseArea {
                                                anchors.fill: parent
                                                hoverEnabled: true
                                                onEntered: accentTooltip.show(modelData.name || modelData.id, parent, 0, 0, "top")
                                                onExited: accentTooltip.hide()
                                            }
                                        }
                                    }
                                }
                            }

                            Rectangle {
                                id: installButton
                                width: 90
                                height: 36
                                radius: Theme.cornerRadius
                                anchors.verticalCenter: parent.verticalCenter
                                color: isInstalled ? (uninstallMouseArea.containsMouse ? Theme.error : Theme.surfaceVariant) : Theme.primary
                                opacity: installMouseArea.containsMouse || uninstallMouseArea.containsMouse ? 0.9 : 1
                                border.width: isInstalled ? 1 : 0
                                border.color: isInstalled ? (uninstallMouseArea.containsMouse ? Theme.error : Theme.outline) : "transparent"

                                Behavior on opacity {
                                    NumberAnimation {
                                        duration: Theme.shortDuration
                                        easing.type: Theme.standardEasing
                                    }
                                }

                                Behavior on color {
                                    ColorAnimation {
                                        duration: Theme.shortDuration
                                    }
                                }

                                Row {
                                    anchors.centerIn: parent
                                    spacing: Theme.spacingXS

                                    DankIcon {
                                        name: isInstalled ? (uninstallMouseArea.containsMouse ? "delete" : "check") : "download"
                                        size: 16
                                        color: isInstalled ? (uninstallMouseArea.containsMouse ? "white" : Theme.surfaceText) : Theme.surface
                                        anchors.verticalCenter: parent.verticalCenter
                                    }

                                    StyledText {
                                        text: {
                                            if (!isInstalled)
                                                return I18n.tr("Install", "install action button");
                                            if (uninstallMouseArea.containsMouse)
                                                return I18n.tr("Uninstall", "uninstall action button");
                                            return I18n.tr("Installed", "installed status");
                                        }
                                        font.pixelSize: Theme.fontSizeMedium
                                        font.weight: Font.Medium
                                        color: isInstalled ? (uninstallMouseArea.containsMouse ? "white" : Theme.surfaceText) : Theme.surface
                                        anchors.verticalCenter: parent.verticalCenter
                                    }
                                }

                                MouseArea {
                                    id: installMouseArea
                                    anchors.fill: parent
                                    hoverEnabled: true
                                    cursorShape: Qt.PointingHandCursor
                                    visible: !isInstalled
                                    onClicked: root.installTheme(modelData.id, modelData.name, false)
                                }

                                MouseArea {
                                    id: uninstallMouseArea
                                    anchors.fill: parent
                                    hoverEnabled: true
                                    cursorShape: Qt.PointingHandCursor
                                    visible: isInstalled
                                    onClicked: root.uninstallTheme(modelData.id, modelData.name)
                                }
                            }
                        }
                    }
                }

                StyledText {
                    anchors.centerIn: listArea
                    text: I18n.tr("No themes found", "empty theme list")
                    font.pixelSize: Theme.fontSizeMedium
                    color: Theme.surfaceVariantText
                    visible: !root.isLoading && root.filteredThemes.length === 0
                }
            }
        }
    }

    FloatingWindowControls {
        id: windowControls
        targetWindow: root
    }
}
