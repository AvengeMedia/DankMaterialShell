#!/usr/bin/env python3
import os
import re
import json
from pathlib import Path
from collections import defaultdict

def extract_qstr_strings(root_dir):
    translations = defaultdict(list)
    qstr_pattern = re.compile(r'qsTr\(["\']([^"\']+)["\']\)')
    i18n_pattern = re.compile(r'I18n\.tr\(["\']([^"\']+)["\'],\s*["\']([^"\']+)["\']\)')

    for qml_file in Path(root_dir).rglob('*.qml'):
        relative_path = qml_file.relative_to(root_dir)

        with open(qml_file, 'r', encoding='utf-8') as f:
            for line_num, line in enumerate(f, 1):
                qstr_matches = qstr_pattern.findall(line)
                for match in qstr_matches:
                    translations[match].append({
                        'file': str(relative_path),
                        'line': line_num
                    })

                i18n_matches = i18n_pattern.findall(line)
                for match in i18n_matches:
                    term = match[0]
                    translations[term].append({
                        'file': str(relative_path),
                        'line': line_num
                    })

    return translations

def create_poeditor_json(translations):
    poeditor_data = []

    for term, occurrences in sorted(translations.items()):
        references = []

        for occ in occurrences:
            ref = f"{occ['file']}:{occ['line']}"
            references.append(ref)

        entry = {
            "term": term,
            "context": term,
            "reference": ", ".join(references),
            "comment": ""
        }
        poeditor_data.append(entry)

    return poeditor_data

def create_template_json(translations):
    template_data = []

    for term in sorted(translations.keys()):
        entry = {
            "term": term,
            "translation": "",
            "context": "",
            "reference": "",
            "comment": ""
        }
        template_data.append(entry)

    return template_data

def main():
    script_dir = Path(__file__).parent
    root_dir = script_dir.parent
    translations_dir = script_dir

    print("Extracting qsTr() strings from QML files...")
    translations = extract_qstr_strings(root_dir)

    print(f"Found {len(translations)} unique strings")

    poeditor_data = create_poeditor_json(translations)
    en_json_path = translations_dir / 'en.json'
    with open(en_json_path, 'w', encoding='utf-8') as f:
        json.dump(poeditor_data, f, indent=2, ensure_ascii=False)
    print(f"Created source language file: {en_json_path}")

    template_data = create_template_json(translations)
    template_json_path = translations_dir / 'template.json'
    with open(template_json_path, 'w', encoding='utf-8') as f:
        json.dump(template_data, f, indent=2, ensure_ascii=False)
    print(f"Created template file: {template_json_path}")

    print("\nSummary:")
    print(f"  - Unique strings: {len(translations)}")
    print(f"  - Total occurrences: {sum(len(occs) for occs in translations.values())}")
    print(f"  - Source file: {en_json_path}")
    print(f"  - Template file: {template_json_path}")

if __name__ == '__main__':
    main()
