.pragma library

function path(schema, key) {
    return "/" + schema.replace(/\./g, "/") + "/" + key;
}

// gsettings reaches whichever backend its own GLib links, not necessarily the
// dconf store GTK apps read, and it exits 0 either way.
function backendIsDconf() {
    return "[ \"${GSETTINGS_BACKEND:-dconf}\" = dconf ]";
}

function getCmd(schema, key) {
    return "{ { " + backendIsDconf() + " && dconf read " + path(schema, key) + " 2>/dev/null | grep .; } || gsettings get " + schema + " " + key + " 2>/dev/null; } | tr -d \"'\"";
}

function setCmd(schema, key, value) {
    return "{ " + backendIsDconf() + " && dconf write " + path(schema, key) + " \"'" + value + "'\" 2>/dev/null; } || gsettings set " + schema + " " + key + " '" + value + "'";
}
