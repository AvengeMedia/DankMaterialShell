import QtQuick
import Quickshell
import qs.Services

Item {
    id: root

    property var pluginService: null
    property string trigger: "#"

    signal itemsChanged()

    // TODO: Define your items
    property var allItems: [
        {
            name: "Example Item",
            icon: "material:star",
            comment: "An example launcher item",
            action: "toast:Hello from my launcher!",
            categories: ["MyLauncher"]
        }
    ]

    function getItems(query) {
        if (!query || query.length === 0) return allItems

        var q = query.toLowerCase()
        return allItems.filter(function(item) {
            return item.name.toLowerCase().includes(q) ||
                   item.comment.toLowerCase().includes(q)
        })
    }

    function executeItem(item) {
        var actionParts = item.action.split(":")
        var actionType = actionParts[0]
        var actionData = actionParts.slice(1).join(":")

        switch (actionType) {
            case "toast":
                if (typeof ToastService !== "undefined")
                    ToastService.showInfo(actionData)
                break
            case "copy":
                Quickshell.execDetached(["dms", "cl", "copy", actionData])
                if (typeof ToastService !== "undefined")
                    ToastService.showInfo("Copied to clipboard")
                break
            default:
                console.warn("Unknown action type:", actionType)
        }
    }

    Component.onCompleted: {
        if (pluginService) {
            trigger = pluginService.loadPluginData("myLauncher", "trigger", "#")
        }
    }
}
