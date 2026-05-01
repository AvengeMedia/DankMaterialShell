pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Effects
import qs.Common
import qs.Services
import qs.Widgets

Rectangle {
    id: root

    property bool isVisible: false
    property bool showLogout: true
    property int selectedIndex: 0
    property int selectedRow: 0
    property int selectedCol: 0
    property var visibleActions: []
    property int gridColumns: 3
    property int gridRows: 2
    property bool useGridLayout: false

    property string holdAction: ""
    property int holdActionIndex: -1
    property real holdProgress: 0
    property bool showHoldHint: false

    property var powerActionConfirmOverride: undefined
    property var powerActionHoldDurationOverride: undefined
    property var powerMenuActionsOverride: undefined
    property var powerMenuDefaultActionOverride: undefined
    property var powerMenuGridLayoutOverride: undefined
    property var requiredActions: []

    readonly property bool needsConfirmation: powerActionConfirmOverride !== undefined ? powerActionConfirmOverride : SettingsData.powerActionConfirm
    readonly property int holdDurationMs: (powerActionHoldDurationOverride !== undefined ? powerActionHoldDurationOverride : SettingsData.powerActionHoldDuration) * 1000

    signal closed

    function updateVisibleActions() {
        const allActions = powerMenuActionsOverride !== undefined ? powerMenuActionsOverride : ((typeof SettingsData !== "undefined" && SettingsData.powerMenuActions) ? SettingsData.powerMenuActions : ["logout", "suspend", "hibernate", "reboot", "poweroff"]);
        const hibernateSupported = (typeof SessionService !== "undefined" && SessionService.hibernateSupported) || false;
        let filtered = allActions.filter(action => {
            if (action === "hibernate" && !hibernateSupported)
                return false;
            if (action === "lock")
                return false;
            if (action === "restart")
                return false;
            if (action === "logout" && !showLogout)
                return false;
            return true;
        });

        for (const action of requiredActions) {
            if (!filtered.includes(action))
                filtered.push(action);
        }

        visibleActions = filtered;

        useGridLayout = powerMenuGridLayoutOverride !== undefined ? powerMenuGridLayoutOverride : ((typeof SettingsData !== "undefined" && SettingsData.powerMenuGridLayout !== undefined) ? SettingsData.powerMenuGridLayout : false);
        if (!useGridLayout)
            return;
        const count = visibleActions.length;
        if (count === 0) {
            gridColumns = 1;
            gridRows = 1;
            return;
        }

        if (count <= 3) {
            gridColumns = 1;
            gridRows = count;
            return;
        }

        if (count === 4) {
            gridColumns = 2;
            gridRows = 2;
            return;
        }

        gridColumns = 3;
        gridRows = Math.ceil(count / 3);
    }

    function getDefaultActionIndex() {
        const defaultAction = powerMenuDefaultActionOverride !== undefined ? powerMenuDefaultActionOverride : ((typeof SettingsData !== "undefined" && SettingsData.powerMenuDefaultAction) ? SettingsData.powerMenuDefaultAction : "suspend");
        const index = visibleActions.indexOf(defaultAction);
        return index >= 0 ? index : 0;
    }

    function getActionAtIndex(index) {
        if (index < 0 || index >= visibleActions.length)
            return "";
        return visibleActions[index];
    }

    function getActionData(action) {
        switch (action) {
        case "reboot":
            return {
                "icon": "restart_alt",
                "label": I18n.tr("Reboot"),
                "key": "R"
            };
        case "logout":
            return {
                "icon": "logout",
                "label": I18n.tr("Log Out"),
                "key": "X"
            };
        case "poweroff":
            return {
                "icon": "power_settings_new",
                "label": I18n.tr("Power Off"),
                "key": "P"
            };
        case "suspend":
            return {
                "icon": "bedtime",
                "label": I18n.tr("Suspend"),
                "key": "S"
            };
        case "hibernate":
            return {
                "icon": "ac_unit",
                "label": I18n.tr("Hibernate"),
                "key": "H"
            };
        default:
            return {
                "icon": "help",
                "label": action,
                "key": "?"
            };
        }
    }

    function actionNeedsConfirm(action) {
        return action !== "lock" && action !== "restart";
    }

    function startHold(action, actionIndex) {
        if (!needsConfirmation || !actionNeedsConfirm(action)) {
            executeAction(action);
            return;
        }
        holdAction = action;
        holdActionIndex = actionIndex;
        holdProgress = 0;
        showHoldHint = false;
        holdTimer.start();
    }

    function cancelHold() {
        if (holdAction === "")
            return;
        const wasHolding = holdProgress > 0;
        holdTimer.stop();
        if (wasHolding && holdProgress < 1) {
            showHoldHint = true;
            hintTimer.restart();
        }
        holdAction = "";
        holdActionIndex = -1;
        holdProgress = 0;
    }

    function completeHold() {
        if (holdProgress < 1) {
            cancelHold();
            return;
        }
        const action = holdAction;
        holdTimer.stop();
        holdAction = "";
        holdActionIndex = -1;
        holdProgress = 0;
        executeAction(action);
    }

    function executeAction(action) {
        if (!action)
            return;
        if (typeof SessionService === "undefined")
            return;
        hide();
        switch (action) {
        case "logout":
            SessionService.logout();
            break;
        case "suspend":
            SessionService.suspend();
            break;
        case "hibernate":
            SessionService.hibernate();
            break;
        case "reboot":
            SessionService.reboot();
            break;
        case "poweroff":
            SessionService.poweroff();
            break;
        }
    }

    function selectOption(action, actionIndex) {
        startHold(action, actionIndex !== undefined ? actionIndex : -1);
    }

    function show() {
        holdAction = "";
        holdActionIndex = -1;
        holdProgress = 0;
        showHoldHint = false;
        updateVisibleActions();
        const defaultIndex = getDefaultActionIndex();
        if (useGridLayout) {
            selectedRow = Math.floor(defaultIndex / gridColumns);
            selectedCol = defaultIndex % gridColumns;
            selectedIndex = defaultIndex;
        } else {
            selectedIndex = defaultIndex;
        }
        isVisible = true;
        Qt.callLater(() => powerMenuFocusScope.forceActiveFocus());
    }

    function hide() {
        cancelHold();
        isVisible = false;
        closed();
    }

    function handleListNavigation(event, isPressed) {
        if (!isPressed) {
            if (event.key === Qt.Key_Return || event.key === Qt.Key_Enter || event.key === Qt.Key_R || event.key === Qt.Key_X || event.key === Qt.Key_S || event.key === Qt.Key_H || (event.key === Qt.Key_P && !(event.modifiers & Qt.ControlModifier))) {
                cancelHold();
                event.accepted = true;
            }
            return;
        }

        switch (event.key) {
        case Qt.Key_Up:
        case Qt.Key_Backtab:
            selectedIndex = (selectedIndex - 1 + visibleActions.length) % visibleActions.length;
            event.accepted = true;
            break;
        case Qt.Key_Down:
        case Qt.Key_Tab:
            selectedIndex = (selectedIndex + 1) % visibleActions.length;
            event.accepted = true;
            break;
        case Qt.Key_Return:
        case Qt.Key_Enter:
            startHold(getActionAtIndex(selectedIndex), selectedIndex);
            event.accepted = true;
            break;
        case Qt.Key_N:
            if (event.modifiers & Qt.ControlModifier) {
                selectedIndex = (selectedIndex + 1) % visibleActions.length;
                event.accepted = true;
            }
            break;
        case Qt.Key_P:
            if (!(event.modifiers & Qt.ControlModifier)) {
                const idx = visibleActions.indexOf("poweroff");
                startHold("poweroff", idx);
                event.accepted = true;
            } else {
                selectedIndex = (selectedIndex - 1 + visibleActions.length) % visibleActions.length;
                event.accepted = true;
            }
            break;
        case Qt.Key_J:
            if (event.modifiers & Qt.ControlModifier) {
                selectedIndex = (selectedIndex + 1) % visibleActions.length;
                event.accepted = true;
            }
            break;
        case Qt.Key_K:
            if (event.modifiers & Qt.ControlModifier) {
                selectedIndex = (selectedIndex - 1 + visibleActions.length) % visibleActions.length;
                event.accepted = true;
            }
            break;
        case Qt.Key_R:
            startHold("reboot", visibleActions.indexOf("reboot"));
            event.accepted = true;
            break;
        case Qt.Key_X:
            startHold("logout", visibleActions.indexOf("logout"));
            event.accepted = true;
            break;
        case Qt.Key_S:
            startHold("suspend", visibleActions.indexOf("suspend"));
            event.accepted = true;
            break;
        case Qt.Key_H:
            startHold("hibernate", visibleActions.indexOf("hibernate"));
            event.accepted = true;
            break;
        }
    }

    function handleGridNavigation(event, isPressed) {
        if (!isPressed) {
            if (event.key === Qt.Key_Return || event.key === Qt.Key_Enter || event.key === Qt.Key_R || event.key === Qt.Key_X || event.key === Qt.Key_S || event.key === Qt.Key_H || (event.key === Qt.Key_P && !(event.modifiers & Qt.ControlModifier))) {
                cancelHold();
                event.accepted = true;
            }
            return;
        }

        switch (event.key) {
        case Qt.Key_Left:
            selectedCol = (selectedCol - 1 + gridColumns) % gridColumns;
            selectedIndex = selectedRow * gridColumns + selectedCol;
            event.accepted = true;
            break;
        case Qt.Key_Right:
            selectedCol = (selectedCol + 1) % gridColumns;
            selectedIndex = selectedRow * gridColumns + selectedCol;
            event.accepted = true;
            break;
        case Qt.Key_Up:
        case Qt.Key_Backtab:
            selectedRow = (selectedRow - 1 + gridRows) % gridRows;
            selectedIndex = selectedRow * gridColumns + selectedCol;
            event.accepted = true;
            break;
        case Qt.Key_Down:
        case Qt.Key_Tab:
            selectedRow = (selectedRow + 1) % gridRows;
            selectedIndex = selectedRow * gridColumns + selectedCol;
            event.accepted = true;
            break;
        case Qt.Key_Return:
        case Qt.Key_Enter:
            startHold(getActionAtIndex(selectedIndex), selectedIndex);
            event.accepted = true;
            break;
        case Qt.Key_N:
            if (event.modifiers & Qt.ControlModifier) {
                selectedCol = (selectedCol + 1) % gridColumns;
                selectedIndex = selectedRow * gridColumns + selectedCol;
                event.accepted = true;
            }
            break;
        case Qt.Key_P:
            if (!(event.modifiers & Qt.ControlModifier)) {
                const idx = visibleActions.indexOf("poweroff");
                startHold("poweroff", idx);
                event.accepted = true;
            } else {
                selectedCol = (selectedCol - 1 + gridColumns) % gridColumns;
                selectedIndex = selectedRow * gridColumns + selectedCol;
                event.accepted = true;
            }
            break;
        case Qt.Key_J:
            if (event.modifiers & Qt.ControlModifier) {
                selectedRow = (selectedRow + 1) % gridRows;
                selectedIndex = selectedRow * gridColumns + selectedCol;
                event.accepted = true;
            }
            break;
        case Qt.Key_K:
            if (event.modifiers & Qt.ControlModifier) {
                selectedRow = (selectedRow - 1 + gridRows) % gridRows;
                selectedIndex = selectedRow * gridColumns + selectedCol;
                event.accepted = true;
            }
            break;
        case Qt.Key_R:
            startHold("reboot", visibleActions.indexOf("reboot"));
            event.accepted = true;
            break;
        case Qt.Key_X:
            startHold("logout", visibleActions.indexOf("logout"));
            event.accepted = true;
            break;
        case Qt.Key_S:
            startHold("suspend", visibleActions.indexOf("suspend"));
            event.accepted = true;
            break;
        case Qt.Key_H:
            startHold("hibernate", visibleActions.indexOf("hibernate"));
            event.accepted = true;
            break;
        }
    }

    anchors.fill: parent
    color: Qt.rgba(0, 0, 0, 0.5)
    visible: isVisible
    z: 1000

    MouseArea {
        anchors.fill: parent
        onClicked: root.hide()
    }

    Timer {
        id: holdTimer
        interval: 16
        repeat: true
        onTriggered: {
            root.holdProgress = Math.min(1, root.holdProgress + (interval / root.holdDurationMs));
            if (root.holdProgress >= 1) {
                stop();
                root.completeHold();
            }
        }
    }

    Timer {
        id: hintTimer
        interval: 2000
        onTriggered: root.showHoldHint = false
    }

    FocusScope {
        id: powerMenuFocusScope
        anchors.fill: parent
        focus: root.isVisible

        onVisibleChanged: {
            if (visible)
                Qt.callLater(() => forceActiveFocus());
        }

        Keys.onEscapePressed: root.hide()
        Keys.onPressed: event => {
            if (event.isAutoRepeat) {
                event.accepted = true;
                return;
            }
            if (useGridLayout) {
                handleGridNavigation(event, true);
            } else {
                handleListNavigation(event, true);
            }
        }
        Keys.onReleased: event => {
            if (event.isAutoRepeat) {
                event.accepted = true;
                return;
            }
            if (useGridLayout) {
                handleGridNavigation(event, false);
            } else {
                handleListNavigation(event, false);
            }
        }

        Rectangle {
            anchors.centerIn: parent
            width: useGridLayout ? Math.min(550, gridColumns * 180 + Theme.spacingS * (gridColumns - 1) + Theme.spacingL * 2) : 320
            height: contentItem.implicitHeight + Theme.spacingL * 2
            radius: Theme.cornerRadius
            color: Theme.surfaceContainer
            border.color: Theme.outlineMedium
            border.width: 1

            Item {
                id: contentItem
                anchors.fill: parent
                anchors.margins: Theme.spacingL
                implicitHeight: headerRow.height + Theme.spacingM + (useGridLayout ? buttonGrid.implicitHeight : buttonColumn.implicitHeight) + (root.needsConfirmation ? hintRow.height + Theme.spacingM : 0)

                Row {
                    id: headerRow
                    width: parent.width
                    height: 30

                    StyledText {
                        text: I18n.tr("Power Options")
                        font.pixelSize: Theme.fontSizeLarge
                        color: Theme.surfaceText
                        font.weight: Font.Medium
                        anchors.verticalCenter: parent.verticalCenter
                    }

                    Item {
                        width: parent.width - 150
                        height: 1
                    }

                    DankActionButton {
                        iconName: "close"
                        iconSize: Theme.iconSize - 4
                        iconColor: Theme.surfaceText
                        onClicked: root.hide()
                    }
                }

                Grid {
                    id: buttonGrid
                    visible: useGridLayout
                    anchors.top: headerRow.bottom
                    anchors.topMargin: Theme.spacingM
                    anchors.horizontalCenter: parent.horizontalCenter
                    columns: root.gridColumns
                    columnSpacing: Theme.spacingS
                    rowSpacing: Theme.spacingS
                    width: parent.width

                    Repeater {
                        model: root.visibleActions

                        Rectangle {
                            id: gridButtonRect
                            required property int index
                            required property string modelData

                            readonly property var actionData: root.getActionData(modelData)
                            readonly property bool isSelected: root.selectedIndex === index
                            readonly property bool showWarning: modelData === "reboot" || modelData === "poweroff"
                            readonly property bool isHolding: root.holdActionIndex === index && root.holdProgress > 0

                            width: (contentItem.width - Theme.spacingS * (root.gridColumns - 1)) / root.gridColumns
                            height: 100
                            radius: Theme.cornerRadius
                            color: {
                                if (isSelected)
                                    return Qt.rgba(Theme.primary.r, Theme.primary.g, Theme.primary.b, 0.12);
                                if (mouseArea.containsMouse)
                                    return Qt.rgba(Theme.primary.r, Theme.primary.g, Theme.primary.b, 0.08);
                                return Qt.rgba(Theme.surfaceVariant.r, Theme.surfaceVariant.g, Theme.surfaceVariant.b, 0.08);
                            }
                            border.color: isSelected ? Theme.primary : "transparent"
                            border.width: isSelected ? 2 : 0

                            Rectangle {
                                id: gridProgressMask
                                anchors.fill: parent
                                radius: parent.radius
                                visible: false
                                layer.enabled: true
                            }

                            Item {
                                anchors.fill: parent
                                visible: gridButtonRect.isHolding
                                layer.enabled: gridButtonRect.isHolding
                                layer.effect: MultiEffect {
                                    maskEnabled: true
                                    maskSource: gridProgressMask
                                    maskSpreadAtMin: 1
                                    maskThresholdMin: 0.5
                                }

                                Rectangle {
                                    anchors.left: parent.left
                                    anchors.top: parent.top
                                    anchors.bottom: parent.bottom
                                    width: parent.width * root.holdProgress
                                    color: {
                                        if (gridButtonRect.modelData === "poweroff")
                                            return Qt.rgba(Theme.error.r, Theme.error.g, Theme.error.b, 0.3);
                                        if (gridButtonRect.modelData === "reboot")
                                            return Qt.rgba(Theme.warning.r, Theme.warning.g, Theme.warning.b, 0.3);
                                        return Qt.rgba(Theme.primary.r, Theme.primary.g, Theme.primary.b, 0.3);
                                    }
                                }
                            }

                            Column {
                                anchors.centerIn: parent
                                spacing: Theme.spacingS

                                DankIcon {
                                    name: gridButtonRect.actionData.icon
                                    size: Theme.iconSize + 8
                                    color: {
                                        if (gridButtonRect.showWarning && (mouseArea.containsMouse || gridButtonRect.isHolding)) {
                                            return gridButtonRect.modelData === "poweroff" ? Theme.error : Theme.warning;
                                        }
                                        return Theme.surfaceText;
                                    }
                                    anchors.horizontalCenter: parent.horizontalCenter
                                }

                                StyledText {
                                    text: gridButtonRect.actionData.label
                                    font.pixelSize: Theme.fontSizeMedium
                                    color: {
                                        if (gridButtonRect.showWarning && (mouseArea.containsMouse || gridButtonRect.isHolding)) {
                                            return gridButtonRect.modelData === "poweroff" ? Theme.error : Theme.warning;
                                        }
                                        return Theme.surfaceText;
                                    }
                                    font.weight: Font.Medium
                                    anchors.horizontalCenter: parent.horizontalCenter
                                }

                                Rectangle {
                                    width: 20
                                    height: 16
                                    radius: 4
                                    color: Qt.rgba(Theme.surfaceText.r, Theme.surfaceText.g, Theme.surfaceText.b, 0.1)
                                    anchors.horizontalCenter: parent.horizontalCenter

                                    StyledText {
                                        text: gridButtonRect.actionData.key
                                        font.pixelSize: Theme.fontSizeSmall - 1
                                        color: Qt.rgba(Theme.surfaceText.r, Theme.surfaceText.g, Theme.surfaceText.b, 0.6)
                                        font.weight: Font.Medium
                                        anchors.centerIn: parent
                                    }
                                }
                            }

                            MouseArea {
                                id: mouseArea
                                anchors.fill: parent
                                hoverEnabled: true
                                cursorShape: Qt.PointingHandCursor
                                onPressed: {
                                    root.selectedRow = Math.floor(index / root.gridColumns);
                                    root.selectedCol = index % root.gridColumns;
                                    root.selectedIndex = index;
                                    root.startHold(modelData, index);
                                }
                                onReleased: root.cancelHold()
                                onCanceled: root.cancelHold()
                            }
                        }
                    }
                }

                Column {
                    id: buttonColumn
                    visible: !useGridLayout
                    anchors.top: headerRow.bottom
                    anchors.topMargin: Theme.spacingM
                    anchors.left: parent.left
                    anchors.right: parent.right
                    spacing: Theme.spacingS

                    Repeater {
                        model: root.visibleActions

                        Rectangle {
                            id: listButtonRect
                            required property int index
                            required property string modelData

                            readonly property var actionData: root.getActionData(modelData)
                            readonly property bool isSelected: root.selectedIndex === index
                            readonly property bool showWarning: modelData === "reboot" || modelData === "poweroff"
                            readonly property bool isHolding: root.holdActionIndex === index && root.holdProgress > 0

                            width: parent.width
                            height: 50
                            radius: Theme.cornerRadius
                            color: {
                                if (isSelected)
                                    return Qt.rgba(Theme.primary.r, Theme.primary.g, Theme.primary.b, 0.12);
                                if (listMouseArea.containsMouse)
                                    return Qt.rgba(Theme.primary.r, Theme.primary.g, Theme.primary.b, 0.08);
                                return Qt.rgba(Theme.surfaceVariant.r, Theme.surfaceVariant.g, Theme.surfaceVariant.b, 0.08);
                            }
                            border.color: isSelected ? Theme.primary : "transparent"
                            border.width: isSelected ? 2 : 0

                            Rectangle {
                                id: listProgressMask
                                anchors.fill: parent
                                radius: parent.radius
                                visible: false
                                layer.enabled: true
                            }

                            Item {
                                anchors.fill: parent
                                visible: listButtonRect.isHolding
                                layer.enabled: listButtonRect.isHolding
                                layer.effect: MultiEffect {
                                    maskEnabled: true
                                    maskSource: listProgressMask
                                    maskSpreadAtMin: 1
                                    maskThresholdMin: 0.5
                                }

                                Rectangle {
                                    anchors.left: parent.left
                                    anchors.top: parent.top
                                    anchors.bottom: parent.bottom
                                    width: parent.width * root.holdProgress
                                    color: {
                                        if (listButtonRect.modelData === "poweroff")
                                            return Qt.rgba(Theme.error.r, Theme.error.g, Theme.error.b, 0.3);
                                        if (listButtonRect.modelData === "reboot")
                                            return Qt.rgba(Theme.warning.r, Theme.warning.g, Theme.warning.b, 0.3);
                                        return Qt.rgba(Theme.primary.r, Theme.primary.g, Theme.primary.b, 0.3);
                                    }
                                }
                            }

                            Row {
                                anchors.left: parent.left
                                anchors.right: parent.right
                                anchors.leftMargin: Theme.spacingM
                                anchors.rightMargin: Theme.spacingM
                                anchors.verticalCenter: parent.verticalCenter
                                spacing: Theme.spacingM

                                DankIcon {
                                    name: listButtonRect.actionData.icon
                                    size: Theme.iconSize + 4
                                    color: {
                                        if (listButtonRect.showWarning && (listMouseArea.containsMouse || listButtonRect.isHolding)) {
                                            return listButtonRect.modelData === "poweroff" ? Theme.error : Theme.warning;
                                        }
                                        return Theme.surfaceText;
                                    }
                                    anchors.verticalCenter: parent.verticalCenter
                                }

                                StyledText {
                                    text: listButtonRect.actionData.label
                                    font.pixelSize: Theme.fontSizeMedium
                                    color: {
                                        if (listButtonRect.showWarning && (listMouseArea.containsMouse || listButtonRect.isHolding)) {
                                            return listButtonRect.modelData === "poweroff" ? Theme.error : Theme.warning;
                                        }
                                        return Theme.surfaceText;
                                    }
                                    font.weight: Font.Medium
                                    anchors.verticalCenter: parent.verticalCenter
                                }
                            }

                            Rectangle {
                                width: 28
                                height: 20
                                radius: 4
                                color: Qt.rgba(Theme.surfaceText.r, Theme.surfaceText.g, Theme.surfaceText.b, 0.1)
                                anchors.right: parent.right
                                anchors.rightMargin: Theme.spacingM
                                anchors.verticalCenter: parent.verticalCenter

                                StyledText {
                                    text: listButtonRect.actionData.key
                                    font.pixelSize: Theme.fontSizeSmall
                                    color: Qt.rgba(Theme.surfaceText.r, Theme.surfaceText.g, Theme.surfaceText.b, 0.6)
                                    font.weight: Font.Medium
                                    anchors.centerIn: parent
                                }
                            }

                            MouseArea {
                                id: listMouseArea
                                anchors.fill: parent
                                hoverEnabled: true
                                cursorShape: Qt.PointingHandCursor
                                onPressed: {
                                    root.selectedIndex = index;
                                    root.startHold(modelData, index);
                                }
                                onReleased: root.cancelHold()
                                onCanceled: root.cancelHold()
                            }
                        }
                    }
                }

                Row {
                    id: hintRow
                    anchors.horizontalCenter: parent.horizontalCenter
                    anchors.bottom: parent.bottom
                    anchors.bottomMargin: Theme.spacingS
                    spacing: Theme.spacingXS
                    visible: root.needsConfirmation
                    opacity: root.showHoldHint ? 1 : 0.5

                    Behavior on opacity {
                        NumberAnimation {
                            duration: 150
                        }
                    }

                    DankIcon {
                        name: root.showHoldHint ? "warning" : "touch_app"
                        size: Theme.fontSizeSmall
                        color: root.showHoldHint ? Theme.warning : Qt.rgba(Theme.surfaceText.r, Theme.surfaceText.g, Theme.surfaceText.b, 0.6)
                        anchors.verticalCenter: parent.verticalCenter
                    }

                    StyledText {
                        readonly property real totalMs: root.holdDurationMs
                        readonly property int remainingMs: Math.ceil(totalMs * (1 - root.holdProgress))
                        readonly property real durationSec: root.holdDurationMs / 1000
                        text: {
                            if (root.showHoldHint)
                                return I18n.tr("Hold longer to confirm");
                            if (root.holdProgress > 0) {
                                if (totalMs < 1000)
                                    return I18n.tr("Hold to confirm (%1 ms)").arg(remainingMs);
                                return I18n.tr("Hold to confirm (%1s)").arg(Math.ceil(remainingMs / 1000));
                            }
                            if (totalMs < 1000)
                                return I18n.tr("Hold to confirm (%1 ms)").arg(totalMs);
                            return I18n.tr("Hold to confirm (%1s)").arg(durationSec);
                        }
                        font.pixelSize: Theme.fontSizeSmall
                        color: root.showHoldHint ? Theme.warning : Qt.rgba(Theme.surfaceText.r, Theme.surfaceText.g, Theme.surfaceText.b, 0.6)
                        anchors.verticalCenter: parent.verticalCenter
                    }
                }
            }
        }
    }

    Component.onCompleted: updateVisibleActions()
}
