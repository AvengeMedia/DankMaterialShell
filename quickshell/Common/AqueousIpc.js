function socketPath(path, runtime) {
    if (!runtime.startsWith("/") || runtime.endsWith("/") || !path.startsWith(runtime + "/aqueous/"))
        return false;
    if (/[\r\n\u0000]/.test(path) || path.includes("//") || path.split("/").some(part => part === "." || part === ".."))
        return false;
    return /^\/aqueous\/[^/]+\/ipc\.sock$/.test(path.slice(runtime.length));
}

function byteLength(text) {
    return encodeURIComponent(text).replace(/%[0-9A-F]{2}/g, "x").length;
}

function object(value) {
    return value !== null && typeof value === "object" && !Array.isArray(value);
}

function decimal(value) {
    return typeof value === "string" && /^[0-9]{1,20}$/.test(value);
}

function nextId(value) {
    const digits = value.split("");
    for (let i = digits.length - 1; i >= 0; i--) {
        if (digits[i] !== "9") {
            digits[i] = String(Number(digits[i]) + 1);
            return digits.join("");
        }
        digits[i] = "0";
    }
    if (digits.length === 20)
        throw new Error("IPC request IDs exhausted");
    return "1" + digits.join("");
}

function hello(value) {
    if (!object(value) || value.schema !== 1 || typeof value.session !== "string" || !/^[0-9a-f]{32}$/.test(value.session) || value.max_pending_requests !== 1)
        throw new Error("unsupported: Aqueous IPC hello");
    const limits = {max_request_bytes: 65536, max_frame_bytes: 4259840, max_batch_bytes: 4194304};
    for (const key of Object.keys(limits)) {
        if (!Number.isInteger(value[key]) || value[key] <= 0 || value[key] > limits[key])
            throw new Error("unsupported: IPC " + key);
    }
    if (!object(value.capabilities))
        throw new Error("unsupported: IPC capabilities");
    for (const name of ["state", "commands", "keyboard", "overview", "shortcut_inhibition"]) {
        if (typeof value.capabilities[name] !== "boolean")
            throw new Error("unsupported: missing capability " + name);
    }
    if (!value.capabilities.state)
        throw new Error("unsupported: shell state");
    return value;
}

function envelope(line, limit) {
    if (byteLength(line) > limit)
        throw new Error("IPC frame exceeds size bound");
    let depth = 0, quoted = false, escaped = false;
    for (const c of line) {
        if (quoted) {
            if (escaped) escaped = false;
            else if (c === "\\") escaped = true;
            else if (c === '"') quoted = false;
            continue;
        }
        if (c === '"') quoted = true;
        if (c === "{" || c === "[") depth++;
        if (c === "}" || c === "]") depth--;
        if (depth > 32)
            throw new Error("IPC nesting exceeds limit");
    }
    const value = JSON.parse(line);
    if (!object(value) || value.ipc !== 1)
        throw new Error("unsupported: IPC envelope");
    return value;
}

function response(value, id) {
    if (value.id !== id || !decimal(value.id) || typeof value.ok !== "boolean" || value.event !== undefined)
        throw new Error("invalid IPC response correlation");
    if (value.ok) {
        if (!object(value.result) || value.error !== undefined)
            throw new Error("invalid IPC result");
        return "";
    }
    if (!object(value.error) || typeof value.error.code !== "string" || !value.error.code || value.error.code.length > 128 || typeof value.error.message !== "string" || byteLength(value.error.message) > 4096 || value.result !== undefined)
        throw new Error("malformed IPC error");
    return value.error.code + ": " + value.error.message;
}
