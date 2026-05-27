.pragma library

const KEY_MAP = {
    16777234: "Left",
    16777236: "Right",
    16777235: "Up",
    16777237: "Down",
    44: "Comma",
    46: "Period",
    47: "Slash",
    59: "Semicolon",
    39: "Apostrophe",
    91: "BracketLeft",
    93: "BracketRight",
    92: "Backslash",
    45: "Minus",
    61: "Equal",
    96: "grave",
    32: "space",
    16777225: "Print",
    16777226: "Print",
    16777220: "Return",
    16777221: "Return",
    16777217: "Tab",
    16777219: "BackSpace",
    16777223: "Delete",
    16777222: "Insert",
    16777232: "Home",
    16777233: "End",
    16777238: "Page_Up",
    16777239: "Page_Down",
    16777216: "Escape",
    16777252: "Caps_Lock",
    16777253: "Num_Lock",
    16777254: "Scroll_Lock",
    16777224: "Pause",
    16777330: "XF86AudioRaiseVolume",
    16777328: "XF86AudioLowerVolume",
    16777329: "XF86AudioMute",
    16842808: "XF86AudioMicMute",
    16777344: "XF86AudioPlay",
    16777345: "XF86AudioStop",
    16777346: "XF86AudioPrev",
    16777347: "XF86AudioNext",
    16777348: "XF86AudioPause",
    16777349: "XF86AudioMedia",
    16777350: "XF86AudioRecord",
    16842798: "XF86MonBrightnessUp",
    16777394: "XF86MonBrightnessUp",
    16842797: "XF86MonBrightnessDown",
    16777395: "XF86MonBrightnessDown",
    16842800: "XF86KbdBrightnessUp",
    16842799: "XF86KbdBrightnessDown",
    16842796: "XF86PowerOff",
    16842803: "XF86Sleep",
    16842804: "XF86WakeUp",
    16842802: "XF86Eject",
    16842791: "XF86Calculator",
    16842806: "XF86Explorer",
    16777360: "XF86HomePage",
    16842794: "XF86HomePage",
    16777362: "XF86Search",
    16777426: "XF86Search",
    16777376: "XF86Mail",
    16777427: "XF86Mail",
    16777377: "XF86AudioMedia",
    16777419: "XF86Calculator",
    16777429: "XF86Explorer",
    16777442: "XF86Launch0",
    16777443: "XF86Launch1",
    33: "1",
    64: "2",
    35: "3",
    36: "4",
    37: "5",
    94: "6",
    38: "7",
    42: "8",
    40: "9",
    41: "0",
    60: "Comma",
    62: "Period",
    63: "Slash",
    58: "Semicolon",
    34: "Apostrophe",
    123: "BracketLeft",
    125: "BracketRight",
    124: "Backslash",
    95: "Minus",
    43: "Equal",
    126: "grave",
    196: "Adiaeresis",
    214: "Odiaeresis",
    220: "Udiaeresis",
    228: "adiaeresis",
    246: "odiaeresis",
    252: "udiaeresis",
    223: "ssharp",
    201: "Eacute",
    233: "eacute",
    200: "Egrave",
    232: "egrave",
    202: "Ecircumflex",
    234: "ecircumflex",
    203: "Ediaeresis",
    235: "ediaeresis",
    192: "Agrave",
    224: "agrave",
    194: "Acircumflex",
    226: "acircumflex",
    199: "Ccedilla",
    231: "ccedilla",
    206: "Icircumflex",
    238: "icircumflex",
    207: "Idiaeresis",
    239: "idiaeresis",
    212: "Ocircumflex",
    244: "ocircumflex",
    217: "Ugrave",
    249: "ugrave",
    219: "Ucircumflex",
    251: "ucircumflex",
    209: "Ntilde",
    241: "ntilde",
    191: "questiondown",
    161: "exclamdown"
};

function xkbKeyFromQtKey(qk) {
    if (qk >= 65 && qk <= 90)
        return String.fromCharCode(qk);
    if (qk >= 97 && qk <= 122)
        return String.fromCharCode(qk - 32);
    if (qk >= 48 && qk <= 57)
        return String.fromCharCode(qk);
    if (qk >= 16777264 && qk <= 16777298)
        return "F" + (qk - 16777264 + 1);
    if (qk >= 16777378 && qk <= 16777387)
        return "XF86Launch" + (qk - 16777378);
    if (qk >= 16777388 && qk <= 16777393)
        return "XF86Launch" + String.fromCharCode(65 + qk - 16777388);
    return KEY_MAP[qk] || "";
}

function modsFromEvent(mods) {
    var result = [];
    if (mods & 0x10000000)
        result.push("Super");
    if (mods & 0x08000000)
        result.push("Alt");
    if (mods & 0x04000000)
        result.push("Ctrl");
    if (mods & 0x02000000)
        result.push("Shift");
    return result;
}

function formatToken(mods, key) {
    return (mods.length ? mods.join("+") + "+" : "") + key;
}

function normalizeKeyCombo(keyCombo) {
    if (!keyCombo)
        return "";
    return keyCombo.toLowerCase().replace(/\bmod\b/g, "super").replace(/\bsuper\b/g, "super");
}

function getConflictingBinds(keyCombo, currentAction, allBinds) {
    if (!keyCombo)
        return [];
    var conflicts = [];
    var normalizedKey = normalizeKeyCombo(keyCombo);
    for (var i = 0; i < allBinds.length; i++) {
        var bind = allBinds[i];
        if (bind.action === currentAction)
            continue;
        for (var k = 0; k < bind.keys.length; k++) {
            if (normalizeKeyCombo(bind.keys[k].key) === normalizedKey) {
                conflicts.push({
                    action: bind.action,
                    desc: bind.desc || bind.action
                });
                break;
            }
        }
    }
    return conflicts;
}
