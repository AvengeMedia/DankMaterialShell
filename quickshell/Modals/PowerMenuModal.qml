import QtQuick
import Quickshell
import Quickshell.Widgets
import qs.Common
import qs.Modals.Common
import qs.Services
import qs.Widgets

DankModal {
    id: root

    layerNamespace: "dms:power-menu"
    keepPopoutsOpen: true
    useOverlayLayer: true

    property int selectedIndex: 0
    property int selectedRow: 0
    property int selectedCol: 0
    property rect parentBounds: Qt.rect(0, 0, 0, 0)
    property var parentScreen: null
    property var visibleActions: []
    property int gridColumns: 3
    property int gridRows: 2

    property string holdAction: ""
    property int holdActionIndex: -1
    property real holdProgress: 0
    property bool showHoldHint: false
    property bool holdFromKeyboard: false
    property string committedAction: ""

    readonly property bool needsConfirmation: SettingsData.powerActionConfirm
    readonly property int holdDurationMs: SettingsData.powerActionHoldDuration * 1000

    signal powerActionRequested(string action, string title, string message)
    signal lockRequested

    function actionNeedsConfirm(action) {
        return action !== "lock" && action !== "restart";
    }

    function actionWakesOnKeyRelease(action) {
        return action === "suspend" || action === "hibernate";
    }

    function startHold(action, actionIndex) {
        if (committedAction !== "")
            return;
        if (!needsConfirmation || !actionNeedsConfirm(action)) {
            if (holdFromKeyboard && actionWakesOnKeyRelease(action)) {
                commitAction(action, actionIndex);
                return;
            }
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
        holdTimer.stop();
        if (holdFromKeyboard && actionWakesOnKeyRelease(holdAction)) {
            commitAction(holdAction, holdActionIndex);
            return;
        }
        const action = holdAction;
        holdAction = "";
        holdActionIndex = -1;
        holdProgress = 0;
        executeAction(action);
    }

    function commitAction(action, actionIndex) {
        holdTimer.stop();
        holdAction = "";
        holdActionIndex = actionIndex;
        committedAction = action;
        commitFallbackTimer.restart();
    }

    function executeCommittedAction() {
        if (committedAction === "")
            return;
        commitFallbackTimer.stop();
        const action = committedAction;
        committedAction = "";
        holdActionIndex = -1;
        holdProgress = 0;
        executeAction(action);
    }

    signal switchUserRequested

    function executeAction(action) {
        if (action === "lock") {
            close();
            lockRequested();
            return;
        }
        if (action === "restart") {
            close();
            Quickshell.execDetached(["dms", "restart"]);
            return;
        }
        if (action === "switchuser") {
            close();
            switchUserRequested();
            return;
        }
        close();
        root.powerActionRequested(action, "", "");
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

    Timer {
        id: commitFallbackTimer
        interval: 5000
        onTriggered: root.executeCommittedAction()
    }

    function openCentered() {
        parentBounds = Qt.rect(0, 0, 0, 0);
        parentScreen = null;
        open();
    }

    function openFromControlCenter(bounds, targetScreen) {
        parentBounds = bounds;
        parentScreen = targetScreen;
        open();
    }

    function updateVisibleActions() {
        const allActions = SettingsData.powerMenuActions || ["reboot", "logout", "poweroff", "lock", "suspend", "restart"];
        visibleActions = allActions.filter(action => {
            if (action === "hibernate" && !SessionService.hibernateSupported)
                return false;
            return true;
        });

        if (!SettingsData.powerMenuGridLayout)
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
        const defaultAction = SettingsData.powerMenuDefaultAction || "logout";
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
        case "lock":
            return {
                "icon": "lock",
                "label": I18n.tr("Lock"),
                "key": "L"
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
        case "restart":
            return {
                "icon": "refresh",
                "label": I18n.tr("Restart DMS"),
                "key": "D"
            };
        case "switchuser":
            return {
                "icon": "switch_account",
                "label": I18n.tr("Switch User"),
                "key": "U"
            };
        default:
            return {
                "icon": "help",
                "label": action,
                "key": "?"
            };
        }
    }

    function selectOption(action, actionIndex) {
        startHold(action, actionIndex !== undefined ? actionIndex : -1);
    }

    shouldBeVisible: false
    modalWidth: SettingsData.powerMenuGridLayout ? Math.min(550, gridColumns * 180 + Theme.spacingS * (gridColumns - 1) + Theme.spacingL * 2) : 400
    modalHeight: contentLoader.item ? contentLoader.item.implicitHeight : 300
    enableShadow: true
    targetScreen: parentScreen
    positioning: parentBounds.width > 0 ? "custom" : "center"
    customPosition: {
        if (parentBounds.width > 0) {
            const effectiveBarThickness = Math.max(26 + (SettingsData.barConfigs[0]?.innerPadding ?? 4) * 0.6 + (SettingsData.barConfigs[0]?.innerPadding ?? 4) + 4, Theme.barHeight - 4 - (8 - (SettingsData.barConfigs[0]?.innerPadding ?? 4)));
            const barExclusionZone = effectiveBarThickness + (SettingsData.barConfigs[0]?.spacing ?? 4) + (SettingsData.barConfigs[0]?.bottomGap ?? 0);
            const screenW = parentScreen?.width ?? 1920;
            const screenH = parentScreen?.height ?? 1080;
            const margin = Theme.spacingL;

            let targetX = parentBounds.x + (parentBounds.width - modalWidth) / 2;
            let targetY = parentBounds.y + (parentBounds.height - modalHeight) / 2;

            const minY = (SettingsData.barConfigs[0]?.position ?? SettingsData.Position.Top) === SettingsData.Position.Top ? barExclusionZone + margin : margin;
            const maxY = (SettingsData.barConfigs[0]?.position ?? SettingsData.Position.Top) === SettingsData.Position.Bottom ? screenH - modalHeight - barExclusionZone - margin : screenH - modalHeight - margin;

            targetY = Math.max(minY, Math.min(maxY, targetY));

            return Qt.point(targetX, targetY);
        }
        return Qt.point(0, 0);
    }
    onBackgroundClicked: () => {
        cancelHold();
        close();
    }
    onShouldBeVisibleChanged: {
        if (!shouldBeVisible)
            return;
        holdAction = "";
        holdActionIndex = -1;
        holdProgress = 0;
        showHoldHint = false;
        holdFromKeyboard = false;
        committedAction = "";
        commitFallbackTimer.stop();
        updateVisibleActions();
        const defaultIndex = getDefaultActionIndex();
        selectedIndex = defaultIndex;
        if (SettingsData.powerMenuGridLayout) {
            selectedRow = Math.floor(defaultIndex / gridColumns);
            selectedCol = defaultIndex % gridColumns;
        }
    }
    onShouldHaveFocusChanged: {
        if (!shouldHaveFocus)
            return;
        Qt.callLater(() => modalFocusScope.forceActiveFocus());
    }
    onDialogClosed: () => {
        cancelHold();
    }
    Component.onCompleted: updateVisibleActions()
    modalFocusScope.Keys.onPressed: event => {
        if (event.isAutoRepeat) {
            event.accepted = true;
            return;
        }
        if (committedAction !== "") {
            event.accepted = true;
            return;
        }
        holdFromKeyboard = true;
        if (SettingsData.powerMenuGridLayout) {
            handleGridNavigation(event, true);
        } else {
            handleListNavigation(event, true);
        }
    }
    modalFocusScope.Keys.onReleased: event => {
        if (event.isAutoRepeat) {
            event.accepted = true;
            return;
        }
        if (committedAction !== "") {
            event.accepted = true;
            executeCommittedAction();
            return;
        }
        if (SettingsData.powerMenuGridLayout) {
            handleGridNavigation(event, false);
        } else {
            handleListNavigation(event, false);
        }
    }

    function handleListNavigation(event, isPressed) {
        if (!isPressed) {
            if (event.key === Qt.Key_Return || event.key === Qt.Key_Enter || event.key === Qt.Key_R || event.key === Qt.Key_X || event.key === Qt.Key_L || event.key === Qt.Key_S || event.key === Qt.Key_H || event.key === Qt.Key_D || (event.key === Qt.Key_P && !(event.modifiers & Qt.ControlModifier))) {
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
                if (visibleActions.includes("poweroff")) {
                    const idx = visibleActions.indexOf("poweroff");
                    startHold("poweroff", idx);
                    event.accepted = true;
                }
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
            if (visibleActions.includes("reboot")) {
                startHold("reboot", visibleActions.indexOf("reboot"));
                event.accepted = true;
            }
            break;
        case Qt.Key_X:
            if (visibleActions.includes("logout")) {
                startHold("logout", visibleActions.indexOf("logout"));
                event.accepted = true;
            }
            break;
        case Qt.Key_L:
            if (visibleActions.includes("lock")) {
                startHold("lock", visibleActions.indexOf("lock"));
                event.accepted = true;
            }
            break;
        case Qt.Key_S:
            if (visibleActions.includes("suspend")) {
                startHold("suspend", visibleActions.indexOf("suspend"));
                event.accepted = true;
            }
            break;
        case Qt.Key_H:
            if (visibleActions.includes("hibernate")) {
                startHold("hibernate", visibleActions.indexOf("hibernate"));
                event.accepted = true;
            }
            break;
        case Qt.Key_D:
            if (visibleActions.includes("restart")) {
                startHold("restart", visibleActions.indexOf("restart"));
                event.accepted = true;
            }
            break;
        }
    }

    function handleGridNavigation(event, isPressed) {
        if (!isPressed) {
            if (event.key === Qt.Key_Return || event.key === Qt.Key_Enter || event.key === Qt.Key_R || event.key === Qt.Key_X || event.key === Qt.Key_L || event.key === Qt.Key_S || event.key === Qt.Key_H || event.key === Qt.Key_D || (event.key === Qt.Key_P && !(event.modifiers & Qt.ControlModifier))) {
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
                if (visibleActions.includes("poweroff")) {
                    const idx = visibleActions.indexOf("poweroff");
                    startHold("poweroff", idx);
                    event.accepted = true;
                }
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
            if (visibleActions.includes("reboot")) {
                startHold("reboot", visibleActions.indexOf("reboot"));
                event.accepted = true;
            }
            break;
        case Qt.Key_X:
            if (visibleActions.includes("logout")) {
                startHold("logout", visibleActions.indexOf("logout"));
                event.accepted = true;
            }
            break;
        case Qt.Key_L:
            if (visibleActions.includes("lock")) {
                startHold("lock", visibleActions.indexOf("lock"));
                event.accepted = true;
            }
            break;
        case Qt.Key_S:
            if (visibleActions.includes("suspend")) {
                startHold("suspend", visibleActions.indexOf("suspend"));
                event.accepted = true;
            }
            break;
        case Qt.Key_H:
            if (visibleActions.includes("hibernate")) {
                startHold("hibernate", visibleActions.indexOf("hibernate"));
                event.accepted = true;
            }
            break;
        case Qt.Key_D:
            if (visibleActions.includes("restart")) {
                startHold("restart", visibleActions.indexOf("restart"));
                event.accepted = true;
            }
            break;
        }
    }

    content: Component {
        Item {
            anchors.fill: parent
            implicitHeight: (SettingsData.powerMenuGridLayout ? buttonGrid.implicitHeight : buttonColumn.implicitHeight) + Theme.spacingL * 2 + (root.needsConfirmation ? hintRow.height + Theme.spacingM : 0)

            Grid {
                id: buttonGrid
                visible: SettingsData.powerMenuGridLayout
                anchors.horizontalCenter: parent.horizontalCenter
                anchors.top: parent.top
                anchors.topMargin: Theme.spacingL
                columns: root.gridColumns
                columnSpacing: Theme.spacingS
                rowSpacing: Theme.spacingS

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

                        width: (root.modalWidth - Theme.spacingL * 2 - Theme.spacingS * (root.gridColumns - 1)) / root.gridColumns
                        height: 100
                        radius: Theme.cornerRadius
                        color: {
                            if (isSelected)
                                return Theme.primaryHover;
                            if (mouseArea.containsMouse)
                                return Theme.primaryHoverLight;
                            return Theme.surfaceHover;
                        }
                        border.color: isSelected ? Theme.primary : Theme.withAlpha(Theme.primary, 0)
                        border.width: isSelected ? 2 : 0

                        ClippingRectangle {
                            anchors.fill: parent
                            radius: parent.radius
                            color: "transparent"
                            visible: gridButtonRect.isHolding

                            Rectangle {
                                anchors.left: parent.left
                                anchors.top: parent.top
                                anchors.bottom: parent.bottom
                                width: parent.width * root.holdProgress
                                color: {
                                    if (gridButtonRect.modelData === "poweroff")
                                        return Theme.errorSelected;
                                    if (gridButtonRect.modelData === "reboot")
                                        return Theme.withAlpha(Theme.warning, 0.3);
                                    return Theme.primarySelected;
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
                                color: Theme.onSurface_12
                                anchors.horizontalCenter: parent.horizontalCenter

                                StyledText {
                                    text: gridButtonRect.actionData.key
                                    font.pixelSize: Theme.fontSizeSmall - 1
                                    color: Theme.surfaceTextSecondary
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
                                root.holdFromKeyboard = false;
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
                visible: !SettingsData.powerMenuGridLayout
                anchors {
                    left: parent.left
                    right: parent.right
                    top: parent.top
                    leftMargin: Theme.spacingL
                    rightMargin: Theme.spacingL
                    topMargin: Theme.spacingL
                }
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
                        height: 56
                        radius: Theme.cornerRadius
                        color: {
                            if (isSelected)
                                return Theme.primaryHover;
                            if (listMouseArea.containsMouse)
                                return Theme.primaryHoverLight;
                            return Theme.surfaceHover;
                        }
                        border.color: isSelected ? Theme.primary : Theme.withAlpha(Theme.primary, 0)
                        border.width: isSelected ? 2 : 0

                        ClippingRectangle {
                            anchors.fill: parent
                            radius: parent.radius
                            color: "transparent"
                            visible: listButtonRect.isHolding

                            Rectangle {
                                anchors.left: parent.left
                                anchors.top: parent.top
                                anchors.bottom: parent.bottom
                                width: parent.width * root.holdProgress
                                color: {
                                    if (listButtonRect.modelData === "poweroff")
                                        return Theme.errorSelected;
                                    if (listButtonRect.modelData === "reboot")
                                        return Theme.withAlpha(Theme.warning, 0.3);
                                    return Theme.primarySelected;
                                }
                            }
                        }

                        Row {
                            anchors {
                                left: parent.left
                                right: parent.right
                                leftMargin: Theme.spacingM
                                rightMargin: Theme.spacingM
                                verticalCenter: parent.verticalCenter
                            }
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
                            color: Theme.onSurface_12
                            anchors {
                                right: parent.right
                                rightMargin: Theme.spacingM
                                verticalCenter: parent.verticalCenter
                            }

                            StyledText {
                                text: listButtonRect.actionData.key
                                font.pixelSize: Theme.fontSizeSmall
                                color: Theme.surfaceTextSecondary
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
                                root.holdFromKeyboard = false;
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
                readonly property bool selectedNeedsHold: root.actionNeedsConfirm(root.getActionAtIndex(root.selectedIndex))
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
                    name: {
                        if (root.showHoldHint)
                            return "warning";
                        if (!hintRow.selectedNeedsHold)
                            return "bolt";
                        return "touch_app";
                    }
                    size: Theme.fontSizeSmall
                    color: root.showHoldHint ? Theme.warning : Theme.surfaceTextSecondary
                    anchors.verticalCenter: parent.verticalCenter
                }

                StyledText {
                    readonly property real totalMs: SettingsData.powerActionHoldDuration * 1000
                    readonly property int remainingMs: Math.ceil(totalMs * (1 - root.holdProgress))
                    text: {
                        if (root.committedAction !== "")
                            return I18n.tr("Release to confirm");
                        if (root.showHoldHint)
                            return I18n.tr("Hold longer to confirm");
                        if (!hintRow.selectedNeedsHold)
                            return I18n.tr("Activates immediately");
                        if (root.holdProgress > 0) {
                            if (totalMs < 1000)
                                return I18n.tr("Hold to confirm (%1 ms)").arg(remainingMs);
                            return I18n.tr("Hold to confirm (%1s)").arg(Math.ceil(remainingMs / 1000));
                        }
                        if (totalMs < 1000)
                            return I18n.tr("Hold to confirm (%1 ms)").arg(totalMs);
                        return I18n.tr("Hold to confirm (%1s)").arg(SettingsData.powerActionHoldDuration);
                    }
                    font.pixelSize: Theme.fontSizeSmall
                    color: root.showHoldHint ? Theme.warning : Theme.surfaceTextSecondary
                    anchors.verticalCenter: parent.verticalCenter
                }
            }
        }
    }
}
