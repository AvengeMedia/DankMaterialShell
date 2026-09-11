import QtQuick
import Quickshell
import qs.Common
import qs.Modals.Common
import qs.Services
import qs.Widgets

DankFloatingWindow {
    id: root

    property var allThemes: []
    property string searchQuery: ""
    property var filteredThemes: []
    property int selectedIndex: -1
    property bool keyboardNavigationActive: false
    property bool isLoading: false
    property var parentModal: null
    parentWindow: parentModal
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

    function ensureSelectedVisible() {
        if (selectedIndex >= 0)
            themeGrid.positionViewAtIndex(selectedIndex, GridView.Contain);
    }

    function selectNext() {
        if (filteredThemes.length === 0)
            return;
        if (!keyboardNavigationActive) {
            keyboardNavigationActive = true;
            selectedIndex = 0;
            ensureSelectedVisible();
            return;
        }
        selectedIndex = Math.min(selectedIndex + themeGrid.columns, filteredThemes.length - 1);
        ensureSelectedVisible();
    }

    function selectPrevious() {
        if (filteredThemes.length === 0 || !keyboardNavigationActive)
            return;
        const next = selectedIndex - themeGrid.columns;
        if (next < 0) {
            selectedIndex = -1;
            keyboardNavigationActive = false;
            return;
        }
        selectedIndex = next;
        ensureSelectedVisible();
    }

    function selectStep(delta) {
        if (filteredThemes.length === 0 || !keyboardNavigationActive)
            return;
        selectedIndex = Math.max(0, Math.min(selectedIndex + delta, filteredThemes.length - 1));
        ensureSelectedVisible();
    }

    function themeBadges(theme) {
        const badges = PluginService.badgeModel(theme);
        const variants = theme.variants || null;
        const variantCount = variants ? (variants.type === "multi" ? (variants.accents?.length ?? 0) : (variants.options?.length ?? 0)) : 0;
        if (variantCount > 0)
            badges.push({
                label: I18n.tr("%1 variants").arg(variantCount),
                icon: "",
                tone: "secondary"
            });
        const wcag = wcagLabel(theme);
        if (wcag)
            badges.push({
                label: wcag,
                icon: "contrast",
                tone: "info"
            });
        return badges;
    }

    function themePreviewUrl(theme) {
        const base = "https://raw.githubusercontent.com/AvengeMedia/dms-plugin-registry/main/themes/" + (theme.sourceDir || theme.id) + "/";
        const variants = theme.variants || null;
        if (!variants)
            return base + "preview.svg";
        let variantId = "";
        if (variants.type === "multi") {
            const mode = Theme.isLightMode ? "light" : "dark";
            const defaults = variants.defaults?.[mode] || variants.defaults?.dark || {};
            variantId = (defaults.flavor || "") + (defaults.accent ? "-" + defaults.accent : "");
        } else {
            variantId = variants.default || (variants.options?.[0]?.id ?? "");
        }
        return variantId ? base + "preview-" + variantId + ".svg" : base + "preview.svg";
    }

    function wcagLabel(theme) {
        const rows = (theme.wcag?.dark?.breakdown ?? []).concat(theme.wcag?.light?.breakdown ?? []);
        let hasAAA = false;
        for (let i = 0; i < rows.length; i++) {
            if (rows[i].level === "AA")
                return "WCAG AA";
            if (rows[i].level === "AAA")
                hasAAA = true;
        }
        return hasAAA ? "WCAG AAA" : "";
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
        const wasVisible = visible;
        visible = true;
        if (wasVisible && PopoutService.pendingThemeInstall) {
            pendingInstallHandled = false;
            checkPendingInstall();
        }
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

    ConfirmDialogOverlay {
        id: urlInstallConfirm

        onDialogClosed: Qt.callLater(() => browserSearchField.forceActiveFocus())
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
            case Qt.Key_Left:
                if (!root.keyboardNavigationActive)
                    return;
                root.selectStep(-1);
                event.accepted = true;
                return;
            case Qt.Key_Right:
                if (!root.keyboardNavigationActive)
                    return;
                root.selectStep(1);
                event.accepted = true;
                return;
            case Qt.Key_Return:
            case Qt.Key_Enter:
                {
                    if (!root.keyboardNavigationActive || root.selectedIndex < 0)
                        return;
                    const theme = root.filteredThemes[root.selectedIndex];
                    if (!theme.installed)
                        root.installTheme(theme.id, theme.name, false);
                    event.accepted = true;
                    return;
                }
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

                    DankRefreshButton {
                        id: refreshButton
                        iconSize: 18
                        iconColor: Theme.primary
                        busy: root.isLoading
                        onClicked: root.refreshThemes()
                    }

                    DankActionButton {
                        visible: windowControls.canMaximize
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

                    DankSpinner {
                        anchors.centerIn: parent
                        running: root.isLoading
                    }
                }

                DankGridView {
                    id: themeGrid

                    property int columns: Math.max(1, Math.floor(width / 300))
                    readonly property real cardSpacing: Theme.spacingM
                    readonly property int previewHeight: Math.round((cellWidth - cardSpacing - Theme.spacingS * 2) * 0.52)
                    readonly property int infoHeight: 100

                    anchors.fill: parent
                    cellWidth: Math.floor(width / columns)
                    cellHeight: previewHeight + infoHeight + Math.round(cardSpacing) + Theme.spacingS * 2 + Theme.spacingM
                    model: root.filteredThemes
                    clip: true
                    visible: !root.isLoading
                    cacheBuffer: cellHeight * 2

                    delegate: Item {
                        id: cardCell

                        required property var modelData
                        required property int index

                        width: themeGrid.cellWidth
                        height: themeGrid.cellHeight

                        PluginCard {
                            anchors.fill: parent
                            anchors.margins: themeGrid.cardSpacing / 2
                            plugin: cardCell.modelData
                            fallbackIcon: "palette"
                            previewSource: root.themePreviewUrl(cardCell.modelData)
                            badges: root.themeBadges(cardCell.modelData)
                            allowUninstall: true
                            previewHeight: themeGrid.previewHeight
                            installed: cardCell.modelData.installed || false
                            selected: root.keyboardNavigationActive && cardCell.index === root.selectedIndex
                            onClicked: {
                                root.selectedIndex = cardCell.index;
                                root.keyboardNavigationActive = true;
                            }
                            onInstallRequested: root.installTheme(cardCell.modelData.id, cardCell.modelData.name, false)
                            onUninstallRequested: root.uninstallTheme(cardCell.modelData.id, cardCell.modelData.name)
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
