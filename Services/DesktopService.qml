pragma Singleton

pragma ComponentBehavior: Bound

import QtQuick
import Quickshell
import Quickshell.Io

Singleton {
    id: root
    function resolveIconPath(moddedAppId) {
    	     const entry = DesktopEntries.heuristicLookup(moddedAppId)
    	     const appIds = [moddedAppId, moddedAppId.toLowerCase()];

    	     const lastPart = moddedAppId.split('.').pop();
    	     if (lastPart && lastPart !== moddedAppId) {
                  appIds.push(lastPart);

        	  const firstChar = lastPart.charAt(0);
        	  const rest = lastPart.slice(1);
        	  let toggled;

        	  if (firstChar === firstChar.toLowerCase()) {
            	     toggled = firstChar.toUpperCase() + rest;
        	  } else {
            	     toggled = firstChar.toLowerCase() + rest;
        	  }

        	  if (toggled !== lastPart) {
            	     appIds.push(toggled);
        	  }
    	     }
	     for (const appId of appIds){
    	     let icon = Quickshell.iconPath(entry?.icon, true)
	     console.log(icon)
    	     if (icon && icon !== "") return icon

    	     let execPath = entry?.execString?.replace(/\/bin.*/, "")
	     console.log(execPath)
    	     if (!execPath) continue

	     //Check that the app is installed with nix/guix
    	     if (execPath.startsWith("/nix/store/") || execPath.startsWith("/gnu/store/")) {
             const basePath = execPath
             const sizes = ["256x256", "128x128", "64x64", "48x48", "32x32", "24x24", "16x16"]

	     let iconPath = `${basePath}/share/icons/hicolor/scalable/apps/${appId}.svg`
            	 icon = Quickshell.iconPath(iconPath, true)
		 console.log(icon)
		 if (icon && icon !== "") return icon

             for (const size of sizes) {
             	 iconPath = `${basePath}/share/icons/hicolor/${size}/apps/${appId}.png`
            	 icon = Quickshell.iconPath(iconPath, true)
		 console.log(icon)
		 if (icon && icon !== "") return icon
       	     }
	     }
    }

    return ""
}
}
