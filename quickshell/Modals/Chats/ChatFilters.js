.pragma library

// Filter rules for the conversation list.
//
// A rule is deliberately small and general, because the things worth filtering
// differ per service and the shell cannot know them in advance:
//
//   { field, mode, value, action, enabled }
//
//   field   "tag" | "name" | "handle" | "provider"
//   mode    "is" | "contains" | "startsWith"
//   value   the text or tag to match
//   action  "hide" | "show"
//   enabled whether the rule participates at all
//
// Tags come from the providers themselves (archived, status, channel,
// broadcast, group) plus a few the host derives, so a WhatsApp status and a
// mail label are filtered by the same machinery.

var FIELDS = ["tag", "name", "handle", "provider"];
var MODES = ["is", "contains", "startsWith"];
var ACTIONS = ["hide", "show"];

function defaultRule() {
    return {
        "field": "tag",
        "mode": "is",
        "value": "",
        "action": "hide",
        "enabled": true
    };
}

function _valuesFor(chat, field) {
    switch (field) {
    case "tag":
        return chat.tags || [];
    case "handle":
        return chat.handles || [];
    case "provider":
        return [chat.provider || ""];
    default:
        return [chat.name || "", chat.subject || ""];
    }
}

function _matchesOne(candidate, mode, value) {
    var a = String(candidate || "").toLowerCase();
    var b = String(value || "").toLowerCase();
    if (b === "")
        return false;

    switch (mode) {
    case "contains":
        return a.indexOf(b) !== -1;
    case "startsWith":
        return a.indexOf(b) === 0;
    default:
        return a === b;
    }
}

// matches reports whether a rule applies to a conversation.
function matches(rule, chat) {
    if (!rule || rule.enabled === false || !chat)
        return false;

    var candidates = _valuesFor(chat, rule.field);
    for (var i = 0; i < candidates.length; i++) {
        if (_matchesOne(candidates[i], rule.mode, rule.value))
            return true;
    }
    return false;
}

// apply runs every rule over a conversation list.
//
// A "show" rule wins over a "hide" one, so a broad hide can be carved out
// without having to express the exception as a negation -- hide everything
// tagged archived, but show the one archived chat that still matters.
function apply(chats, rules) {
    if (!rules || rules.length === 0)
        return chats;

    var active = [];
    for (var r = 0; r < rules.length; r++) {
        if (rules[r] && rules[r].enabled !== false && String(rules[r].value || "") !== "")
            active.push(rules[r]);
    }
    if (active.length === 0)
        return chats;

    var out = [];
    for (var i = 0; i < chats.length; i++) {
        var chat = chats[i];
        var hidden = false;
        var forced = false;

        for (var j = 0; j < active.length; j++) {
            if (!matches(active[j], chat))
                continue;
            if (active[j].action === "show")
                forced = true;
            else
                hidden = true;
        }

        if (!hidden || forced)
            out.push(chat);
    }
    return out;
}

// describe renders a rule as a sentence, for the settings list.
function describe(rule) {
    if (!rule)
        return "";

    var verb = rule.action === "show" ? "Show" : "Hide";
    var mode = rule.mode === "contains" ? "contains" : (rule.mode === "startsWith" ? "starts with" : "is");

    if (rule.field === "tag" && rule.mode === "is")
        return verb + " conversations tagged " + rule.value;

    return verb + " when " + rule.field + " " + mode + " " + rule.value;
}
