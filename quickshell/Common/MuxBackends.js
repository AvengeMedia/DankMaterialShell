.pragma library

// Terminal multiplexer backends for the mux launcher. Each command is an argv
// array. attach and create run inside the user's terminal; the rest run
// headless. rename is optional: backends without it hide the rename action.
// Parsers turn `list` output into [{ name, windows, attached }].

function parseTmux(output) {
    return output.trim().split("\n").map(line => line.trim().split("|")).filter(parts => parts.length >= 3 && parts[0]).map(parts => ({
        name: parts[0],
        windows: parts[1],
        attached: parts[2] === "1"
    }));
}

function parseZellij(output) {
    return output.trim().split("\n").map(line => line.trim()).filter(line => line).map(line => {
        const bracketIdx = line.indexOf(" [");
        return {
            name: (bracketIdx > 0 ? line.substring(0, bracketIdx) : line).trim(),
            windows: "N/A",
            attached: !line.includes("(EXITED")
        };
    });
}

function parseHerdr(output) {
    return (JSON.parse(output).sessions ?? []).map(session => ({
        name: session.name,
        windows: "N/A",
        attached: session.running === true
    }));
}

// var, not const: QML only exposes var and function bindings from .js libraries
var BACKENDS = {
    tmux: {
        displayName: "Tmux",
        list: ["tmux", "list-sessions", "-F", "#{session_name}|#{session_windows}|#{session_attached}"],
        parse: parseTmux,
        attach: name => ["tmux", "attach", "-t", name],
        create: name => ["tmux", "new-session", "-s", name],
        kill: name => ["tmux", "kill-session", "-t", name],
        rename: (oldName, newName) => ["tmux", "rename-session", "-t", oldName, newName]
    },
    zellij: {
        displayName: "Zellij",
        list: ["zellij", "list-sessions", "--no-formatting"],
        parse: parseZellij,
        attach: name => ["zellij", "attach", name],
        create: name => ["zellij", "-s", name],
        kill: name => ["zellij", "kill-session", name]
    },
    herdr: {
        displayName: "Herdr",
        list: ["herdr", "session", "list", "--json"],
        parse: parseHerdr,
        attach: name => ["herdr", "session", "attach", name],
        create: name => ["herdr", "--session", name],
        // stop, not delete: the session stays listed so it can be reattached
        kill: name => ["herdr", "session", "stop", name]
    }
};

// filter is a comma separated list of exact names or /regex/ patterns.
function isSessionExcluded(name, filter) {
    return filter.split(",").map(pattern => pattern.trim()).filter(pattern => pattern).some(pattern => {
        if (pattern.startsWith("/") && pattern.endsWith("/") && pattern.length > 2) {
            try {
                return new RegExp(pattern.slice(1, -1)).test(name);
            } catch (e) {
                return false;
            }
        }
        return name.toLowerCase() === pattern.toLowerCase();
    });
}
