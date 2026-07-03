function shQuote(value) {
    return "'" + String(value ?? "").replace(/'/g, "'\\''") + "'";
}

function dirname(path) {
    const idx = String(path ?? "").lastIndexOf("/");
    return idx > 0 ? path.substring(0, idx) : ".";
}

function sectionHeaderFor(includeLine) {
    const line = String(includeLine ?? "").trim();
    if (line.startsWith("require"))
        return "-- DMS Include Configs";
    if (line.startsWith("source"))
        return "# DMS Include Configs";
    return "// DMS Include Configs";
}

function managedIncludePatternFor(includeLine) {
    const line = String(includeLine ?? "").trim();
    if (line.startsWith("require"))
        return "require.*dms[.]";
    if (line.startsWith("source"))
        return "source.*dms/";
    return "include.*dms/";
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
        const sectionHeader = options.sectionHeader || sectionHeaderFor(include.includeLine);
        const managedIncludePattern = managedIncludePatternFor(include.includeLine);
        commands.push(`if ! grep -v '^[[:space:]]*\\(//\\|#\\|--\\)' ${shQuote(configFile)} 2>/dev/null | grep -q ${shQuote(include.grepPattern)}; then if grep -Fqx ${shQuote(sectionHeader)} ${shQuote(configFile)} 2>/dev/null || grep -v '^[[:space:]]*\\(//\\|#\\|--\\)' ${shQuote(configFile)} 2>/dev/null | grep -q ${shQuote(managedIncludePattern)}; then printf '%s\\n' ${shQuote(include.includeLine)} >> ${shQuote(configFile)}; elif [ -s ${shQuote(configFile)} ]; then printf '\\n%s\\n%s\\n' ${shQuote(sectionHeader)} ${shQuote(include.includeLine)} >> ${shQuote(configFile)}; else printf '%s\\n%s\\n' ${shQuote(sectionHeader)} ${shQuote(include.includeLine)} >> ${shQuote(configFile)}; fi; fi`);
    }

    return commands.join("; ");
}
