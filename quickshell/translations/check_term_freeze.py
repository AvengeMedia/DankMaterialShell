#!/usr/bin/env python3
"""Enforce the i18n term freeze.

While term_freeze.json exists, any I18n.tr()/qsTr() term not in it fails the check.
Existing terms may be reused or moved freely.

The freeze is term-granular: adding a new real context to a frozen term via
I18n.tr(term, ctx, true) does not trip it (same English string, new slot).

  --update   re-snapshot the current terms into term_freeze.json
  (delete term_freeze.json to lift the freeze)
"""
import json
import sys
from pathlib import Path

from extract_translations import extract_qstr_strings

SCRIPT_DIR = Path(__file__).parent
ROOT_DIR = SCRIPT_DIR.parent
FREEZE_FILE = SCRIPT_DIR / 'term_freeze.json'



# dms-plugins and dms-plugins-external are separate checkouts with their own
# release cadence; the freeze only guards this repo's terms. Catalog
# extraction still includes plugins.
def shell_terms(translations):
    return {
        term: info for term, info in translations.items()
        if any(not occ['file'].startswith(('dms-plugins/', 'dms-plugins-external/')) for occ in info['occurrences'])
    }

def main():
    if '--update' in sys.argv:
        translations = shell_terms(extract_qstr_strings(ROOT_DIR))
        FREEZE_FILE.write_text(json.dumps(sorted(translations), indent=2, ensure_ascii=False) + '\n', encoding='utf-8')
        print(f"Froze {len(translations)} terms to {FREEZE_FILE}")
        return 0

    if not FREEZE_FILE.exists():
        print("i18n term freeze inactive (term_freeze.json not present)")
        return 0

    frozen = set(json.loads(FREEZE_FILE.read_text(encoding='utf-8')))
    translations = shell_terms(extract_qstr_strings(ROOT_DIR))
    new_terms = sorted(term for term in translations if term not in frozen)
    if not new_terms:
        return 0

    print(f"i18n term freeze: {len(new_terms)} new term(s) introduced:", file=sys.stderr)
    for term in new_terms:
        print(f'\n  "{term}"', file=sys.stderr)
        for occ in translations[term]['occurrences']:
            print(f"    quickshell/{occ['file']}:{occ['line']}", file=sys.stderr)
    print("\nReuse an existing term instead. To intentionally allow new terms, run", file=sys.stderr)
    print("  python3 quickshell/translations/check_term_freeze.py --update", file=sys.stderr)
    print("and stage term_freeze.json. Delete term_freeze.json to lift the freeze entirely.", file=sys.stderr)
    return 1


if __name__ == '__main__':
    sys.exit(main())
