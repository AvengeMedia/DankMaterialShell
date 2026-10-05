pragma Singleton

import Quickshell

Singleton {
    readonly property string domain: "danklinux.com"
    readonly property string web: "https://" + domain
    readonly property string docs: web + "/docs"
    readonly property string api: "https://api." + domain
    readonly property string plugins: "https://plugins." + domain
}
