#!/usr/bin/env python3
"""Format staged .qml files using qmlls (the Qt QML language server).

Per file:
  1. Speak LSP over stdio to qmlls: initialize -> didOpen -> formatting,
     apply returned edits, save, `git add`.
  2. Run qmllint on the formatted file and warn about unused imports
     (informational only — never modifies files).

Refuses to run if any staged file also has unstaged changes, since `git add`
would silently absorb those into the commit.
"""

import json
import os
import shutil
import subprocess
import sys
from pathlib import Path


TAB_SIZE = 4
QMLLS_CANDIDATES = ["qmlls6", "qmlls"]
QMLLINT_CANDIDATES = ["/usr/lib/qt6/bin/qmllint", "qmllint6", "qmllint"]


def git(*args, cwd=None):
    return subprocess.run(
        ["git", *args],
        cwd=cwd,
        capture_output=True,
        text=True,
        check=True,
    ).stdout


def repo_root():
    return Path(git("rev-parse", "--show-toplevel").strip())


def staged_qml_files(root):
    out = git("diff", "--cached", "--name-only", "--diff-filter=ACMR", cwd=root)
    return [root / line for line in out.splitlines() if line.endswith(".qml")]


def has_unstaged_changes(root, file):
    rel = str(file.relative_to(root))
    return git("diff", "--name-only", "--", rel, cwd=root).strip() != ""


def find_qmlls():
    for name in QMLLS_CANDIDATES:
        path = shutil.which(name)
        if path:
            return path
    return None


def find_qmllint():
    for candidate in QMLLINT_CANDIDATES:
        path = candidate if "/" in candidate and Path(candidate).is_file() else shutil.which(candidate)
        if not path:
            continue
        try:
            result = subprocess.run([path, "--help"], capture_output=True, text=True, timeout=5)
        except (subprocess.TimeoutExpired, OSError):
            continue
        if "--json" in result.stdout:
            return path
    return None


def lint_unused_imports(qmllint, file):
    """Return a list of (line, message, suspect) for unused-import warnings.

    `suspect` is True when the same line also has an import-resolution failure,
    which often means the warning is a false positive (qmllint couldn't find
    the module, so its 'unused' verdict is unreliable).
    """
    result = subprocess.run(
        [qmllint, "--unused-imports", "warning", "--json", "-", str(file)],
        capture_output=True, text=True,
    )
    try:
        data = json.loads(result.stdout)
    except json.JSONDecodeError:
        return []

    files = data.get("files", [])
    if not files:
        return []
    warnings = files[0].get("warnings", [])

    failed_lines = {w["line"] for w in warnings if w.get("id") == "import" and "line" in w}
    findings = []
    for w in warnings:
        if w.get("id") != "unused-imports" or "line" not in w:
            continue
        line = w["line"]
        findings.append((line, w.get("message", "Unused import"), line in failed_lines))
    findings.sort(key=lambda x: x[0])
    return findings


class LspClient:
    def __init__(self, command):
        self.proc = subprocess.Popen(
            command,
            stdin=subprocess.PIPE,
            stdout=subprocess.PIPE,
            stderr=subprocess.DEVNULL,
        )
        self._next_id = 1

    def _send(self, msg):
        body = json.dumps(msg).encode("utf-8")
        header = f"Content-Length: {len(body)}\r\n\r\n".encode("ascii")
        self.proc.stdin.write(header + body)
        self.proc.stdin.flush()

    def _read(self):
        headers = {}
        while True:
            line = self.proc.stdout.readline()
            if not line:
                raise RuntimeError("qmlls closed unexpectedly")
            line = line.decode("ascii").rstrip("\r\n")
            if line == "":
                break
            key, _, value = line.partition(":")
            headers[key.strip().lower()] = value.strip()
        length = int(headers["content-length"])
        body = b""
        while len(body) < length:
            chunk = self.proc.stdout.read(length - len(body))
            if not chunk:
                raise RuntimeError("qmlls closed mid-message")
            body += chunk
        return json.loads(body)

    def request(self, method, params):
        req_id = self._next_id
        self._next_id += 1
        self._send({"jsonrpc": "2.0", "id": req_id, "method": method, "params": params})
        while True:
            msg = self._read()
            if msg.get("id") == req_id and ("result" in msg or "error" in msg):
                if "error" in msg:
                    raise RuntimeError(f"LSP {method} error: {msg['error']}")
                return msg.get("result")
            if "id" in msg and "method" in msg:
                # Server-to-client request — reply with null so it doesn't stall.
                self._send({"jsonrpc": "2.0", "id": msg["id"], "result": None})

    def notify(self, method, params):
        self._send({"jsonrpc": "2.0", "method": method, "params": params})

    def shutdown(self):
        try:
            self.request("shutdown", None)
            self.notify("exit", None)
        except Exception:
            pass
        try:
            self.proc.wait(timeout=2)
        except subprocess.TimeoutExpired:
            self.proc.kill()


def apply_edits(text, edits):
    """Apply LSP TextEdits (non-overlapping) to text, end-first."""
    if not edits:
        return text

    lines = text.splitlines(keepends=True)
    line_starts = [0]
    for line in lines:
        line_starts.append(line_starts[-1] + len(line))

    def offset(pos):
        line = pos["line"]
        if line >= len(line_starts):
            return len(text)
        return min(line_starts[line] + pos["character"], len(text))

    sorted_edits = sorted(
        edits,
        key=lambda e: (e["range"]["start"]["line"], e["range"]["start"]["character"]),
        reverse=True,
    )
    for edit in sorted_edits:
        start = offset(edit["range"]["start"])
        end = offset(edit["range"]["end"])
        text = text[:start] + edit["newText"] + text[end:]
    return text


def main():
    root = repo_root()
    files = staged_qml_files(root)
    if not files:
        print("No staged .qml files.")
        return 0

    dirty = [f for f in files if has_unstaged_changes(root, f)]
    if dirty:
        print("Refusing to format: staged files have unstaged changes:", file=sys.stderr)
        for f in dirty:
            print(f"  {f.relative_to(root)}", file=sys.stderr)
        print("\nStash or stage those changes first.", file=sys.stderr)
        return 1

    qmlls = find_qmlls()
    if not qmlls:
        print(f"qmlls not found (tried: {', '.join(QMLLS_CANDIDATES)})", file=sys.stderr)
        return 1

    qmllint = find_qmllint()
    if not qmllint:
        print("warning: qmllint with --json not found; skipping unused-import checks", file=sys.stderr)

    client = LspClient([qmlls])
    changed = 0
    unused_by_file = {}
    try:
        client.request("initialize", {
            "processId": os.getpid(),
            "rootUri": root.as_uri(),
            "workspaceFolders": [{"uri": root.as_uri(), "name": root.name}],
            "capabilities": {
                "textDocument": {
                    "formatting": {"dynamicRegistration": False},
                    "synchronization": {"dynamicRegistration": False},
                },
            },
        })
        client.notify("initialized", {})

        for file in files:
            rel = file.relative_to(root)
            print(f"  {rel} ... ", end="", flush=True)

            original = file.read_text()
            uri = file.as_uri()

            client.notify("textDocument/didOpen", {
                "textDocument": {
                    "uri": uri,
                    "languageId": "qml",
                    "version": 1,
                    "text": original,
                },
            })

            edits = client.request("textDocument/formatting", {
                "textDocument": {"uri": uri},
                "options": {"tabSize": TAB_SIZE, "insertSpaces": True},
            })

            client.notify("textDocument/didClose", {"textDocument": {"uri": uri}})

            new_text = apply_edits(original, edits or [])
            if new_text == original:
                print("unchanged")
                continue

            file.write_text(new_text)
            git("add", "--", str(rel), cwd=root)
            changed += 1
            print("formatted & staged")

        if qmllint:
            for file in files:
                findings = lint_unused_imports(qmllint, file)
                if findings:
                    unused_by_file[file] = findings

        print(f"\n{changed} of {len(files)} file(s) changed.")

        if unused_by_file:
            print("\nUnused import warnings (informational, not auto-removed):")
            for file, findings in unused_by_file.items():
                rel = file.relative_to(root)
                for line, message, suspect in findings:
                    suffix = "  [suspect: import didn't resolve]" if suspect else ""
                    print(f"  {rel}:{line}  {message}{suffix}")

        return 0
    finally:
        client.shutdown()


if __name__ == "__main__":
    sys.exit(main())
