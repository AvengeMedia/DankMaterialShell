pragma ComponentBehavior: Bound

import QtQuick
import Quickshell
import qs.Common
import qs.Modals.Common
import qs.Services
import qs.Widgets

Item {
    id: keybindsTab

    LayoutMirroring.enabled: I18n.isRtl
    LayoutMirroring.childrenInherit: true

    property var parentModal: null
    property string selectedCategory: ""
    property string searchQuery: ""
    property string requestedSearchQuery: ""
    property string expandedKey: ""
    property bool showingNewBind: false

    property int _lastDataVersion: -1
    property var _cachedCategories: []
    property var _filteredBinds: []
    property real _savedScrollY: 0
    property bool _preserveScroll: false
    property string _editingKey: ""

    property var editDraft: null
    property var reviewSnapshot: null
    property bool reviewingEdit: false
    property bool editBusy: false
    property string editError: ""
    property int _editRequest: 0
    property bool _editAlive: true
    readonly property bool hasEditDraft: editDraft !== null
    readonly property bool editInvalidated: hasEditDraft && (editDraft.provider !== KeybindsService.currentProvider || !KeybindsService.bindEditSession || editDraft.session !== KeybindsService.bindEditSession)

    onEditInvalidatedChanged: {
        if (!editInvalidated)
            return;
        _editRequest++;
        editBusy = false;
        reviewingEdit = true;
        reviewSnapshot = null;
        editError = KeybindsService.bindEditError("invalidated");
    }

    Component.onDestruction: {
        _editAlive = false;
        _editRequest++;
    }

    function beginEdit(binding, key) {
        if (hasEditDraft || editBusy || KeybindsService.bindMutationBusy) {
            ToastService.showInfo(I18n.tr("Save or discard the current edit before editing another shortcut.", "Aqueous keyboard shortcut editor, retaining an unsaved edit while reviewing current bindings"));
            return false;
        }
        try {
            editDraft = KeybindsService.captureBindEdit(binding, key);
            editError = "";
            reviewSnapshot = null;
            reviewingEdit = false;
            return true;
        } catch (e) {
            ToastService.showError(I18n.tr("Failed to load keybinds", "Aqueous shortcut editor could not load the current bindings"), AqueousService.errorMessage(String(e)), String(e));
            return false;
        }
    }

    function updateEditDraft(originalKey, data) {
        if (!editDraft || editDraft.operation !== "set" || editBusy || editInvalidated)
            return;
        editDraft = KeybindsService.updateBindEdit(editDraft, originalKey, data);
    }

    function submitEdit() {
        if (!editDraft || editBusy || reviewingEdit || editInvalidated || KeybindsService.bindMutationBusy)
            return;
        editBusy = true;
        editError = "";
        const token = ++_editRequest;
        const complete = result => {
            if (!keybindsTab._editAlive || token !== keybindsTab._editRequest)
                return;
            keybindsTab.editBusy = false;
            if (result.success) {
                const key = keybindsTab.editDraft.operation === "set" ? keybindsTab.editDraft.data.key : "";
                const action = keybindsTab.editDraft.data.action;
                keybindsTab.editDraft = null;
                keybindsTab.reviewSnapshot = null;
                keybindsTab.reviewingEdit = false;
                keybindsTab._editingKey = key;
                keybindsTab.expandedKey = action;
                return;
            }
            keybindsTab.reviewSnapshot = result.snapshot || null;
            keybindsTab.reviewingEdit = result.code !== "load_failed" && result.code !== "busy";
            keybindsTab.editError = KeybindsService.bindEditError(result.code);
        };
        switch (editDraft.operation) {
        case "set":
            KeybindsService.saveBind(editDraft.originalKey, editDraft.data, editDraft, complete);
            return;
        case "remove":
            KeybindsService.removeBind(editDraft.originalKey, editDraft, complete);
            return;
        case "reset":
            KeybindsService.resetBind(editDraft.originalKey, editDraft, complete);
            return;
        }
    }

    function reloadEdit() {
        if (!editDraft || editBusy || editInvalidated)
            return;
        editBusy = true;
        reviewingEdit = true;
        const token = ++_editRequest;
        KeybindsService.loadBindReview((snapshot, message) => {
            if (!keybindsTab._editAlive || token !== keybindsTab._editRequest)
                return;
            keybindsTab.editBusy = false;
            keybindsTab.reviewSnapshot = snapshot;
            keybindsTab.editError = message;
        });
    }

    function acceptReview() {
        if (!editDraft || !reviewSnapshot || editBusy || editInvalidated)
            return;
        const result = KeybindsService.reconcileBindEdit(editDraft, reviewSnapshot);
        if (!result.draft) {
            editError = KeybindsService.bindEditError(result.code);
            return;
        }
        editDraft = result.draft;
        reviewingEdit = false;
        editError = "";
        if (editDraft.operation !== "set")
            confirmEditRemoval();
    }

    function confirmEditRemoval() {
        if (!editDraft)
            return;
        if (editDraft.operation === "reset") {
            confirmResetBind(editDraft.originalKey, "");
            return;
        }
        confirmRemoveBind(editDraft.originalKey, "");
    }

    function discardEdit() {
        if (editBusy || KeybindsService.bindMutationBusy)
            return;
        _editRequest++;
        editDraft = null;
        reviewSnapshot = null;
        reviewingEdit = false;
        editError = "";
        expandedKey = "";
        showingNewBind = false;
        _editingKey = "";
        KeybindsService.loadBinds(false);
    }

    function _updateFiltered() {
        let allBinds = KeybindsService.getFlatBinds();
        if (keybindsTab.editDraft?.action) {
            const binding = keybindsTab.editDraft.binding;
            const found = allBinds.some(bind => bind.action === binding.action);
            allBinds = allBinds.map(bind => bind.action === binding.action ? binding : bind);
            if (!found)
                allBinds.push(binding);
        }
        if (!searchQuery && !selectedCategory) {
            _filteredBinds = allBinds;
            return;
        }

        const q = searchQuery.toLowerCase();
        const isOverrideFilter = selectedCategory === "__overrides__";
        const result = [];

        for (let i = 0; i < allBinds.length; i++) {
            const group = allBinds[i];
            if (q) {
                let keyMatch = false;
                for (let k = 0; k < group.keys.length; k++) {
                    if (group.keys[k].key.toLowerCase().indexOf(q) !== -1) {
                        keyMatch = true;
                        break;
                    }
                }
                if (!keyMatch && group.desc.toLowerCase().indexOf(q) === -1 && group.action.toLowerCase().indexOf(q) === -1)
                    continue;
            }
            if (isOverrideFilter) {
                let hasOverride = false;
                for (let k = 0; k < group.keys.length; k++) {
                    if (group.keys[k].isOverride) {
                        hasOverride = true;
                        break;
                    }
                }
                if (!hasOverride)
                    continue;
            } else if (selectedCategory && group.category !== selectedCategory) {
                continue;
            }
            result.push(group);
        }
        _filteredBinds = result;
    }

    function _updateCategories() {
        _cachedCategories = ["__overrides__"].concat(KeybindsService.getCategories());
    }

    function getCategoryLabel(cat) {
        if (cat === "__overrides__")
            return I18n.tr("Overrides");
        return cat;
    }

    function toggleExpanded(action) {
        if (KeybindsService.requiresBindReview && !keybindsTab.hasEditDraft) {
            const binding = KeybindsService.getFlatBinds().find(bind => bind.action === action);
            if (!binding || !keybindsTab.beginEdit(binding, binding.keys[0]?.key || ""))
                return;
        } else if (keybindsTab.hasEditDraft && action !== keybindsTab.editDraft.action) {
            ToastService.showInfo(I18n.tr("Save or discard the current edit before editing another shortcut.", "Aqueous keyboard shortcut editor, retaining an unsaved edit while reviewing current bindings"));
            return;
        }
        expandedKey = expandedKey === action ? "" : action;
    }

    function startNewBind() {
        if (KeybindsService.readOnly) {
            KeybindsService.showHyprlandReadOnlyWarning();
            return;
        }
        if (KeybindsService.requiresBindReview) {
            if (!keybindsTab.beginEdit({
                action: "",
                desc: ""
            }, ""))
                return;
            newBindItem.resetEdits();
        }
        showingNewBind = true;
        expandedKey = "";
    }

    function cancelNewBind() {
        if (keybindsTab.hasEditDraft) {
            keybindsTab.discardEdit();
            return;
        }
        showingNewBind = false;
    }

    function saveNewBind(bindData) {
        saveBind("", bindData);
    }

    function saveBind(originalKey, bindData) {
        if (KeybindsService.requiresBindReview) {
            keybindsTab.updateEditDraft(originalKey, bindData);
            keybindsTab.submitEdit();
            return;
        }
        KeybindsService.saveBind(originalKey, bindData);
        _editingKey = bindData.key;
        expandedKey = bindData.action;
    }

    function confirmRemoveBind(key, remainingKey) {
        const draft = KeybindsService.requiresBindReview ? prepareRemoval(key, "remove") : null;
        if (KeybindsService.requiresBindReview && !draft)
            return;
        const baselineDraft = keybindsTab.editDraft;
        removeBindConfirm.showWithOptions({
            title: I18n.tr("Remove Shortcut?"),
            message: KeybindsService.currentProvider === "hyprland" ? I18n.tr("Remove the shortcut %1? An unbind entry will be saved to dms/binds-user.lua so it stays removed across DMS updates.").arg(key) : I18n.tr("Remove the shortcut %1?").arg(key),
            confirmText: I18n.tr("Remove"),
            confirmColor: Theme.primary,
            onConfirm: () => {
                if (draft) {
                    if (keybindsTab.editDraft !== baselineDraft)
                        return;
                    keybindsTab.editDraft = draft;
                    keybindsTab.submitEdit();
                    return;
                }
                KeybindsService.removeBind(key);
                keybindsTab._editingKey = remainingKey;
            }
        });
    }

    function confirmResetBind(key, remainingKey) {
        const draft = KeybindsService.requiresBindReview ? prepareRemoval(key, "reset") : null;
        if (KeybindsService.requiresBindReview && !draft)
            return;
        const baselineDraft = keybindsTab.editDraft;
        removeBindConfirm.showWithOptions({
            title: I18n.tr("Reset to default"),
            message: I18n.tr("Drop your override for %1 so the DMS default action re-applies?").arg(key),
            confirmText: I18n.tr("Reset"),
            confirmColor: Theme.primary,
            onConfirm: () => {
                if (draft) {
                    if (keybindsTab.editDraft !== baselineDraft)
                        return;
                    keybindsTab.editDraft = draft;
                    keybindsTab.submitEdit();
                    return;
                }
                KeybindsService.resetBind(key);
                keybindsTab._editingKey = remainingKey;
            }
        });
    }

    function prepareRemoval(key, operation) {
        if (!hasEditDraft) {
            const binding = KeybindsService.getFlatBinds().find(bind => bind.keys.some(entry => entry.key === key));
            if (!binding || !beginEdit(binding, key))
                return null;
        }
        if (editBusy || reviewingEdit || editInvalidated)
            return null;
        return KeybindsService.updateBindEdit(editDraft, key, null, operation);
    }

    function _onSaveSuccess() {
        if (showingNewBind) {
            showingNewBind = false;
            selectedCategory = "";
        }
    }

    function scrollToTop() {
        flickable.contentY = 0;
    }

    function _scrollToExpandedItem() {
        for (let i = 0; i < bindsRepeater.count; i++) {
            const item = bindsRepeater.itemAt(i);
            if (item && item.modelData.action === expandedKey) {
                const itemY = item.mapToItem(flickable.contentItem, 0, 0).y;
                const itemH = item.height;
                const viewH = flickable.height;
                if (itemY >= flickable.contentY && itemY + itemH <= flickable.contentY + viewH)
                    return;
                flickable.contentY = Math.max(0, Math.min(itemY - viewH / 4, flickable.contentHeight - viewH));
                return;
            }
        }
        flickable.contentY = _savedScrollY;
    }

    Timer {
        id: searchDebounce
        interval: 150
        onTriggered: keybindsTab._updateFiltered()
    }

    ConfirmModal {
        id: removeBindConfirm
    }

    Connections {
        target: KeybindsService
        function onBindsLoaded() {
            const savedY = keybindsTab._savedScrollY;
            const wasPreserving = keybindsTab._preserveScroll;
            keybindsTab._lastDataVersion = KeybindsService._dataVersion;
            keybindsTab._updateCategories();
            keybindsTab._updateFiltered();
            keybindsTab._preserveScroll = false;
            if (wasPreserving) {
                if (keybindsTab.expandedKey)
                    Qt.callLater(keybindsTab._scrollToExpandedItem);
                else
                    Qt.callLater(() => flickable.contentY = savedY);
            }
        }
        function onBindSaved(key) {
            keybindsTab._savedScrollY = flickable.contentY;
            keybindsTab._preserveScroll = true;
        }
        function onBindSaveCompleted(success) {
            if (success)
                keybindsTab._onSaveSuccess();
        }
        function onBindRemoved(key) {
            keybindsTab._savedScrollY = flickable.contentY;
            keybindsTab._preserveScroll = true;
        }
    }

    function _ensureCurrentProvider() {
        if (!KeybindsService.available)
            return;
        if (KeybindsService.requiresBindReview) {
            if (!keybindsTab.hasEditDraft && !KeybindsService.bindMutationBusy)
                KeybindsService.loadBinds(false);
            return;
        }
        const cachedProvider = KeybindsService.keybinds?.provider;
        const targetProvider = KeybindsService.currentProvider;
        if (cachedProvider !== targetProvider || KeybindsService._dataVersion === 0) {
            KeybindsService.loadBinds();
            return;
        }
        if (_lastDataVersion !== KeybindsService._dataVersion) {
            _lastDataVersion = KeybindsService._dataVersion;
            _updateCategories();
            _updateFiltered();
        }
    }

    function _applyRequestedSearch() {
        if (!requestedSearchQuery)
            return;
        const query = requestedSearchQuery;
        selectedCategory = "";
        searchField.text = query;
        searchQuery = query;
        _updateFiltered();
        if (parentModal?.keybindSearchQuery === query)
            parentModal.keybindSearchQuery = "";
        Qt.callLater(scrollToTop);
    }

    Component.onCompleted: {
        _ensureCurrentProvider();
        Qt.callLater(_applyRequestedSearch);
    }

    onRequestedSearchQueryChanged: Qt.callLater(_applyRequestedSearch)

    onVisibleChanged: {
        if (!visible)
            return;
        _ensureCurrentProvider();
        Qt.callLater(() => {
            _applyRequestedSearch();
            scrollToTop();
        });
    }

    DankFlickable {
        id: flickable
        anchors.fill: parent
        clip: true
        contentWidth: width
        contentHeight: contentColumn.implicitHeight

        Column {
            id: contentColumn
            width: flickable.width
            spacing: Theme.spacingL
            topPadding: Theme.spacingXL
            bottomPadding: Theme.spacingXL

            StyledRect {
                width: Math.min(650, parent.width - Theme.spacingL * 2)
                height: headerSection.implicitHeight + Theme.spacingL * 2
                anchors.horizontalCenter: parent.horizontalCenter
                radius: Theme.cornerRadius
                color: Theme.floatingWindowNestedSurface
                border.color: Theme.outlineMedium
                border.width: Theme.layerOutlineWidth

                Column {
                    id: headerSection
                    anchors.fill: parent
                    anchors.margins: Theme.spacingL
                    spacing: Theme.spacingM

                    Row {
                        width: parent.width
                        spacing: Theme.spacingM

                        DankIcon {
                            name: "keyboard"
                            size: Theme.iconSize
                            color: Theme.primary
                            anchors.verticalCenter: parent.verticalCenter
                        }

                        Column {
                            width: parent.width - Theme.iconSize - Theme.spacingM * 2
                            spacing: Theme.spacingXS
                            anchors.verticalCenter: parent.verticalCenter

                            StyledText {
                                text: I18n.tr("Keyboard Shortcuts")
                                font.pixelSize: Theme.fontSizeLarge
                                font.weight: Font.Medium
                                color: Theme.surfaceText
                                width: parent.width
                                horizontalAlignment: Text.AlignLeft
                            }

                            StyledText {
                                readonly property string bindsFile: KeybindsService.requiresBindReview ? "aqueous-config" : KeybindsService.currentProvider === "niri" ? "dms/binds.kdl" : KeybindsService.currentProvider === "hyprland" ? "dms/binds-user.lua" : "dms/binds.conf"
                                text: KeybindsService.requiresBindReview ? I18n.tr("Click any shortcut to edit Aqueous configuration", "Aqueous keyboard shortcut editor, retaining an unsaved edit while reviewing current bindings") : KeybindsService.readOnly ? I18n.tr("Hyprland conf mode is read-only in Settings") : I18n.tr("Click any shortcut to edit. Changes save to %1").arg(bindsFile)
                                font.pixelSize: Theme.fontSizeSmall
                                color: Theme.surfaceVariantText
                                wrapMode: Text.WordWrap
                                width: parent.width
                                horizontalAlignment: Text.AlignLeft
                            }
                        }
                    }

                    Row {
                        width: parent.width
                        spacing: Theme.spacingM

                        DankTextField {
                            id: searchField
                            width: parent.width - addButton.width - Theme.spacingM
                            placeholderText: I18n.tr("Search keybinds...")
                            leftIconName: "search"
                            onTextChanged: {
                                keybindsTab.searchQuery = text;
                                searchDebounce.restart();
                            }
                        }

                        DankActionButton {
                            id: addButton
                            width: searchField.height
                            height: searchField.height
                            circular: false
                            iconName: "add"
                            iconSize: Theme.iconSize
                            iconColor: Theme.primary
                            anchors.verticalCenter: parent.verticalCenter
                            enabled: !keybindsTab.showingNewBind && !KeybindsService.readOnly
                            opacity: enabled ? 1 : 0.5
                            onClicked: keybindsTab.startNewBind()
                        }
                    }
                }
            }

            StyledRect {
                id: warningBox
                width: Math.min(650, parent.width - Theme.spacingL * 2)
                height: warningSection.implicitHeight + Theme.spacingL * 2
                anchors.horizontalCenter: parent.horizontalCenter
                radius: Theme.cornerRadius

                readonly property var status: KeybindsService.dmsStatus
                readonly property bool showLegacy: KeybindsService.readOnly
                readonly property bool showWarning: !showLegacy && status.included && status.overriddenBy > 0
                readonly property bool showSetup: !showLegacy && !status.included

                color: (showLegacy || showWarning || showSetup) ? Theme.withAlpha(Theme.primary, 0.15) : Theme.withAlpha(Theme.primary, 0)
                border.color: (showLegacy || showWarning || showSetup) ? Theme.withAlpha(Theme.primary, 0.3) : Theme.withAlpha(Theme.primary, 0)
                border.width: 1
                visible: (showLegacy || showWarning || showSetup) && !KeybindsService.loading

                Column {
                    id: warningSection
                    anchors.fill: parent
                    anchors.margins: Theme.spacingL
                    spacing: Theme.spacingM

                    Row {
                        width: parent.width
                        spacing: Theme.spacingM

                        DankIcon {
                            name: warningBox.showWarning ? "info" : "warning"
                            size: Theme.iconSize
                            color: Theme.primary
                            anchors.verticalCenter: parent.verticalCenter
                        }

                        Column {
                            width: parent.width - Theme.iconSize - (fixButton.visible ? fixButton.width + Theme.spacingM : 0) - Theme.spacingM
                            spacing: Theme.spacingXS
                            anchors.verticalCenter: parent.verticalCenter

                            StyledText {
                                text: {
                                    if (warningBox.showLegacy)
                                        return I18n.tr("Hyprland conf mode");
                                    if (warningBox.showSetup)
                                        return I18n.tr("First Time Setup");
                                    if (warningBox.showWarning)
                                        return I18n.tr("Possible Override Conflicts");
                                    return "";
                                }
                                font.pixelSize: Theme.fontSizeMedium
                                font.weight: Font.Medium
                                color: Theme.primary
                                width: parent.width
                                horizontalAlignment: Text.AlignLeft
                            }

                            StyledText {
                                text: {
                                    if (warningBox.showLegacy)
                                        return I18n.tr("This install is still using hyprland.conf. Run dms setup to migrate before changing these settings.");
                                    if (warningBox.showSetup)
                                        return I18n.tr("Click 'Setup' to create %1 and add include to your compositor config.").arg("dms/binds");
                                    if (warningBox.showWarning) {
                                        const count = warningBox.status.overriddenBy;
                                        return I18n.ntr("%1 DMS bind may be overridden by config binds that come after the include.", "%1 DMS binds may be overridden by config binds that come after the include.", count).arg(count);
                                    }
                                    return "";
                                }
                                font.pixelSize: Theme.fontSizeSmall
                                color: Theme.surfaceVariantText
                                wrapMode: Text.WordWrap
                                width: parent.width
                                horizontalAlignment: Text.AlignLeft
                            }
                        }

                        DankButton {
                            id: fixButton
                            visible: !warningBox.showLegacy && warningBox.showSetup
                            text: KeybindsService.fixing ? I18n.tr("Setting up...") : I18n.tr("Setup")
                            backgroundColor: Theme.primary
                            textColor: Theme.primaryText
                            enabled: !KeybindsService.fixing
                            anchors.verticalCenter: parent.verticalCenter
                            onClicked: KeybindsService.fixDmsBindsInclude()
                        }
                    }
                }
            }

            StyledRect {
                width: Math.min(650, parent.width - Theme.spacingL * 2)
                height: categorySection.implicitHeight + Theme.spacingL * 2
                anchors.horizontalCenter: parent.horizontalCenter
                radius: Theme.cornerRadius
                color: Theme.floatingWindowNestedSurface
                border.color: Theme.outlineMedium
                border.width: Theme.layerOutlineWidth

                Column {
                    id: categorySection
                    anchors.fill: parent
                    anchors.margins: Theme.spacingL
                    spacing: Theme.spacingM

                    Flow {
                        width: parent.width
                        spacing: Theme.spacingS

                        Rectangle {
                            readonly property real chipHeight: allChip.implicitHeight + Theme.spacingM
                            width: allChip.implicitWidth + Theme.spacingL
                            height: chipHeight
                            radius: chipHeight / 2
                            color: !keybindsTab.selectedCategory ? Theme.primary : Theme.floatingWindowFieldColor

                            StyledText {
                                id: allChip
                                text: I18n.tr("All")
                                font.pixelSize: Theme.fontSizeSmall
                                color: !keybindsTab.selectedCategory ? Theme.primaryText : Theme.surfaceVariantText
                                anchors.centerIn: parent
                            }

                            MouseArea {
                                anchors.fill: parent
                                cursorShape: Qt.PointingHandCursor
                                onClicked: {
                                    keybindsTab.selectedCategory = "";
                                    keybindsTab._updateFiltered();
                                }
                            }
                        }

                        Repeater {
                            model: keybindsTab._cachedCategories

                            delegate: Rectangle {
                                required property string modelData
                                required property int index

                                readonly property real chipHeight: catText.implicitHeight + Theme.spacingM
                                width: catText.implicitWidth + Theme.spacingL
                                height: chipHeight
                                radius: chipHeight / 2
                                color: keybindsTab.selectedCategory === modelData ? Theme.primary : (modelData === "__overrides__" ? Theme.withAlpha(Theme.primary, 0.15) : Theme.floatingWindowFieldColor)

                                StyledText {
                                    id: catText
                                    text: keybindsTab.getCategoryLabel(modelData)
                                    font.pixelSize: Theme.fontSizeSmall
                                    color: keybindsTab.selectedCategory === modelData ? Theme.primaryText : (modelData === "__overrides__" ? Theme.primary : Theme.surfaceVariantText)
                                    anchors.centerIn: parent
                                }

                                MouseArea {
                                    anchors.fill: parent
                                    cursorShape: Qt.PointingHandCursor
                                    onClicked: {
                                        keybindsTab.selectedCategory = modelData;
                                        keybindsTab._updateFiltered();
                                    }
                                }
                            }
                        }
                    }
                }
            }

            Column {
                width: Math.min(650, parent.width - Theme.spacingL * 2)
                anchors.horizontalCenter: parent.horizontalCenter
                visible: keybindsTab.hasEditDraft && (keybindsTab.reviewingEdit || keybindsTab.editError !== "" || keybindsTab.editDraft.operation !== "set")
                spacing: Theme.spacingM

                StyledText {
                    width: parent.width
                    visible: keybindsTab.reviewingEdit || keybindsTab.editError !== ""
                    text: keybindsTab.editError || I18n.tr("Review the current bindings before saving this edit.", "Aqueous keyboard shortcut editor, retaining an unsaved edit while reviewing current bindings")
                    color: Theme.error
                    wrapMode: Text.WordWrap
                }

                StyledText {
                    width: parent.width
                    visible: keybindsTab.reviewingEdit && !!keybindsTab.reviewSnapshot
                    text: KeybindsService.describeBindReview(keybindsTab.editDraft, keybindsTab.reviewSnapshot)
                    color: Theme.surfaceText
                    wrapMode: Text.WordWrap
                }

                Flow {
                    width: parent.width
                    spacing: Theme.spacingS
                    DankButton {
                        text: I18n.tr("Refresh")
                        enabled: !keybindsTab.editBusy && !keybindsTab.editInvalidated
                        onClicked: keybindsTab.reloadEdit()
                    }
                    DankButton {
                        text: I18n.tr("Accept reviewed changes", "Aqueous keyboard shortcut editor, retaining an unsaved edit while reviewing current bindings")
                        visible: keybindsTab.reviewingEdit && !!keybindsTab.reviewSnapshot
                        enabled: !keybindsTab.editBusy && !keybindsTab.editInvalidated
                        onClicked: keybindsTab.acceptReview()
                    }
                    DankButton {
                        text: I18n.tr("Discard")
                        enabled: !keybindsTab.editBusy && !KeybindsService.bindMutationBusy
                        onClicked: keybindsTab.discardEdit()
                    }
                    DankButton {
                        text: I18n.tr("Remove")
                        visible: keybindsTab.hasEditDraft && keybindsTab.editDraft.operation !== "set"
                        enabled: !keybindsTab.editBusy && !keybindsTab.reviewingEdit && !keybindsTab.editInvalidated
                        onClicked: keybindsTab.confirmEditRemoval()
                    }
                }
            }

            StyledRect {
                width: Math.min(650, parent.width - Theme.spacingL * 2)
                height: newBindSection.implicitHeight + Theme.spacingL * 2
                anchors.horizontalCenter: parent.horizontalCenter
                radius: Theme.cornerRadius
                color: Theme.floatingWindowNestedSurface
                border.color: Theme.outlineMedium
                border.width: Theme.layerOutlineWidth
                visible: keybindsTab.showingNewBind

                Column {
                    id: newBindSection
                    anchors.fill: parent
                    anchors.margins: Theme.spacingL
                    spacing: Theme.spacingM

                    Row {
                        width: parent.width
                        spacing: Theme.spacingM

                        DankIcon {
                            name: "add"
                            size: Theme.iconSize
                            color: Theme.surfaceText
                            anchors.verticalCenter: parent.verticalCenter
                        }

                        StyledText {
                            text: I18n.tr("New Keybind")
                            font.pixelSize: Theme.fontSizeMedium
                            font.weight: Font.Medium
                            color: Theme.surfaceText
                            anchors.verticalCenter: parent.verticalCenter
                        }
                    }

                    KeybindItem {
                        id: newBindItem
                        width: parent.width
                        isNew: true
                        isExpanded: true
                        bindData: ({
                                keys: [
                                    {
                                        key: "",
                                        source: "dms",
                                        isOverride: true
                                    }
                                ],
                                action: "",
                                desc: ""
                            })
                        panelWindow: keybindsTab.parentModal
                        readOnly: KeybindsService.readOnly
                        retainedEdit: keybindsTab.hasEditDraft && keybindsTab.showingNewBind ? keybindsTab.editDraft : null
                        saveBlocked: retainEdits && (keybindsTab.reviewingEdit || keybindsTab.editDraft.operation !== "set")
                        enabled: !retainEdits || (!keybindsTab.editBusy && !keybindsTab.editInvalidated && !KeybindsService.bindMutationBusy)
                        onEditChanged: {
                            if (retainEdits)
                                keybindsTab.updateEditDraft("", {
                                    key: editKey,
                                    action: editAction,
                                    desc: editDesc
                                });
                        }
                        onSaveBind: (originalKey, newData) => keybindsTab.saveNewBind(newData)
                        onCancelEdit: keybindsTab.cancelNewBind()
                    }
                }
            }

            StyledRect {
                width: Math.min(650, parent.width - Theme.spacingL * 2)
                height: bindsListHeader.implicitHeight + Theme.spacingL * 2
                anchors.horizontalCenter: parent.horizontalCenter
                radius: Theme.cornerRadius
                color: Theme.floatingWindowNestedSurface
                border.color: Theme.outlineMedium
                border.width: Theme.layerOutlineWidth

                Column {
                    id: bindsListHeader
                    anchors.fill: parent
                    anchors.margins: Theme.spacingL
                    spacing: Theme.spacingM

                    Row {
                        width: parent.width
                        spacing: Theme.spacingM

                        DankIcon {
                            name: "list"
                            size: Theme.iconSize
                            color: Theme.primary
                            anchors.verticalCenter: parent.verticalCenter
                        }

                        StyledText {
                            text: {
                                if (KeybindsService.loading)
                                    return I18n.tr("Shortcuts");
                                const count = keybindsTab._filteredBinds.length;
                                return count === 1 ? I18n.tr("Shortcut (%1)").arg(count) : I18n.tr("Shortcuts (%1)").arg(count);
                            }
                            font.pixelSize: Theme.fontSizeMedium
                            font.weight: Font.Medium
                            color: Theme.surfaceText
                            anchors.verticalCenter: parent.verticalCenter
                        }
                    }

                    Row {
                        width: parent.width
                        spacing: Theme.spacingM
                        visible: KeybindsService.loading

                        DankIcon {
                            id: loadingIcon
                            name: "sync"
                            size: 20
                            color: Theme.primary
                            anchors.verticalCenter: parent.verticalCenter
                            smoothTransform: KeybindsService.loading

                            RotationAnimator on rotation {
                                from: 0
                                to: 360
                                duration: 1000
                                loops: Animation.Infinite
                                running: KeybindsService.loading
                            }
                        }

                        StyledText {
                            text: I18n.tr("Loading keybinds...")
                            font.pixelSize: Theme.fontSizeMedium
                            color: Theme.surfaceVariantText
                            anchors.verticalCenter: parent.verticalCenter
                        }
                    }

                    StyledText {
                        text: I18n.tr("No keybinds found")
                        font.pixelSize: Theme.fontSizeMedium
                        color: Theme.surfaceVariantText
                        visible: !KeybindsService.loading && keybindsTab._filteredBinds.length === 0
                    }
                }
            }

            Column {
                width: parent.width
                spacing: Theme.spacingXS

                Repeater {
                    id: bindsRepeater
                    model: ScriptModel {
                        values: keybindsTab._filteredBinds
                        objectProp: "action"
                    }

                    delegate: Item {
                        required property var modelData
                        required property int index

                        width: parent.width
                        height: bindItem.height

                        KeybindItem {
                            id: bindItem
                            width: Math.min(650, parent.width - Theme.spacingL * 2)
                            anchors.horizontalCenter: parent.horizontalCenter
                            bindData: modelData
                            isExpanded: keybindsTab.expandedKey === modelData.action
                            retainedEdit: keybindsTab.hasEditDraft && keybindsTab.editDraft.action === modelData.action ? keybindsTab.editDraft : null
                            saveBlocked: retainEdits && (keybindsTab.reviewingEdit || keybindsTab.editDraft.operation !== "set")
                            enabled: !retainEdits || (!keybindsTab.editBusy && !keybindsTab.editInvalidated && !KeybindsService.bindMutationBusy)
                            onEditChanged: {
                                if (KeybindsService.requiresBindReview && isExpanded && hasChanges && !keybindsTab.hasEditDraft)
                                    keybindsTab.beginEdit(bindData, addingNewKey ? "" : _originalKey);
                                if (retainEdits)
                                    keybindsTab.updateEditDraft(addingNewKey ? "" : _originalKey, {
                                        key: editKey,
                                        action: editAction,
                                        desc: editDesc
                                    });
                            }
                            onCancelEdit: keybindsTab.discardEdit()
                            panelWindow: keybindsTab.parentModal
                            readOnly: KeybindsService.readOnly
                            onToggleExpand: keybindsTab.toggleExpanded(modelData.action)
                            onSaveBind: (originalKey, newData) => {
                                keybindsTab.saveBind(originalKey, newData);
                            }
                            onRemoveBind: key => {
                                const remainingKey = bindItem.keys.find(k => k.key !== key)?.key ?? "";
                                keybindsTab.confirmRemoveBind(key, remainingKey);
                            }
                            onResetBind: key => {
                                const remainingKey = bindItem.keys.find(k => k.key !== key)?.key ?? "";
                                keybindsTab.confirmResetBind(key, remainingKey);
                            }
                            onIsExpandedChanged: {
                                if (!isExpanded || !keybindsTab._editingKey)
                                    return;
                                const keyExists = keys.some(k => k.key === keybindsTab._editingKey);
                                if (keyExists) {
                                    restoreKey = keybindsTab._editingKey;
                                    keybindsTab._editingKey = "";
                                }
                            }

                            onKeysChanged: {
                                if (!isExpanded || !keybindsTab._editingKey)
                                    return;
                                const keyExists = keys.some(k => k.key === keybindsTab._editingKey);
                                if (keyExists) {
                                    restoreKey = keybindsTab._editingKey;
                                    keybindsTab._editingKey = "";
                                }
                            }

                            Connections {
                                target: keybindsTab
                                function on_EditingKeyChanged() {
                                    if (!bindItem.isExpanded || !keybindsTab._editingKey)
                                        return;
                                    const keyExists = bindItem.keys.some(k => k.key === keybindsTab._editingKey);
                                    if (keyExists) {
                                        bindItem.restoreKey = keybindsTab._editingKey;
                                        keybindsTab._editingKey = "";
                                    }
                                }
                            }
                        }
                    }
                }
            }
        }
    }
}
