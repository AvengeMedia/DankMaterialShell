import QtCore
import QtQuick
import QtQuick.Controls
import QtQuick.Effects
import QtQuick.Layouts
import Quickshell
import Quickshell.Io
import Quickshell.Services.Pam
import qs.Common
import qs.Services
import qs.Widgets

Item {
    id: root

    property string passwordBuffer: ""
    property bool demoMode: false
    property string screenName: ""

    signal unlockRequested

    // Internal power dialog state
    property bool powerDialogVisible: false
    property string powerDialogTitle: ""
    property string powerDialogMessage: ""
    property string powerDialogConfirmText: ""
    property color powerDialogConfirmColor: Theme.primary
    property var powerDialogOnConfirm: function () {}

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
        if (demoMode) {
            LockScreenService.pickRandomFact()
        }

        WeatherService.addRef()
        UserInfoService.refreshUserInfo()
    }
    onDemoModeChanged: {
        if (demoMode) {
            LockScreenService.pickRandomFact()
        }
    }
    Component.onDestruction: {
        WeatherService.removeRef()
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
                const baseDir = cacheHome.startsWith("file://") ? cacheHome.substring(7) : cacheHome
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

                Item {
                    id: avatarContainer

                    property bool hasImage: profileImageLoader.status === Image.Ready

                    Layout.preferredWidth: 60
                    Layout.preferredHeight: 60

                    Rectangle {
                        anchors.fill: parent
                        radius: width / 2
                        color: "transparent"
                        border.color: Theme.primary
                        border.width: 1
                        visible: parent.hasImage
                    }

                    Image {
                        id: profileImageLoader

                        source: {
                            if (PortalService.profileImage === "") {
                                return ""
                            }

                            if (PortalService.profileImage.startsWith("/")) {
                                return "file://" + PortalService.profileImage
                            }

                            return PortalService.profileImage
                        }
                        smooth: true
                        asynchronous: true
                        mipmap: true
                        cache: true
                        visible: false
                    }

                    MultiEffect {
                        anchors.fill: parent
                        anchors.margins: 5
                        source: profileImageLoader
                        maskEnabled: true
                        maskSource: circularMask
                        visible: avatarContainer.hasImage
                        maskThresholdMin: 0.5
                        maskSpreadAtMin: 1
                    }

                    Item {
                        id: circularMask

                        width: 60 - 10
                        height: 60 - 10
                        layer.enabled: true
                        layer.smooth: true
                        visible: false

                        Rectangle {
                            anchors.fill: parent
                            radius: width / 2
                            color: "black"
                            antialiasing: true
                        }
                    }

                    Rectangle {
                        anchors.fill: parent
                        radius: width / 2
                        color: Theme.primary
                        visible: !parent.hasImage

                        DankIcon {
                            anchors.centerIn: parent
                            name: "person"
                            size: Theme.iconSize + 4
                            color: Theme.primaryText
                        }
                    }

                    DankIcon {
                        anchors.centerIn: parent
                        name: "warning"
                        size: Theme.iconSize + 4
                        color: Theme.primaryText
                        visible: PortalService.profileImage !== "" && profileImageLoader.status === Image.Error
                    }
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
                        focus: !demoMode
                        enabled: !demoMode
                        echoMode: parent.showPassword ? TextInput.Normal : TextInput.Password
                        onTextChanged: {
                            if (!demoMode) {
                                root.passwordBuffer = text
                            }
                        }
                        onAccepted: {
                            if (!demoMode && root.passwordBuffer.length > 0 && !pam.active) {
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

                        Timer {
                            id: focusTimer

                            interval: 100
                            running: !demoMode
                            onTriggered: passwordField.forceActiveFocus()
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
                            if (LockScreenService.unlocking) {
                                return "Unlocking..."
                            }
                            if (pam.active) {
                                return "Authenticating..."
                            }
                            return "Password..."
                        }
                        color: LockScreenService.unlocking ? Theme.primary : (pam.active ? Theme.primary : Theme.outline)
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
                        visible: !demoMode && root.passwordBuffer.length > 0 && !pam.active && !LockScreenService.unlocking
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
                        visible: !demoMode && !pam.active && !LockScreenService.unlocking
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
                        visible: !demoMode && (pam.active || LockScreenService.unlocking)

                        DankIcon {
                            anchors.centerIn: parent
                            name: "check_circle"
                            size: 20
                            color: Theme.primary
                            visible: LockScreenService.unlocking

                            SequentialAnimation on scale {
                                running: LockScreenService.unlocking

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
                            visible: pam.active && !LockScreenService.unlocking

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
                                    running: pam.active && !LockScreenService.unlocking
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
                        visible: (demoMode || (root.passwordBuffer.length > 0 && !pam.active && !LockScreenService.unlocking))
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
                Layout.preferredHeight: LockScreenService.pamState ? 20 : 0
                text: {
                    if (LockScreenService.pamState === "error") {
                        return "Authentication error - try again"
                    }
                    if (LockScreenService.pamState === "max") {
                        return "Too many attempts - locked out"
                    }
                    if (LockScreenService.pamState === "fail") {
                        return "Incorrect password - try again"
                    }
                    return ""
                }
                color: Theme.error
                font.pixelSize: Theme.fontSizeSmall
                horizontalAlignment: Text.AlignHCenter
                visible: LockScreenService.pamState !== ""
                opacity: LockScreenService.pamState !== "" ? 1 : 0

                Behavior on opacity {
                    NumberAnimation {
                        duration: Theme.shortDuration
                        easing.type: Theme.standardEasing
                    }
                }

                Behavior on Layout.preferredHeight {
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
            text: "DEMO MODE - Click anywhere to exit"
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

        Row {
            anchors.bottom: parent.bottom
            anchors.left: parent.left
            anchors.margins: Theme.spacingXL
            spacing: Theme.spacingL
            visible: SettingsData.lockScreenShowPowerActions

            DankActionButton {
                iconName: "power_settings_new"
                iconColor: Theme.error
                buttonSize: 40
                onClicked: {
                    if (demoMode) {
                        console.log("Demo: Power")
                    } else {
                        showPowerDialog("Power Off", "Power off this computer?", "Power Off", Theme.error, function () {
                            SessionService.poweroff()
                        })
                    }
                }
            }

            DankActionButton {
                iconName: "refresh"
                buttonSize: 40
                onClicked: {
                    if (demoMode) {
                        console.log("Demo: Reboot")
                    } else {
                        showPowerDialog("Restart", "Restart this computer?", "Restart", Theme.primary, function () {
                            SessionService.reboot()
                        })
                    }
                }
            }

            DankActionButton {
                iconName: "logout"
                buttonSize: 40
                onClicked: {
                    if (demoMode) {
                        console.log("Demo: Logout")
                    } else {
                        showPowerDialog("Log Out", "End this session?", "Log Out", Theme.primary, function () {
                            SessionService.logout()
                        })
                    }
                }
            }
        }

        StyledText {
            anchors.bottom: parent.bottom
            anchors.horizontalCenter: parent.horizontalCenter
            anchors.margins: Theme.spacingL
            width: Math.min(parent.width - Theme.spacingXL * 2, implicitWidth)
            text: LockScreenService.randomFact
            font.pixelSize: Theme.fontSizeSmall
            color: "white"
            opacity: 0.8
            horizontalAlignment: Text.AlignHCenter
            wrapMode: Text.NoWrap
            visible: LockScreenService.randomFact !== ""
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
                             LockScreenService.setUnlocking(true)
                             passwordField.text = ""
                             root.passwordBuffer = ""
                             root.unlockRequested()
                             return
                         }
                         console.log("Authentication failed:", res)
                         if (res === PamResult.Error)
                         LockScreenService.setPamState("error")
                         else if (res === PamResult.MaxTries)
                         LockScreenService.setPamState("max")
                         else if (res === PamResult.Failed)
                         LockScreenService.setPamState("fail")
                         placeholderDelay.restart()
                     }
    }

    Timer {
        id: placeholderDelay

        interval: 4000
        onTriggered: LockScreenService.setPamState("")
    }

    MouseArea {
        anchors.fill: parent
        enabled: demoMode
        onClicked: root.unlockRequested()
    }

    // Internal power dialog
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
                            text: "Cancel"
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
