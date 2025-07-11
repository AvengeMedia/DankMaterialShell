import QtQuick
import QtQuick.Controls
import Qt5Compat.GraphicalEffects
import Quickshell
import Quickshell.Services.Mpris
import "../../Common"
import "../../Services"

Rectangle {
    id: mediaPlayerWidget
    
    property MprisPlayer activePlayer: MprisController.activePlayer
    property var theme: Theme
    
    width: parent.width
    height: 160  // Reduced height to prevent overflow
    radius: theme.cornerRadius
    color: Qt.rgba(theme.primary.r, theme.primary.g, theme.primary.b, 0.08)
    border.color: Qt.rgba(theme.primary.r, theme.primary.g, theme.primary.b, 0.2)
    border.width: 1
    
    // Constants and helpers - all microseconds
    readonly property real oneSecondUs: 1000000.0
    
    function asSec(us) { return us / oneSecondUs }
    function ratio() { return trackLenUs > 0 ? uiPosUs / trackLenUs : 0 }
    
    function normalizeLength(lenRaw) {
        // If length < 86 400 it's almost certainly seconds (24 h upper bound).
        // Convert to µs; otherwise return as-is.
        return (lenRaw > 0 && lenRaw < 86400) ? lenRaw * oneSecondUs : lenRaw;
    }
    
    
    // Call seek() in safe 5-second chunks so every player obeys.
    function chunkedSeek(offsetUs) {
        if (Math.abs(offsetUs) < 5 * oneSecondUs) {   // ≤5 s? single shot.
            activePlayer.seek(offsetUs);
            return;
        }
        
        const step = 5 * oneSecondUs;                 // 5 s
        let remaining = offsetUs;
        let safety    = 0;                            // avoid infinite loops
        while (Math.abs(remaining) > step && safety < 40) {   // max 200 s
            activePlayer.seek(Math.sign(remaining) * step);
            remaining -= Math.sign(remaining) * step;
            safety++;
        }
        if (remaining !== 0) activePlayer.seek(remaining);
    }
    
    // Returns a guaranteed-valid object-path for the current track.
    function trackPath() {
        const md = activePlayer.metadata || {};
        // Spec: "/org/mpris/MediaPlayer2/Track/NNN"
        if (typeof md["mpris:trackid"] === "string" &&
            md["mpris:trackid"].length > 1 && md["mpris:trackid"].startsWith("/"))
            return md["mpris:trackid"];

        // Nothing reliable?  Fall back to the *current* playlist entry object if exposed
        if (activePlayer.currentTrackPath)      return activePlayer.currentTrackPath;

        // Absolute last resort—return null so caller knows SetPosition will fail
        return null;
    }
    
    // Position tracking - all microseconds
    property real uiPosUs: 0
    property real backendPosUs: 0
    property real trackLenUs: 0
    property double backendStamp: Date.now()    // wall-clock of last update in ms
    
    // Optimistic timer
    Timer {
        id: tickTimer
        interval: 50            // 20 fps feels smooth, cheap
        repeat: true
        running: activePlayer?.playbackState === MprisPlaybackState.Playing
        onTriggered: {
            if (trackLenUs <= 0) return;
            const projected = backendPosUs + (Date.now() - backendStamp) * 1000.0;
            uiPosUs = Math.min(projected, trackLenUs);   // never exceed track end
        }
    }
    
    // --- 500-ms poll to keep external moves in sync -------------------
    // Timer {
    //     id: pollTimer
    //     interval: 500             // ms
    //     repeat: true
    //     running: true             // always on; cost is negligible
    //     onTriggered: {
    //         if (!activePlayer || trackLenUs <= 0) return;

    //         const polledUs = activePlayer.position;   // property read
    //         // Compare in percent to avoid false positives
    //         if (Math.abs((polledUs - backendPosUs) / trackLenUs) > 0.01) { // >1 % jump
    //             backendPosUs = polledUs;
    //             backendStamp = Date.now();
    //             uiPosUs      = polledUs;      // snap instantly
    //         }
    //     }
    // }
    
    // Initialize when player changes
    onActivePlayerChanged: {
        if (activePlayer) {
            backendPosUs = activePlayer.position || 0
            trackLenUs = normalizeLength(activePlayer.length || 0)
            backendStamp = Date.now()
            uiPosUs = backendPosUs
            console.log(`player change → len ${asSec(trackLenUs)} s, pos ${asSec(uiPosUs)} s`)
        } else {
            backendPosUs = 0
            trackLenUs = 0
            backendStamp = Date.now()
            uiPosUs = 0
        }
    }
    
    // Backend events
    Connections {
        target: activePlayer
        
        function onPositionChanged() {
            const posUs = activePlayer.position
            backendPosUs = posUs
            backendStamp = Date.now()
            uiPosUs = posUs                 // snap immediately on tick
        }
        
        function onSeeked(pos) {
            backendPosUs = pos
            backendStamp = Date.now()
            uiPosUs = backendPosUs
        }
        
        function onPostTrackChanged() {
            backendPosUs = activePlayer?.position || 0
            trackLenUs = normalizeLength(activePlayer?.length || 0)
            backendStamp = Date.now()
            uiPosUs = backendPosUs
        }
        
        function onTrackTitleChanged() {
            backendPosUs = activePlayer?.position || 0
            trackLenUs = normalizeLength(activePlayer?.length || 0)
            backendStamp = Date.now()
            uiPosUs = backendPosUs
        }
    }
    
    Column {
        anchors.fill: parent
        anchors.margins: theme.spacingM
        spacing: theme.spacingM
        
        // Album art and track info
        Row {
            width: parent.width
            height: 70  // Reduced height
            spacing: theme.spacingM
            
            // Album Art
            Rectangle {
                width: 70
                height: 70
                radius: theme.cornerRadius
                color: Qt.rgba(theme.surfaceVariant.r, theme.surfaceVariant.g, theme.surfaceVariant.b, 0.3)
                
                Item {
                    anchors.fill: parent
                    clip: true
                    
                    Image {
                        id: albumArt
                        anchors.fill: parent
                        source: activePlayer?.trackArtUrl || ""
                        fillMode: Image.PreserveAspectCrop
                        smooth: true
                    }
                    
                    Rectangle {
                        anchors.fill: parent
                        visible: albumArt.status !== Image.Ready
                        color: "transparent"
                        
                        Text {
                            anchors.centerIn: parent
                            text: "album"
                            font.family: theme.iconFont
                            font.pixelSize: 28
                            color: theme.surfaceVariantText
                        }
                    }
                }
            }
            
            // Track Info
            Column {
                width: parent.width - 70 - theme.spacingM
                spacing: theme.spacingXS
                anchors.verticalCenter: parent.verticalCenter
                
                Text {
                    text: activePlayer?.trackTitle || "Unknown Track"
                    font.pixelSize: theme.fontSizeMedium
                    font.weight: Font.Bold
                    color: theme.surfaceText
                    width: parent.width
                    elide: Text.ElideRight
                }
                
                Text {
                    text: activePlayer?.trackArtist || "Unknown Artist"
                    font.pixelSize: theme.fontSizeSmall
                    color: Qt.rgba(theme.surfaceText.r, theme.surfaceText.g, theme.surfaceText.b, 0.8)
                    width: parent.width
                    elide: Text.ElideRight
                }
                
                Text {
                    text: activePlayer?.trackAlbum || ""
                    font.pixelSize: theme.fontSizeSmall
                    color: Qt.rgba(theme.surfaceText.r, theme.surfaceText.g, theme.surfaceText.b, 0.6)
                    width: parent.width
                    elide: Text.ElideRight
                    visible: text.length > 0
                }
            }
        }
        
        // Progress bar
        Rectangle {
            width: parent.width
            height: 6
            radius: 3
            color: Qt.rgba(theme.surfaceVariant.r, theme.surfaceVariant.g, theme.surfaceVariant.b, 0.3)
            
            Rectangle {
                id: progressFill
                height: parent.height
                radius: parent.radius
                color: theme.primary
                
                width: parent.width * ratio()
            }
            
            MouseArea {
                anchors.fill: parent
                cursorShape: Qt.PointingHandCursor
                
                onClicked: (mouse) => {
                    if (!activePlayer || !activePlayer.canSeek || trackLenUs <= 0) return
                    
                    const targetUs = (mouse.x / width) * trackLenUs
                    const offset = targetUs - backendPosUs
                    
                    if (typeof activePlayer.setPosition === "function") {
                        activePlayer.setPosition(trackPath() || "/", Math.round(targetUs))
                        console.log(`SetPosition → ${asSec(targetUs)} s`)
                    } else {
                        chunkedSeek(offset)                          // <-- use helper
                        console.log(`chunkedSeek → ${asSec(offset/oneSecondUs)} s`)
                    }
                    
                    uiPosUs = backendPosUs = targetUs
                }
            }
        }
        
        // Control buttons - compact to fit
        Row {
            anchors.horizontalCenter: parent.horizontalCenter
            spacing: theme.spacingL
            
            // Previous button  
            Rectangle {
                width: 28
                height: 28
                radius: 14
                color: prevBtnArea.containsMouse ? Qt.rgba(theme.surfaceVariant.r, theme.surfaceVariant.g, theme.surfaceVariant.b, 0.12) : "transparent"
                
                Text {
                    anchors.centerIn: parent
                    text: "skip_previous"
                    font.family: theme.iconFont
                    font.pixelSize: 16
                    color: theme.surfaceText
                }
                
                MouseArea {
                    id: prevBtnArea
                    anchors.fill: parent
                    hoverEnabled: true
                    cursorShape: Qt.PointingHandCursor
                    onClicked: {
                        if (!activePlayer) return
                        
                        // >8 s → jump to start, otherwise previous track
                        if (uiPosUs > 8 * oneSecondUs && activePlayer.canSeek) {
                            if (typeof activePlayer.setPosition === "function") {
                                activePlayer.setPosition(trackPath() || "/", 0)
                                console.log("Back → SetPosition 0 µs")
                            } else {
                                chunkedSeek(-backendPosUs)                   // <-- use helper
                                console.log("Back → chunkedSeek to 0")
                            }
                            uiPosUs = backendPosUs = 0
                        } else {
                            activePlayer.previous()
                        }
                    }
                }
            }
            
            // Play/Pause button
            Rectangle {
                width: 36
                height: 36
                radius: 18
                color: theme.primary
                
                Text {
                    anchors.centerIn: parent
                    text: activePlayer?.playbackState === MprisPlaybackState.Playing ? "pause" : "play_arrow"
                    font.family: theme.iconFont
                    font.pixelSize: 20
                    color: theme.background
                }
                
                MouseArea {
                    anchors.fill: parent
                    hoverEnabled: true
                    cursorShape: Qt.PointingHandCursor
                    onClicked: activePlayer?.togglePlaying()
                }
            }
            
            // Next button
            Rectangle {
                width: 28
                height: 28
                radius: 14
                color: nextBtnArea.containsMouse ? Qt.rgba(theme.surfaceVariant.r, theme.surfaceVariant.g, theme.surfaceVariant.b, 0.12) : "transparent"
                
                Text {
                    anchors.centerIn: parent
                    text: "skip_next"
                    font.family: theme.iconFont
                    font.pixelSize: 16
                    color: theme.surfaceText
                }
                
                MouseArea {
                    id: nextBtnArea
                    anchors.fill: parent
                    hoverEnabled: true
                    cursorShape: Qt.PointingHandCursor
                    onClicked: activePlayer?.next()
                }
            }
        }
    }
}