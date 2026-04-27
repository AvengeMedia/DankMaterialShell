.pragma library

function stripHtmlTags(html) {
    if (!html)
        return "";
    return String(html)
        .replace(/<[^>]+>/g, "")
        .replace(/&nbsp;/g, " ")
        .replace(/&amp;/g, "&")
        .replace(/&lt;/g, "<")
        .replace(/&gt;/g, ">")
        .replace(/&quot;/g, "\"")
        .replace(/&#039;/g, "'");
}

function elideRichText(html, visibleBudget) {
    if (!html)
        return "";
    if (visibleBudget <= 0)
        return "";

    var out = "";
    var visible = 0;
    var i = 0;
    var openTags = [];
    var len = html.length;

    while (i < len && visible < visibleBudget) {
        var ch = html.charAt(i);
        if (ch === "<") {
            var end = html.indexOf(">", i);
            if (end < 0)
                break;
            var tag = html.substring(i, end + 1);
            out += tag;
            var isClose = tag.charAt(1) === "/";
            var match = tag.match(/^<\/?([a-zA-Z]+)/);
            var name = match ? match[1] : "";
            if (isClose) {
                if (openTags.length > 0 && openTags[openTags.length - 1] === name)
                    openTags.pop();
            } else if (!tag.endsWith("/>") && name) {
                openTags.push(name);
            }
            i = end + 1;
        } else if (ch === "&") {
            var eend = html.indexOf(";", i);
            if (eend < 0 || eend - i > 6) {
                out += "&amp;";
                visible++;
                i++;
            } else {
                out += html.substring(i, eend + 1);
                visible++;
                i = eend + 1;
            }
        } else {
            out += ch;
            visible++;
            i++;
        }
    }

    while (i < len && html.charAt(i) === "<") {
        var tend = html.indexOf(">", i);
        if (tend < 0)
            break;
        var ttag = html.substring(i, tend + 1);
        out += ttag;
        var tisClose = ttag.charAt(1) === "/";
        var tmatch = ttag.match(/^<\/?([a-zA-Z]+)/);
        var tname = tmatch ? tmatch[1] : "";
        if (tisClose) {
            if (openTags.length > 0 && openTags[openTags.length - 1] === tname)
                openTags.pop();
        } else if (!ttag.endsWith("/>") && tname) {
            openTags.push(tname);
        }
        i = tend + 1;
    }

    if (i < len) {
        out = out.replace(/\s+$/, "");
        while (openTags.length > 0)
            out += "</" + openTags.pop() + ">";
        out += "…";
    } else {
        while (openTags.length > 0)
            out += "</" + openTags.pop() + ">";
    }

    return out;
}
