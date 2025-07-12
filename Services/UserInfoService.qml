import QtQuick
import Quickshell
import Quickshell.Io
pragma Singleton
pragma ComponentBehavior: Bound

Singleton {
    id: root
    
    property string username: ""
    property string fullName: ""
    property string profilePicture: ""
    property string uptime: ""
    property string hostname: ""
    property bool profileAvailable: false
    
    Component.onCompleted: {
        getUserInfo()
        getUptime()
        
        // Update uptime every minute
        uptimeTimer.start()
    }
    
    Timer {
        id: uptimeTimer
        interval: 60000 // 1 minute
        running: false
        repeat: true
        onTriggered: getUptime()
    }
    
    // Get username and full name
    Process {
        id: userInfoProcess
        command: ["bash", "-c", "echo \"$USER|$(getent passwd $USER | cut -d: -f5 | cut -d, -f1)|$(hostname)\""]
        running: false
        
        stdout: StdioCollector {
            onStreamFinished: {
                const parts = text.trim().split("|")
                if (parts.length >= 3) {
                    root.username = parts[0] || ""
                    root.fullName = parts[1] || parts[0] || ""
                    root.hostname = parts[2] || ""
                    console.log("UserInfoService: User info loaded -", root.username, root.fullName, root.hostname)
                    
                    // Try to find profile picture
                    getProfilePicture()
                }
            }
        }
        
        onExited: (exitCode) => {
            if (exitCode !== 0) {
                console.warn("UserInfoService: Failed to get user info")
                root.username = "User"
                root.fullName = "User"
                root.hostname = "System"
            }
        }
    }
    
    // Get system uptime
    Process {
        id: uptimeProcess
        command: ["bash", "-c", "uptime -p | sed 's/up //'"]
        running: false
        
        stdout: StdioCollector {
            onStreamFinished: {
                root.uptime = text.trim() || "Unknown"
                console.log("UserInfoService: Uptime updated -", root.uptime)
            }
        }
        
        onExited: (exitCode) => {
            if (exitCode !== 0) {
                console.warn("UserInfoService: Failed to get uptime")
                root.uptime = "Unknown"
            }
        }
    }
    
    // Look for profile picture in common locations
    Process {
        id: profilePictureProcess
        command: ["bash", "-c", `
            # Try common profile picture locations
            for path in \
                "$HOME/.face" \
                "$HOME/.face.icon" \
                "/var/lib/AccountsService/icons/$USER" \
                "/usr/share/pixmaps/faces/$USER" \
                "/usr/share/pixmaps/faces/$USER.png" \
                "/usr/share/pixmaps/faces/$USER.jpg"; do
                if [ -f "$path" ]; then
                    echo "$path"
                    exit 0
                fi
            done
            # Fallback to generic user icon
            echo ""
        `]
        running: false
        
        stdout: StdioCollector {
            onStreamFinished: {
                const path = text.trim()
                if (path && path.length > 0) {
                    root.profilePicture = "file://" + path
                    root.profileAvailable = true
                    console.log("UserInfoService: Profile picture found at", path)
                } else {
                    root.profilePicture = ""
                    root.profileAvailable = false
                    console.log("UserInfoService: No profile picture found, using default avatar")
                }
            }
        }
        
        onExited: (exitCode) => {
            if (exitCode !== 0) {
                console.warn("UserInfoService: Failed to find profile picture")
                root.profilePicture = ""
                root.profileAvailable = false
            }
        }
    }
    
    function getUserInfo() {
        userInfoProcess.running = true
    }
    
    function getUptime() {
        uptimeProcess.running = true
    }
    
    function getProfilePicture() {
        profilePictureProcess.running = true
    }
    
    function refreshUserInfo() {
        getUserInfo()
        getUptime()
        getProfilePicture()
    }
}