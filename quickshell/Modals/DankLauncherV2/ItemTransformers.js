.pragma library

    .import "ControllerUtils.js" as Utils

function transformApp(app, override, defaultActions, primaryActionLabel) {
    var appId = app.id || app.execString || app.exec || "";

    var actions = [];
    if (app.actions && app.actions.length > 0) {
        for (var i = 0; i < app.actions.length; i++) {
            actions.push({
                name: app.actions[i].name,
                icon: "play_arrow",
                actionData: app.actions[i]
            });
        }
    }

    return {
        id: appId,
        type: "app",
        name: override?.name || app.name || "",
        subtitle: override?.comment || app.comment || "",
        icon: override?.icon || app.icon || "application-x-executable",
        iconType: "image",
        section: "apps",
        data: app,
        keywords: app.keywords || [],
        actions: actions,
        primaryAction: {
            name: primaryActionLabel,
            icon: "open_in_new",
            action: "launch"
        },
        _hName: "",
        _hSub: "",
        _hRich: false,
        _preScored: undefined
    };
}

function transformCoreApp(app, openLabel) {
    var iconName = "apps";
    var iconType = "material";

    if (app.icon) {
        if (app.icon.startsWith("svg+corner:")) {
            iconType = "composite";
        } else if (app.icon.startsWith("material:")) {
            iconName = app.icon.substring(9);
        } else {
            iconName = app.icon;
            iconType = "image";
        }
    }

    return {
        id: app.builtInPluginId || app.action || "",
        type: "app",
        name: app.name || "",
        subtitle: app.comment || "",
        icon: iconName,
        iconType: iconType,
        iconFull: app.icon,
        section: "apps",
        data: app,
        isCore: true,
        actions: [],
        primaryAction: {
            name: openLabel,
            icon: "open_in_new",
            action: "launch"
        },
        _hName: "",
        _hSub: "",
        _hRich: false,
        _preScored: undefined
    };
}

function transformBuiltInLauncherItem(item, pluginId, openLabel) {
    var rawIcon = item.icon || "extension";
    var icon = Utils.stripIconPrefix(rawIcon);
    var iconType = item.iconType;
    if (!iconType) {
        if (rawIcon.startsWith("material:"))
            iconType = "material";
        else if (rawIcon.startsWith("unicode:"))
            iconType = "unicode";
        else
            iconType = "image";
    }

    return {
        id: item.action || "",
        type: "plugin",
        name: item.name || "",
        subtitle: item.comment || "",
        icon: icon,
        iconType: iconType,
        section: "plugin_" + pluginId,
        data: item,
        pluginId: pluginId,
        isBuiltInLauncher: true,
        keywords: item.keywords || [],
        actions: [],
        primaryAction: {
            name: openLabel,
            icon: "open_in_new",
            action: "execute"
        },
        _hName: "",
        _hSub: "",
        _hRich: false,
        _preScored: item._preScored
    };
}

function transformFileResult(file, openLabel, openFolderLabel, copyPathLabel, openTerminalLabel) {
    var filename = file.path ? file.path.split("/").pop() : "";
    var dirname = file.path ? file.path.substring(0, file.path.lastIndexOf("/")) : "";
    var isDir = file.is_dir || false;

    var actions = [];
    if (isDir) {
        if (openTerminalLabel) {
            actions.push({
                name: openTerminalLabel,
                icon: "terminal",
                action: "open_terminal"
            });
        }
    } else {
        actions.push({
            name: openFolderLabel,
            icon: "folder_open",
            action: "open_folder"
        });
    }
    actions.push({
        name: copyPathLabel,
        icon: "content_copy",
        action: "copy_path"
    });

    return {
        id: file.path || "",
        type: "file",
        name: filename,
        subtitle: dirname,
        icon: isDir ? "folder" : Utils.getFileIcon(filename),
        iconType: "material",
        section: "files",
        data: file,
        actions: actions,
        primaryAction: {
            name: openLabel,
            icon: "open_in_new",
            action: "open"
        },
        _hName: "",
        _hSub: "",
        _hRich: false,
        _preScored: undefined
    };
}

function transformPluginItem(item, pluginId, selectLabel) {
    var rawIcon = item.icon || "extension";
    var icon = Utils.stripIconPrefix(rawIcon);
    var iconType = item.iconType;
    if (!iconType) {
        if (rawIcon.startsWith("material:"))
            iconType = "material";
        else if (rawIcon.startsWith("unicode:"))
            iconType = "unicode";
        else
            iconType = "image";
    }

    return {
        id: item.id || item.name || "",
        type: "plugin",
        name: item.name || "",
        subtitle: item.comment || item.description || "",
        icon: icon,
        iconType: iconType,
        section: "plugin_" + pluginId,
        data: item,
        pluginId: pluginId,
        keywords: item.keywords || [],
        actions: item.actions || [],
        primaryAction: item.primaryAction || {
            name: selectLabel,
            icon: "check",
            action: "execute"
        },
        _hName: "",
        _hSub: "",
        _hRich: false,
        _preScored: item._preScored
    };
}

function createPluginBrowseItem(pluginId, plugin, trigger, isBuiltIn, isAllowed, browseLabel, triggerLabel, noTriggerLabel) {
    var rawIcon = isBuiltIn ? (plugin.cornerIcon || "extension") : (plugin.icon || "extension");
    return {
        id: "browse_" + pluginId,
        type: "plugin_browse",
        name: plugin.name || pluginId,
        subtitle: trigger ? triggerLabel.replace("%1", trigger) : noTriggerLabel,
        icon: isBuiltIn ? rawIcon : Utils.stripIconPrefix(rawIcon),
        iconType: isBuiltIn ? "material" : Utils.detectIconType(rawIcon),
        section: "browse_plugins",
        data: {
            pluginId: pluginId,
            plugin: plugin,
            isBuiltIn: isBuiltIn
        },
        actions: [
            {
                name: "All",
                icon: isAllowed ? "visibility" : "visibility_off",
                action: "toggle_all_visibility"
            }
        ],
        primaryAction: {
            name: browseLabel,
            icon: "arrow_forward",
            action: "browse_plugin"
        },
        _hName: "",
        _hSub: "",
        _hRich: false,
        _preScored: undefined
    };
}
