pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Layouts
import Quickshell.Wayland
import qs.Common
import qs.Services
import qs.Widgets
import "../Common/KeyUtils.js" as KeyUtils
import "../Common/KeybindActions.js" as Actions

Item {
    id: root

    property var bindData: ({})
    property bool isExpanded: false
    property var panelWindow: null
    property bool recording: false
    property bool isNew: false
    property string restoreKey: ""

    property int editingKeyIndex: -1
    property string editKey: ""
    property string editAction: ""
    property string editDesc: ""
    property int editCooldownMs: 0
    property int _savedCooldownMs: -1
    property bool hasChanges: false
    property string _actionType: ""
    property bool addingNewKey: false
    property bool useCustomCompositor: false
    property var _shortcutInhibitor: null
    property bool _altShiftGhost: false

    readonly property bool _shortcutInhibitorAvailable: {
        try {
            return typeof ShortcutInhibitor !== "undefined";
        } catch (e) {
            return false;
        }
    }

    readonly property var keys: bindData.keys || []
    readonly property bool hasOverride: {
        for (let i = 0; i < keys.length; i++) {
            if (keys[i].isOverride)
                return true;
        }
        return false;
    }
    readonly property var configConflict: bindData.conflict || null
    readonly property bool hasConfigConflict: configConflict !== null
    readonly property string _originalKey: editingKeyIndex >= 0 && editingKeyIndex < keys.length ? keys[editingKeyIndex].key : ""
    readonly property var _conflicts: editKey ? KeyUtils.getConflictingBinds(editKey, bindData.action, KeybindsService.getFlatBinds()) : []
    readonly property bool hasConflict: _conflicts.length > 0

    readonly property real _inputHeight: Math.round(Theme.fontSizeMedium * 3)
    readonly property real _chipHeight: Math.round(Theme.fontSizeSmall * 2.3)
    readonly property real _buttonHeight: Math.round(Theme.fontSizeMedium * 2.3)
    readonly property real _keysColumnWidth: Math.round(Theme.fontSizeSmall * 12)
    readonly property real _labelWidth: Math.round(Theme.fontSizeSmall * 5)

    signal toggleExpand
    signal saveBind(string originalKey, var newData)
    signal removeBind(string key)
    signal cancelEdit

    implicitHeight: contentColumn.implicitHeight
    height: implicitHeight

    Component.onDestruction: _destroyShortcutInhibitor()

    Component.onCompleted: {
        if (isNew && isExpanded)
            resetEdits();
    }

    onIsExpandedChanged: {
        if (!isExpanded)
            return;
        if (restoreKey) {
            restoreToKey(restoreKey);
        } else {
            resetEdits();
        }
    }

    onRestoreKeyChanged: {
        if (!isExpanded || !restoreKey)
            return;
        restoreToKey(restoreKey);
    }

    function restoreToKey(keyToFind) {
        for (let i = 0; i < keys.length; i++) {
            if (keys[i].key === keyToFind) {
                editingKeyIndex = i;
                editKey = keyToFind;
                editAction = bindData.action || "";
                editDesc = bindData.desc || "";
                if (_savedCooldownMs >= 0) {
                    editCooldownMs = _savedCooldownMs;
                    _savedCooldownMs = -1;
                } else {
                    editCooldownMs = keys[i].cooldownMs || 0;
                }
                hasChanges = false;
                _actionType = Actions.getActionType(editAction);
                useCustomCompositor = _actionType === "compositor" && editAction && !Actions.isKnownCompositorAction(editAction);
                return;
            }
        }
        resetEdits();
    }

    onEditActionChanged: {
        _actionType = Actions.getActionType(editAction);
    }

    function resetEdits() {
        addingNewKey = false;
        editingKeyIndex = keys.length > 0 ? 0 : -1;
        editKey = editingKeyIndex >= 0 ? keys[editingKeyIndex].key : "";
        editAction = bindData.action || "";
        editDesc = bindData.desc || "";
        editCooldownMs = editingKeyIndex >= 0 ? (keys[editingKeyIndex].cooldownMs || 0) : 0;
        hasChanges = false;
        _actionType = Actions.getActionType(editAction);
        useCustomCompositor = _actionType === "compositor" && editAction && !Actions.isKnownCompositorAction(editAction);
    }

    function startAddingNewKey() {
        addingNewKey = true;
        editingKeyIndex = -1;
        editKey = "";
        hasChanges = true;
    }

    function selectKeyForEdit(index) {
        if (index < 0 || index >= keys.length)
            return;
        addingNewKey = false;
        editingKeyIndex = index;
        editKey = keys[index].key;
        editCooldownMs = keys[index].cooldownMs || 0;
        hasChanges = false;
    }

    function updateEdit(changes) {
        if (changes.key !== undefined)
            editKey = changes.key;
        if (changes.action !== undefined)
            editAction = changes.action;
        if (changes.desc !== undefined)
            editDesc = changes.desc;
        if (changes.cooldownMs !== undefined)
            editCooldownMs = changes.cooldownMs;
        const origKey = editingKeyIndex >= 0 && editingKeyIndex < keys.length ? keys[editingKeyIndex].key : "";
        const origCooldown = editingKeyIndex >= 0 && editingKeyIndex < keys.length ? (keys[editingKeyIndex].cooldownMs || 0) : 0;
        hasChanges = editKey !== origKey || editAction !== (bindData.action || "") || editDesc !== (bindData.desc || "") || editCooldownMs !== origCooldown;
    }

    function canSave() {
        if (!editKey)
            return false;
        if (!Actions.isValidAction(editAction))
            return false;
        return true;
    }

    function doSave() {
        if (!canSave())
            return;
        const origKey = addingNewKey ? "" : _originalKey;
        let desc = editDesc;
        if (expandedLoader.item?.currentTitle !== undefined)
            desc = expandedLoader.item.currentTitle;
        _savedCooldownMs = editCooldownMs;
        saveBind(origKey, {
            key: editKey,
            action: editAction,
            desc: desc,
            cooldownMs: editCooldownMs
        });
        hasChanges = false;
        addingNewKey = false;
    }

    function _createShortcutInhibitor() {
        if (!_shortcutInhibitorAvailable || _shortcutInhibitor)
            return;

        const qmlString = `
            import QtQuick
            import Quickshell.Wayland

            ShortcutInhibitor {
                enabled: false
                window: null
            }
        `;

        _shortcutInhibitor = Qt.createQmlObject(qmlString, root, "KeybindItem.ShortcutInhibitor");
        _shortcutInhibitor.enabled = Qt.binding(() => root.recording);
        _shortcutInhibitor.window = Qt.binding(() => root.panelWindow);
    }

    function _destroyShortcutInhibitor() {
        if (_shortcutInhibitor) {
            _shortcutInhibitor.destroy();
            _shortcutInhibitor = null;
        }
    }

    function startRecording() {
        _createShortcutInhibitor();
        recording = true;
    }

    function stopRecording() {
        recording = false;
    }

    Column {
        id: contentColumn
        width: parent.width
        spacing: 0

        Rectangle {
            id: collapsedRect
            width: parent.width
            height: Math.max(root._inputHeight + Theme.spacingM, keysColumn.implicitHeight + Theme.spacingM * 2)
            radius: root.isExpanded ? 0 : Theme.cornerRadius
            topLeftRadius: Theme.cornerRadius
            topRightRadius: Theme.cornerRadius
            color: root.hasOverride ? Theme.surfaceContainer : Theme.surfaceContainerHighest
            border.color: root.hasOverride ? Theme.outlineVariant : "transparent"
            border.width: root.hasOverride ? 1 : 0

            RowLayout {
                id: collapsedContent
                anchors.fill: parent
                anchors.leftMargin: Theme.spacingM
                anchors.rightMargin: Theme.spacingM
                spacing: Theme.spacingM

                Column {
                    id: keysColumn
                    Layout.preferredWidth: root._keysColumnWidth
                    Layout.alignment: Qt.AlignVCenter
                    spacing: Theme.spacingXS

                    Repeater {
                        model: root.keys

                        delegate: Rectangle {
                            required property var modelData
                            required property int index

                            property bool isSelected: root.isExpanded && root.editingKeyIndex === index && !root.addingNewKey

                            width: root._keysColumnWidth
                            height: root._chipHeight
                            radius: root._chipHeight / 4
                            color: isSelected ? Theme.primary : Theme.surfaceVariant

                            Rectangle {
                                anchors.fill: parent
                                radius: parent.radius
                                color: chipArea.pressed ? Theme.surfaceTextHover : (chipArea.containsMouse ? Theme.surfaceTextHover : "transparent")
                            }

                            StyledText {
                                text: modelData.key
                                font.pixelSize: Theme.fontSizeSmall
                                font.weight: parent.isSelected ? Font.Medium : Font.Normal
                                isMonospace: true
                                color: parent.isSelected ? Theme.primaryText : Theme.surfaceVariantText
                                anchors.centerIn: parent
                                width: parent.width - Theme.spacingS
                                horizontalAlignment: Text.AlignHCenter
                                elide: Text.ElideRight
                            }

                            MouseArea {
                                id: chipArea
                                anchors.fill: parent
                                hoverEnabled: true
                                cursorShape: Qt.PointingHandCursor
                                onClicked: {
                                    root.selectKeyForEdit(index);
                                    if (!root.isExpanded)
                                        root.toggleExpand();
                                }
                            }
                        }
                    }
                }

                ColumnLayout {
                    Layout.fillWidth: true
                    Layout.alignment: Qt.AlignVCenter
                    spacing: 2

                    StyledText {
                        text: root.bindData.desc || root.bindData.action || I18n.tr("No action")
                        font.pixelSize: Theme.fontSizeMedium
                        color: Theme.surfaceText
                        elide: Text.ElideRight
                        Layout.fillWidth: true
                    }

                    RowLayout {
                        spacing: Theme.spacingS
                        Layout.fillWidth: true

                        StyledText {
                            text: root.bindData.category || ""
                            font.pixelSize: Theme.fontSizeSmall
                            color: Theme.surfaceVariantText
                            visible: text.length > 0
                        }

                        Rectangle {
                            width: 4
                            height: 4
                            radius: 2
                            color: Theme.surfaceVariantText
                            visible: root.hasOverride && (root.bindData.category ?? "")
                        }

                        StyledText {
                            text: I18n.tr("Override")
                            font.pixelSize: Theme.fontSizeSmall
                            color: Theme.primary
                            visible: root.hasOverride && !root.hasConfigConflict
                        }

                        DankIcon {
                            name: "warning"
                            size: Theme.iconSizeSmall
                            color: Theme.primary
                            visible: root.hasConfigConflict
                        }

                        StyledText {
                            text: I18n.tr("Overridden by config")
                            font.pixelSize: Theme.fontSizeSmall
                            color: Theme.primary
                            visible: root.hasConfigConflict
                        }

                        Item {
                            Layout.fillWidth: true
                        }
                    }
                }

                DankIcon {
                    name: root.isExpanded ? "expand_less" : "expand_more"
                    size: Theme.iconSize - 4
                    color: Theme.surfaceVariantText
                    Layout.alignment: Qt.AlignVCenter
                }
            }

            MouseArea {
                anchors.fill: parent
                anchors.leftMargin: root._keysColumnWidth + Theme.spacingM * 2
                cursorShape: Qt.PointingHandCursor
                onClicked: root.toggleExpand()
            }
        }

        Loader {
            id: expandedLoader
            width: parent.width
            active: root.isExpanded
            visible: status === Loader.Ready
            asynchronous: true
            sourceComponent: expandedComponent
        }
    }

    Component {
        id: expandedComponent

        Rectangle {
            id: expandedRect
            width: parent ? parent.width : 0
            height: expandedContent.implicitHeight + Theme.spacingL * 2
            color: Theme.surfaceContainerHigh
            border.color: root.hasOverride ? Theme.outlineVariant : "transparent"
            border.width: root.hasOverride ? 1 : 0
            bottomLeftRadius: Theme.cornerRadius
            bottomRightRadius: Theme.cornerRadius

            property alias currentTitle: titleField.text

            ColumnLayout {
                id: expandedContent
                anchors.left: parent.left
                anchors.right: parent.right
                anchors.top: parent.top
                anchors.margins: Theme.spacingL
                spacing: Theme.spacingM

                Rectangle {
                    Layout.fillWidth: true
                    Layout.preferredHeight: conflictColumn.implicitHeight + Theme.spacingM * 2
                    radius: Theme.cornerRadius
                    color: Theme.withAlpha(Theme.primary, 0.15)
                    border.color: Theme.withAlpha(Theme.primary, 0.3)
                    border.width: 1
                    visible: root.hasConfigConflict

                    Column {
                        id: conflictColumn
                        anchors.fill: parent
                        anchors.margins: Theme.spacingM
                        spacing: Theme.spacingS

                        RowLayout {
                            width: parent.width
                            spacing: Theme.spacingS

                            DankIcon {
                                name: "warning"
                                size: Theme.iconSizeSmall
                                color: Theme.primary
                            }

                            StyledText {
                                text: I18n.tr("This bind is overridden by config.kdl")
                                font.pixelSize: Theme.fontSizeSmall
                                font.weight: Font.Medium
                                color: Theme.primary
                                Layout.fillWidth: true
                            }
                        }

                        StyledText {
                            text: I18n.tr("Config action: %1").arg(root.configConflict?.action ?? "")
                            font.pixelSize: Theme.fontSizeSmall
                            color: Theme.surfaceVariantText
                            width: parent.width
                            wrapMode: Text.WordWrap
                        }

                        StyledText {
                            text: I18n.tr("To use this DMS bind, remove or change the keybind in your config.kdl")
                            font.pixelSize: Theme.fontSizeSmall
                            color: Theme.surfaceVariantText
                            width: parent.width
                            wrapMode: Text.WordWrap
                        }
                    }
                }

                RowLayout {
                    Layout.fillWidth: true
                    spacing: Theme.spacingM
                    visible: root.keys.length > 1 || root.addingNewKey

                    StyledText {
                        text: I18n.tr("Keys")
                        font.pixelSize: Theme.fontSizeSmall
                        font.weight: Font.Medium
                        color: Theme.surfaceVariantText
                        Layout.preferredWidth: root._labelWidth
                    }

                    Flow {
                        Layout.fillWidth: true
                        spacing: Theme.spacingXS

                        Repeater {
                            model: root.keys

                            delegate: Rectangle {
                                required property var modelData
                                required property int index

                                property bool isSelected: root.editingKeyIndex === index && !root.addingNewKey

                                width: editKeyChipText.implicitWidth + Theme.spacingM
                                height: root._chipHeight
                                radius: root._chipHeight / 4
                                color: isSelected ? Theme.primary : Theme.surfaceVariant

                                Rectangle {
                                    anchors.fill: parent
                                    radius: parent.radius
                                    color: editKeyChipArea.pressed ? Theme.surfaceTextHover : (editKeyChipArea.containsMouse && !parent.isSelected ? Theme.surfaceTextHover : "transparent")
                                }

                                StyledText {
                                    id: editKeyChipText
                                    text: modelData.key
                                    font.pixelSize: Theme.fontSizeSmall
                                    font.weight: parent.isSelected ? Font.Medium : Font.Normal
                                    isMonospace: true
                                    color: parent.isSelected ? Theme.primaryText : Theme.surfaceVariantText
                                    anchors.centerIn: parent
                                }

                                MouseArea {
                                    id: editKeyChipArea
                                    anchors.fill: parent
                                    hoverEnabled: true
                                    cursorShape: Qt.PointingHandCursor
                                    onClicked: root.selectKeyForEdit(index)
                                }
                            }
                        }

                        Rectangle {
                            width: root._chipHeight
                            height: root._chipHeight
                            radius: root._chipHeight / 4
                            color: root.addingNewKey ? Theme.primary : Theme.surfaceVariant
                            visible: !root.isNew

                            Rectangle {
                                anchors.fill: parent
                                radius: parent.radius
                                color: addKeyArea.pressed ? Theme.surfaceTextHover : (addKeyArea.containsMouse && !root.addingNewKey ? Theme.surfaceTextHover : "transparent")
                            }

                            DankIcon {
                                name: "add"
                                size: Theme.iconSizeSmall
                                color: root.addingNewKey ? Theme.primaryText : Theme.surfaceVariantText
                                anchors.centerIn: parent
                            }

                            MouseArea {
                                id: addKeyArea
                                anchors.fill: parent
                                hoverEnabled: true
                                cursorShape: Qt.PointingHandCursor
                                onClicked: root.startAddingNewKey()
                            }
                        }
                    }
                }

                RowLayout {
                    Layout.fillWidth: true
                    spacing: Theme.spacingM

                    StyledText {
                        text: root.addingNewKey ? I18n.tr("New Key") : I18n.tr("Key")
                        font.pixelSize: Theme.fontSizeSmall
                        font.weight: Font.Medium
                        color: Theme.surfaceVariantText
                        Layout.preferredWidth: root._labelWidth
                    }

                    FocusScope {
                        id: captureScope
                        Layout.fillWidth: true
                        Layout.preferredHeight: root._inputHeight
                        focus: root.recording

                        Component.onCompleted: {
                            if (root.recording)
                                forceActiveFocus();
                        }

                        Connections {
                            target: root
                            function onRecordingChanged() {
                                if (root.recording)
                                    captureScope.forceActiveFocus();
                            }
                        }

                        Rectangle {
                            anchors.fill: parent
                            radius: Theme.cornerRadius
                            color: root.recording ? Theme.primaryContainer : Theme.surfaceContainer
                            border.color: root.recording ? Theme.primary : Qt.rgba(Theme.outline.r, Theme.outline.g, Theme.outline.b, 0.3)
                            border.width: root.recording ? 2 : 1

                            Row {
                                anchors.left: parent.left
                                anchors.right: parent.right
                                anchors.verticalCenter: parent.verticalCenter
                                anchors.margins: Theme.spacingS
                                spacing: Theme.spacingS

                                StyledText {
                                    text: root.editKey || (root.recording ? I18n.tr("Press key...") : I18n.tr("Click to capture"))
                                    font.pixelSize: Theme.fontSizeMedium
                                    isMonospace: root.editKey ? true : false
                                    color: root.editKey ? Theme.surfaceText : Theme.surfaceVariantText
                                    width: parent.width - recordBtn.width - parent.spacing
                                    anchors.verticalCenter: parent.verticalCenter
                                    elide: Text.ElideRight
                                }

                                DankActionButton {
                                    id: recordBtn
                                    width: root._chipHeight
                                    height: root._chipHeight
                                    anchors.verticalCenter: parent.verticalCenter
                                    circular: false
                                    iconName: root.recording ? "close" : "radio_button_checked"
                                    iconSize: Theme.iconSizeSmall
                                    iconColor: root.recording ? Theme.error : Theme.primary
                                    onClicked: root.recording ? root.stopRecording() : root.startRecording()
                                }
                            }
                        }

                        Keys.onPressed: event => {
                            if (!root.recording)
                                return;

                            event.accepted = true;

                            switch (event.key) {
                            case Qt.Key_Control:
                            case Qt.Key_Shift:
                            case Qt.Key_Alt:
                            case Qt.Key_Meta:
                                return;
                            }

                            if (event.key === 0 && (event.modifiers & Qt.AltModifier)) {
                                root._altShiftGhost = true;
                                return;
                            }

                            let mods = KeyUtils.modsFromEvent(event.modifiers);
                            let qtKey = event.key;

                            if (root._altShiftGhost && (event.modifiers & Qt.AltModifier) && !mods.includes("Shift")) {
                                mods.push("Shift");
                            }
                            root._altShiftGhost = false;

                            if (qtKey === Qt.Key_Backtab) {
                                qtKey = Qt.Key_Tab;
                                if (!mods.includes("Shift"))
                                    mods.push("Shift");
                            }

                            const key = KeyUtils.xkbKeyFromQtKey(qtKey);
                            if (!key) {
                                console.warn("[KeybindItem] Unknown key:", event.key, "mods:", event.modifiers);
                                return;
                            }

                            root.updateEdit({
                                key: KeyUtils.formatToken(mods, key)
                            });
                            root.stopRecording();
                        }

                        MouseArea {
                            anchors.fill: parent
                            hoverEnabled: true
                            cursorShape: root.recording ? Qt.CrossCursor : Qt.PointingHandCursor
                            acceptedButtons: Qt.LeftButton

                            onClicked: {
                                if (!root.recording)
                                    root.startRecording();
                            }

                            onWheel: wheel => {
                                if (!root.recording) {
                                    wheel.accepted = false;
                                    return;
                                }
                                wheel.accepted = true;

                                const mods = [];
                                if (wheel.modifiers & Qt.ControlModifier)
                                    mods.push("Ctrl");
                                if (wheel.modifiers & Qt.ShiftModifier)
                                    mods.push("Shift");
                                if (wheel.modifiers & Qt.AltModifier)
                                    mods.push("Alt");
                                if (wheel.modifiers & Qt.MetaModifier)
                                    mods.push("Super");

                                let wheelKey = "";
                                if (wheel.angleDelta.y > 0)
                                    wheelKey = "WheelScrollUp";
                                else if (wheel.angleDelta.y < 0)
                                    wheelKey = "WheelScrollDown";
                                else if (wheel.angleDelta.x > 0)
                                    wheelKey = "WheelScrollRight";
                                else if (wheel.angleDelta.x < 0)
                                    wheelKey = "WheelScrollLeft";

                                if (!wheelKey)
                                    return;

                                root.updateEdit({
                                    key: KeyUtils.formatToken(mods, wheelKey)
                                });
                                root.stopRecording();
                            }
                        }
                    }

                    Rectangle {
                        Layout.preferredWidth: root._inputHeight
                        Layout.preferredHeight: root._inputHeight
                        radius: Theme.cornerRadius
                        color: root.addingNewKey ? Theme.primary : Theme.surfaceVariant
                        visible: root.keys.length === 1 && !root.isNew

                        Rectangle {
                            anchors.fill: parent
                            radius: parent.radius
                            color: singleAddKeyArea.pressed ? Theme.surfaceTextHover : (singleAddKeyArea.containsMouse && !root.addingNewKey ? Theme.surfaceTextHover : "transparent")
                        }

                        DankIcon {
                            name: "add"
                            size: Theme.iconSizeSmall + 2
                            color: root.addingNewKey ? Theme.primaryText : Theme.surfaceVariantText
                            anchors.centerIn: parent
                        }

                        MouseArea {
                            id: singleAddKeyArea
                            anchors.fill: parent
                            hoverEnabled: true
                            cursorShape: Qt.PointingHandCursor
                            onClicked: root.startAddingNewKey()
                        }
                    }
                }

                RowLayout {
                    Layout.fillWidth: true
                    spacing: Theme.spacingS
                    visible: root.hasConflict
                    Layout.leftMargin: root._labelWidth + Theme.spacingM

                    DankIcon {
                        name: "warning"
                        size: Theme.iconSizeSmall
                        color: Theme.primary
                    }

                    StyledText {
                        text: I18n.tr("Conflicts with: %1").arg(root._conflicts.map(c => c.desc).join(", "))
                        font.pixelSize: Theme.fontSizeSmall
                        color: Theme.primary
                        Layout.fillWidth: true
                        elide: Text.ElideRight
                    }
                }

                RowLayout {
                    Layout.fillWidth: true
                    spacing: Theme.spacingM

                    StyledText {
                        text: I18n.tr("Type")
                        font.pixelSize: Theme.fontSizeSmall
                        font.weight: Font.Medium
                        color: Theme.surfaceVariantText
                        Layout.preferredWidth: root._labelWidth
                    }

                    RowLayout {
                        Layout.fillWidth: true
                        spacing: Theme.spacingS

                        Repeater {
                            model: KeybindsService.actionTypes

                            delegate: Rectangle {
                                id: typeDelegate
                                required property var modelData
                                required property int index

                                readonly property var tooltipTexts: ({
                                        "dms": I18n.tr("DMS shell actions (launcher, clipboard, etc.)"),
                                        "compositor": I18n.tr("Niri compositor actions (focus, move, etc.)"),
                                        "spawn": I18n.tr("Run a program (e.g., firefox, kitty)"),
                                        "shell": I18n.tr("Run a shell command (e.g., notify-send)")
                                    })

                                Layout.fillWidth: true
                                Layout.preferredHeight: root._buttonHeight
                                radius: Theme.cornerRadius
                                color: root._actionType === modelData.id ? Theme.surfaceContainerHighest : Theme.surfaceContainer
                                border.color: root._actionType === modelData.id ? Theme.outline : (typeArea.containsMouse ? Theme.outlineVariant : "transparent")
                                border.width: 1

                                RowLayout {
                                    anchors.centerIn: parent
                                    spacing: Theme.spacingXS

                                    DankIcon {
                                        name: typeDelegate.modelData.icon
                                        size: Theme.iconSizeSmall
                                        color: root._actionType === typeDelegate.modelData.id ? Theme.surfaceText : Theme.surfaceVariantText
                                    }

                                    StyledText {
                                        text: typeDelegate.modelData.label
                                        font.pixelSize: Theme.fontSizeSmall
                                        color: root._actionType === typeDelegate.modelData.id ? Theme.surfaceText : Theme.surfaceVariantText
                                        visible: typeDelegate.width > 100
                                    }
                                }

                                MouseArea {
                                    id: typeArea
                                    anchors.fill: parent
                                    hoverEnabled: true
                                    cursorShape: Qt.PointingHandCursor
                                    onClicked: {
                                        switch (typeDelegate.modelData.id) {
                                        case "dms":
                                            root.updateEdit({
                                                action: KeybindsService.dmsActions[0].id,
                                                desc: KeybindsService.dmsActions[0].label
                                            });
                                            break;
                                        case "compositor":
                                            root.updateEdit({
                                                action: "close-window",
                                                desc: "Close Window"
                                            });
                                            break;
                                        case "spawn":
                                            root.updateEdit({
                                                action: "spawn ",
                                                desc: ""
                                            });
                                            break;
                                        case "shell":
                                            root.updateEdit({
                                                action: "spawn sh -c \"\"",
                                                desc: ""
                                            });
                                            break;
                                        }
                                    }
                                    onContainsMouseChanged: {
                                        if (containsMouse) {
                                            typeTooltip.show(typeDelegate.tooltipTexts[typeDelegate.modelData.id], typeDelegate, 0, 0, "bottom");
                                        } else {
                                            typeTooltip.hide();
                                        }
                                    }
                                }
                            }
                        }
                    }

                    DankTooltipV2 {
                        id: typeTooltip
                    }
                }

                RowLayout {
                    Layout.fillWidth: true
                    spacing: Theme.spacingM
                    visible: root._actionType === "dms"

                    StyledText {
                        text: I18n.tr("Action")
                        font.pixelSize: Theme.fontSizeSmall
                        font.weight: Font.Medium
                        color: Theme.surfaceVariantText
                        Layout.preferredWidth: root._labelWidth
                    }

                    DankDropdown {
                        Layout.fillWidth: true
                        compactMode: true
                        currentValue: KeybindsService.getActionLabel(root.editAction) || I18n.tr("Select...")
                        options: KeybindsService.getDmsActions().map(a => a.label)
                        enableFuzzySearch: true
                        maxPopupHeight: 300
                        onValueChanged: value => {
                            const actions = KeybindsService.getDmsActions();
                            for (const act of actions) {
                                if (act.label === value) {
                                    root.updateEdit({
                                        action: act.id,
                                        desc: act.label
                                    });
                                    return;
                                }
                            }
                        }
                    }
                }

                RowLayout {
                    id: dmsArgsRow
                    Layout.fillWidth: true
                    spacing: Theme.spacingM

                    readonly property var argConfig: Actions.getActionArgConfig(root.editAction)
                    readonly property var parsedArgs: argConfig?.type === "dms" ? Actions.parseDmsActionArgs(root.editAction) : null
                    readonly property var dmsActionArgs: Actions.getDmsActionArgs()
                    readonly property bool hasAmountArg: parsedArgs?.base ? (dmsActionArgs?.[parsedArgs.base]?.args?.some(a => a.name === "amount") ?? false) : false
                    readonly property bool hasDeviceArg: parsedArgs?.base ? (dmsActionArgs?.[parsedArgs.base]?.args?.some(a => a.name === "device") ?? false) : false
                    readonly property bool hasTabArg: parsedArgs?.base ? (dmsActionArgs?.[parsedArgs.base]?.args?.some(a => a.name === "tab") ?? false) : false

                    visible: root._actionType === "dms" && argConfig?.type === "dms"

                    StyledText {
                        text: I18n.tr("Amount")
                        font.pixelSize: Theme.fontSizeSmall
                        font.weight: Font.Medium
                        color: Theme.surfaceVariantText
                        Layout.preferredWidth: root._labelWidth
                        visible: dmsArgsRow.hasAmountArg
                    }

                    DankTextField {
                        id: dmsAmountField
                        Layout.preferredWidth: Math.round(Theme.fontSizeMedium * 5.5)
                        Layout.preferredHeight: root._inputHeight
                        placeholderText: "5"
                        visible: dmsArgsRow.hasAmountArg

                        Connections {
                            target: dmsArgsRow
                            function onParsedArgsChanged() {
                                const newText = dmsArgsRow.parsedArgs?.args?.amount || "";
                                if (dmsAmountField.text !== newText)
                                    dmsAmountField.text = newText;
                            }
                        }

                        Component.onCompleted: {
                            text = dmsArgsRow.parsedArgs?.args?.amount || "";
                        }

                        onEditingFinished: {
                            if (!dmsArgsRow.parsedArgs)
                                return;
                            const newArgs = Object.assign({}, dmsArgsRow.parsedArgs.args);
                            newArgs.amount = text || "5";
                            root.updateEdit({
                                action: Actions.buildDmsAction(dmsArgsRow.parsedArgs.base, newArgs)
                            });
                        }
                    }

                    StyledText {
                        text: "%"
                        font.pixelSize: Theme.fontSizeSmall
                        color: Theme.surfaceVariantText
                        visible: dmsArgsRow.hasAmountArg
                    }

                    StyledText {
                        text: I18n.tr("Device")
                        font.pixelSize: Theme.fontSizeSmall
                        font.weight: Font.Medium
                        color: Theme.surfaceVariantText
                        Layout.leftMargin: dmsArgsRow.hasAmountArg ? Theme.spacingM : 0
                        Layout.preferredWidth: dmsArgsRow.hasAmountArg ? -1 : root._labelWidth
                        visible: dmsArgsRow.hasDeviceArg
                    }

                    DankTextField {
                        id: dmsDeviceField
                        Layout.fillWidth: true
                        Layout.preferredHeight: root._inputHeight
                        placeholderText: I18n.tr("leave empty for default")
                        visible: dmsArgsRow.hasDeviceArg

                        Connections {
                            target: dmsArgsRow
                            function onParsedArgsChanged() {
                                const newText = dmsArgsRow.parsedArgs?.args?.device || "";
                                if (dmsDeviceField.text !== newText)
                                    dmsDeviceField.text = newText;
                            }
                        }

                        Component.onCompleted: {
                            text = dmsArgsRow.parsedArgs?.args?.device || "";
                        }

                        onEditingFinished: {
                            if (!dmsArgsRow.parsedArgs)
                                return;
                            const newArgs = Object.assign({}, dmsArgsRow.parsedArgs.args);
                            newArgs.device = text;
                            root.updateEdit({
                                action: Actions.buildDmsAction(dmsArgsRow.parsedArgs.base, newArgs)
                            });
                        }
                    }

                    Item {
                        Layout.fillWidth: true
                        visible: !dmsArgsRow.hasDeviceArg && !dmsArgsRow.hasTabArg
                    }

                    StyledText {
                        text: I18n.tr("Tab")
                        font.pixelSize: Theme.fontSizeSmall
                        font.weight: Font.Medium
                        color: Theme.surfaceVariantText
                        Layout.preferredWidth: root._labelWidth
                        visible: dmsArgsRow.hasTabArg
                    }

                    DankDropdown {
                        id: dmsTabDropdown
                        Layout.fillWidth: true
                        compactMode: true
                        visible: dmsArgsRow.hasTabArg
                        currentValue: {
                            const tab = dmsArgsRow.parsedArgs?.args?.tab || "";
                            switch (tab) {
                            case "media":
                                return I18n.tr("Media");
                            case "wallpaper":
                                return I18n.tr("Wallpaper");
                            case "weather":
                                return I18n.tr("Weather");
                            default:
                                return I18n.tr("Overview");
                            }
                        }
                        options: [I18n.tr("Overview"), I18n.tr("Media"), I18n.tr("Wallpaper"), I18n.tr("Weather")]
                        onValueChanged: value => {
                            if (!dmsArgsRow.parsedArgs)
                                return;
                            const newArgs = Object.assign({}, dmsArgsRow.parsedArgs.args);
                            switch (value) {
                            case I18n.tr("Media"):
                                newArgs.tab = "media";
                                break;
                            case I18n.tr("Wallpaper"):
                                newArgs.tab = "wallpaper";
                                break;
                            case I18n.tr("Weather"):
                                newArgs.tab = "weather";
                                break;
                            default:
                                newArgs.tab = "";
                                break;
                            }
                            root.updateEdit({
                                action: Actions.buildDmsAction(dmsArgsRow.parsedArgs.base, newArgs)
                            });
                        }
                    }
                }

                RowLayout {
                    Layout.fillWidth: true
                    spacing: Theme.spacingM
                    visible: root._actionType === "compositor" && !root.useCustomCompositor

                    StyledText {
                        text: I18n.tr("Action")
                        font.pixelSize: Theme.fontSizeSmall
                        font.weight: Font.Medium
                        color: Theme.surfaceVariantText
                        Layout.preferredWidth: root._labelWidth
                    }

                    DankDropdown {
                        id: compositorCatDropdown
                        Layout.preferredWidth: Math.round(Theme.fontSizeMedium * 8.5)
                        compactMode: true
                        currentValue: {
                            const base = root.editAction.split(" ")[0];
                            const cats = KeybindsService.getCompositorCategories();
                            for (const cat of cats) {
                                const actions = KeybindsService.getCompositorActions(cat);
                                for (const act of actions) {
                                    if (act.id === base)
                                        return cat;
                                }
                            }
                            return cats[0] || "Window";
                        }
                        options: KeybindsService.getCompositorCategories()
                    }

                    DankDropdown {
                        Layout.fillWidth: true
                        compactMode: true
                        currentValue: KeybindsService.getActionLabel(root.editAction) || I18n.tr("Select...")
                        options: KeybindsService.getCompositorActions(compositorCatDropdown.currentValue).map(a => a.label)
                        enableFuzzySearch: true
                        maxPopupHeight: 300
                        onValueChanged: value => {
                            const actions = KeybindsService.getCompositorActions(compositorCatDropdown.currentValue);
                            for (const act of actions) {
                                if (act.label === value) {
                                    root.updateEdit({
                                        action: act.id,
                                        desc: act.label
                                    });
                                    return;
                                }
                            }
                        }
                    }

                    Rectangle {
                        Layout.preferredWidth: root._inputHeight
                        Layout.preferredHeight: root._inputHeight
                        radius: Theme.cornerRadius
                        color: Theme.surfaceVariant

                        Rectangle {
                            anchors.fill: parent
                            radius: parent.radius
                            color: customToggleArea.pressed ? Theme.surfaceTextHover : (customToggleArea.containsMouse ? Theme.surfaceTextHover : "transparent")
                        }

                        DankIcon {
                            name: "edit"
                            size: Theme.iconSizeSmall + 2
                            color: Theme.surfaceVariantText
                            anchors.centerIn: parent
                        }

                        MouseArea {
                            id: customToggleArea
                            anchors.fill: parent
                            hoverEnabled: true
                            cursorShape: Qt.PointingHandCursor
                            onClicked: root.useCustomCompositor = true
                        }
                    }
                }

                RowLayout {
                    id: optionsRow
                    Layout.fillWidth: true
                    spacing: Theme.spacingM
                    visible: root._actionType === "compositor" && !root.useCustomCompositor && Actions.getActionArgConfig(root.editAction)

                    readonly property var argConfig: Actions.getActionArgConfig(root.editAction)
                    readonly property var parsedArgs: Actions.parseCompositorActionArgs(root.editAction)

                    StyledText {
                        text: I18n.tr("Options")
                        font.pixelSize: Theme.fontSizeSmall
                        font.weight: Font.Medium
                        color: Theme.surfaceVariantText
                        Layout.preferredWidth: root._labelWidth
                    }

                    RowLayout {
                        Layout.fillWidth: true
                        spacing: Theme.spacingS

                        DankTextField {
                            id: argValueField
                            Layout.fillWidth: true
                            Layout.preferredHeight: root._inputHeight
                            visible: {
                                const cfg = optionsRow.argConfig;
                                if (!cfg?.config?.args)
                                    return false;
                                const firstArg = cfg.config.args[0];
                                return firstArg && (firstArg.type === "text" || firstArg.type === "number");
                            }
                            placeholderText: optionsRow.argConfig?.config?.args?.[0]?.placeholder || ""

                            Connections {
                                target: optionsRow
                                function onParsedArgsChanged() {
                                    const newText = optionsRow.parsedArgs?.args?.value || optionsRow.parsedArgs?.args?.index || "";
                                    if (argValueField.text !== newText)
                                        argValueField.text = newText;
                                }
                            }

                            Component.onCompleted: {
                                text = optionsRow.parsedArgs?.args?.value || optionsRow.parsedArgs?.args?.index || "";
                            }

                            onEditingFinished: {
                                const cfg = optionsRow.argConfig;
                                if (!cfg)
                                    return;
                                const parsed = optionsRow.parsedArgs;
                                const args = {};
                                if (cfg.config.args[0]?.type === "number")
                                    args.index = text;
                                else
                                    args.value = text;
                                if (parsed?.args?.focus === false)
                                    args.focus = false;
                                root.updateEdit({
                                    action: Actions.buildCompositorAction(parsed?.base || cfg.base, args)
                                });
                            }
                        }

                        RowLayout {
                            visible: {
                                const cfg = optionsRow.argConfig;
                                if (!cfg)
                                    return false;
                                switch (cfg.base) {
                                case "move-column-to-workspace":
                                case "move-column-to-workspace-down":
                                case "move-column-to-workspace-up":
                                    return true;
                                }
                                return false;
                            }
                            spacing: Theme.spacingXS

                            DankToggle {
                                id: focusToggle
                                checked: optionsRow.parsedArgs?.args?.focus !== false
                                onToggled: newChecked => {
                                    const cfg = optionsRow.argConfig;
                                    if (!cfg)
                                        return;
                                    const parsed = optionsRow.parsedArgs;
                                    const args = {};
                                    if (cfg.base === "move-column-to-workspace")
                                        args.index = parsed?.args?.index || "";
                                    if (!newChecked)
                                        args.focus = false;
                                    root.updateEdit({
                                        action: Actions.buildCompositorAction(cfg.base, args)
                                    });
                                }
                            }

                            StyledText {
                                text: I18n.tr("Follow focus")
                                font.pixelSize: Theme.fontSizeSmall
                                color: Theme.surfaceVariantText
                            }
                        }

                        RowLayout {
                            visible: optionsRow.argConfig?.base?.startsWith("screenshot") ?? false
                            spacing: Theme.spacingM

                            RowLayout {
                                spacing: Theme.spacingXS

                                DankToggle {
                                    id: showPointerToggle
                                    checked: optionsRow.parsedArgs?.args?.["show-pointer"] === true
                                    onToggled: newChecked => {
                                        const parsed = optionsRow.parsedArgs;
                                        const base = parsed?.base || "screenshot";
                                        const args = Object.assign({}, parsed?.args || {});
                                        args["show-pointer"] = newChecked;
                                        root.updateEdit({
                                            action: Actions.buildCompositorAction(base, args)
                                        });
                                    }
                                }

                                StyledText {
                                    text: I18n.tr("Pointer")
                                    font.pixelSize: Theme.fontSizeSmall
                                    color: Theme.surfaceVariantText
                                }
                            }

                            RowLayout {
                                visible: optionsRow.argConfig?.base !== "screenshot"
                                spacing: Theme.spacingXS

                                DankToggle {
                                    id: writeToDiskToggle
                                    checked: optionsRow.parsedArgs?.args?.["write-to-disk"] === true
                                    onToggled: newChecked => {
                                        const parsed = optionsRow.parsedArgs;
                                        const base = parsed?.base || "screenshot-screen";
                                        const args = Object.assign({}, parsed?.args || {});
                                        args["write-to-disk"] = newChecked;
                                        root.updateEdit({
                                            action: Actions.buildCompositorAction(base, args)
                                        });
                                    }
                                }

                                StyledText {
                                    text: I18n.tr("Save")
                                    font.pixelSize: Theme.fontSizeSmall
                                    color: Theme.surfaceVariantText
                                }
                            }
                        }
                    }
                }

                RowLayout {
                    Layout.fillWidth: true
                    spacing: Theme.spacingM
                    visible: root._actionType === "compositor" && root.useCustomCompositor

                    StyledText {
                        text: I18n.tr("Custom")
                        font.pixelSize: Theme.fontSizeSmall
                        font.weight: Font.Medium
                        color: Theme.surfaceVariantText
                        Layout.preferredWidth: root._labelWidth
                    }

                    DankTextField {
                        id: customCompositorField
                        Layout.fillWidth: true
                        Layout.preferredHeight: root._inputHeight
                        placeholderText: I18n.tr("e.g., focus-workspace 3, resize-column -10")
                        text: root._actionType === "compositor" ? root.editAction : ""
                        onTextChanged: {
                            if (root._actionType !== "compositor")
                                return;
                            root.updateEdit({
                                action: text
                            });
                        }
                    }

                    Rectangle {
                        Layout.preferredWidth: root._inputHeight
                        Layout.preferredHeight: root._inputHeight
                        radius: Theme.cornerRadius
                        color: Theme.surfaceVariant

                        Rectangle {
                            anchors.fill: parent
                            radius: parent.radius
                            color: presetToggleArea.pressed ? Theme.surfaceTextHover : (presetToggleArea.containsMouse ? Theme.surfaceTextHover : "transparent")
                        }

                        DankIcon {
                            name: "list"
                            size: Theme.iconSizeSmall + 2
                            color: Theme.surfaceVariantText
                            anchors.centerIn: parent
                        }

                        MouseArea {
                            id: presetToggleArea
                            anchors.fill: parent
                            hoverEnabled: true
                            cursorShape: Qt.PointingHandCursor
                            onClicked: {
                                root.useCustomCompositor = false;
                                root.updateEdit({
                                    action: "close-window",
                                    desc: "Close Window"
                                });
                            }
                        }
                    }
                }

                RowLayout {
                    Layout.fillWidth: true
                    spacing: Theme.spacingM
                    visible: root._actionType === "spawn"

                    StyledText {
                        text: I18n.tr("Command")
                        font.pixelSize: Theme.fontSizeSmall
                        font.weight: Font.Medium
                        color: Theme.surfaceVariantText
                        Layout.preferredWidth: root._labelWidth
                    }

                    DankTextField {
                        id: spawnTextField
                        Layout.fillWidth: true
                        Layout.preferredHeight: root._inputHeight
                        placeholderText: I18n.tr("e.g., firefox, kitty --title foo")
                        readonly property var _parsed: root._actionType === "spawn" ? Actions.parseSpawnCommand(root.editAction) : null
                        text: _parsed ? (_parsed.command + " " + _parsed.args.join(" ")).trim() : ""
                        onTextChanged: {
                            if (root._actionType !== "spawn")
                                return;
                            const parts = text.trim().split(" ").filter(p => p);
                            const action = parts.length > 0 ? "spawn " + parts.join(" ") : "spawn ";
                            root.updateEdit({
                                action: action
                            });
                        }
                    }
                }

                RowLayout {
                    Layout.fillWidth: true
                    spacing: Theme.spacingM
                    visible: root._actionType === "shell"

                    StyledText {
                        text: I18n.tr("Shell")
                        font.pixelSize: Theme.fontSizeSmall
                        font.weight: Font.Medium
                        color: Theme.surfaceVariantText
                        Layout.preferredWidth: root._labelWidth
                    }

                    DankTextField {
                        id: shellTextField
                        Layout.fillWidth: true
                        Layout.preferredHeight: root._inputHeight
                        placeholderText: I18n.tr("e.g., notify-send 'Hello' && sleep 1")
                        text: root._actionType === "shell" ? Actions.parseShellCommand(root.editAction) : ""
                        onTextChanged: {
                            if (root._actionType !== "shell")
                                return;
                            root.updateEdit({
                                action: Actions.buildShellAction(text)
                            });
                        }
                    }
                }

                RowLayout {
                    Layout.fillWidth: true
                    spacing: Theme.spacingM

                    StyledText {
                        text: I18n.tr("Title")
                        font.pixelSize: Theme.fontSizeSmall
                        font.weight: Font.Medium
                        color: Theme.surfaceVariantText
                        Layout.preferredWidth: root._labelWidth
                    }

                    DankTextField {
                        id: titleField
                        Layout.fillWidth: true
                        Layout.preferredHeight: root._inputHeight
                        placeholderText: I18n.tr("Hotkey overlay title (optional)")
                        text: root.editDesc
                        onTextChanged: root.updateEdit({
                            desc: text
                        })
                    }
                }

                RowLayout {
                    Layout.fillWidth: true
                    spacing: Theme.spacingM

                    StyledText {
                        text: I18n.tr("Cooldown")
                        font.pixelSize: Theme.fontSizeSmall
                        font.weight: Font.Medium
                        color: Theme.surfaceVariantText
                        Layout.preferredWidth: root._labelWidth
                    }

                    DankTextField {
                        id: cooldownField
                        Layout.preferredWidth: Math.round(Theme.fontSizeMedium * 7)
                        Layout.preferredHeight: root._inputHeight
                        placeholderText: "0"

                        Connections {
                            target: root
                            function onEditCooldownMsChanged() {
                                const newText = root.editCooldownMs > 0 ? String(root.editCooldownMs) : "";
                                if (cooldownField.text !== newText)
                                    cooldownField.text = newText;
                            }
                        }

                        Component.onCompleted: {
                            text = root.editCooldownMs > 0 ? String(root.editCooldownMs) : "";
                        }

                        onTextChanged: {
                            const val = parseInt(text) || 0;
                            if (val !== root.editCooldownMs)
                                root.updateEdit({
                                    cooldownMs: val
                                });
                        }
                    }

                    StyledText {
                        text: I18n.tr("ms")
                        font.pixelSize: Theme.fontSizeSmall
                        color: Theme.surfaceVariantText
                    }

                    Item {
                        Layout.fillWidth: true
                    }
                }

                Rectangle {
                    Layout.fillWidth: true
                    Layout.preferredHeight: 1
                    color: Qt.rgba(Theme.outline.r, Theme.outline.g, Theme.outline.b, 0.1)
                }

                RowLayout {
                    Layout.fillWidth: true
                    spacing: Theme.spacingM

                    DankActionButton {
                        Layout.preferredWidth: root._buttonHeight
                        Layout.preferredHeight: root._buttonHeight
                        circular: false
                        iconName: "delete"
                        iconSize: Theme.iconSize - 4
                        iconColor: Theme.error
                        visible: root.editingKeyIndex >= 0 && root.editingKeyIndex < root.keys.length && root.keys[root.editingKeyIndex].isOverride && !root.isNew
                        onClicked: root.removeBind(root._originalKey)
                    }

                    Item {
                        Layout.fillWidth: true
                    }

                    StyledText {
                        text: !root.canSave() ? I18n.tr("Set key and action to save") : (root.hasChanges ? I18n.tr("Unsaved changes") : I18n.tr("No changes"))
                        font.pixelSize: Theme.fontSizeSmall
                        color: root.hasChanges ? Theme.surfaceText : Theme.surfaceVariantText
                        visible: !root.isNew
                    }

                    DankButton {
                        text: I18n.tr("Cancel")
                        buttonHeight: root._buttonHeight
                        backgroundColor: Theme.surfaceContainer
                        textColor: Theme.surfaceText
                        visible: root.hasChanges || root.isNew
                        onClicked: {
                            if (root.isNew) {
                                root.cancelEdit();
                            } else {
                                root.resetEdits();
                                root.toggleExpand();
                            }
                        }
                    }

                    DankButton {
                        text: root.isNew ? I18n.tr("Add") : I18n.tr("Save")
                        buttonHeight: root._buttonHeight
                        enabled: root.canSave()
                        visible: root.hasChanges || root.isNew
                        onClicked: root.doSave()
                    }
                }
            }
        }
    }
}
