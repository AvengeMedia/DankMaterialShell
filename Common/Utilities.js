function parseWorkspaceOutput(data) {
    const lines = data.split('\n')
    let currentOutputName = ""
    let focusedOutput = ""
    let focusedWorkspace = 1
    let outputWorkspaces = {}
    
    
    for (const line of lines) {
        if (line.startsWith('Output "')) {
            const outputMatch = line.match(/Output "(.+)"/)
            if (outputMatch) {
                currentOutputName = outputMatch[1]
                outputWorkspaces[currentOutputName] = []
            }
            continue
        }
        
        if (line.trim() && line.match(/^\s*\*?\s*(\d+)$/)) {
            const wsMatch = line.match(/^\s*(\*?)\s*(\d+)$/)
            if (wsMatch) {
                const isActive = wsMatch[1] === '*'
                const wsNum = parseInt(wsMatch[2])
                
                if (currentOutputName && outputWorkspaces[currentOutputName]) {
                    outputWorkspaces[currentOutputName].push(wsNum)
                }
                
                if (isActive) {
                    focusedOutput = currentOutputName
                    focusedWorkspace = wsNum
                }
            }
        }
    }
    
    // Show workspaces for THIS screen only
    if (topBar.screenName && outputWorkspaces[topBar.screenName]) {
        workspaceList = outputWorkspaces[topBar.screenName]
        
        // Always track the active workspace for this display
        // Parse all lines to find which workspace is active on this display
        let thisDisplayActiveWorkspace = 1
        let inThisOutput = false
        
        for (const line of lines) {
            if (line.startsWith('Output "')) {
                const outputMatch = line.match(/Output "(.+)"/)
                inThisOutput = outputMatch && outputMatch[1] === topBar.screenName
                continue
            }
            
            if (inThisOutput && line.trim() && line.match(/^\s*\*\s*(\d+)$/)) {
                const wsMatch = line.match(/^\s*\*\s*(\d+)$/)
                if (wsMatch) {
                    thisDisplayActiveWorkspace = parseInt(wsMatch[1])
                    break
                }
            }
        }
        
        currentWorkspace = thisDisplayActiveWorkspace
        // console.log("Monitor", topBar.screenName, "active workspace:", thisDisplayActiveWorkspace)
    } else {
        // Fallback if screen name not found
        workspaceList = [1, 2]
        currentWorkspace = 1
    }
}

function showMenu(x, y) {
    root.currentTrayMenu = customTrayMenu
    root.currentTrayItem = trayItem
    
    // Simple positioning: right side of screen, below the panel
    root.trayMenuX = rightSection.x + rightSection.width - 180 - theme.spacingL
    root.trayMenuY = theme.barHeight + theme.spacingS
    
    console.log("Showing menu at:", root.trayMenuX, root.trayMenuY)
    menuVisible = true
    root.showTrayMenu = true
}

function hideMenu() {
    menuVisible = false
    root.showTrayMenu = false
    root.currentTrayMenu = null
    root.currentTrayItem = null
}

function showNotificationPopup(notification) {
    root.activeNotification = notification
    root.showNotificationPopup = true
    notificationTimer.restart()
}

function hideNotificationPopup() {
    root.showNotificationPopup = false
    notificationTimer.stop()
    clearNotificationTimer.restart()
}