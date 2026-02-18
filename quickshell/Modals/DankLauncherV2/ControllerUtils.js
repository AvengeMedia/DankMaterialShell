.pragma library

function getFileIcon(filename) {
    var ext = filename.lastIndexOf(".") > 0 ? filename.substring(filename.lastIndexOf(".") + 1).toLowerCase() : "";

    switch (ext) {
        case "pdf":
            return "picture_as_pdf";
        case "doc":
        case "docx":
        case "odt":
            return "description";
        case "xls":
        case "xlsx":
        case "ods":
            return "table_chart";
        case "ppt":
        case "pptx":
        case "odp":
            return "slideshow";
        case "txt":
        case "md":
        case "rst":
            return "article";
        case "jpg":
        case "jpeg":
        case "png":
        case "gif":
        case "svg":
        case "webp":
            return "image";
        case "mp3":
        case "wav":
        case "flac":
        case "ogg":
            return "audio_file";
        case "mp4":
        case "mkv":
        case "avi":
        case "webm":
            return "video_file";
        case "zip":
        case "tar":
        case "gz":
        case "7z":
        case "rar":
            return "folder_zip";
        case "js":
        case "ts":
        case "py":
        case "rs":
        case "go":
        case "java":
        case "c":
        case "cpp":
        case "h":
            return "code";
        case "html":
        case "css":
        case "htm":
            return "web";
        case "json":
        case "xml":
        case "yaml":
        case "yml":
            return "data_object";
        case "sh":
        case "bash":
        case "zsh":
            return "terminal";
        default:
            return "insert_drive_file";
    }
}

function stripIconPrefix(iconName) {
    if (!iconName)
        return "extension";
    if (iconName.startsWith("unicode:"))
        return iconName.substring(8);
    if (iconName.startsWith("material:"))
        return iconName.substring(9);
    if (iconName.startsWith("image:"))
        return iconName.substring(6);
    return iconName;
}

function detectIconType(iconName) {
    if (!iconName)
        return "material";
    if (iconName.startsWith("unicode:"))
        return "unicode";
    if (iconName.startsWith("material:"))
        return "material";
    if (iconName.startsWith("image:"))
        return "image";
    if (iconName.indexOf("/") >= 0 || iconName.indexOf(".") >= 0)
        return "image";
    if (/^[a-z]+-[a-z]/.test(iconName.toLowerCase()))
        return "image";
    return "material";
}

function sortPluginIdsByOrder(pluginIds, order) {
    if (!order || order.length === 0)
        return pluginIds;
    var orderMap = {};
    for (var i = 0; i < order.length; i++)
        orderMap[order[i]] = i;
    return pluginIds.slice().sort(function (a, b) {
        var aOrder = orderMap[a] !== undefined ? orderMap[a] : 9999;
        var bOrder = orderMap[b] !== undefined ? orderMap[b] : 9999;
        return aOrder - bOrder;
    });
}

function sortPluginsOrdered(plugins, order) {
    if (!order || order.length === 0)
        return plugins;
    var orderMap = {};
    for (var i = 0; i < order.length; i++)
        orderMap[order[i]] = i;
    return plugins.sort(function (a, b) {
        var aOrder = orderMap[a.id] !== undefined ? orderMap[a.id] : 9999;
        var bOrder = orderMap[b.id] !== undefined ? orderMap[b.id] : 9999;
        return aOrder - bOrder;
    });
}
