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

// Preserve unshifted symbols from the active layout
const SYMBOL_KEYSYM = {
    33: "exclam",
    34: "quotedbl",
    35: "numbersign",
    36: "dollar",
    37: "percent",
    38: "ampersand",
    40: "parenleft",
    41: "parenright",
    42: "asterisk",
    43: "plus",
    58: "colon",
    60: "less",
    62: "greater",
    63: "question",
    64: "at",
    94: "asciicircum",
    95: "underscore",
    123: "braceleft",
    124: "bar",
    125: "braceright",
    126: "asciitilde"
};

// Preserve the existing shifted-US physical-key mapping
const SHIFTED_US_FALLBACK = {
    33: "1",
    34: "Apostrophe",
    35: "3",
    36: "4",
    37: "5",
    38: "7",
    40: "9",
    41: "0",
    42: "8",
    43: "Equal",
    58: "Semicolon",
    60: "Comma",
    62: "Period",
    63: "Slash",
    64: "2",
    94: "6",
    95: "Minus",
    123: "BracketLeft",
    124: "Backslash",
    125: "BracketRight",
    126: "grave"
};

// Numpad (keypad) keys. Qt reuses the same Qt::Key_* values for the numpad and
// the main rows/nav cluster; only Qt.KeypadModifier distinguishes them. niri and
// the other compositors bind against the xkb KP_* keysym names, so we must emit
// those instead of the collapsed twin. With NumLock off the numpad sends the
// navigation keysyms (KP_Home, KP_End, ...); with NumLock on it sends KP_0..KP_9
// (handled by the digit range in xkbKeyFromQtKey). Operators/Enter are the same
// in both states.
const KP_MAP = {
    16777232: "KP_Home",
    16777235: "KP_Up",
    16777238: "KP_Prior",
    16777234: "KP_Left",
    16777227: "KP_Begin",
    16777236: "KP_Right",
    16777233: "KP_End",
    16777237: "KP_Down",
    16777239: "KP_Next",
    16777222: "KP_Insert",
    16777223: "KP_Delete",
    16777221: "KP_Enter",
    43: "KP_Add",
    45: "KP_Subtract",
    42: "KP_Multiply",
    47: "KP_Divide",
    46: "KP_Decimal"
};

// Shift+digit arrives as the layout's shifted symbol (latam Shift+0 is "="),
// but compositors match binds on the unshifted keysym, so resolve the digit
// row from the physical key instead. xkb keycodes 10..19 are evdev KEY_1..KEY_0.
function digitFromScanCode(scanCode) {
    if (!(scanCode >= 10 && scanCode <= 19))
        return "";
    return String((scanCode - 9) % 10);
}

function xkbKeyFromQtKey(qk, isKeypad, hasShift, scanCode) {
    if (isKeypad) {
        if (qk >= 48 && qk <= 57)
            return "KP_" + (qk - 48);
        if (KP_MAP[qk])
            return KP_MAP[qk];
    }
    if (hasShift) {
        const digit = digitFromScanCode(scanCode);
        if (digit)
            return digit;
    }
    if (!hasShift && SYMBOL_KEYSYM[qk])
        return SYMBOL_KEYSYM[qk];
    if (hasShift && SHIFTED_US_FALLBACK[qk])
        return SHIFTED_US_FALLBACK[qk];
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

function canonicalModifier(modifier) {
    var normalized = (modifier || "").toLowerCase();
    if (normalized === "control")
        return "ctrl";
    if (normalized === "win")
        return "super";
    return normalized;
}

function withSymbolicMod(mods, modKey) {
    var configuredMod = canonicalModifier(modKey);
    if (!configuredMod)
        return mods;
    return mods.map(function (modifier) {
        return canonicalModifier(modifier) === configuredMod ? "Mod" : modifier;
    });
}

function normalizeKeyCombo(keyCombo, modKey) {
    if (!keyCombo)
        return "";
    var configuredMod = canonicalModifier(modKey) || "super";
    return keyCombo.toLowerCase().replace(/\bmod\b/g, configuredMod).replace(/\bcontrol\b/g, "ctrl").replace(/\bwin\b/g, "super");
}

function getConflictingBinds(keyCombo, currentAction, allBinds, modKey) {
    if (!keyCombo)
        return [];
    var conflicts = [];
    var normalizedKey = normalizeKeyCombo(keyCombo, modKey);
    for (var i = 0; i < allBinds.length; i++) {
        var bind = allBinds[i];
        if (bind.action === currentAction)
            continue;
        for (var k = 0; k < bind.keys.length; k++) {
            if (normalizeKeyCombo(bind.keys[k].key, modKey) === normalizedKey) {
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

function qtKeyFromName(name) {
    var n = (name || "").toUpperCase();
    if (n.length === 1 && n >= "A" && n <= "Z")
        return Qt.Key_A + (n.charCodeAt(0) - 65);
    if (n.length === 1 && n >= "0" && n <= "9")
        return Qt.Key_0 + (n.charCodeAt(0) - 48);
    if (n.length >= 2 && n[0] === "F") {
        var f = parseInt(n.slice(1), 10);
        if (f >= 1 && f <= 12)
            return Qt.Key_F1 + (f - 1);
    }
    var named = {
        "SPACE": Qt.Key_Space,
        "TAB": Qt.Key_Tab,
        "RETURN": Qt.Key_Return,
        "ENTER": Qt.Key_Enter,
        "BACKSPACE": Qt.Key_Backspace,
        "DELETE": Qt.Key_Delete,
        "HOME": Qt.Key_Home,
        "END": Qt.Key_End,
        "UP": Qt.Key_Up,
        "DOWN": Qt.Key_Down,
        "LEFT": Qt.Key_Left,
        "RIGHT": Qt.Key_Right
    };
    return named[n] || 0;
}

function isModifierKey(qk) {
    return qk === Qt.Key_Control || qk === Qt.Key_Shift || qk === Qt.Key_Alt || qk === Qt.Key_Meta
        || qk === Qt.Key_NumLock || qk === Qt.Key_CapsLock || qk === Qt.Key_ScrollLock;
}

function eventMatchesCombo(event, combo) {
    if (!combo)
        return false;
    var parts = combo.split("+");
    var keyName = parts[parts.length - 1].trim().toUpperCase();
    var wantsShift = false;
    var hasCtrl = false;
    for (var i = 0; i < parts.length - 1; i++) {
        var mod = parts[i].trim().toLowerCase();
        if (mod === "shift")
            wantsShift = true;
        else if (mod === "ctrl" || mod === "control")
            hasCtrl = true;
        else
            return false;
    }
    if (hasCtrl && !(event.modifiers & Qt.ControlModifier))
        return false;
    if (event.modifiers & (Qt.AltModifier | Qt.MetaModifier))
        return false;
    if (((event.modifiers & Qt.ShiftModifier) !== 0) !== wantsShift)
        return false;
    return event.key === qtKeyFromName(keyName);
}
