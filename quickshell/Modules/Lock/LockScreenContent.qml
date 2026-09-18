pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Effects
import QtQuick.Layouts
import QtQuick.Window
import Quickshell
import qs.Common
import qs.Modals
import qs.Modules.Notifications as Notifications
import qs.Services
import qs.Widgets
import qs.DankCommon.Session
import "../../Common/KeyUtils.js" as KeyUtils

Item {
    id: root
    readonly property var log: Log.scoped("LockScreenContent")

    function encodeFileUrl(path) {
        if (!path)
            return "";
        return "file://" + path.split('/').map(s => encodeURIComponent(s)).join('/');
    }

    property string passwordBuffer: ""
    property bool demoMode: false
    property var pam: demoPam
    property string screenName: ""
    property bool unlocking: false
    property string pamState: ""
    property bool lockerReadySent: false
    property bool lockerReadyArmed: false
    property var sessionLock: null
    readonly property bool hasCustomWallpaper: SettingsData.lockScreenWallpaperPath !== ""
    readonly property string lockFontFamily: SettingsData.lockScreenFontFamily

    component ClockDigitText: StyledText {
        font.pixelSize: LockMetrics.clockSize
        font.weight: Theme.fontWeight
        color: Theme.lockScreenContentColor
        horizontalAlignment: Text.AlignHCenter
        font.family: root.lockFontFamily !== "" ? root.lockFontFamily : resolvedFontFamily
    }

    signal unlockRequested
    signal passwordEdited(string text)

    function resetLockState() {
        lockerReadySent = false;
        lockerReadyArmed = true;
        unlocking = false;
        pamState = "";
        if (pam)
            pam.lockMessage = "";
    }

    function focusPasswordField() {
        if (demoMode || !passwordField)
            return;
        passwordField.forceActiveFocus();
    }

    function currentAuthFeedbackText() {
        if (!pam)
            return "";
        if (pam.u2fState === "insert" && !pam.u2fPending)
            return I18n.tr("Insert your security key...");
        if (pam.u2fState === "waiting" && !pam.u2fPending)
            return I18n.tr("Touch your security key...");
        if (pam.lockMessage && pam.lockMessage.length > 0)
            return pam.lockMessage;
        if (root.pamState === "error")
            return I18n.tr("Authentication error - try again");
        if (root.pamState === "max")
            return I18n.tr("Too many attempts - locked out");
        if (root.pamState === "fail")
            return I18n.tr("Incorrect password - try again");
        if (pam.fprintState === "error")
            return I18n.tr("Fingerprint error");
        if (pam.fprintState === "max")
            return I18n.tr("Maximum fingerprint attempts reached. Please use password.");
        if (pam.fprintState === "fail")
            return I18n.tr("Fingerprint not recognized (%1/%2). Please try again or use password.", "lock screen message, %1 is attempts used, %2 is max attempts").arg(pam.fprint.tries).arg(SettingsData.maxFprintTries);
        return "";
    }

    function authFeedbackIsHint() {
        return pam && (pam.u2fState === "waiting" || pam.u2fState === "insert") && !pam.u2fPending;
    }

    function canStartSecurityKeyUnlock() {
        return !demoMode && pam && pam.u2f && pam.u2f.available && SettingsData.enableU2f && SettingsData.u2fMode === "or" && !pam.passwd.active && !pam.u2f.active && !pam.u2fPending && !root.unlocking;
    }

    function triggerSecurityKeyUnlock() {
        if (!canStartSecurityKeyUnlock())
            return;
        passwordField.clear();
        pam.u2f.startForAlternativeAuth();
    }

    function securityKeyShortcutMatches(event) {
        return SettingsData.lockScreenSecurityKeyShortcutEnabled && KeyUtils.eventMatchesCombo(event, SettingsData.lockScreenSecurityKeyShortcut);
    }

    Component.onCompleted: {
        WeatherService.addRef();
        UserInfoService.getUserInfo();

        lockerReadyArmed = true;
    }

    Component.onDestruction: {
        WeatherService.removeRef();
    }

    function sendLockerReadyOnce() {
        if (root.demoMode)
            return;
        if (lockerReadySent)
            return;
        if (root.unlocking)
            return;
        lockerReadySent = true;
        if (SessionService.loginctlAvailable && DMSService.apiVersion >= 2) {
            DMSService.sendRequest("loginctl.lockerReady", null, resp => {
                if (resp?.error)
                    log.warn("lockerReady failed:", resp.error);
                else
                    log.debug("lockerReady sent (afterAnimating/afterRendering)");
            });
        }
    }

    function maybeSend() {
        if (!lockerReadyArmed)
            return;
        if (root.unlocking)
            return;
        if (!root.visible || root.opacity <= 0)
            return;
        if (root.sessionLock && !root.sessionLock.secure)
            return;
        Qt.callLater(() => {
            if (root.visible && root.opacity > 0 && !root.unlocking)
                sendLockerReadyOnce();
        });
    }

    Connections {
        target: root.sessionLock
        enabled: target !== null
        function onSecureChanged() {
            root.maybeSend();
        }
    }

    Connections {
        target: root.Window.window
        enabled: target !== null

        function onAfterAnimating() {
            maybeSend();
        }
        function onAfterRendering() {
            maybeSend();
        }
    }

    onVisibleChanged: maybeSend()
    onOpacityChanged: maybeSend()

    Rectangle {
        anchors.fill: parent
        color: SettingsData.effectiveWallpaperBackgroundColor
    }

    Loader {
        anchors.fill: parent
        active: {
            if (root.hasCustomWallpaper)
                return false;
            var currentWallpaper = SessionData.getMonitorWallpaper(screenName);
            return !currentWallpaper || (currentWallpaper && currentWallpaper.startsWith("#"));
        }
        asynchronous: true

        sourceComponent: DankBackdrop {
            screenName: root.screenName
        }
    }

    Loader {
        id: wallpaperBackground
        anchors.fill: parent

        readonly property string wallpaperSource: {
            if (root.hasCustomWallpaper)
                return root.encodeFileUrl(SettingsData.lockScreenWallpaperPath);
            var w = SessionData.getMonitorWallpaper(screenName);
            return (w && !w.startsWith("#")) ? encodeFileUrl(w) : "";
        }
        readonly property string fillModeName: {
            if (SettingsData.lockScreenWallpaperFillMode !== "")
                return SettingsData.lockScreenWallpaperFillMode;
            return root.hasCustomWallpaper ? "Fill" : SessionData.getMonitorWallpaperFillMode(root.screenName);
        }

        readonly property real screenScale: CompositorService.getScreenScale(Quickshell.screens.find(s => s.name === root.screenName) ?? null)
        readonly property size decodeSize: Qt.size(Math.round(width * screenScale), Math.round(height * screenScale))

        active: wallpaperSource !== "" && width > 0 && height > 0
        asynchronous: false

        sourceComponent: fillModeName === "Scrolling" ? scrollWallpaperComp : plainWallpaperComp

        layer.enabled: true
        layer.effect: MultiEffect {
            autoPaddingEnabled: false
            blurEnabled: true
            blur: Theme.lockScreenBlur
            blurMax: Theme.lockScreenBlurMax
            blurMultiplier: 1
        }

        Behavior on opacity {
            NumberAnimation {
                duration: LockMetrics.effectsDuration
                easing.type: Easing.BezierSpline
                easing.bezierCurve: Theme.expressiveCurves.expressiveEffects
            }
        }
    }

    Component {
        id: plainWallpaperComp
        Image {
            source: wallpaperBackground.wallpaperSource
            sourceSize: wallpaperBackground.decodeSize
            fillMode: Theme.getFillMode(wallpaperBackground.fillModeName)
            smooth: true
            cache: true
            asynchronous: false
        }
    }

    Component {
        id: scrollWallpaperComp
        Item {
            Image {
                id: scrollSource
                anchors.fill: parent
                visible: false
                source: wallpaperBackground.wallpaperSource
                sourceSize: wallpaperBackground.decodeSize
                asynchronous: false
                cache: true
            }

            ShaderEffectSource {
                id: scrollSrc
                sourceItem: scrollSource
                hideSource: true
                live: false
            }

            ShaderEffect {
                anchors.fill: parent

                readonly property var scrollPos: SessionData.getMonitorScrollPosition(screenName)

                property variant source1: scrollSrc
                property variant source2: scrollSrc
                property real progress: 0.0
                property real fillMode: Theme.getShaderFillMode(wallpaperBackground.fillModeName)
                property real scrollX: scrollPos.scrollX
                property real scrollY: scrollPos.scrollY
                property real imageWidth1: scrollSource.implicitWidth > 0 ? scrollSource.implicitWidth : 1
                property real imageHeight1: scrollSource.implicitHeight > 0 ? scrollSource.implicitHeight : 1
                property real imageWidth2: imageWidth1
                property real imageHeight2: imageHeight1
                property real screenWidth: width > 0 ? width : 1
                property real screenHeight: height > 0 ? height : 1
                property vector4d fillColor: Qt.vector4d(0, 0, 0, 1)

                fragmentShader: Qt.resolvedUrl("../../Shaders/qsb/wp_fade.frag.qsb")
            }
        }
    }

    Rectangle {
        anchors.fill: parent
        color: Theme.screenOffColor
        opacity: Theme.lockScreenScrimAlpha
    }

    SystemClock {
        id: systemClock

        precision: SystemClock.Seconds
    }

    Rectangle {
        anchors.fill: parent
        color: "transparent"

        Item {
            id: clockContainer
            anchors.horizontalCenter: parent.horizontalCenter
            anchors.bottom: parent.verticalCenter
            anchors.bottomMargin: LockMetrics.fieldHeight
            width: parent.width
            height: verticalClock.visible ? verticalClock.implicitHeight : clockText.implicitHeight
            visible: SettingsData.lockScreenShowTime

            Row {
                id: clockText
                anchors.horizontalCenter: parent.horizontalCenter
                anchors.top: parent.top
                spacing: 0
                visible: SettingsData.lockScreenClockStyle !== "vertical"

                property string fullTimeStr: {
                    const format = SettingsData.getEffectiveTimeFormat();
                    return systemClock.date.toLocaleTimeString(Qt.locale(), format);
                }
                property var timeParts: fullTimeStr.split(':')
                property string hours: timeParts[0] || ""
                property string minutes: timeParts[1] || ""
                property string secondsWithAmPm: timeParts.length > 2 ? timeParts[2] : ""
                property string seconds: secondsWithAmPm.replace(/\s*(AM|PM|am|pm)$/i, '')
                property string ampm: {
                    const match = fullTimeStr.match(/\s*(AM|PM|am|pm)$/i);
                    return match ? match[0].trim() : "";
                }
                property bool hasSeconds: timeParts.length > 2

                ClockDigitText {
                    width: clockText.hours.length > 1 ? LockMetrics.clockDigitWidth : 0
                    text: clockText.hours.length > 1 ? clockText.hours[0] : ""
                }

                ClockDigitText {
                    width: LockMetrics.clockDigitWidth
                    text: clockText.hours.length > 1 ? clockText.hours[1] : clockText.hours.length > 0 ? clockText.hours[0] : ""
                }

                ClockDigitText {
                    text: ":"
                }

                ClockDigitText {
                    width: LockMetrics.clockDigitWidth
                    text: clockText.minutes.length > 0 ? clockText.minutes[0] : ""
                }

                ClockDigitText {
                    width: LockMetrics.clockDigitWidth
                    text: clockText.minutes.length > 1 ? clockText.minutes[1] : ""
                }

                ClockDigitText {
                    text: clockText.hasSeconds ? ":" : ""
                    visible: clockText.hasSeconds
                }

                ClockDigitText {
                    width: LockMetrics.clockDigitWidth
                    text: clockText.hasSeconds && clockText.seconds.length > 0 ? clockText.seconds[0] : ""
                    visible: clockText.hasSeconds
                }

                ClockDigitText {
                    width: LockMetrics.clockDigitWidth
                    text: clockText.hasSeconds && clockText.seconds.length > 1 ? clockText.seconds[1] : ""
                    visible: clockText.hasSeconds
                }

                ClockDigitText {
                    width: Theme.iconSizeSmall
                    text: " "
                    visible: clockText.ampm !== ""
                }

                ClockDigitText {
                    text: clockText.ampm
                    visible: clockText.ampm !== ""
                }
            }

            Column {
                id: verticalClock
                anchors.horizontalCenter: parent.horizontalCenter
                anchors.top: parent.top
                spacing: -Theme.spacingS
                visible: SettingsData.lockScreenClockStyle === "vertical"

                Row {
                    anchors.horizontalCenter: parent.horizontalCenter
                    spacing: 0

                    ClockDigitText {
                        width: clockText.hours.length > 1 ? LockMetrics.clockDigitWidth : 0
                        text: clockText.hours.length > 1 ? clockText.hours[0] : ""
                    }
                    ClockDigitText {
                        width: LockMetrics.clockDigitWidth
                        text: clockText.hours.length > 1 ? clockText.hours[1] : clockText.hours.length > 0 ? clockText.hours[0] : ""
                    }
                }

                Row {
                    anchors.horizontalCenter: parent.horizontalCenter
                    spacing: 0

                    ClockDigitText {
                        width: LockMetrics.clockDigitWidth
                        text: clockText.minutes.length > 0 ? clockText.minutes[0] : ""
                    }
                    ClockDigitText {
                        width: LockMetrics.clockDigitWidth
                        text: clockText.minutes.length > 1 ? clockText.minutes[1] : ""
                    }
                }

                StyledText {
                    anchors.horizontalCenter: parent.horizontalCenter
                    text: clockText.hasSeconds ? clockText.seconds + (clockText.ampm !== "" ? " " + clockText.ampm : "") : clockText.ampm
                    font.pixelSize: Theme.fontSizeDisplay
                    font.weight: Theme.fontWeight
                    font.family: root.lockFontFamily !== "" ? root.lockFontFamily : resolvedFontFamily
                    color: Theme.lockScreenContentColor
                    visible: clockText.hasSeconds || clockText.ampm !== ""
                }
            }
        }

        StyledText {
            id: dateText
            anchors.horizontalCenter: parent.horizontalCenter
            anchors.top: clockContainer.bottom
            anchors.topMargin: Theme.spacingXS
            visible: SettingsData.lockScreenShowDate
            text: {
                if (SettingsData.lockDateFormat && SettingsData.lockDateFormat.length > 0) {
                    return systemClock.date.toLocaleDateString(I18n.locale(), SettingsData.lockDateFormat);
                }
                return systemClock.date.toLocaleDateString(I18n.locale(), Locale.LongFormat);
            }
            font.pixelSize: Theme.fontSizeXLarge
            font.family: root.lockFontFamily !== "" ? root.lockFontFamily : resolvedFontFamily
            color: Theme.lockScreenContentColor
            opacity: 1
        }

        Item {
            id: lockNotificationPanel

            readonly property int notificationMode: SettingsData.lockScreenNotificationMode
            readonly property var notifications: NotificationService.groupedNotifications
            readonly property int totalCount: {
                let count = 0;
                for (const group of notifications) {
                    count += group.count || 0;
                }
                return count;
            }
            readonly property bool hasNotifications: totalCount > 0
            readonly property var appNameGroups: {
                const groups = {};
                for (const group of notifications) {
                    const appName = (group.appName || "Unknown").toLowerCase();
                    if (!groups[appName]) {
                        groups[appName] = {
                            appName: group.appName || I18n.tr("Unknown"),
                            count: 0,
                            latestNotification: group.latestNotification
                        };
                    }
                    groups[appName].count += group.count || 0;
                    if (group.latestNotification && (!groups[appName].latestNotification || group.latestNotification.time > groups[appName].latestNotification.time)) {
                        groups[appName].latestNotification = group.latestNotification;
                    }
                }
                return Object.values(groups).sort((a, b) => b.count - a.count);
            }

            anchors.horizontalCenter: parent.horizontalCenter
            anchors.top: capsLockRow.bottom
            anchors.topMargin: Theme.spacingM
            width: Math.min(LockMetrics.notificationCardWidth, parent.width - Theme.spacingXL * 2)
            height: notificationMode === 0 || !hasNotifications ? 0 : contentLoader.height
            visible: notificationMode > 0 && hasNotifications
            clip: true

            Loader {
                id: contentLoader
                anchors.left: parent.left
                anchors.right: parent.right
                active: lockNotificationPanel.notificationMode > 0 && lockNotificationPanel.hasNotifications
                sourceComponent: lockNotificationPanel.notificationMode === 1 ? countOnlyComponent : notificationListComponent
            }

            Component {
                id: countOnlyComponent

                LockNotificationCard {
                    width: parent.width
                    height: Theme.listItemHeight
                    color: Theme.notificationFloatingSurface
                    Accessible.name: countLabel.text

                    Row {
                        anchors.centerIn: parent
                        spacing: Theme.spacingS

                        DankIcon {
                            name: "notifications"
                            size: Theme.iconSize
                            color: Theme.onSurfaceVariant
                            anchors.verticalCenter: parent.verticalCenter
                        }

                        StyledText {
                            id: countLabel
                            text: lockNotificationPanel.totalCount === 1 ? I18n.tr("1 notification") : I18n.tr("%1 notifications").arg(lockNotificationPanel.totalCount)
                            font.pixelSize: Theme.fontSizeMedium
                            color: Theme.onSurface
                            anchors.verticalCenter: parent.verticalCenter
                        }
                    }
                }
            }

            Component {
                id: notificationListComponent

                DankFlickable {
                    width: parent.width
                    height: Math.min(notificationColumn.implicitHeight, LockMetrics.notificationMaxHeight, Math.max(0, root.height - lockNotificationPanel.y - Theme.spacingXL))
                    contentHeight: notificationColumn.implicitHeight
                    clip: true

                    Column {
                        id: notificationColumn
                        width: parent.width
                        spacing: Theme.groupedListGap

                        Repeater {
                            id: notificationRepeater
                            model: lockNotificationPanel.appNameGroups.slice(0, LockMetrics.notificationLimit)

                            Notifications.NotificationCard {
                                required property var modelData
                                required property int index
                                width: notificationColumn.width
                                notificationData: modelData.latestNotification
                                groupCount: modelData.count
                                interactive: false
                                headerOnly: lockNotificationPanel.notificationMode === 2
                                showActions: false
                                showDismiss: false
                                showClose: false
                                showTime: !headerOnly
                                animateHeight: false
                                firstInGroup: index === 0
                                lastInGroup: index === notificationRepeater.count - 1
                            }
                        }

                        StyledText {
                            width: parent.width
                            visible: lockNotificationPanel.appNameGroups.length > LockMetrics.notificationLimit
                            text: I18n.tr("+ %1 more", "lock screen notification list overflow, %1 is a count of hidden apps").arg(lockNotificationPanel.appNameGroups.length - LockMetrics.notificationLimit)
                            font.pixelSize: Theme.fontSizeSmall
                            color: Theme.lockScreenContentColor
                            horizontalAlignment: Text.AlignHCenter
                        }
                    }
                }
            }
        }

        ColumnLayout {
            id: passwordLayout
            anchors.horizontalCenter: parent.horizontalCenter
            anchors.top: dateText.visible ? dateText.bottom : clockContainer.bottom
            anchors.topMargin: Theme.spacingL
            spacing: Theme.spacingM
            width: Math.min(LockMetrics.passwordRowWidth, parent.width - Theme.spacingXL * 2)

            RowLayout {
                LayoutMirroring.enabled: I18n.isRtl
                LayoutMirroring.childrenInherit: true
                spacing: Theme.spacingM
                Layout.fillWidth: true

                DankCircularImage {
                    Layout.preferredWidth: LockMetrics.avatarSize
                    Layout.preferredHeight: LockMetrics.fieldHeight
                    imageSource: {
                        if (PortalService.profileImage === "")
                            return "";
                        if (PortalService.profileImage.startsWith("/"))
                            return encodeFileUrl(PortalService.profileImage);
                        return PortalService.profileImage;
                    }
                    fallbackIcon: "material:person"
                    visible: SettingsData.lockScreenShowProfileImage
                }

                Rectangle {
                    id: passwordBox

                    property bool showPassword: false
                    property real errorOffset: 0
                    transform: Translate {
                        x: Math.max(-LockMetrics.shakeDistance, Math.min(LockMetrics.shakeDistance, passwordBox.errorOffset))
                    }

                    Layout.fillWidth: true
                    Layout.preferredHeight: LockMetrics.fieldHeight
                    radius: Theme.fullRadius(width, height)
                    color: Theme.cardSurface
                    border.width: passwordField.activeFocus ? Math.max(Theme.outlineWidth, Theme.focusRingWidth) : Theme.outlineWidth
                    border.color: passwordField.activeFocus ? Theme.focusRingColor : Theme.outlineVariant
                    Accessible.name: I18n.tr("Password")
                    visible: SettingsData.lockScreenShowPasswordField || root.passwordBuffer.length > 0

                    Item {
                        id: lockIconContainer
                        anchors.left: parent.left
                        anchors.leftMargin: Theme.spacingM
                        anchors.verticalCenter: parent.verticalCenter
                        width: Theme.iconSizeSmall
                        height: Theme.iconSizeSmall

                        DankIcon {
                            id: lockIcon

                            anchors.centerIn: parent
                            name: {
                                if (pam.u2fPending)
                                    return "passkey";
                                if (pam.fprint.tries >= SettingsData.maxFprintTries)
                                    return "fingerprint_off";
                                if (pam.fprint.active || pam.fprint.retrying)
                                    return "fingerprint";
                                if (pam.u2f.active)
                                    return "passkey";
                                return "lock";
                            }
                            size: Theme.iconSizeSmall
                            color: {
                                if (pam.fprint.tries >= SettingsData.maxFprintTries)
                                    return Theme.error;
                                if (pam.u2fState !== "")
                                    return Theme.tertiary;
                                return passwordField.activeFocus ? Theme.primary : Theme.surfaceVariantText;
                            }
                            opacity: pam.passwd.active ? 0 : 1

                            Behavior on opacity {
                                NumberAnimation {
                                    duration: LockMetrics.effectsDuration
                                    easing.type: Easing.BezierSpline
                                    easing.bezierCurve: Theme.expressiveCurves.expressiveEffects
                                }
                            }
                        }
                    }

                    FocusScope {
                        id: passwordField

                        KeyNavigation.tab: virtualKeyboardButton.visible ? virtualKeyboardButton : powerButton
                        KeyNavigation.backtab: powerButton
                        Accessible.role: Accessible.EditableText
                        Accessible.name: I18n.tr("Password")

                        readonly property string text: root.passwordBuffer
                        property int cursorPosition: text.length

                        signal accepted

                        function clampCursorPosition() {
                            cursorPosition = Math.max(0, Math.min(cursorPosition, text.length));
                        }

                        function clear() {
                            root.passwordEdited("");
                            cursorPosition = 0;
                        }

                        function insertText(value) {
                            if (value.length === 0)
                                return;
                            clampCursorPosition();
                            const pos = cursorPosition;
                            root.passwordEdited(text.slice(0, pos) + value + text.slice(pos));
                            cursorPosition = pos + value.length;
                        }

                        function backspace() {
                            clampCursorPosition();
                            if (cursorPosition === 0)
                                return;
                            const pos = cursorPosition;
                            root.passwordEdited(text.slice(0, pos - 1) + text.slice(pos));
                            cursorPosition = pos - 1;
                        }

                        function deleteForward() {
                            clampCursorPosition();
                            if (cursorPosition === text.length)
                                return;
                            const pos = cursorPosition;
                            root.passwordEdited(text.slice(0, pos) + text.slice(pos + 1));
                            cursorPosition = pos;
                        }

                        function deleteToLineStart() {
                            clampCursorPosition();
                            if (cursorPosition === 0)
                                return;
                            root.passwordEdited(text.slice(cursorPosition));
                            cursorPosition = 0;
                        }

                        function deleteToLineEnd() {
                            clampCursorPosition();
                            if (cursorPosition === text.length)
                                return;
                            root.passwordEdited(text.slice(0, cursorPosition));
                        }

                        function deleteWordBackward() {
                            clampCursorPosition();
                            if (cursorPosition === 0)
                                return;
                            let pos = cursorPosition;
                            while (pos > 0 && text.charAt(pos - 1) === " ")
                                pos--;
                            while (pos > 0 && text.charAt(pos - 1) !== " ")
                                pos--;
                            root.passwordEdited(text.slice(0, pos) + text.slice(cursorPosition));
                            cursorPosition = pos;
                        }

                        function isPrintableText(value) {
                            if (value.length === 0)
                                return false;
                            const code = value.charCodeAt(0);
                            return code >= 0x20 && code !== 0x7f;
                        }

                        anchors.fill: parent
                        anchors.leftMargin: lockIconContainer.width + Theme.spacingM * 2
                        anchors.rightMargin: {
                            let margin = Theme.spacingM;
                            if (loadingSpinner.visible) {
                                margin += loadingSpinner.width;
                            }
                            if (enterButton.visible) {
                                margin += enterButton.width + Theme.spacingXXS;
                            }
                            if (securityKeyButton.visible) {
                                margin += securityKeyButton.width;
                            }
                            if (virtualKeyboardButton.visible) {
                                margin += virtualKeyboardButton.width;
                            }
                            if (revealButton.visible) {
                                margin += revealButton.width;
                            }
                            return margin;
                        }
                        opacity: 0
                        focus: true
                        enabled: !demoMode
                        activeFocusOnTab: !demoMode
                        onTextChanged: cursorPosition = text.length
                        onAccepted: {
                            if (!demoMode && !root.unlocking && !pam.passwd.active && !pam.u2fPending) {
                                pam.passwd.start();
                            }
                        }
                        Keys.onPressed: event => handleKey(event)

                        function handleKey(event) {
                            if (demoMode) {
                                return;
                            }

                            if (root.unlocking) {
                                event.accepted = true;
                                return;
                            }

                            if (event.key === Qt.Key_Escape) {
                                if (keyboardController.isKeyboardActive) {
                                    keyboardController.hide();
                                    event.accepted = true;
                                    return;
                                }
                                if (pam.u2fPending) {
                                    pam.cancelU2fPending();
                                    event.accepted = true;
                                    return;
                                }
                                clear();
                                event.accepted = true;
                                return;
                            }

                            if (pam.passwd.active) {
                                log.debug("PAM is active, ignoring input");
                                event.accepted = true;
                                return;
                            }

                            if ((event.modifiers & Qt.ControlModifier) && !(event.modifiers & (Qt.AltModifier | Qt.MetaModifier))) {
                                if (securityKeyShortcutMatches(event) && canStartSecurityKeyUnlock()) {
                                    triggerSecurityKeyUnlock();
                                    event.accepted = true;
                                    return;
                                }

                                switch (event.key) {
                                case Qt.Key_A:
                                    cursorPosition = 0;
                                    event.accepted = true;
                                    return;
                                case Qt.Key_E:
                                    cursorPosition = text.length;
                                    event.accepted = true;
                                    return;
                                case Qt.Key_B:
                                    clampCursorPosition();
                                    cursorPosition = Math.max(0, cursorPosition - 1);
                                    event.accepted = true;
                                    return;
                                case Qt.Key_F:
                                    clampCursorPosition();
                                    cursorPosition = Math.min(text.length, cursorPosition + 1);
                                    event.accepted = true;
                                    return;
                                case Qt.Key_U:
                                    deleteToLineStart();
                                    event.accepted = true;
                                    return;
                                case Qt.Key_K:
                                    deleteToLineEnd();
                                    event.accepted = true;
                                    return;
                                case Qt.Key_W:
                                case Qt.Key_Backspace:
                                    deleteWordBackward();
                                    event.accepted = true;
                                    return;
                                case Qt.Key_H:
                                    backspace();
                                    event.accepted = true;
                                    return;
                                case Qt.Key_D:
                                    deleteForward();
                                    event.accepted = true;
                                    return;
                                }
                            }

                            switch (event.key) {
                            case Qt.Key_Return:
                            case Qt.Key_Enter:
                                accepted();
                                event.accepted = true;
                                return;
                            case Qt.Key_Backspace:
                                backspace();
                                event.accepted = true;
                                return;
                            case Qt.Key_Delete:
                                deleteForward();
                                event.accepted = true;
                                return;
                            case Qt.Key_Left:
                                clampCursorPosition();
                                cursorPosition = Math.max(0, cursorPosition - 1);
                                event.accepted = true;
                                return;
                            case Qt.Key_Right:
                                clampCursorPosition();
                                cursorPosition = Math.min(text.length, cursorPosition + 1);
                                event.accepted = true;
                                return;
                            case Qt.Key_Home:
                                cursorPosition = 0;
                                event.accepted = true;
                                return;
                            case Qt.Key_End:
                                cursorPosition = text.length;
                                event.accepted = true;
                                return;
                            }

                            if (isPrintableText(event.text)) {
                                insertText(event.text);
                                event.accepted = true;
                            }
                        }

                        // IME commits use a hidden password input: https://github.com/AvengeMedia/DankMaterialShell/issues/2950
                        TextInput {
                            id: imeCommitSink

                            focus: true
                            width: Theme.dividerWidth
                            height: 1
                            opacity: 0
                            cursorDelegate: Item {}
                            echoMode: TextInput.Password
                            inputMethodHints: Qt.ImhHiddenText | Qt.ImhSensitiveData | Qt.ImhNoPredictiveText | Qt.ImhNoAutoUppercase
                            KeyNavigation.tab: virtualKeyboardButton.visible ? virtualKeyboardButton : powerButton
                            KeyNavigation.backtab: powerButton
                            Keys.onPressed: event => {
                                passwordField.handleKey(event);
                                if (!event.accepted && (event.modifiers & (Qt.ControlModifier | Qt.AltModifier | Qt.MetaModifier)))
                                    event.accepted = true;
                            }
                            onTextChanged: {
                                if (text.length === 0)
                                    return;
                                const committed = text;
                                text = "";
                                if (demoMode || root.unlocking || pam.passwd.active)
                                    return;
                                passwordField.insertText(committed);
                            }
                        }

                        Component.onCompleted: {
                            if (!demoMode) {
                                forceActiveFocus();
                            }
                        }

                        onVisibleChanged: {
                            if (visible && !demoMode) {
                                forceActiveFocus();
                            }
                        }
                    }

                    KeyboardController {
                        id: keyboardController
                        target: passwordField
                        rootObject: root
                        expressive: true
                    }

                    StyledText {
                        id: placeholder

                        anchors.left: lockIconContainer.right
                        anchors.leftMargin: Theme.spacingM
                        anchors.right: (revealButton.visible ? revealButton.left : (virtualKeyboardButton.visible ? virtualKeyboardButton.left : (securityKeyButton.visible ? securityKeyButton.left : (enterButton.visible ? enterButton.left : (loadingSpinner.visible ? loadingSpinner.left : parent.right)))))
                        anchors.rightMargin: Theme.spacingXXS
                        anchors.verticalCenter: parent.verticalCenter
                        text: {
                            if (demoMode) {
                                return "";
                            }
                            if (root.unlocking) {
                                return I18n.tr("Unlocking...", "lock screen status text while unlocking");
                            }
                            if (pam.u2fPending) {
                                if (pam.u2fState === "insert")
                                    return I18n.tr("Insert your security key...");
                                return I18n.tr("Touch your security key...");
                            }
                            if (pam.passwd.active) {
                                return I18n.tr("Authenticating...", "lock screen status text while the password is checked");
                            }
                            return I18n.tr("Password", "lock screen password field placeholder") + "…";
                        }
                        color: root.unlocking ? Theme.primary : (pam.passwd.active ? Theme.primary : Theme.outline)
                        font.pixelSize: Theme.fontSizeMedium
                        opacity: (demoMode || root.passwordBuffer.length === 0) ? 1 : 0

                        Behavior on opacity {
                            NumberAnimation {
                                duration: LockMetrics.effectsDuration
                                easing.type: Easing.BezierSpline
                                easing.bezierCurve: Theme.expressiveCurves.expressiveEffects
                            }
                        }

                        Behavior on color {
                            ColorAnimation {
                                duration: LockMetrics.effectsDuration
                                easing.type: Easing.BezierSpline
                                easing.bezierCurve: Theme.expressiveCurves.expressiveEffects
                            }
                        }
                    }

                    Item {
                        id: passwordViewport

                        property real scrollX: 0
                        property real scrollY: 0

                        function followCursor() {
                            const rect = passwordDisplay.cursorRectangle;
                            const contentWidth = passwordDisplay.contentWidth + passwordCursor.width;
                            const contentHeight = passwordDisplay.contentHeight;
                            scrollX = followAxis(scrollX, rect.x, rect.x + passwordCursor.width, contentWidth, width);
                            scrollY = contentHeight < height ? (height - contentHeight) / 2 : followAxis(scrollY, rect.y, rect.y + rect.height, contentHeight, height);
                        }

                        function followAxis(offset, start, end, contentSize, viewSize) {
                            if (contentSize <= viewSize)
                                return 0;
                            if (start + offset < 0)
                                return -start;
                            if (end + offset > viewSize)
                                return viewSize - end;
                            return Math.max(viewSize - contentSize, Math.min(0, offset));
                        }

                        anchors.left: lockIconContainer.right
                        anchors.leftMargin: Theme.spacingM
                        anchors.right: (revealButton.visible ? revealButton.left : (virtualKeyboardButton.visible ? virtualKeyboardButton.left : (securityKeyButton.visible ? securityKeyButton.left : (enterButton.visible ? enterButton.left : (loadingSpinner.visible ? loadingSpinner.left : parent.right)))))
                        anchors.rightMargin: Theme.spacingXXS
                        anchors.top: parent.top
                        anchors.bottom: parent.bottom
                        anchors.topMargin: Theme.spacingXS
                        anchors.bottomMargin: Theme.spacingXS
                        clip: true

                        MouseArea {
                            anchors.fill: parent
                            enabled: !root.demoMode
                            onClicked: passwordField.forceActiveFocus()
                        }

                        onWidthChanged: followCursor()
                        onHeightChanged: followCursor()

                        TextEdit {
                            id: passwordDisplay
                            LayoutMirroring.enabled: false

                            x: passwordViewport.scrollX
                            y: passwordViewport.scrollY
                            width: wrapMode === TextEdit.NoWrap ? implicitWidth : passwordViewport.width
                            readOnly: true
                            activeFocusOnPress: false
                            selectByMouse: false
                            wrapMode: passwordBox.showPassword ? TextEdit.Wrap : TextEdit.NoWrap
                            text: {
                                if (demoMode) {
                                    return "••••••••";
                                }
                                if (passwordBox.showPassword) {
                                    return root.passwordBuffer;
                                }
                                return "•".repeat(root.passwordBuffer.length);
                            }
                            color: Theme.surfaceText
                            font.family: Theme.fontFamily
                            font.weight: Theme.fontWeight
                            font.pixelSize: passwordBox.showPassword ? Theme.fontSizeMedium : Theme.fontSizeLarge
                            opacity: (demoMode || root.passwordBuffer.length > 0) ? 1 : 0

                            onTextChanged: cursorPosition = passwordField.cursorPosition
                            onCursorRectangleChanged: passwordViewport.followCursor()
                            onContentWidthChanged: passwordViewport.followCursor()
                            onContentHeightChanged: passwordViewport.followCursor()

                            Behavior on opacity {
                                NumberAnimation {
                                    duration: LockMetrics.effectsDuration
                                    easing.type: Easing.BezierSpline
                                    easing.bezierCurve: Theme.expressiveCurves.expressiveEffects
                                }
                            }
                        }

                        DankTextCursor {
                            id: passwordCursor

                            x: passwordDisplay.x + passwordDisplay.cursorRectangle.x
                            y: passwordDisplay.y + passwordDisplay.cursorRectangle.y
                            height: passwordDisplay.cursorRectangle.height
                            shown: !demoMode && passwordField.activeFocus && !pam.passwd.active && !pam.u2fPending && !root.unlocking

                            readonly property int fieldCursorPosition: passwordField.cursorPosition
                            readonly property string fieldText: passwordField.text

                            onFieldCursorPositionChanged: {
                                passwordDisplay.cursorPosition = fieldCursorPosition;
                                resetBlink();
                            }

                            onFieldTextChanged: resetBlink()
                        }
                    }

                    LockActionButton {
                        id: revealButton

                        activeFocusOnTab: false
                        Accessible.name: parent.showPassword ? I18n.tr("Hide password") : I18n.tr("Show password")

                        anchors.right: virtualKeyboardButton.visible ? virtualKeyboardButton.left : (securityKeyButton.visible ? securityKeyButton.left : (enterButton.visible ? enterButton.left : (loadingSpinner.visible ? loadingSpinner.left : parent.right)))
                        anchors.rightMargin: 0
                        anchors.verticalCenter: parent.verticalCenter
                        iconName: parent.showPassword ? "visibility_off" : "visibility"
                        buttonSize: Theme.buttonHeightXS
                        visible: !demoMode && root.passwordBuffer.length > 0 && !pam.passwd.active && !root.unlocking
                        enabled: visible
                        onClicked: parent.showPassword = !parent.showPassword
                    }
                    LockActionButton {
                        id: securityKeyButton

                        activeFocusOnTab: false

                        anchors.right: enterButton.visible ? enterButton.left : (loadingSpinner.visible ? loadingSpinner.left : parent.right)
                        anchors.rightMargin: 0
                        anchors.verticalCenter: parent.verticalCenter
                        iconName: "passkey"
                        buttonSize: Theme.buttonHeightXS
                        visible: root.canStartSecurityKeyUnlock()
                        enabled: visible
                        tooltipText: SettingsData.lockScreenSecurityKeyShortcutEnabled ? I18n.tr("Security key (%1)", "lock screen security key button tooltip with shortcut").arg(SettingsData.lockScreenSecurityKeyShortcut) : I18n.tr("Security key", "lock screen security key button tooltip")
                        onClicked: root.triggerSecurityKeyUnlock()
                    }
                    LockActionButton {
                        id: virtualKeyboardButton
                        Keys.onEscapePressed: {
                            keyboardController.hide();
                            passwordField.forceActiveFocus();
                        }

                        KeyNavigation.tab: powerButton
                        KeyNavigation.backtab: passwordField
                        Accessible.name: I18n.tr("On-screen keyboard")

                        anchors.right: securityKeyButton.visible ? securityKeyButton.left : (enterButton.visible ? enterButton.left : (loadingSpinner.visible ? loadingSpinner.left : parent.right))
                        anchors.rightMargin: securityKeyButton.visible || enterButton.visible ? 0 : Theme.spacingS
                        anchors.verticalCenter: parent.verticalCenter
                        iconName: "keyboard"
                        buttonSize: Theme.buttonHeightXS
                        visible: !demoMode && !pam.passwd.active && !root.unlocking && !pam.u2fPending
                        enabled: visible
                        onClicked: {
                            if (keyboardController.isKeyboardActive) {
                                keyboardController.hide();
                            } else {
                                keyboardController.show();
                            }
                        }
                    }

                    Rectangle {
                        id: loadingSpinner

                        anchors.right: enterButton.visible ? enterButton.left : parent.right
                        anchors.rightMargin: Theme.spacingM
                        anchors.verticalCenter: parent.verticalCenter
                        width: Theme.iconSize
                        height: Theme.iconSize
                        radius: Theme.fullRadius(width, height)
                        color: "transparent"
                        visible: !demoMode && (pam.passwd.active || root.unlocking)

                        DankIcon {
                            anchors.centerIn: parent
                            name: "check_circle"
                            size: Theme.iconSizeSmall
                            color: Theme.primary
                            visible: root.unlocking

                            opacity: root.unlocking ? 1 : 0
                            Behavior on opacity {
                                NumberAnimation {
                                    duration: LockMetrics.effectsDuration
                                    easing.type: Easing.BezierSpline
                                    easing.bezierCurve: Theme.expressiveCurves.expressiveEffects
                                }
                            }
                        }

                        Item {
                            anchors.fill: parent
                            visible: pam.passwd.active && !root.unlocking

                            Rectangle {
                                width: Theme.iconSizeSmall
                                height: Theme.iconSizeSmall
                                radius: Theme.fullRadius(width, height)
                                anchors.centerIn: parent
                                color: "transparent"
                                border.color: Theme.primarySelected
                                border.width: Theme.outlineWidthFocused
                            }

                            Rectangle {
                                width: Theme.iconSizeSmall
                                height: Theme.iconSizeSmall
                                radius: Theme.fullRadius(width, height)
                                anchors.centerIn: parent
                                color: "transparent"
                                border.color: Theme.primary
                                border.width: Theme.outlineWidthFocused

                                Rectangle {
                                    width: parent.width
                                    height: parent.height / 2
                                    anchors.top: parent.top
                                    anchors.topMargin: -Theme.outlineWidth
                                    anchors.horizontalCenter: parent.horizontalCenter
                                    color: Theme.cardSurface
                                }

                                RotationAnimator on rotation {
                                    running: pam.passwd.active && !root.unlocking
                                    loops: Animation.Infinite
                                    duration: Anims.durLong
                                    from: 0
                                    to: 360
                                }
                            }
                        }
                    }

                    LockActionButton {
                        id: enterButton

                        activeFocusOnTab: false
                        Accessible.name: I18n.tr("Unlock", "verb, lock screen submit button")

                        anchors.right: parent.right
                        anchors.rightMargin: Theme.spacingXXS
                        anchors.verticalCenter: parent.verticalCenter
                        iconName: "keyboard_return"
                        buttonSize: Theme.buttonHeightXS
                        visible: (demoMode || (!pam.passwd.active && !root.unlocking && !pam.u2fPending))
                        enabled: !demoMode
                        onClicked: {
                            if (!demoMode && !root.unlocking && !pam.u2fPending) {
                                pam.passwd.start();
                            }
                        }

                        Behavior on opacity {
                            NumberAnimation {
                                duration: LockMetrics.effectsDuration
                                easing.type: Easing.BezierSpline
                                easing.bezierCurve: Theme.expressiveCurves.expressiveEffects
                            }
                        }
                    }

                    Behavior on border.color {
                        ColorAnimation {
                            duration: LockMetrics.effectsDuration
                            easing.type: Easing.BezierSpline
                            easing.bezierCurve: Theme.expressiveCurves.expressiveEffects
                        }
                    }
                }
            }

            StyledText {
                id: authFeedbackText

                Layout.fillWidth: true
                Layout.preferredHeight: text.length > 0 ? Math.min(implicitHeight, Math.ceil(Theme.fontSizeSmall * 4.5)) : 0
                text: root.currentAuthFeedbackText()
                color: root.authFeedbackIsHint() ? Theme.outline : Theme.error
                font.pixelSize: Theme.fontSizeSmall
                horizontalAlignment: Text.AlignHCenter
                wrapMode: Text.WordWrap
                maximumLineCount: 3
                elide: Text.ElideRight
                opacity: text.length > 0 ? 1 : 0

                Behavior on opacity {
                    NumberAnimation {
                        duration: LockMetrics.effectsDuration
                        easing.type: Easing.BezierSpline
                        easing.bezierCurve: Theme.expressiveCurves.expressiveEffects
                    }
                }
            }
        }

        Row {
            id: capsLockRow
            anchors.top: passwordLayout.bottom
            anchors.topMargin: Theme.spacingS
            anchors.horizontalCenter: passwordLayout.horizontalCenter
            spacing: Theme.spacingXS
            opacity: DMSService.capsLockState ? 1 : 0

            DankIcon {
                name: "shift_lock"
                size: Theme.iconSizeSmall
                color: Theme.error
                anchors.verticalCenter: parent.verticalCenter
            }

            StyledText {
                text: I18n.tr("Caps Lock is on")
                font.pixelSize: Theme.fontSizeSmall
                color: Theme.error
                anchors.verticalCenter: parent.verticalCenter
            }

            Behavior on opacity {
                NumberAnimation {
                    duration: LockMetrics.effectsDuration
                    easing.type: Easing.BezierSpline
                    easing.bezierCurve: Theme.expressiveCurves.expressiveEffects
                }
            }
        }

        StyledText {
            anchors.top: parent.top
            anchors.left: parent.left
            anchors.margins: Theme.spacingXL
            text: I18n.tr("DEMO MODE - Click anywhere to exit")
            font.pixelSize: Theme.fontSizeSmall
            color: Theme.lockScreenContentColor
            opacity: Theme.pendingOpacity
            visible: demoMode
        }

        LockStatusRow {
            anchors.top: parent.top
            anchors.right: parent.right
            anchors.margins: Theme.spacingXL
            visible: SettingsData.lockScreenShowSystemIcons
            interactive: !root.demoMode
            showMediaPlayer: SettingsData.lockScreenShowMediaPlayer
            showWeather: SettingsData.lockScreenShowWeather
            useFahrenheit: SettingsData.useFahrenheit
        }

        LockActionButton {
            id: powerButton
            KeyNavigation.tab: passwordField
            KeyNavigation.backtab: virtualKeyboardButton.visible ? virtualKeyboardButton : passwordField
            Accessible.name: I18n.tr("Power Options")
            anchors.bottom: parent.bottom
            anchors.left: parent.left
            anchors.margins: Theme.spacingXL
            visible: SettingsData.lockScreenShowPowerActions
            iconName: "power_settings_new"
            iconColor: Theme.onSecondaryContainer
            backgroundColor: Theme.secondaryContainer
            radius: pressed ? Theme.cornerRadiusS : Theme.fullRadius(width, height)
            buttonSize: Theme.buttonHeightM
            onClicked: {
                if (demoMode) {
                    log.debug("Demo: Power Menu");
                } else {
                    powerMenu.show();
                }
            }
        }
    }

    Pam {
        id: demoPam
        lockSecured: false
    }

    Connections {
        target: root.pam

        function onUnlockRequested() {
            root.unlocking = true;
            lockerReadyArmed = false;
            passwordField.clear();
            root.unlockRequested();
        }

        function onStateChanged() {
            root.pamState = root.pam.state;
            if (root.pam.state === "")
                return;
            root.unlocking = false;
            errorShake.restart();
            placeholderDelay.restart();
            passwordField.clear();
        }

        function onU2fPendingChanged() {
            if (!root.pam.u2fPending)
                return;
            passwordField.clear();
            if (keyboardController.isKeyboardActive)
                keyboardController.hide();
        }

        function onUnlockInProgressChanged() {
            if (!root.pam.unlockInProgress && root.unlocking)
                root.unlocking = false;
        }
    }

    SequentialAnimation {
        id: errorShake
        NumberAnimation {
            target: passwordBox
            property: "errorOffset"
            to: LockMetrics.shakeDistance
            duration: LockMetrics.shakeDuration / 3
            easing.type: Easing.BezierSpline
            easing.bezierCurve: Theme.expressiveCurves.expressiveFastSpatial
        }
        NumberAnimation {
            target: passwordBox
            property: "errorOffset"
            to: -LockMetrics.shakeDistance
            duration: LockMetrics.shakeDuration / 3
            easing.type: Easing.BezierSpline
            easing.bezierCurve: Theme.expressiveCurves.expressiveFastSpatial
        }
        NumberAnimation {
            target: passwordBox
            property: "errorOffset"
            to: 0
            duration: LockMetrics.shakeDuration / 3
            easing.type: Easing.BezierSpline
            easing.bezierCurve: Theme.expressiveCurves.expressiveFastSpatial
        }
    }

    Timer {
        id: placeholderDelay

        interval: 4000
        onTriggered: root.pamState = ""
    }

    MouseArea {
        anchors.fill: parent
        enabled: demoMode
        onClicked: root.unlockRequested()
    }

    LockPowerMenu {
        id: powerMenu
        expressive: true
        showLogout: true
        onClosed: {
            if (!demoMode && passwordField && passwordField.forceActiveFocus) {
                Qt.callLater(() => passwordField.forceActiveFocus());
            }
        }
        onSwitchUserRequested: {
            switchUserPicker.showFromLockScreen();
        }
    }

    SwitchUserModal {
        id: switchUserPicker
    }
}
