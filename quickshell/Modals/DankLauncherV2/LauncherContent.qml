pragma ComponentBehavior: Bound

import QtQuick
import qs.Common
import qs.Services
import qs.Widgets

FocusScope {
    id: root

    LayoutMirroring.enabled: I18n.isRtl
    LayoutMirroring.childrenInherit: true

    property var parentModal: null
    property string viewModeContext: "spotlight"
    property alias searchField: searchField
    property alias controller: controller
    property alias resultsList: resultsList
    property alias actionPanel: actionPanel

    property bool editMode: false
    property var editingApp: null
    property string editAppId: ""

    function resetScroll() {
        resultsList.resetScroll();
    }

    function focusSearchField() {
        searchField.forceActiveFocus();
    }

    function openEditMode(app) {
        if (!app)
            return;
        editingApp = app;
        editAppId = app.id || app.execString || app.exec || "";
        var existing = SessionData.getAppOverride(editAppId);
        editNameField.text = existing?.name || "";
        editIconField.text = existing?.icon || "";
        editCommentField.text = existing?.comment || "";
        editEnvVarsField.text = existing?.envVars || "";
        editExtraFlagsField.text = existing?.extraFlags || "";
        editMode = true;
        Qt.callLater(() => editNameField.forceActiveFocus());
    }

    function closeEditMode() {
        editMode = false;
        editingApp = null;
        editAppId = "";
        Qt.callLater(() => searchField.forceActiveFocus());
    }

    function saveAppOverride() {
        var override = {};
        if (editNameField.text.trim())
            override.name = editNameField.text.trim();
        if (editIconField.text.trim())
            override.icon = editIconField.text.trim();
        if (editCommentField.text.trim())
            override.comment = editCommentField.text.trim();
        if (editEnvVarsField.text.trim())
            override.envVars = editEnvVarsField.text.trim();
        if (editExtraFlagsField.text.trim())
            override.extraFlags = editExtraFlagsField.text.trim();
        SessionData.setAppOverride(editAppId, override);
        closeEditMode();
    }

    function resetAppOverride() {
        SessionData.clearAppOverride(editAppId);
        closeEditMode();
    }

    function showContextMenu(item, x, y, fromKeyboard) {
        if (!item)
            return;
        if (!contextMenu.hasContextMenuActions(item))
            return;
        contextMenu.show(x, y, item, fromKeyboard);
    }

    anchors.fill: parent
    focus: true

    Controller {
        id: controller
        active: root.parentModal?.spotlightOpen ?? true
        viewModeContext: root.viewModeContext

        onItemExecuted: {
            if (root.parentModal) {
                root.parentModal.hide();
            }
            if (SettingsData.spotlightCloseNiriOverview && NiriService.inOverview) {
                NiriService.toggleOverview();
            }
        }
    }

    LauncherContextMenu {
        id: contextMenu
        parent: root
        controller: root.controller
        searchField: root.searchField
        parentHandler: root

        onEditAppRequested: app => {
            root.openEditMode(app);
        }
    }

    Keys.onPressed: event => {
        if (editMode) {
            if (event.key === Qt.Key_Escape) {
                closeEditMode();
                event.accepted = true;
            }
            return;
        }

        var hasCtrl = event.modifiers & Qt.ControlModifier;
        event.accepted = true;

        switch (event.key) {
        case Qt.Key_Escape:
            if (actionPanel.expanded) {
                actionPanel.hide();
                return;
            }
            if (controller.clearPluginFilter())
                return;
            if (root.parentModal)
                root.parentModal.hide();
            return;
        case Qt.Key_Backspace:
            if (searchField.text.length === 0) {
                if (controller.clearPluginFilter())
                    return;
                if (controller.autoSwitchedToFiles) {
                    controller.restorePreviousMode();
                    return;
                }
            }
            event.accepted = false;
            return;
        case Qt.Key_Down:
            controller.selectNext();
            return;
        case Qt.Key_Up:
            controller.selectPrevious();
            return;
        case Qt.Key_PageDown:
            controller.selectPageDown(8);
            return;
        case Qt.Key_PageUp:
            controller.selectPageUp(8);
            return;
        case Qt.Key_Right:
            if (controller.getCurrentSectionViewMode() !== "list") {
                controller.selectRight();
                return;
            }
            event.accepted = false;
            return;
        case Qt.Key_Left:
            if (controller.getCurrentSectionViewMode() !== "list") {
                controller.selectLeft();
                return;
            }
            event.accepted = false;
            return;
        case Qt.Key_J:
            if (hasCtrl) {
                controller.selectNext();
                return;
            }
            event.accepted = false;
            return;
        case Qt.Key_K:
            if (hasCtrl) {
                controller.selectPrevious();
                return;
            }
            event.accepted = false;
            return;
        case Qt.Key_N:
            if (hasCtrl) {
                controller.selectNextSection();
                return;
            }
            event.accepted = false;
            return;
        case Qt.Key_P:
            if (hasCtrl) {
                controller.selectPreviousSection();
                return;
            }
            event.accepted = false;
            return;
        case Qt.Key_Tab:
            if (actionPanel.hasActions) {
                actionPanel.expanded ? actionPanel.cycleAction() : actionPanel.show();
            }
            return;
        case Qt.Key_Backtab:
            if (actionPanel.expanded)
                actionPanel.hide();
            return;
        case Qt.Key_Return:
        case Qt.Key_Enter:
            if (event.modifiers & Qt.ShiftModifier) {
                controller.pasteSelected();
                return;
            }
            if (actionPanel.expanded && actionPanel.selectedActionIndex > 0) {
                actionPanel.executeSelectedAction();
            } else {
                controller.executeSelected();
            }
            return;
        case Qt.Key_Menu:
        case Qt.Key_F10:
            if (contextMenu.hasContextMenuActions(controller.selectedItem)) {
                var scenePos = resultsList.getSelectedItemPosition();
                var localPos = root.mapFromItem(null, scenePos.x, scenePos.y);
                showContextMenu(controller.selectedItem, localPos.x, localPos.y, true);
            }
            return;
        case Qt.Key_1:
            if (hasCtrl) {
                controller.setMode("all");
                return;
            }
            event.accepted = false;
            return;
        case Qt.Key_2:
            if (hasCtrl) {
                controller.setMode("apps");
                return;
            }
            event.accepted = false;
            return;
        case Qt.Key_3:
            if (hasCtrl) {
                controller.setMode("files");
                return;
            }
            event.accepted = false;
            return;
        case Qt.Key_4:
            if (hasCtrl) {
                controller.setMode("plugins");
                return;
            }
            event.accepted = false;
            return;
        case Qt.Key_Slash:
            if (event.modifiers === Qt.NoModifier && searchField.text.length === 0) {
                controller.setMode("files", true);
                return;
            }
            event.accepted = false;
            return;
        default:
            event.accepted = false;
        }
    }

    Item {
        anchors.fill: parent
        visible: !editMode

        Item {
            id: footerBar
            anchors.left: parent.left
            anchors.right: parent.right
            anchors.bottom: parent.bottom
            anchors.leftMargin: root.parentModal?.borderWidth ?? 1
            anchors.rightMargin: root.parentModal?.borderWidth ?? 1
            anchors.bottomMargin: root.parentModal?.borderWidth ?? 1
            readonly property bool showFooter: SettingsData.dankLauncherV2Size !== "micro" && SettingsData.dankLauncherV2ShowFooter
            height: showFooter ? 36 : 0
            visible: showFooter
            clip: true

            Rectangle {
                anchors.fill: parent
                anchors.topMargin: -Theme.cornerRadius
                color: Theme.withAlpha(Theme.surfaceContainerHigh, Theme.popupTransparency)
                radius: Theme.cornerRadius
            }

            Row {
                id: modeButtonsRow
                anchors.left: parent.left
                anchors.leftMargin: Theme.spacingXS
                anchors.verticalCenter: parent.verticalCenter
                layoutDirection: I18n.isRtl ? Qt.RightToLeft : Qt.LeftToRight
                spacing: 2

                Repeater {
                    model: [
                        {
                            id: "all",
                            label: I18n.tr("All"),
                            icon: "search"
                        },
                        {
                            id: "apps",
                            label: I18n.tr("Apps"),
                            icon: "apps"
                        },
                        {
                            id: "files",
                            label: I18n.tr("Files"),
                            icon: "folder"
                        },
                        {
                            id: "plugins",
                            label: I18n.tr("Plugins"),
                            icon: "extension"
                        }
                    ]

                    Rectangle {
                        required property var modelData
                        required property int index

                        width: buttonContent.width + Theme.spacingM * 2
                        height: 28
                        radius: Theme.cornerRadius
                        color: controller.searchMode === modelData.id || modeArea.containsMouse ? Theme.primaryContainer : "transparent"

                        Row {
                            id: buttonContent
                            anchors.centerIn: parent
                            spacing: Theme.spacingXS

                            DankIcon {
                                anchors.verticalCenter: parent.verticalCenter
                                name: modelData.icon
                                size: 14
                                color: controller.searchMode === modelData.id ? Theme.primary : Theme.surfaceVariantText
                            }

                            StyledText {
                                anchors.verticalCenter: parent.verticalCenter
                                text: modelData.label
                                font.pixelSize: Theme.fontSizeSmall
                                color: controller.searchMode === modelData.id ? Theme.primary : Theme.surfaceText
                            }
                        }

                        MouseArea {
                            id: modeArea
                            anchors.fill: parent
                            hoverEnabled: true
                            cursorShape: Qt.PointingHandCursor
                            onClicked: controller.setMode(modelData.id)
                        }
                    }
                }
            }

            Row {
                id: hintsRow
                anchors.right: parent.right
                anchors.rightMargin: Theme.spacingS
                anchors.verticalCenter: parent.verticalCenter
                layoutDirection: I18n.isRtl ? Qt.RightToLeft : Qt.LeftToRight
                spacing: Theme.spacingM

                StyledText {
                    anchors.verticalCenter: parent.verticalCenter
                    text: "↑↓ " + I18n.tr("nav")
                    font.pixelSize: Theme.fontSizeSmall - 1
                    color: Theme.surfaceVariantText
                }

                StyledText {
                    anchors.verticalCenter: parent.verticalCenter
                    text: "↵ " + I18n.tr("open")
                    font.pixelSize: Theme.fontSizeSmall - 1
                    color: Theme.surfaceVariantText
                }

                StyledText {
                    anchors.verticalCenter: parent.verticalCenter
                    text: "Tab " + I18n.tr("actions")
                    font.pixelSize: Theme.fontSizeSmall - 1
                    color: Theme.surfaceVariantText
                    visible: actionPanel.hasActions
                }
            }
        }

        Column {
            anchors.left: parent.left
            anchors.right: parent.right
            anchors.top: parent.top
            anchors.bottom: footerBar.top
            anchors.leftMargin: Theme.spacingM
            anchors.rightMargin: Theme.spacingM
            anchors.topMargin: Theme.spacingM
            spacing: Theme.spacingXS
            clip: false

            Row {
                width: parent.width
                spacing: Theme.spacingS

                Rectangle {
                    id: pluginBadge
                    visible: controller.activePluginName.length > 0
                    width: visible ? pluginBadgeContent.implicitWidth + Theme.spacingM : 0
                    height: searchField.height
                    radius: 16
                    color: Theme.primary

                    Row {
                        id: pluginBadgeContent
                        anchors.centerIn: parent
                        spacing: Theme.spacingXS

                        DankIcon {
                            anchors.verticalCenter: parent.verticalCenter
                            name: "extension"
                            size: 14
                            color: Theme.primaryText
                        }

                        StyledText {
                            anchors.verticalCenter: parent.verticalCenter
                            text: controller.activePluginName
                            font.pixelSize: Theme.fontSizeSmall
                            font.weight: Font.Medium
                            color: Theme.primaryText
                        }
                    }

                    Behavior on width {
                        NumberAnimation {
                            duration: Theme.shortDuration
                            easing.type: Theme.standardEasing
                        }
                    }
                }

                DankTextField {
                    id: searchField
                    width: parent.width - (pluginBadge.visible ? pluginBadge.width + Theme.spacingS : 0)
                    cornerRadius: Theme.cornerRadius
                    backgroundColor: Theme.withAlpha(Theme.surfaceContainerHigh, Theme.popupTransparency)
                    normalBorderColor: Theme.outlineMedium
                    focusedBorderColor: Theme.primary
                    leftIconName: controller.activePluginId ? "extension" : controller.searchQuery.startsWith("/") ? "folder" : "search"
                    leftIconSize: Theme.iconSize
                    leftIconColor: Theme.surfaceVariantText
                    leftIconFocusedColor: Theme.primary
                    showClearButton: true
                    textColor: Theme.surfaceText
                    font.pixelSize: Theme.fontSizeLarge
                    enabled: root.parentModal ? root.parentModal.spotlightOpen : true
                    placeholderText: ""
                    ignoreUpDownKeys: true
                    ignoreTabKeys: true
                    keyForwardTargets: [root]

                    onTextChanged: {
                        controller.setSearchQuery(text);
                        if (actionPanel.expanded) {
                            actionPanel.hide();
                        }
                    }

                    Keys.onPressed: event => {
                        if (event.key === Qt.Key_Escape) {
                            if (root.parentModal) {
                                root.parentModal.hide();
                            }
                            event.accepted = true;
                        } else if ((event.key === Qt.Key_Return || event.key === Qt.Key_Enter)) {
                            if (actionPanel.expanded && actionPanel.selectedActionIndex > 0) {
                                actionPanel.executeSelectedAction();
                            } else {
                                controller.executeSelected();
                            }
                            event.accepted = true;
                        }
                    }
                }
            }

            Row {
                id: categoryRow
                width: parent.width
                height: controller.activePluginCategories.length > 0 ? 36 : 0
                visible: controller.activePluginCategories.length > 0
                spacing: Theme.spacingS

                clip: true

                Behavior on height {
                    NumberAnimation {
                        duration: Theme.shortDuration
                        easing.type: Theme.standardEasing
                    }
                }

                DankDropdown {
                    id: categoryDropdown
                    width: Math.min(200, parent.width)
                    compactMode: true
                    dropdownWidth: 200
                    popupWidth: 240
                    maxPopupHeight: 300
                    enableFuzzySearch: controller.activePluginCategories.length > 8
                    currentValue: {
                        const cats = controller.activePluginCategories;
                        const current = controller.activePluginCategory;
                        if (!current)
                            return cats.length > 0 ? cats[0].name : "";
                        for (let i = 0; i < cats.length; i++) {
                            if (cats[i].id === current)
                                return cats[i].name;
                        }
                        return cats.length > 0 ? cats[0].name : "";
                    }
                    options: {
                        const cats = controller.activePluginCategories;
                        const names = [];
                        for (let i = 0; i < cats.length; i++)
                            names.push(cats[i].name);
                        return names;
                    }

                    onValueChanged: value => {
                        const cats = controller.activePluginCategories;
                        for (let i = 0; i < cats.length; i++) {
                            if (cats[i].name === value) {
                                controller.setActivePluginCategory(cats[i].id);
                                return;
                            }
                        }
                    }
                }
            }

            Item {
                id: fileFilterRow
                width: parent.width
                height: showFileFilters ? fileFilterContent.height : 0
                visible: showFileFilters

                readonly property bool showFileFilters: controller.searchMode === "files"

                Behavior on height {
                    NumberAnimation {
                        duration: Theme.shortDuration
                        easing.type: Theme.standardEasing
                    }
                }

                Row {
                    id: fileFilterContent
                    width: parent.width
                    spacing: Theme.spacingS

                    Row {
                        id: typeChips
                        anchors.verticalCenter: parent.verticalCenter
                        spacing: 2
                        visible: DSearchService.supportsTypeFilter

                        Repeater {
                            model: [
                                {
                                    id: "all",
                                    label: I18n.tr("All"),
                                    icon: "search"
                                },
                                {
                                    id: "file",
                                    label: I18n.tr("Files"),
                                    icon: "insert_drive_file"
                                },
                                {
                                    id: "dir",
                                    label: I18n.tr("Folders"),
                                    icon: "folder"
                                }
                            ]

                            Rectangle {
                                required property var modelData
                                required property int index

                                width: chipContent.width + Theme.spacingM * 2
                                height: sortDropdown.height
                                radius: Theme.cornerRadius
                                color: controller.fileSearchType === modelData.id || chipArea.containsMouse ? Theme.primaryContainer : "transparent"

                                Row {
                                    id: chipContent
                                    anchors.centerIn: parent
                                    spacing: Theme.spacingXS

                                    DankIcon {
                                        anchors.verticalCenter: parent.verticalCenter
                                        name: modelData.icon
                                        size: 14
                                        color: controller.fileSearchType === modelData.id ? Theme.primary : Theme.surfaceVariantText
                                    }

                                    StyledText {
                                        anchors.verticalCenter: parent.verticalCenter
                                        text: modelData.label
                                        font.pixelSize: Theme.fontSizeSmall
                                        color: controller.fileSearchType === modelData.id ? Theme.primary : Theme.surfaceText
                                    }
                                }

                                MouseArea {
                                    id: chipArea
                                    anchors.fill: parent
                                    hoverEnabled: true
                                    cursorShape: Qt.PointingHandCursor
                                    onClicked: controller.setFileSearchType(modelData.id)
                                }
                            }
                        }
                    }

                    Rectangle {
                        width: 1
                        height: 20
                        anchors.verticalCenter: parent.verticalCenter
                        color: Theme.outlineMedium
                        visible: typeChips.visible
                    }

                    DankDropdown {
                        id: sortDropdown
                        anchors.verticalCenter: parent.verticalCenter
                        width: Math.min(130, parent.width / 3)
                        compactMode: true
                        dropdownWidth: 130
                        popupWidth: 150
                        maxPopupHeight: 200
                        currentValue: {
                            switch (controller.fileSearchSort) {
                            case "score":
                                return I18n.tr("Score");
                            case "name":
                                return I18n.tr("Name");
                            case "modified":
                                return I18n.tr("Modified");
                            case "size":
                                return I18n.tr("Size");
                            default:
                                return I18n.tr("Score");
                            }
                        }
                        options: [I18n.tr("Score"), I18n.tr("Name"), I18n.tr("Modified"), I18n.tr("Size")]

                        onValueChanged: value => {
                            var sortMap = {};
                            sortMap[I18n.tr("Score")] = "score";
                            sortMap[I18n.tr("Name")] = "name";
                            sortMap[I18n.tr("Modified")] = "modified";
                            sortMap[I18n.tr("Size")] = "size";
                            controller.setFileSearchSort(sortMap[value] || "score");
                        }
                    }

                    DankTextField {
                        id: extFilterField
                        anchors.verticalCenter: parent.verticalCenter
                        width: Math.min(100, parent.width / 4)
                        height: sortDropdown.height
                        placeholderText: I18n.tr("ext")
                        font.pixelSize: Theme.fontSizeSmall
                        showClearButton: text.length > 0

                        onTextChanged: {
                            controller.setFileSearchExt(text.trim());
                        }
                    }
                }
            }

            Item {
                width: parent.width
                height: parent.height - searchField.height - categoryRow.height - fileFilterRow.height - actionPanel.height - Theme.spacingXS * ((categoryRow.visible ? 1 : 0) + (fileFilterRow.visible ? 1 : 0) + 2)
                opacity: root.parentModal?.isClosing ? 0 : 1

                ResultsList {
                    id: resultsList
                    anchors.fill: parent
                    controller: root.controller

                    onItemRightClicked: (index, item, sceneX, sceneY) => {
                        if (item && contextMenu.hasContextMenuActions(item)) {
                            var localPos = root.mapFromItem(null, sceneX, sceneY);
                            root.showContextMenu(item, localPos.x, localPos.y, false);
                        }
                    }
                }
            }

            ActionPanel {
                id: actionPanel
                width: parent.width
                selectedItem: controller.selectedItem
                controller: controller
            }
        }
    }

    Connections {
        target: controller
        function onSelectedItemChanged() {
            if (actionPanel.expanded && !actionPanel.hasActions) {
                actionPanel.hide();
            }
        }
        function onSearchQueryRequested(query) {
            searchField.text = query;
        }
        function onModeChanged() {
            extFilterField.text = "";
        }
    }

    FocusScope {
        id: editView
        anchors.fill: parent
        anchors.margins: Theme.spacingM
        visible: editMode
        focus: editMode

        Keys.onPressed: event => {
            if (event.key === Qt.Key_Escape) {
                closeEditMode();
                event.accepted = true;
            } else if (event.key === Qt.Key_Return || event.key === Qt.Key_Enter) {
                if (event.modifiers & Qt.ControlModifier) {
                    saveAppOverride();
                    event.accepted = true;
                }
            } else if (event.key === Qt.Key_S && event.modifiers & Qt.ControlModifier) {
                saveAppOverride();
                event.accepted = true;
            }
        }

        Column {
            anchors.fill: parent
            spacing: Theme.spacingM

            Row {
                width: parent.width
                spacing: Theme.spacingM

                Rectangle {
                    width: 40
                    height: 40
                    radius: Theme.cornerRadius
                    color: backButtonArea.containsMouse ? Theme.surfaceHover : "transparent"

                    DankIcon {
                        anchors.centerIn: parent
                        name: "arrow_back"
                        size: 20
                        color: Theme.surfaceText
                    }

                    MouseArea {
                        id: backButtonArea
                        anchors.fill: parent
                        hoverEnabled: true
                        cursorShape: Qt.PointingHandCursor
                        onClicked: closeEditMode()
                    }
                }

                Image {
                    width: 40
                    height: 40
                    source: editingApp?.icon ? "image://icon/" + editingApp.icon : "image://icon/application-x-executable"
                    sourceSize.width: 40
                    sourceSize.height: 40
                    fillMode: Image.PreserveAspectFit
                    anchors.verticalCenter: parent.verticalCenter
                }

                Column {
                    anchors.verticalCenter: parent.verticalCenter
                    spacing: 2

                    StyledText {
                        text: I18n.tr("Edit App")
                        font.pixelSize: Theme.fontSizeLarge
                        color: Theme.surfaceText
                        font.weight: Font.Medium
                    }

                    StyledText {
                        text: editingApp?.name || ""
                        font.pixelSize: Theme.fontSizeSmall
                        color: Theme.surfaceVariantText
                    }
                }
            }

            Rectangle {
                width: parent.width
                height: 1
                color: Theme.outlineMedium
            }

            Flickable {
                width: parent.width
                height: parent.height - y - buttonsRow.height - Theme.spacingM
                contentHeight: editFieldsColumn.height
                clip: true
                boundsBehavior: Flickable.StopAtBounds

                Column {
                    id: editFieldsColumn
                    width: parent.width
                    spacing: Theme.spacingS

                    Column {
                        width: parent.width
                        spacing: 4

                        StyledText {
                            text: I18n.tr("Name")
                            font.pixelSize: Theme.fontSizeSmall
                            color: Theme.surfaceText
                            font.weight: Font.Medium
                        }

                        DankTextField {
                            id: editNameField
                            width: parent.width
                            placeholderText: editingApp?.name || ""
                            keyNavigationTab: editIconField
                            keyNavigationBacktab: editExtraFlagsField
                        }
                    }

                    Column {
                        width: parent.width
                        spacing: 4

                        StyledText {
                            text: I18n.tr("Icon")
                            font.pixelSize: Theme.fontSizeSmall
                            color: Theme.surfaceText
                            font.weight: Font.Medium
                        }

                        DankTextField {
                            id: editIconField
                            width: parent.width
                            placeholderText: editingApp?.icon || ""
                            keyNavigationTab: editCommentField
                            keyNavigationBacktab: editNameField
                        }
                    }

                    Column {
                        width: parent.width
                        spacing: 4

                        StyledText {
                            text: I18n.tr("Description")
                            font.pixelSize: Theme.fontSizeSmall
                            color: Theme.surfaceText
                            font.weight: Font.Medium
                        }

                        DankTextField {
                            id: editCommentField
                            width: parent.width
                            placeholderText: editingApp?.comment || ""
                            keyNavigationTab: editEnvVarsField
                            keyNavigationBacktab: editIconField
                        }
                    }

                    Column {
                        width: parent.width
                        spacing: 4

                        StyledText {
                            text: I18n.tr("Environment Variables")
                            font.pixelSize: Theme.fontSizeSmall
                            color: Theme.surfaceText
                            font.weight: Font.Medium
                        }

                        StyledText {
                            text: "KEY=value KEY2=value2"
                            font.pixelSize: Theme.fontSizeSmall - 1
                            color: Theme.surfaceVariantText
                        }

                        DankTextField {
                            id: editEnvVarsField
                            width: parent.width
                            placeholderText: "VAR=value"
                            keyNavigationTab: editExtraFlagsField
                            keyNavigationBacktab: editCommentField
                        }
                    }

                    Column {
                        width: parent.width
                        spacing: 4

                        StyledText {
                            text: I18n.tr("Extra Arguments")
                            font.pixelSize: Theme.fontSizeSmall
                            color: Theme.surfaceText
                            font.weight: Font.Medium
                        }

                        DankTextField {
                            id: editExtraFlagsField
                            width: parent.width
                            placeholderText: "--flag --option=value"
                            keyNavigationTab: editNameField
                            keyNavigationBacktab: editEnvVarsField
                        }
                    }
                }
            }

            Row {
                id: buttonsRow
                anchors.horizontalCenter: parent.horizontalCenter
                spacing: Theme.spacingM

                Rectangle {
                    id: resetButton
                    width: 90
                    height: 40
                    radius: Theme.cornerRadius
                    color: resetButtonArea.containsMouse ? Theme.surfacePressed : Theme.surfaceVariantAlpha
                    visible: SessionData.getAppOverride(editAppId) !== null

                    StyledText {
                        text: I18n.tr("Reset")
                        font.pixelSize: Theme.fontSizeMedium
                        color: Theme.error
                        font.weight: Font.Medium
                        anchors.centerIn: parent
                    }

                    MouseArea {
                        id: resetButtonArea
                        anchors.fill: parent
                        hoverEnabled: true
                        cursorShape: Qt.PointingHandCursor
                        onClicked: resetAppOverride()
                    }
                }

                Rectangle {
                    id: cancelButton
                    width: 90
                    height: 40
                    radius: Theme.cornerRadius
                    color: cancelButtonArea.containsMouse ? Theme.surfacePressed : Theme.surfaceVariantAlpha

                    StyledText {
                        text: I18n.tr("Cancel")
                        font.pixelSize: Theme.fontSizeMedium
                        color: Theme.surfaceText
                        font.weight: Font.Medium
                        anchors.centerIn: parent
                    }

                    MouseArea {
                        id: cancelButtonArea
                        anchors.fill: parent
                        hoverEnabled: true
                        cursorShape: Qt.PointingHandCursor
                        onClicked: closeEditMode()
                    }
                }

                Rectangle {
                    id: saveButton
                    width: 90
                    height: 40
                    radius: Theme.cornerRadius
                    color: saveButtonArea.containsMouse ? Qt.rgba(Theme.primary.r, Theme.primary.g, Theme.primary.b, 0.9) : Theme.primary

                    StyledText {
                        text: I18n.tr("Save")
                        font.pixelSize: Theme.fontSizeMedium
                        color: Theme.primaryText
                        font.weight: Font.Medium
                        anchors.centerIn: parent
                    }

                    MouseArea {
                        id: saveButtonArea
                        anchors.fill: parent
                        hoverEnabled: true
                        cursorShape: Qt.PointingHandCursor
                        onClicked: saveAppOverride()
                    }
                }
            }
        }
    }
}
