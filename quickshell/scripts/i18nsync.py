#!/usr/bin/env python3

import sys
import json
import os
import subprocess
from pathlib import Path
from urllib import request, parse

REPO_ROOT = Path(__file__).parent.parent
EN_JSON = REPO_ROOT / "translations" / "en.json"
TEMPLATE_JSON = REPO_ROOT / "translations" / "template.json"
POEXPORTS_DIR = REPO_ROOT / "translations" / "poexports"
SYNC_STATE = REPO_ROOT / ".git" / "i18n_sync_state.json"

LANGUAGES = {
    "ja": "ja.json",
    "zh-Hans": "zh_CN.json",
    "zh-Hant": "zh_TW.json",
    "pt-br": "pt.json",
    "tr": "tr.json",
    "it": "it.json",
    "pl": "pl.json",
    "es": "es.json",
    "he": "he.json",
    "hu": "hu.json",
    "fa": "fa.json"
}

def error(msg):
    print(f"\033[91mError: {msg}\033[0m", file=sys.stderr)
    sys.exit(1)

def warn(msg):
    print(f"\033[93mWarning: {msg}\033[0m", file=sys.stderr)

def info(msg):
    print(f"\033[94m{msg}\033[0m")

def success(msg):
    print(f"\033[92m{msg}\033[0m")

def get_env_or_error(var):
    value = os.environ.get(var)
    if not value:
        error(f"{var} environment variable not set")
    return value

def poeditor_request(endpoint, data):
    url = f"https://api.poeditor.com/v2/{endpoint}"
    data_bytes = parse.urlencode(data).encode()
    req = request.Request(url, data=data_bytes, method="POST")

    try:
        with request.urlopen(req) as response:
            return json.loads(response.read().decode())
    except Exception as e:
        error(f"POEditor API request failed: {e}")

def extract_strings():
    info("Extracting strings from QML files...")
    extract_script = REPO_ROOT / "translations" / "extract_translations.py"

    if not extract_script.exists():
        error(f"Extract script not found: {extract_script}")

    result = subprocess.run([sys.executable, str(extract_script)], cwd=REPO_ROOT)
    if result.returncode != 0:
        error("String extraction failed")

    if not EN_JSON.exists():
        error(f"Extraction did not produce {EN_JSON}")

def normalize_json(file_path):
    if not file_path.exists():
        return {}
    with open(file_path) as f:
        return json.load(f)

def json_changed(file_path, new_data):
    old_data = normalize_json(file_path)
    return json.dumps(old_data, sort_keys=True) != json.dumps(new_data, sort_keys=True)

def upload_source_strings(api_token, project_id):
    if not EN_JSON.exists():
        warn("No en.json to upload")
        return False

    info("Uploading source strings to POEditor...")

    with open(EN_JSON, 'rb') as f:
        boundary = '----WebKitFormBoundary7MA4YWxkTrZu0gW'
        body = (
            f'--{boundary}\r\n'
            f'Content-Disposition: form-data; name="api_token"\r\n\r\n'
            f'{api_token}\r\n'
            f'--{boundary}\r\n'
            f'Content-Disposition: form-data; name="id"\r\n\r\n'
            f'{project_id}\r\n'
            f'--{boundary}\r\n'
            f'Content-Disposition: form-data; name="updating"\r\n\r\n'
            f'terms\r\n'
            f'--{boundary}\r\n'
            f'Content-Disposition: form-data; name="file"; filename="en.json"\r\n'
            f'Content-Type: application/json\r\n\r\n'
        ).encode() + f.read() + f'\r\n--{boundary}--\r\n'.encode()

    req = request.Request(
        'https://api.poeditor.com/v2/projects/upload',
        data=body,
        headers={'Content-Type': f'multipart/form-data; boundary={boundary}'}
    )

    try:
        with request.urlopen(req) as response:
            result = json.loads(response.read().decode())
    except Exception as e:
        error(f"Upload failed: {e}")

    if result.get('response', {}).get('status') != 'success':
        error(f"POEditor upload failed: {result}")

    terms = result.get('result', {}).get('terms', {})
    added = terms.get('added', 0)
    updated = terms.get('updated', 0)
    deleted = terms.get('deleted', 0)

    if added or updated or deleted:
        success(f"POEditor updated: {added} added, {updated} updated, {deleted} deleted")
        return True
    else:
        info("No changes uploaded to POEditor")
        return False

def download_translations(api_token, project_id):
    info("Downloading translations from POEditor...")

    POEXPORTS_DIR.mkdir(parents=True, exist_ok=True)
    any_changed = False

    for po_lang, filename in LANGUAGES.items():
        repo_file = POEXPORTS_DIR / filename

        info(f"Fetching {po_lang}...")

        export_resp = poeditor_request('projects/export', {
            'api_token': api_token,
            'id': project_id,
            'language': po_lang,
            'type': 'key_value_json'
        })

        if export_resp.get('response', {}).get('status') != 'success':
            warn(f"Export request failed for {po_lang}")
            continue

        url = export_resp.get('result', {}).get('url')
        if not url:
            warn(f"No export URL for {po_lang}")
            continue

        try:
            with request.urlopen(url) as response:
                new_data = json.loads(response.read().decode())
        except Exception as e:
            warn(f"Failed to download {po_lang}: {e}")
            continue

        if json_changed(repo_file, new_data):
            with open(repo_file, 'w') as f:
                json.dump(new_data, f, ensure_ascii=False, indent=2, sort_keys=True)
                f.write('\n')
            success(f"Updated {filename}")
            any_changed = True
        else:
            info(f"No changes for {filename}")

    return any_changed

def check_sync_status():
    api_token = get_env_or_error('POEDITOR_API_TOKEN')
    project_id = get_env_or_error('POEDITOR_PROJECT_ID')

    extract_strings()

    current_en = normalize_json(EN_JSON)

    if not SYNC_STATE.exists():
        return True

    with open(SYNC_STATE) as f:
        state = json.load(f)

    last_en = state.get('en_json', {})
    last_translations = state.get('translations', {})

    if json.dumps(current_en, sort_keys=True) != json.dumps(last_en, sort_keys=True):
        return True

    for po_lang, filename in LANGUAGES.items():
        repo_file = POEXPORTS_DIR / filename
        current_trans = normalize_json(repo_file)
        last_trans = last_translations.get(filename, {})

        if json.dumps(current_trans, sort_keys=True) != json.dumps(last_trans, sort_keys=True):
            return True

    export_resp = poeditor_request('projects/export', {
        'api_token': api_token,
        'id': project_id,
        'language': list(LANGUAGES.keys())[0],
        'type': 'key_value_json'
    })

    if export_resp.get('response', {}).get('status') == 'success':
        url = export_resp.get('result', {}).get('url')
        if url:
            try:
                with request.urlopen(url) as response:
                    remote_data = json.loads(response.read().decode())
                    first_file = POEXPORTS_DIR / list(LANGUAGES.values())[0]
                    local_data = normalize_json(first_file)

                    if json.dumps(remote_data, sort_keys=True) != json.dumps(local_data, sort_keys=True):
                        return True
            except:
                pass

    return False

def save_sync_state():
    state = {
        'en_json': normalize_json(EN_JSON),
        'translations': {}
    }

    for filename in LANGUAGES.values():
        repo_file = POEXPORTS_DIR / filename
        state['translations'][filename] = normalize_json(repo_file)

    SYNC_STATE.parent.mkdir(parents=True, exist_ok=True)
    with open(SYNC_STATE, 'w') as f:
        json.dump(state, f, indent=2)

def main():
    if len(sys.argv) < 2:
        error("Usage: i18nsync.py [check|sync|test|local]")

    command = sys.argv[1]

    if command == "test":
        info("Running in test mode (no POEditor upload/download)")
        extract_strings()

        current_en = normalize_json(EN_JSON)
        current_template = normalize_json(TEMPLATE_JSON)

        success(f"✓ Extracted {len(current_en)} terms")

        terms_with_context = sum(1 for entry in current_en if entry.get('context') and entry['context'] != entry['term'])
        if terms_with_context > 0:
            success(f"✓ Found {terms_with_context} terms with custom contexts")

        info("\nFiles generated:")
        info(f"  - {EN_JSON}")
        info(f"  - {TEMPLATE_JSON}")

        sys.exit(0)
    elif command == "check":
        try:
            if check_sync_status():
                error("i18n out of sync - run 'python3 scripts/i18nsync.py sync' first")
            else:
                success("i18n in sync")
                sys.exit(0)
        except SystemExit:
            raise
        except Exception as e:
            error(f"Check failed: {e}")

    elif command == "sync":
        api_token = get_env_or_error('POEDITOR_API_TOKEN')
        project_id = get_env_or_error('POEDITOR_PROJECT_ID')

        extract_strings()

        current_en = normalize_json(EN_JSON)
        staged_en = {}

        try:
            result = subprocess.run(
                ['git', 'show', f':{EN_JSON.relative_to(REPO_ROOT)}'],
                capture_output=True,
                text=True,
                cwd=REPO_ROOT
            )
            if result.returncode == 0:
                staged_en = json.loads(result.stdout)
        except:
            pass

        strings_changed = json.dumps(current_en, sort_keys=True) != json.dumps(staged_en, sort_keys=True)

        if strings_changed:
            upload_source_strings(api_token, project_id)
        else:
            info("No changes in source strings")

        translations_changed = download_translations(api_token, project_id)

        if strings_changed or translations_changed:
            subprocess.run(['git', 'add', 'translations/'], cwd=REPO_ROOT)
            save_sync_state()
            success("Sync complete - changes staged for commit")
        else:
            save_sync_state()
            info("Already in sync")

    elif command == "local":
        info("Updating en.json locally (no POEditor sync)")

        old_en = normalize_json(EN_JSON)
        old_terms = {entry['term']: entry for entry in old_en} if isinstance(old_en, list) else {}

        extract_strings()

        new_en = normalize_json(EN_JSON)
        new_terms = {entry['term']: entry for entry in new_en} if isinstance(new_en, list) else {}

        added = set(new_terms.keys()) - set(old_terms.keys())
        removed = set(old_terms.keys()) - set(new_terms.keys())

        if added:
            info(f"\n+{len(added)} new terms:")
            for term in sorted(added)[:20]:
                print(f"  + {term[:60]}...")
            if len(added) > 20:
                print(f"  ... and {len(added) - 20} more")

        if removed:
            info(f"\n-{len(removed)} removed terms:")
            for term in sorted(removed)[:20]:
                print(f"  - {term[:60]}...")
            if len(removed) > 20:
                print(f"  ... and {len(removed) - 20} more")

        success(f"\n✓ {len(new_en)} total terms")

        if not added and not removed:
            info("No changes detected")

    else:
        error(f"Unknown command: {command}")

if __name__ == '__main__':
    main()
