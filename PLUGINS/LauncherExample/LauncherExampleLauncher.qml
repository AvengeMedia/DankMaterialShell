import QtQuick
import Quickshell
import qs.Services

Item {
    id: root

    // Plugin properties
    property var pluginService: null
    property string trigger: "#"

    // Plugin interface signals
    signal itemsChanged()

    Component.onCompleted: {
        console.info("LauncherExample: Plugin loaded")

        // Load custom trigger from settings
        if (pluginService) {
            trigger = pluginService.loadPluginData("launcherExample", "trigger", "#")
        }
    }

    // Required function: Get items for launcher
    function getItems(query) {
        const baseItems = [
            {
                name: "Test Item 1",
                icon: "material:lightbulb",
                comment: "This is a test item that shows a toast notification",
                action: "toast:Test Item 1 executed!",
                categories: ["LauncherExample"]
            },
            {
                name: "Test Item 2",
                icon: "material:star",
                comment: "Another test item with different action",
                action: "toast:Test Item 2 clicked!",
                categories: ["LauncherExample"]
            },
            {
                name: "Test Item 3",
                icon: "material:favorite",
                comment: "Third test item for demonstration",
                action: "toast:Test Item 3 activated!",
                categories: ["LauncherExample"]
            },
            {
                name: "Unicode Icon Example",
                icon: "unicode:🚀",
                comment: "Demonstrates unicode/emoji icon support",
                action: "toast:Unicode icons work great!",
                categories: ["LauncherExample"]
            },
            {
                name: "Example Copy Action",
                icon: "material:content_copy",
                comment: "Demonstrates copying text to clipboard",
                action: "copy:This text was copied by the launcher plugin!",
                categories: ["LauncherExample"]
            },
            {
                name: "Example Script Action",
                icon: "material:terminal",
                comment: "Demonstrates running a simple command",
                action: "script:echo 'Hello from launcher plugin!'",
                categories: ["LauncherExample"]
            }
        ]

        if (!query || query.length === 0) {
            return baseItems
        }

        // Filter items based on query
        const lowerQuery = query.toLowerCase()
        return baseItems.filter(item => {
            return item.name.toLowerCase().includes(lowerQuery) ||
                   item.comment.toLowerCase().includes(lowerQuery)
        })
    }

    // Required function: Execute item action
    function executeItem(item) {
        if (!item || !item.action) {
            console.warn("LauncherExample: Invalid item or action")
            return
        }

        console.log("LauncherExample: Executing item:", item.name, "with action:", item.action)

        const actionParts = item.action.split(":")
        const actionType = actionParts[0]
        const actionData = actionParts.slice(1).join(":")

        switch (actionType) {
            case "toast":
                showToast(actionData)
                break
            case "copy":
                copyToClipboard(actionData)
                break
            case "script":
                runScript(actionData)
                break
            default:
                console.warn("LauncherExample: Unknown action type:", actionType)
                showToast("Unknown action: " + actionType)
        }
    }

    // Helper functions for different action types
    function showToast(message) {
        if (typeof ToastService !== "undefined") {
            ToastService.showInfo("LauncherExample", message)
        } else {
            console.log("LauncherExample Toast:", message)
        }
    }

    function copyToClipboard(text) {
        Quickshell.execDetached(["sh", "-c", "echo -n '" + text + "' | wl-copy"])
        showToast("Copied to clipboard: " + text)
    }

    function runScript(command) {
        console.log("LauncherExample: Would run script:", command)
        showToast("Script executed: " + command)

        // In a real plugin, you might create a Process component here
        // For demo purposes, we just show what would happen
    }

    // Watch for trigger changes
    onTriggerChanged: {
        if (pluginService) {
            pluginService.savePluginData("launcherExample", "trigger", trigger)
        }
    }
}
