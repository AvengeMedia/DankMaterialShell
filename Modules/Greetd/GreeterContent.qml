import QtCore
import QtQuick
import QtQuick.Controls
import QtQuick.Effects
import QtQuick.Layouts
import Quickshell
import Quickshell.Io
import Quickshell.Services.Greetd
import Quickshell.Services.Pam
import Quickshell.Services.Mpris
import qs.Common
import qs.Services
import qs.Widgets
import qs.Modules.Lock

Item {
    id: root

    required property var sessionLock

    readonly property string xdgDataDirs: Quickshell.env("XDG_DATA_DIRS")
    property string screenName: ""
    property string randomFact: ""
    property string hyprlandCurrentLayout: ""
    property string hyprlandKeyboard: ""
    property int hyprlandLayoutCount: 0
    property bool isPrimaryScreen: {
        if (!Qt.application.screens || Qt.application.screens.length === 0)
            return true
        if (!screenName || screenName === "")
            return true
        return screenName === Qt.application.screens[0].name
    }

    signal launchRequested

    property bool powerDialogVisible: false
    property string powerDialogTitle: ""
    property string powerDialogMessage: ""
    property string powerDialogConfirmText: ""
    property color powerDialogConfirmColor: Theme.primary
    property var powerDialogOnConfirm: function () {}

    function pickRandomFact() {
        randomFact = Facts.getRandomFact()
    }

    function showPowerDialog(title, message, confirmText, confirmColor, onConfirm) {
        powerDialogTitle = title
        powerDialogMessage = message
        powerDialogConfirmText = confirmText
        powerDialogConfirmColor = confirmColor
        powerDialogOnConfirm = onConfirm
        powerDialogVisible = true
    }

    function hidePowerDialog() {
        powerDialogVisible = false
    }

    Component.onCompleted: {
        pickRandomFact()
        WeatherService.addRef()

        if (isPrimaryScreen) {
            sessionListProc.running = true
            applyLastSuccessfulUser()
        }

        if (CompositorService.isHyprland) {
            updateHyprlandLayout()
            hyprlandLayoutUpdateTimer.start()
        }
    }

    function applyLastSuccessfulUser() {
        const lastUser = GreetdMemory.lastSuccessfulUser
        if (lastUser && !GreeterState.showPasswordInput && !GreeterState.username) {
            GreeterState.username = lastUser
            GreeterState.usernameInput = lastUser
            GreeterState.showPasswordInput = true
            PortalService.getGreeterUserProfileImage(lastUser)
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

    // ! This was for development and testing, just leaving so people can see how I did it.
    // Timer {
    //     id: autoUnlockTimer
    //     interval: 10000
    //     running: true
    //     onTriggered: {
    //         root.sessionLock.locked = false
    //         GreeterState.unlocking = true
    //         const sessionCmd = GreeterState.selectedSession || GreeterState.sessionExecs[GreeterState.currentSessionIndex]
    //         if (sessionCmd) {
    //             GreetdMemory.setLastSessionId(sessionCmd.split(" ")[0])
    //             Greetd.launch(sessionCmd.split(" "), [], true)
    //         }
    //     }
    // }

    Connections {
        target: GreetdMemory
        enabled: isPrimaryScreen
        function onLastSuccessfulUserChanged() {
            applyLastSuccessfulUser()
        }
    }

    Connections {
        target: GreeterState
        function onUsernameChanged() {
            if (GreeterState.username) {
                PortalService.getGreeterUserProfileImage(GreeterState.username)
            }
        }
    }

    DankBackdrop {
        anchors.fill: parent
        screenName: root.screenName
        visible: {
            var currentWallpaper = SessionData.getMonitorWallpaper(screenName)
            return !currentWallpaper || currentWallpaper === "" || (currentWallpaper && currentWallpaper.startsWith("#"))
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
                    const format = GreetdSettings.use24HourClock ? "HH:mm" : "h:mm AP"
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
                    if (GreetdSettings.lockDateFormat && GreetdSettings.lockDateFormat.length > 0) {
                        return systemClock.date.toLocaleDateString(Qt.locale(), GreetdSettings.lockDateFormat)
                    }
                    return systemClock.date.toLocaleDateString(Qt.locale(), Locale.LongFormat)
                }
                font.pixelSize: Theme.fontSizeXLarge
                color: "white"
                opacity: 0.9
            }
        }

        Item {
            anchors.centerIn: parent
            anchors.verticalCenterOffset: 80
            width: 380
            height: 140

            ColumnLayout {
                anchors.fill: parent
                spacing: Theme.spacingM

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
                        border.color: inputField.activeFocus ? Theme.primary : Qt.rgba(1, 1, 1, 0.3)
                        border.width: inputField.activeFocus ? 2 : 1

                        DankIcon {
                            id: lockIcon

                            anchors.left: parent.left
                            anchors.leftMargin: Theme.spacingM
                            anchors.verticalCenter: parent.verticalCenter
                            name: GreeterState.showPasswordInput ? "lock" : "person"
                            size: 20
                            color: inputField.activeFocus ? Theme.primary : Theme.surfaceVariantText
                        }

                        TextInput {
                            id: inputField

                            property bool syncingFromState: false

                            anchors.fill: parent
                            anchors.leftMargin: lockIcon.width + Theme.spacingM * 2
                            anchors.rightMargin: {
                                let margin = Theme.spacingM
                                if (GreeterState.showPasswordInput && revealButton.visible) {
                                    margin += revealButton.width
                                }
                                if (virtualKeyboardButton.visible) {
                                    margin += virtualKeyboardButton.width
                                }
                                if (enterButton.visible) {
                                    margin += enterButton.width + 2
                                }
                                return margin
                            }
                            opacity: 0
                            focus: true
                            echoMode: GreeterState.showPasswordInput ? (parent.showPassword ? TextInput.Normal : TextInput.Password) : TextInput.Normal
                            onTextChanged: {
                                if (syncingFromState) return
                                if (GreeterState.showPasswordInput) {
                                    GreeterState.passwordBuffer = text
                                } else {
                                    GreeterState.usernameInput = text
                                }
                            }
                            onAccepted: {
                                if (GreeterState.showPasswordInput) {
                                    if (Greetd.state === GreetdState.Inactive && GreeterState.username) {
                                        Greetd.createSession(GreeterState.username)
                                    }
                                } else {
                                    if (text.trim()) {
                                        GreeterState.username = text.trim()
                                        GreeterState.showPasswordInput = true
                                        PortalService.getGreeterUserProfileImage(GreeterState.username)
                                        GreeterState.passwordBuffer = ""
                                        syncingFromState = true
                                        text = ""
                                        syncingFromState = false
                                    }
                                }
                            }

                            Component.onCompleted: {
                                syncingFromState = true
                                text = GreeterState.showPasswordInput ? GreeterState.passwordBuffer : GreeterState.usernameInput
                                syncingFromState = false
                                if (isPrimaryScreen)
                                    forceActiveFocus()
                            }
                            onVisibleChanged: {
                                if (visible && isPrimaryScreen)
                                    forceActiveFocus()
                            }
                        }

                        KeyboardController {
                            id: keyboard_controller
                            target: inputField
                            rootObject: root
                        }

                        StyledText {
                            id: placeholder

                            anchors.left: lockIcon.right
                            anchors.leftMargin: Theme.spacingM
                            anchors.right: (GreeterState.showPasswordInput && revealButton.visible ? revealButton.left : (virtualKeyboardButton.visible ? virtualKeyboardButton.left : (enterButton.visible ? enterButton.left : parent.right)))
                            anchors.rightMargin: 2
                            anchors.verticalCenter: parent.verticalCenter
                            text: {
                                if (GreeterState.unlocking) {
                                    return "Logging in..."
                                }
                                if (Greetd.state !== GreetdState.Inactive) {
                                    return "Authenticating..."
                                }
                                if (GreeterState.showPasswordInput) {
                                    return "Password..."
                                }
                                return "Username..."
                            }
                            color: GreeterState.unlocking ? Theme.primary : (Greetd.state !== GreetdState.Inactive ? Theme.primary : Theme.outline)
                            font.pixelSize: Theme.fontSizeMedium
                            opacity: (GreeterState.showPasswordInput ? GreeterState.passwordBuffer.length === 0 : GreeterState.usernameInput.length === 0) ? 1 : 0

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
                            anchors.right: (GreeterState.showPasswordInput && revealButton.visible ? revealButton.left : (virtualKeyboardButton.visible ? virtualKeyboardButton.left : (enterButton.visible ? enterButton.left : parent.right)))
                            anchors.rightMargin: 2
                            anchors.verticalCenter: parent.verticalCenter
                            text: {
                                if (GreeterState.showPasswordInput) {
                                    if (parent.showPassword) {
                                        return GreeterState.passwordBuffer
                                    }
                                    return "•".repeat(Math.min(GreeterState.passwordBuffer.length, 25))
                                }
                                return GreeterState.usernameInput
                            }
                            color: Theme.surfaceText
                            font.pixelSize: (GreeterState.showPasswordInput && !parent.showPassword) ? Theme.fontSizeLarge : Theme.fontSizeMedium
                            opacity: (GreeterState.showPasswordInput ? GreeterState.passwordBuffer.length > 0 : GreeterState.usernameInput.length > 0) ? 1 : 0
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

                            anchors.right: virtualKeyboardButton.visible ? virtualKeyboardButton.left : (enterButton.visible ? enterButton.left : parent.right)
                            anchors.rightMargin: 0
                            anchors.verticalCenter: parent.verticalCenter
                            iconName: parent.showPassword ? "visibility_off" : "visibility"
                            buttonSize: 32
                            visible: GreeterState.showPasswordInput && GreeterState.passwordBuffer.length > 0 && Greetd.state === GreetdState.Inactive && !GreeterState.unlocking
                            enabled: visible
                            onClicked: parent.showPassword = !parent.showPassword
                        }
                        DankActionButton {
                            id: virtualKeyboardButton

                            anchors.right: enterButton.visible ? enterButton.left : parent.right
                            anchors.rightMargin: enterButton.visible ? 0 : Theme.spacingS
                            anchors.verticalCenter: parent.verticalCenter
                            iconName: "keyboard"
                            buttonSize: 32
                            visible: Greetd.state === GreetdState.Inactive && !GreeterState.unlocking
                            enabled: visible
                            onClicked: {
                                if (keyboard_controller.isKeyboardActive) {
                                    keyboard_controller.hide()
                                } else {
                                    keyboard_controller.show()
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
                            visible: Greetd.state === GreetdState.Inactive && !GreeterState.unlocking
                            enabled: true
                            onClicked: {
                                if (GreeterState.showPasswordInput) {
                                    if (GreeterState.username) {
                                        Greetd.createSession(GreeterState.username)
                                    }
                                } else {
                                    if (inputField.text.trim()) {
                                        GreeterState.username = inputField.text.trim()
                                        GreeterState.showPasswordInput = true
                                        PortalService.getGreeterUserProfileImage(GreeterState.username)
                                        GreeterState.passwordBuffer = ""
                                        inputField.text = ""
                                    }
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
                    Layout.topMargin: -Theme.spacingS
                    Layout.bottomMargin: -Theme.spacingS
                    text: {
                        if (GreeterState.pamState === "error")
                            return "Authentication error - try again"
                        if (GreeterState.pamState === "fail")
                            return "Incorrect password"
                        return ""
                    }
                    color: Theme.error
                    font.pixelSize: Theme.fontSizeSmall
                    horizontalAlignment: Text.AlignHCenter
                    opacity: GreeterState.pamState !== "" ? 1 : 0

                    Behavior on opacity {
                        NumberAnimation {
                            duration: Theme.shortDuration
                            easing.type: Theme.standardEasing
                        }
                    }
                }

                Rectangle {
                    Layout.alignment: Qt.AlignHCenter
                    Layout.topMargin: 0
                    Layout.preferredWidth: switchUserRow.width + Theme.spacingL * 2
                    Layout.preferredHeight: 40
                    radius: Theme.cornerRadius
                    color: Theme.surfaceContainer
                    opacity: GreeterState.showPasswordInput ? 1 : 0
                    enabled: GreeterState.showPasswordInput

                    Behavior on opacity {
                        NumberAnimation {
                            duration: Theme.mediumDuration
                            easing.type: Theme.standardEasing
                        }
                    }

                    Row {
                        id: switchUserRow
                        anchors.centerIn: parent
                        spacing: Theme.spacingS

                        DankIcon {
                            name: "people"
                            size: Theme.iconSize - 4
                            color: Theme.surfaceText
                            anchors.verticalCenter: parent.verticalCenter
                        }

                        StyledText {
                            text: I18n.tr("Switch User")
                            font.pixelSize: Theme.fontSizeMedium
                            color: Theme.surfaceText
                            anchors.verticalCenter: parent.verticalCenter
                        }
                    }

                    StateLayer {
                        stateColor: Theme.primary
                        cornerRadius: parent.radius
                        enabled: !GreeterState.unlocking && Greetd.state === GreetdState.Inactive && GreeterState.showPasswordInput
                        onClicked: {
                            GreeterState.reset()
                            inputField.text = ""
                            PortalService.profileImage = ""
                        }
                    }
                }
            }
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
                    hoverEnabled: true
                    cursorShape: Qt.PointingHandCursor
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
                        if (!player?.trackTitle)
                            return ""
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
                    text: (GreetdSettings.useFahrenheit ? WeatherService.weather.tempF : WeatherService.weather.temp) + "°"
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

        Row {
            anchors.bottom: parent.bottom
            anchors.left: parent.left
            anchors.margins: Theme.spacingXL
            spacing: Theme.spacingL
            visible: GreetdSettings.lockScreenShowPowerActions

            DankActionButton {
                iconName: "power_settings_new"
                iconColor: Theme.error
                buttonSize: 40
                onClicked: {
                    showPowerDialog("Power Off", "Power off this computer?", "Power Off", Theme.error, function () {
                        SessionService.poweroff()
                    })
                }
            }

            DankActionButton {
                iconName: "refresh"
                buttonSize: 40
                onClicked: {
                    showPowerDialog("Restart", "Restart this computer?", "Restart", Theme.primary, function () {
                        SessionService.reboot()
                    })
                }
            }
        }

        Item {
            anchors.bottom: parent.bottom
            anchors.right: parent.right
            anchors.margins: Theme.spacingXL
            width: Math.max(200, currentSessionMetrics.width + 80)
            height: 60

            StyledTextMetrics {
                id: currentSessionMetrics
                text: root.currentSessionName
            }

            property real longestSessionWidth: {
                let maxWidth = 0
                for (var i = 0; i < sessionMetricsRepeater.count; i++) {
                    const item = sessionMetricsRepeater.itemAt(i)
                    if (item && item.width > maxWidth) {
                        maxWidth = item.width
                    }
                }
                return maxWidth
            }

            Repeater {
                id: sessionMetricsRepeater
                model: GreeterState.sessionList
                delegate: StyledTextMetrics {
                    text: modelData
                }
            }

            DankDropdown {
                id: sessionDropdown
                anchors.fill: parent
                text: ""
                description: ""
                currentValue: root.currentSessionName
                options: GreeterState.sessionList
                enableFuzzySearch: GreeterState.sessionList.length > 5
                popupWidthOffset: 0
                popupWidth: Math.max(250, parent.longestSessionWidth + 100)
                openUpwards: true
                alignPopupRight: true
                onValueChanged: value => {
                                    const idx = GreeterState.sessionList.indexOf(value)
                                    if (idx >= 0) {
                                        GreeterState.currentSessionIndex = idx
                                        GreeterState.selectedSession = GreeterState.sessionExecs[idx]
                                        GreetdMemory.setLastSessionId(GreeterState.sessionPaths[idx])
                                    }
                                }
            }
        }
    }

    FileView {
        id: pamConfigWatcher
        path: "/etc/pam.d/dankshell"
        printErrors: false
    }

    property int sessionCount: 0
    property string currentSessionName: GreeterState.sessionList[GreeterState.currentSessionIndex] || ""
    property int pendingParsers: 0


    function finalizeSessionSelection() {
        if (GreeterState.sessionList.length === 0) {
            return
        }

        root.sessionCount = GreeterState.sessionList.length

        const savedSession = GreetdMemory.lastSessionId
        let foundSaved = false
        if (savedSession) {
            for (var i = 0; i < GreeterState.sessionPaths.length; i++) {
                if (GreeterState.sessionPaths[i] === savedSession) {
                    GreeterState.currentSessionIndex = i
                    foundSaved = true
                    break
                }
            }
        }

        if (!foundSaved) {
            GreeterState.currentSessionIndex = 0
        }

        GreeterState.selectedSession = GreeterState.sessionExecs[GreeterState.currentSessionIndex] || GreeterState.sessionExecs[0] || ""
    }

    Process {
        id: sessionListProc
        command: ["find"]
            .concat("/usr/share/wayland-sessions")
            .concat("/usr/share/xsessions")
            .concat("/usr/local/share/wayland-sessions")
            .concat("/usr/local/share/xsessions")
            .concat(xdgDataDirs.split(":").map(d => d + "/wayland-sessions"))
            .concat(xdgDataDirs.split(":").map(d => d + "/xsessions"))
            .concat(["-name", "*.desktop", "-type", "f", "-follow"])
        running: false

        stdout: SplitParser {
            onRead: data => {
                        if (data.trim()) {
                            root.pendingParsers++
                            parseDesktopFile(data.trim())
                        }
                    }
        }
    }

    function parseDesktopFile(path) {
        const parser = desktopParser.createObject(null, {
                                                      "desktopPath": path
                                                  })
    }

    Component {
        id: desktopParser
        Process {
            property string desktopPath: ""
            command: ["bash", "-c", `grep -E '^(Name|Exec)=' "${desktopPath}"`]
            running: true

            stdout: StdioCollector {
                onStreamFinished: {
                    const lines = text.split("\n")
                    let name = ""
                    let exec = ""

                    for (const line of lines) {
                        if (line.startsWith("Name=")) {
                            name = line.substring(5).trim()
                        } else if (line.startsWith("Exec=")) {
                            exec = line.substring(5).trim()
                        }
                    }

                    if (name && exec) {
                        if (!GreeterState.sessionList.includes(name)) {
                            let newList = GreeterState.sessionList.slice()
                            let newExecs = GreeterState.sessionExecs.slice()
                            let newPaths = GreeterState.sessionPaths.slice()
                            newList.push(name)
                            newExecs.push(exec)
                            newPaths.push(desktopPath)
                            GreeterState.sessionList = newList
                            GreeterState.sessionExecs = newExecs
                            GreeterState.sessionPaths = newPaths
                            root.sessionCount = GreeterState.sessionList.length
                        }
                    }
                }
            }

            onExited: code => {
                          root.pendingParsers--
                          if (root.pendingParsers === 0) {
                              Qt.callLater(root.finalizeSessionSelection)
                          }
                          destroy()
                      }
        }
    }

    Connections {
        target: Greetd
        enabled: isPrimaryScreen

        function onAuthMessage(message, error, responseRequired, echoResponse) {
            if (responseRequired) {
                Greetd.respond(GreeterState.passwordBuffer)
                GreeterState.passwordBuffer = ""
                inputField.text = ""
            } else if (!error) {
                Greetd.respond("")
            }
        }

        function onReadyToLaunch() {
            root.sessionLock.locked = false
            GreeterState.unlocking = true
            const sessionCmd = GreeterState.selectedSession || GreeterState.sessionExecs[GreeterState.currentSessionIndex]
            if (sessionCmd) {
                GreetdMemory.setLastSessionId(GreeterState.sessionPaths[GreeterState.currentSessionIndex])
                GreetdMemory.setLastSuccessfulUser(GreeterState.username)
                Greetd.launch(sessionCmd.split(" "), ["XDG_SESSION_TYPE=wayland"])
            }
        }

        function onAuthFailure(message) {
            GreeterState.pamState = "fail"
            GreeterState.passwordBuffer = ""
            inputField.text = ""
            placeholderDelay.restart()
        }

        function onError(error) {
            GreeterState.pamState = "error"
            placeholderDelay.restart()
        }
    }

    Timer {
        id: placeholderDelay
        interval: 4000
        onTriggered: GreeterState.pamState = ""
    }

    Rectangle {
        anchors.fill: parent
        color: Qt.rgba(0, 0, 0, 0.8)
        visible: powerDialogVisible
        z: 1000

        Rectangle {
            anchors.centerIn: parent
            width: 320
            height: 180
            radius: Theme.cornerRadius
            color: Theme.surfaceContainer
            border.color: Theme.outline
            border.width: 1

            Column {
                anchors.centerIn: parent
                spacing: Theme.spacingXL

                DankIcon {
                    anchors.horizontalCenter: parent.horizontalCenter
                    name: "power_settings_new"
                    size: 32
                    color: powerDialogConfirmColor
                }

                StyledText {
                    anchors.horizontalCenter: parent.horizontalCenter
                    text: powerDialogMessage
                    color: Theme.surfaceText
                    font.pixelSize: Theme.fontSizeLarge
                    font.weight: Font.Medium
                }

                Row {
                    anchors.horizontalCenter: parent.horizontalCenter
                    spacing: Theme.spacingM

                    Rectangle {
                        width: 100
                        height: 40
                        radius: Theme.cornerRadius
                        color: Theme.surfaceVariant

                        StyledText {
                            anchors.centerIn: parent
                            text: I18n.tr("Cancel")
                            color: Theme.surfaceText
                            font.pixelSize: Theme.fontSizeMedium
                        }

                        MouseArea {
                            anchors.fill: parent
                            hoverEnabled: true
                            cursorShape: Qt.PointingHandCursor
                            onClicked: hidePowerDialog()
                        }
                    }

                    Rectangle {
                        width: 100
                        height: 40
                        radius: Theme.cornerRadius
                        color: powerDialogConfirmColor

                        StyledText {
                            anchors.centerIn: parent
                            text: powerDialogConfirmText
                            color: Theme.primaryText
                            font.pixelSize: Theme.fontSizeMedium
                            font.weight: Font.Medium
                        }

                        MouseArea {
                            anchors.fill: parent
                            hoverEnabled: true
                            cursorShape: Qt.PointingHandCursor
                            onClicked: {
                                hidePowerDialog()
                                powerDialogOnConfirm()
                            }
                        }
                    }
                }
            }
        }
    }
}
