pragma ComponentBehavior: Bound

import QtCore
import QtQuick
import QtQuick.Effects
import QtQuick.Layouts
import Quickshell
import Quickshell.Io
import Quickshell.Services.Pam
import Quickshell.Services.Mpris
import qs.Common
import qs.Services
import qs.Widgets

Item {
    id: root

    property string passwordBuffer: ""
    property bool demoMode: false
    property string screenName: ""
    property bool unlocking: false
    property string pamState: ""
    property string randomFact: ""
    property string hyprlandCurrentLayout: ""
    property string hyprlandKeyboard: ""
    property int hyprlandLayoutCount: 0

    signal unlockRequested

    function pickRandomFact() {
        randomFact = Facts.getRandomFact()
    }

    Component.onCompleted: {
        if (demoMode) {
            pickRandomFact()
        }

        WeatherService.addRef()
        UserInfoService.refreshUserInfo()

        if (CompositorService.isHyprland) {
            updateHyprlandLayout()
            hyprlandLayoutUpdateTimer.start()
        }

        if (SessionService.loginctlAvailable && DMSService.apiVersion >= 2) {
            DMSService.sendRequest("loginctl.lockerReady", null, response => {
                if (response.error) {
                    console.warn("LockScreenContent: Failed to signal locker ready:", response.error)
                } else {
                    console.log("LockScreenContent: Locker ready signaled, inhibitor released")
                }
            })
        }
    }
    onDemoModeChanged: {
        if (demoMode) {
            pickRandomFact()
        }
    }
    Component.onDestruction: {
        WeatherService.removeRef()
        if (CompositorService.isHyprland) {
            hyprlandLayoutUpdateTimer.stop()
        }
    }

    function updateHyprlandLayout() {
        if (CompositorService.isHyprland) {
            hyprlandLayoutProcess.running = true
        }
    }

    Process {
        id: hyprlandLayoutProcess
        running: false
        command: ["hyprctl", "-j", "devices"]
        stdout: StdioCollector {
            onStreamFinished: {
                try {
                    const data = JSON.parse(text)
                    const mainKeyboard = data.keyboards.find(kb => kb.main === true)
                    hyprlandKeyboard = mainKeyboard.name
                    if (mainKeyboard && mainKeyboard.active_keymap) {
                        const parts = mainKeyboard.active_keymap.split(" ")
                        if (parts.length > 0) {
                            hyprlandCurrentLayout = parts[0].substring(0, 2).toUpperCase()
                        } else {
                            hyprlandCurrentLayout = mainKeyboard.active_keymap.substring(0, 2).toUpperCase()
                        }
                    } else {
                        hyprlandCurrentLayout = ""
                    }
                    if (mainKeyboard && mainKeyboard.layout_names) {
                        hyprlandLayoutCount = mainKeyboard.layout_names.length
                    } else {
                        hyprlandLayoutCount = 0
                    }
                } catch (e) {
                    hyprlandCurrentLayout = ""
                    hyprlandLayoutCount = 0
                }
            }
        }
    }

    Timer {
        id: hyprlandLayoutUpdateTimer
        interval: 1000
        running: false
        repeat: true
        onTriggered: updateHyprlandLayout()
    }

    Loader {
        anchors.fill: parent
        active: {
            var currentWallpaper = SessionData.getMonitorWallpaper(screenName)
            return !currentWallpaper || (currentWallpaper && currentWallpaper.startsWith("#"))
        }
        asynchronous: true

        sourceComponent: DankBackdrop {
            screenName: root.screenName
        }
    }

    Image {
        id: wallpaperBackground

        anchors.fill: parent
        source: {
            var currentWallpaper = SessionData.getMonitorWallpaper(screenName)
            if (screenName && currentWallpaper && currentWallpaper.startsWith("we:")) {
                const cacheHome = StandardPaths.writableLocation(StandardPaths.CacheLocation).toString()
                const baseDir = Paths.strip(cacheHome)
                const screenshotPath = baseDir + "/dankshell/we_screenshots" + "/" + currentWallpaper.substring(3) + ".jpg"
                return screenshotPath
            }
            return (currentWallpaper && !currentWallpaper.startsWith("#")) ? currentWallpaper : ""
        }
        fillMode: Image.PreserveAspectCrop
        smooth: true
        asynchronous: false
        cache: true
        visible: source !== ""
        layer.enabled: true

        layer.effect: MultiEffect {
            autoPaddingEnabled: false
            blurEnabled: true
            blur: 0.8
            blurMax: 32
            blurMultiplier: 1
        }

        Behavior on opacity {
            NumberAnimation {
                duration: Theme.mediumDuration
                easing.type: Theme.standardEasing
            }
        }
    }

    Rectangle {
        anchors.fill: parent
        color: "black"
        opacity: 0.4
    }

    SystemClock {
        id: systemClock

        precision: SystemClock.Minutes
    }

    Rectangle {
        anchors.fill: parent
        color: "transparent"

        Item {
            anchors.centerIn: parent
            anchors.verticalCenterOffset: -100
            width: 400
            height: 140

            StyledText {
                id: clockText

                anchors.horizontalCenter: parent.horizontalCenter
                anchors.top: parent.top
                text: {
                    const format = SettingsData.use24HourClock ? "HH:mm" : "h:mm AP"
                    return systemClock.date.toLocaleTimeString(Qt.locale(), format)
                }
                font.pixelSize: 120
                font.weight: Font.Light
                color: "white"
                lineHeight: 0.8
            }

            StyledText {
                anchors.horizontalCenter: parent.horizontalCenter
                anchors.top: clockText.bottom
                anchors.topMargin: -20
                text: {
                    if (SettingsData.lockDateFormat && SettingsData.lockDateFormat.length > 0) {
                        return systemClock.date.toLocaleDateString(Qt.locale(), SettingsData.lockDateFormat)
                    }
                    return systemClock.date.toLocaleDateString(Qt.locale(), Locale.LongFormat)
                }
                font.pixelSize: Theme.fontSizeXLarge
                color: "white"
                opacity: 0.9
            }
        }

        ColumnLayout {
            anchors.centerIn: parent
            anchors.verticalCenterOffset: 50
            spacing: Theme.spacingM
            width: 380

            RowLayout {
                spacing: Theme.spacingL
                Layout.fillWidth: true

                DankCircularImage {
                    Layout.preferredWidth: 60
                    Layout.preferredHeight: 60
                    imageSource: {
                        if (PortalService.profileImage === "") {
                            return ""
                        }

                        if (PortalService.profileImage.startsWith("/")) {
                            return "file://" + PortalService.profileImage
                        }

                        return PortalService.profileImage
                    }
                    fallbackIcon: "person"
                }

                Rectangle {
                    property bool showPassword: false

                    Layout.fillWidth: true
                    Layout.preferredHeight: 60
                    radius: Theme.cornerRadius
                    color: Qt.rgba(Theme.surfaceContainer.r, Theme.surfaceContainer.g, Theme.surfaceContainer.b, 0.9)
                    border.color: passwordField.activeFocus ? Theme.primary : Qt.rgba(1, 1, 1, 0.3)
                    border.width: passwordField.activeFocus ? 2 : 1

                    DankIcon {
                        id: lockIcon

                        anchors.left: parent.left
                        anchors.leftMargin: Theme.spacingM
                        anchors.verticalCenter: parent.verticalCenter
                        name: "lock"
                        size: 20
                        color: passwordField.activeFocus ? Theme.primary : Theme.surfaceVariantText
                    }

                    TextInput {
                        id: passwordField

                        anchors.fill: parent
                        anchors.leftMargin: lockIcon.width + Theme.spacingM * 2
                        anchors.rightMargin: {
                            let margin = Theme.spacingM
                            if (loadingSpinner.visible) {
                                margin += loadingSpinner.width
                            }
                            if (enterButton.visible) {
                                margin += enterButton.width + 2
                            }
                            if (virtualKeyboardButton.visible) {
                                margin += virtualKeyboardButton.width
                            }
                            if (revealButton.visible) {
                                margin += revealButton.width
                            }
                            return margin
                        }
                        opacity: 0
                        focus: true
                        enabled: !demoMode
                        activeFocusOnTab: !demoMode
                        echoMode: parent.showPassword ? TextInput.Normal : TextInput.Password
                        onTextChanged: {
                            if (!demoMode) {
                                root.passwordBuffer = text
                            }
                        }
                        onAccepted: {
                            if (!demoMode && !pam.active) {
                                console.log("Enter pressed, starting PAM authentication")
                                pam.start()
                            }
                        }
                        Keys.onPressed: event => {
                                            if (demoMode) {
                                                return
                                            }

                                            if (pam.active) {
                                                console.log("PAM is active, ignoring input")
                                                event.accepted = true
                                                return
                                            }
                                        }

                        Component.onCompleted: {
                            if (!demoMode) {
                                forceActiveFocus()
                            }
                        }

                        onVisibleChanged: {
                            if (visible && !demoMode) {
                                forceActiveFocus()
                            }
                        }

                        onActiveFocusChanged: {
                            if (!activeFocus && !demoMode && visible && passwordField && !powerMenu.isVisible) {
                                Qt.callLater(() => {
                                    if (passwordField && passwordField.forceActiveFocus) {
                                        passwordField.forceActiveFocus()
                                    }
                                })
                            }
                        }

                        onEnabledChanged: {
                            if (enabled && !demoMode && visible && passwordField && !powerMenu.isVisible) {
                                Qt.callLater(() => {
                                    if (passwordField && passwordField.forceActiveFocus) {
                                        passwordField.forceActiveFocus()
                                    }
                                })
                            }
                        }
                    }

                    KeyboardController {
                        id: keyboardController
                        target: passwordField
                        rootObject: root
                    }

                    StyledText {
                        id: placeholder

                        anchors.left: lockIcon.right
                        anchors.leftMargin: Theme.spacingM
                        anchors.right: (revealButton.visible ? revealButton.left : (virtualKeyboardButton.visible ? virtualKeyboardButton.left : (enterButton.visible ? enterButton.left : (loadingSpinner.visible ? loadingSpinner.left : parent.right))))
                        anchors.rightMargin: 2
                        anchors.verticalCenter: parent.verticalCenter
                        text: {
                            if (demoMode) {
                                return ""
                            }
                            if (root.unlocking) {
                                return "Unlocking..."
                            }
                            if (pam.active) {
                                return "Authenticating..."
                            }
                            return "Password..."
                        }
                        color: root.unlocking ? Theme.primary : (pam.active ? Theme.primary : Theme.outline)
                        font.pixelSize: Theme.fontSizeMedium
                        opacity: (demoMode || root.passwordBuffer.length === 0) ? 1 : 0

                        Behavior on opacity {
                            NumberAnimation {
                                duration: Theme.mediumDuration
                                easing.type: Theme.standardEasing
                            }
                        }

                        Behavior on color {
                            ColorAnimation {
                                duration: Theme.shortDuration
                                easing.type: Theme.standardEasing
                            }
                        }
                    }

                    StyledText {
                        anchors.left: lockIcon.right
                        anchors.leftMargin: Theme.spacingM
                        anchors.right: (revealButton.visible ? revealButton.left : (virtualKeyboardButton.visible ? virtualKeyboardButton.left : (enterButton.visible ? enterButton.left : (loadingSpinner.visible ? loadingSpinner.left : parent.right))))
                        anchors.rightMargin: 2
                        anchors.verticalCenter: parent.verticalCenter
                        text: {
                            if (demoMode) {
                                return "••••••••"
                            }
                            if (parent.showPassword) {
                                return root.passwordBuffer
                            }
                            return "•".repeat(Math.min(root.passwordBuffer.length, 25))
                        }
                        color: Theme.surfaceText
                        font.pixelSize: parent.showPassword ? Theme.fontSizeMedium : Theme.fontSizeLarge
                        opacity: (demoMode || root.passwordBuffer.length > 0) ? 1 : 0
                        elide: Text.ElideRight

                        Behavior on opacity {
                            NumberAnimation {
                                duration: Theme.mediumDuration
                                easing.type: Theme.standardEasing
                            }
                        }
                    }

                    DankActionButton {
                        id: revealButton

                        anchors.right: virtualKeyboardButton.visible ? virtualKeyboardButton.left : (enterButton.visible ? enterButton.left : (loadingSpinner.visible ? loadingSpinner.left : parent.right))
                        anchors.rightMargin: 0
                        anchors.verticalCenter: parent.verticalCenter
                        iconName: parent.showPassword ? "visibility_off" : "visibility"
                        buttonSize: 32
                        visible: !demoMode && root.passwordBuffer.length > 0 && !pam.active && !root.unlocking
                        enabled: visible
                        onClicked: parent.showPassword = !parent.showPassword
                    }
                    DankActionButton {
                        id: virtualKeyboardButton

                        anchors.right: enterButton.visible ? enterButton.left : (loadingSpinner.visible ? loadingSpinner.left : parent.right)
                        anchors.rightMargin: enterButton.visible ? 0 : Theme.spacingS
                        anchors.verticalCenter: parent.verticalCenter
                        iconName: "keyboard"
                        buttonSize: 32
                        visible: !demoMode && !pam.active && !root.unlocking
                        enabled: visible
                        onClicked: {
                            if (keyboardController.isKeyboardActive) {
                                keyboardController.hide()
                            } else {
                                keyboardController.show()
                            }
                        }
                    }

                    Rectangle {
                        id: loadingSpinner

                        anchors.right: enterButton.visible ? enterButton.left : parent.right
                        anchors.rightMargin: Theme.spacingM
                        anchors.verticalCenter: parent.verticalCenter
                        width: 24
                        height: 24
                        radius: 12
                        color: "transparent"
                        visible: !demoMode && (pam.active || root.unlocking)

                        DankIcon {
                            anchors.centerIn: parent
                            name: "check_circle"
                            size: 20
                            color: Theme.primary
                            visible: root.unlocking

                            SequentialAnimation on scale {
                                running: root.unlocking

                                NumberAnimation {
                                    from: 0
                                    to: 1.2
                                    duration: Anims.durShort
                                    easing.type: Easing.BezierSpline
                                    easing.bezierCurve: Anims.emphasizedDecel
                                }

                                NumberAnimation {
                                    from: 1.2
                                    to: 1
                                    duration: Anims.durShort
                                    easing.type: Easing.BezierSpline
                                    easing.bezierCurve: Anims.emphasizedAccel
                                }
                            }
                        }

                        Item {
                            anchors.fill: parent
                            visible: pam.active && !root.unlocking

                            Rectangle {
                                width: 20
                                height: 20
                                radius: 10
                                anchors.centerIn: parent
                                color: "transparent"
                                border.color: Qt.rgba(Theme.primary.r, Theme.primary.g, Theme.primary.b, 0.3)
                                border.width: 2
                            }

                            Rectangle {
                                width: 20
                                height: 20
                                radius: 10
                                anchors.centerIn: parent
                                color: "transparent"
                                border.color: Theme.primary
                                border.width: 2

                                Rectangle {
                                    width: parent.width
                                    height: parent.height / 2
                                    anchors.top: parent.top
                                    anchors.horizontalCenter: parent.horizontalCenter
                                    color: Qt.rgba(Theme.surfaceContainer.r, Theme.surfaceContainer.g, Theme.surfaceContainer.b, 0.9)
                                }

                                RotationAnimation on rotation {
                                    running: pam.active && !root.unlocking
                                    loops: Animation.Infinite
                                    duration: Anims.durLong
                                    from: 0
                                    to: 360
                                }
                            }
                        }
                    }

                    DankActionButton {
                        id: enterButton

                        anchors.right: parent.right
                        anchors.rightMargin: 2
                        anchors.verticalCenter: parent.verticalCenter
                        iconName: "keyboard_return"
                        buttonSize: 36
                        visible: (demoMode || (!pam.active && !root.unlocking))
                        enabled: !demoMode
                        onClicked: {
                            if (!demoMode) {
                                console.log("Enter button clicked, starting PAM authentication")
                                pam.start()
                            }
                        }

                        Behavior on opacity {
                            NumberAnimation {
                                duration: Theme.shortDuration
                                easing.type: Theme.standardEasing
                            }
                        }
                    }

                    Behavior on border.color {
                        ColorAnimation {
                            duration: Theme.shortDuration
                            easing.type: Theme.standardEasing
                        }
                    }
                }
            }

            StyledText {
                Layout.fillWidth: true
                Layout.preferredHeight: 20
                text: {
                    if (root.pamState === "error") {
                        return "Authentication error - try again"
                    }
                    if (root.pamState === "max") {
                        return "Too many attempts - locked out"
                    }
                    if (root.pamState === "fail") {
                        return "Incorrect password - try again"
                    }
                    return ""
                }
                color: Theme.error
                font.pixelSize: Theme.fontSizeSmall
                horizontalAlignment: Text.AlignHCenter
                opacity: root.pamState !== "" ? 1 : 0

                Behavior on opacity {
                    NumberAnimation {
                        duration: Theme.shortDuration
                        easing.type: Theme.standardEasing
                    }
                }
            }
        }

        StyledText {
            anchors.top: parent.top
            anchors.left: parent.left
            anchors.margins: Theme.spacingXL
            text: I18n.tr("DEMO MODE - Click anywhere to exit")
            font.pixelSize: Theme.fontSizeSmall
            color: "white"
            opacity: 0.7
            visible: demoMode
        }

        Row {
            anchors.top: parent.top
            anchors.right: parent.right
            anchors.margins: Theme.spacingXL
            spacing: Theme.spacingL

            Item {
                width: keyboardLayoutRow.width
                height: keyboardLayoutRow.height
                anchors.verticalCenter: parent.verticalCenter
                visible: {
                    if (CompositorService.isNiri) {
                        return NiriService.keyboardLayoutNames.length > 1
                    } else if (CompositorService.isHyprland) {
                        return hyprlandLayoutCount > 1
                    }
                    return false
                }

                Row {
                    id: keyboardLayoutRow
                    spacing: 4

                    Item {
                        width: Theme.iconSize
                        height: Theme.iconSize

                        DankIcon {
                            name: "keyboard"
                            size: Theme.iconSize
                            color: "white"
                            anchors.centerIn: parent
                        }
                    }

                    Item {
                        width: childrenRect.width
                        height: Theme.iconSize

                        StyledText {
                            text: {
                                if (CompositorService.isNiri) {
                                    const layout = NiriService.getCurrentKeyboardLayoutName()
                                    if (!layout) return ""
                                    const parts = layout.split(" ")
                                    if (parts.length > 0) {
                                        return parts[0].substring(0, 2).toUpperCase()
                                    }
                                    return layout.substring(0, 2).toUpperCase()
                                } else if (CompositorService.isHyprland) {
                                    return hyprlandCurrentLayout
                                }
                                return ""
                            }
                            font.pixelSize: Theme.fontSizeMedium
                            font.weight: Font.Light
                            color: "white"
                            anchors.verticalCenter: parent.verticalCenter
                        }
                    }
                }

                MouseArea {
                    id: keyboardLayoutArea
                    anchors.fill: parent
                    enabled: !demoMode
                    hoverEnabled: enabled
                    cursorShape: enabled ? Qt.PointingHandCursor : Qt.ArrowCursor
                    onClicked: {
                        if (CompositorService.isNiri) {
                            NiriService.cycleKeyboardLayout()
                        } else if (CompositorService.isHyprland) {
                            Quickshell.execDetached([
                                "hyprctl",
                                "switchxkblayout",
                                hyprlandKeyboard,
                                "next"
                            ])
                            updateHyprlandLayout()
                        }
                    }
                }
            }

            Rectangle {
                width: 1
                height: 24
                color: Qt.rgba(255, 255, 255, 0.2)
                anchors.verticalCenter: parent.verticalCenter
                visible: MprisController.activePlayer
            }

            Row {
                spacing: Theme.spacingS
                visible: MprisController.activePlayer
                anchors.verticalCenter: parent.verticalCenter

                Item {
                    width: 20
                    height: Theme.iconSize
                    anchors.verticalCenter: parent.verticalCenter

                    Loader {
                        active: MprisController.activePlayer?.playbackState === MprisPlaybackState.Playing

                        sourceComponent: Component {
                            Ref {
                                service: CavaService
                            }
                        }
                    }

                    Timer {
                        running: !CavaService.cavaAvailable && MprisController.activePlayer?.playbackState === MprisPlaybackState.Playing
                        interval: 256
                        repeat: true
                        onTriggered: {
                            CavaService.values = [Math.random() * 40 + 10, Math.random() * 60 + 20, Math.random() * 50 + 15, Math.random() * 35 + 20, Math.random() * 45 + 15, Math.random() * 55 + 25]
                        }
                    }

                    Row {
                        anchors.centerIn: parent
                        spacing: 1.5

                        Repeater {
                            model: 6

                            Rectangle {
                                width: 2
                                height: {
                                    if (MprisController.activePlayer?.playbackState === MprisPlaybackState.Playing && CavaService.values.length > index) {
                                        const rawLevel = CavaService.values[index] || 0
                                        const scaledLevel = Math.sqrt(Math.min(Math.max(rawLevel, 0), 100) / 100) * 100
                                        const maxHeight = Theme.iconSize - 2
                                        const minHeight = 3
                                        return minHeight + (scaledLevel / 100) * (maxHeight - minHeight)
                                    }
                                    return 3
                                }
                                radius: 1.5
                                color: "white"
                                anchors.verticalCenter: parent.verticalCenter

                                Behavior on height {
                                    NumberAnimation {
                                        duration: Anims.durShort
                                        easing.type: Easing.BezierSpline
                                        easing.bezierCurve: Anims.standardDecel
                                    }
                                }
                            }
                        }
                    }
                }

                StyledText {
                    text: {
                        const player = MprisController.activePlayer
                        if (!player?.trackTitle) return ""
                        const title = player.trackTitle
                        const artist = player.trackArtist || ""
                        return artist ? title + " • " + artist : title
                    }
                    font.pixelSize: Theme.fontSizeLarge
                    color: "white"
                    opacity: 0.9
                    anchors.verticalCenter: parent.verticalCenter
                    elide: Text.ElideRight
                    width: Math.min(implicitWidth, 400)
                    wrapMode: Text.NoWrap
                    maximumLineCount: 1
                }

                Row {
                    spacing: Theme.spacingXS
                    anchors.verticalCenter: parent.verticalCenter

                    Rectangle {
                        width: 20
                        height: 20
                        radius: 10
                        anchors.verticalCenter: parent.verticalCenter
                        color: prevArea.containsMouse ? Qt.rgba(255, 255, 255, 0.2) : "transparent"
                        visible: MprisController.activePlayer
                        opacity: (MprisController.activePlayer?.canGoPrevious ?? false) ? 1 : 0.3

                        DankIcon {
                            anchors.centerIn: parent
                            name: "skip_previous"
                            size: 12
                            color: "white"
                        }

                        MouseArea {
                            id: prevArea
                            anchors.fill: parent
                            enabled: MprisController.activePlayer?.canGoPrevious ?? false
                            hoverEnabled: enabled
                            cursorShape: enabled ? Qt.PointingHandCursor : Qt.ArrowCursor
                            onClicked: MprisController.activePlayer?.previous()
                        }
                    }

                    Rectangle {
                        width: 24
                        height: 24
                        radius: 12
                        anchors.verticalCenter: parent.verticalCenter
                        color: MprisController.activePlayer?.playbackState === MprisPlaybackState.Playing ? Qt.rgba(255, 255, 255, 0.9) : Qt.rgba(255, 255, 255, 0.2)
                        visible: MprisController.activePlayer

                        DankIcon {
                            anchors.centerIn: parent
                            name: MprisController.activePlayer?.playbackState === MprisPlaybackState.Playing ? "pause" : "play_arrow"
                            size: 14
                            color: MprisController.activePlayer?.playbackState === MprisPlaybackState.Playing ? "black" : "white"
                        }

                        MouseArea {
                            anchors.fill: parent
                            enabled: MprisController.activePlayer
                            hoverEnabled: enabled
                            cursorShape: enabled ? Qt.PointingHandCursor : Qt.ArrowCursor
                            onClicked: MprisController.activePlayer?.togglePlaying()
                        }
                    }

                    Rectangle {
                        width: 20
                        height: 20
                        radius: 10
                        anchors.verticalCenter: parent.verticalCenter
                        color: nextArea.containsMouse ? Qt.rgba(255, 255, 255, 0.2) : "transparent"
                        visible: MprisController.activePlayer
                        opacity: (MprisController.activePlayer?.canGoNext ?? false) ? 1 : 0.3

                        DankIcon {
                            anchors.centerIn: parent
                            name: "skip_next"
                            size: 12
                            color: "white"
                        }

                        MouseArea {
                            id: nextArea
                            anchors.fill: parent
                            enabled: MprisController.activePlayer?.canGoNext ?? false
                            hoverEnabled: enabled
                            cursorShape: enabled ? Qt.PointingHandCursor : Qt.ArrowCursor
                            onClicked: MprisController.activePlayer?.next()
                        }
                    }
                }
            }

            Rectangle {
                width: 1
                height: 24
                color: Qt.rgba(255, 255, 255, 0.2)
                anchors.verticalCenter: parent.verticalCenter
                visible: MprisController.activePlayer && WeatherService.weather.available
            }

            Row {
                spacing: 6
                visible: WeatherService.weather.available
                anchors.verticalCenter: parent.verticalCenter

                DankIcon {
                    name: WeatherService.getWeatherIcon(WeatherService.weather.wCode)
                    size: Theme.iconSize
                    color: "white"
                    anchors.verticalCenter: parent.verticalCenter
                }

                StyledText {
                    text: (SettingsData.useFahrenheit ? WeatherService.weather.tempF : WeatherService.weather.temp) + "°"
                    font.pixelSize: Theme.fontSizeLarge
                    font.weight: Font.Light
                    color: "white"
                    anchors.verticalCenter: parent.verticalCenter
                }
            }

            Rectangle {
                width: 1
                height: 24
                color: Qt.rgba(255, 255, 255, 0.2)
                anchors.verticalCenter: parent.verticalCenter
                visible: WeatherService.weather.available && (NetworkService.networkStatus !== "disconnected" || BluetoothService.enabled || (AudioService.sink && AudioService.sink.audio) || BatteryService.batteryAvailable)
            }

            Row {
                spacing: Theme.spacingM
                anchors.verticalCenter: parent.verticalCenter
                visible: NetworkService.networkStatus !== "disconnected" || (BluetoothService.available && BluetoothService.enabled) || (AudioService.sink && AudioService.sink.audio)

                DankIcon {
                    name: NetworkService.networkStatus === "ethernet" ? "lan" : NetworkService.wifiSignalIcon
                    size: Theme.iconSize - 2
                    color: NetworkService.networkStatus !== "disconnected" ? "white" : Qt.rgba(255, 255, 255, 0.5)
                    anchors.verticalCenter: parent.verticalCenter
                    visible: NetworkService.networkStatus !== "disconnected"
                }

                DankIcon {
                    name: "bluetooth"
                    size: Theme.iconSize - 2
                    color: "white"
                    anchors.verticalCenter: parent.verticalCenter
                    visible: BluetoothService.available && BluetoothService.enabled
                }

                DankIcon {
                    name: {
                        if (!AudioService.sink?.audio) {
                            return "volume_up"
                        }
                        if (AudioService.sink.audio.muted || AudioService.sink.audio.volume === 0) {
                            return "volume_off"
                        }
                        if (AudioService.sink.audio.volume * 100 < 33) {
                            return "volume_down"
                        }
                        return "volume_up"
                    }
                    size: Theme.iconSize - 2
                    color: (AudioService.sink && AudioService.sink.audio && (AudioService.sink.audio.muted || AudioService.sink.audio.volume === 0)) ? Qt.rgba(255, 255, 255, 0.5) : "white"
                    anchors.verticalCenter: parent.verticalCenter
                    visible: AudioService.sink && AudioService.sink.audio
                }
            }

            Rectangle {
                width: 1
                height: 24
                color: Qt.rgba(255, 255, 255, 0.2)
                anchors.verticalCenter: parent.verticalCenter
                visible: BatteryService.batteryAvailable && (NetworkService.networkStatus !== "disconnected" || BluetoothService.enabled || (AudioService.sink && AudioService.sink.audio))
            }

            Row {
                spacing: 4
                visible: BatteryService.batteryAvailable
                anchors.verticalCenter: parent.verticalCenter

                DankIcon {
                    name: {
                        if (BatteryService.isCharging) {
                            if (BatteryService.batteryLevel >= 90) {
                                return "battery_charging_full"
                            }

                            if (BatteryService.batteryLevel >= 80) {
                                return "battery_charging_90"
                            }

                            if (BatteryService.batteryLevel >= 60) {
                                return "battery_charging_80"
                            }

                            if (BatteryService.batteryLevel >= 50) {
                                return "battery_charging_60"
                            }

                            if (BatteryService.batteryLevel >= 30) {
                                return "battery_charging_50"
                            }

                            if (BatteryService.batteryLevel >= 20) {
                                return "battery_charging_30"
                            }

                            return "battery_charging_20"
                        }
                        if (BatteryService.isPluggedIn) {
                            if (BatteryService.batteryLevel >= 90) {
                                return "battery_charging_full"
                            }

                            if (BatteryService.batteryLevel >= 80) {
                                return "battery_charging_90"
                            }

                            if (BatteryService.batteryLevel >= 60) {
                                return "battery_charging_80"
                            }

                            if (BatteryService.batteryLevel >= 50) {
                                return "battery_charging_60"
                            }

                            if (BatteryService.batteryLevel >= 30) {
                                return "battery_charging_50"
                            }

                            if (BatteryService.batteryLevel >= 20) {
                                return "battery_charging_30"
                            }

                            return "battery_charging_20"
                        }
                        if (BatteryService.batteryLevel >= 95) {
                            return "battery_full"
                        }

                        if (BatteryService.batteryLevel >= 85) {
                            return "battery_6_bar"
                        }

                        if (BatteryService.batteryLevel >= 70) {
                            return "battery_5_bar"
                        }

                        if (BatteryService.batteryLevel >= 55) {
                            return "battery_4_bar"
                        }

                        if (BatteryService.batteryLevel >= 40) {
                            return "battery_3_bar"
                        }

                        if (BatteryService.batteryLevel >= 25) {
                            return "battery_2_bar"
                        }

                        return "battery_1_bar"
                    }
                    size: Theme.iconSize
                    color: {
                        if (BatteryService.isLowBattery && !BatteryService.isCharging) {
                            return Theme.error
                        }

                        if (BatteryService.isCharging || BatteryService.isPluggedIn) {
                            return Theme.primary
                        }

                        return "white"
                    }
                    anchors.verticalCenter: parent.verticalCenter
                }

                StyledText {
                    text: BatteryService.batteryLevel + "%"
                    font.pixelSize: Theme.fontSizeLarge
                    font.weight: Font.Light
                    color: "white"
                    anchors.verticalCenter: parent.verticalCenter
                }
            }
        }

        DankActionButton {
            anchors.bottom: parent.bottom
            anchors.left: parent.left
            anchors.margins: Theme.spacingXL
            visible: SettingsData.lockScreenShowPowerActions
            iconName: "power_settings_new"
            iconColor: Theme.error
            buttonSize: 40
            onClicked: {
                if (demoMode) {
                    console.log("Demo: Power Menu")
                } else {
                    powerMenu.show()
                }
            }
        }

        StyledText {
            anchors.bottom: parent.bottom
            anchors.horizontalCenter: parent.horizontalCenter
            anchors.margins: Theme.spacingL
            width: Math.min(parent.width - Theme.spacingXL * 2, implicitWidth)
            text: root.randomFact
            font.pixelSize: Theme.fontSizeSmall
            color: "white"
            opacity: 0.8
            horizontalAlignment: Text.AlignHCenter
            wrapMode: Text.NoWrap
            visible: root.randomFact !== ""
        }
    }

    FileView {
        id: pamConfigWatcher

        path: "/etc/pam.d/dankshell"
        printErrors: false
    }

    PamContext {
        id: pam

        config: pamConfigWatcher.loaded ? "dankshell" : "login"
        onResponseRequiredChanged: {
            if (demoMode)
                return

            console.log("PAM response required:", responseRequired)
            if (!responseRequired)
                return

            console.log("Responding to PAM with password buffer length:", root.passwordBuffer.length)
            respond(root.passwordBuffer)
        }
        onCompleted: res => {
                         if (demoMode)
                         return

                         console.log("PAM authentication completed with result:", res)
                         if (res === PamResult.Success) {
                             console.log("Authentication successful, unlocking")
                             root.unlocking = true
                             passwordField.text = ""
                             root.passwordBuffer = ""
                             root.unlockRequested()
                             return
                         }
                         console.log("Authentication failed:", res)
                         passwordField.text = ""
                         root.passwordBuffer = ""
                         if (res === PamResult.Error)
                         root.pamState = "error"
                         else if (res === PamResult.MaxTries)
                         root.pamState = "max"
                         else if (res === PamResult.Failed)
                         root.pamState = "fail"
                         placeholderDelay.restart()
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
        showLogout: true
        onClosed: {
            if (!demoMode && passwordField && passwordField.forceActiveFocus) {
                Qt.callLater(() => passwordField.forceActiveFocus())
            }
        }
    }
}
