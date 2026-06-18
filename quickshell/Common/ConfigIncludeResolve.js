function shQuote(value) {
    return "'" + String(value ?? "").replace(/'/g, "'\\''") + "'";
}

function dirname(path) {
    const idx = String(path ?? "").lastIndexOf("/");
    return idx > 0 ? path.substring(0, idx) : ".";
}

function buildRepairScript(options) {
    const configFile = options.configFile;
    const backupFile = options.backupFile;
    const fragments = options.fragmentFiles || (options.fragmentFile ? [options.fragmentFile] : []);
    const includes = options.includes || [{
                grepPattern: options.grepPattern,
                includeLine: options.includeLine
            }];

    const commands = [];
    if (backupFile)
        commands.push(`cp ${shQuote(configFile)} ${shQuote(backupFile)} 2>/dev/null || true`);

    const dirs = {};
    for (const fragment of fragments)
        dirs[dirname(fragment)] = true;
    for (const dir in dirs)
        commands.push(`mkdir -p ${shQuote(dir)}`);
    if (fragments.length > 0)
        commands.push("touch " + fragments.map(shQuote).join(" "));

    for (const include of includes) {
        if (!include.grepPattern || !include.includeLine)
            continue;
        commands.push(`if ! grep -v '^[[:space:]]*\\(//\\|#\\|--\\)' ${shQuote(configFile)} 2>/dev/null | grep -q ${shQuote(include.grepPattern)}; then echo '' >> ${shQuote(configFile)} && printf '%s\\n' ${shQuote(include.includeLine)} >> ${shQuote(configFile)}; fi`);
    }

    return commands.join("; ");
}
