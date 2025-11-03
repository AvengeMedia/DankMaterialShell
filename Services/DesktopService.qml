pragma Singleton

pragma ComponentBehavior: Bound

import QtQuick
import Quickshell
import Quickshell.Io

Singleton {
    id: root
    function resolveIconPath(appId) {
    	     let entry = DesktopEntries.heuristicLookup(appId)
    	     let icon = Quickshell.iconPath(entry?.icon, true)
	     console.log(icon)
    	     if (icon) return icon

    	     let execPath = entry?.execString?.replace(/\/bin.*/, "")
	     console.log(execPath)
    	     if (!execPath) return ""

	     //Check that the app is installed with nix/guix
    	     if (execPath.startsWith("/nix/store/") || execPath.startsWith("/gnu/store/")) {
             const basePath = execPath
             const sizes = ["256x256", "128x128", "64x64", "48x48", "32x32", "24x24", "16x16"]

             for (const size of sizes) {
             	 const iconPath = `${basePath}/share/icons/hicolor/${size}/apps/${appId}.png`
            	 icon = Quickshell.iconPath(iconPath, true)
		 if (icon) return icon
       	     }
	     return ""
    }

    return ""
}
}
