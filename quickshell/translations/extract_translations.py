#!/usr/bin/env python3
import os
import re
import json
from pathlib import Path
from collections import defaultdict

def extract_qstr_strings(root_dir):
    translations = defaultdict(lambda: {'contexts': set(), 'occurrences': []})
    qstr_pattern = re.compile(r'qsTr\(["\']([^"\']+)["\']\)')
    i18n_pattern_with_context = re.compile(r'I18n\.tr\(["\']([^"\']+)["\']\s*,\s*["\']([^"\']+)["\']\)')
    i18n_pattern_simple = re.compile(r'I18n\.tr\(["\']([^"\']+)["\']\)')

    for qml_file in Path(root_dir).rglob('*.qml'):
        relative_path = qml_file.relative_to(root_dir)

        with open(qml_file, 'r', encoding='utf-8') as f:
            for line_num, line in enumerate(f, 1):
                qstr_matches = qstr_pattern.findall(line)
                for match in qstr_matches:
                    translations[match]['occurrences'].append({
                        'file': str(relative_path),
                        'line': line_num
                    })

                i18n_with_context = i18n_pattern_with_context.findall(line)
                for term, context in i18n_with_context:
                    translations[term]['contexts'].add(context)
                    translations[term]['occurrences'].append({
                        'file': str(relative_path),
                        'line': line_num
                    })

                i18n_simple = i18n_pattern_simple.findall(line)
                for match in i18n_simple:
                    if not i18n_pattern_with_context.search(line):
                        translations[match]['occurrences'].append({
                            'file': str(relative_path),
                            'line': line_num
                        })

    return translations

def create_poeditor_json(translations):
    poeditor_data = []

    for term, data in sorted(translations.items()):
        references = []

        for occ in data['occurrences']:
            ref = f"{occ['file']}:{occ['line']}"
            references.append(ref)

        contexts = sorted(data['contexts']) if data['contexts'] else []
        context_str = " | ".join(contexts) if contexts else term

        entry = {
            "term": term,
            "context": context_str,
            "reference": ", ".join(references),
            "comment": ""
        }
        poeditor_data.append(entry)

    return poeditor_data

def create_template_json(translations):
    template_data = []

    for term, data in sorted(translations.items()):
        contexts = sorted(data['contexts']) if data['contexts'] else []
        context_str = " | ".join(contexts) if contexts else ""

        entry = {
            "term": term,
            "translation": "",
            "context": context_str,
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
    print(f"  - Total occurrences: {sum(len(data['occurrences']) for data in translations.values())}")
    print(f"  - Strings with contexts: {sum(1 for data in translations.values() if data['contexts'])}")
    print(f"  - Source file: {en_json_path}")
    print(f"  - Template file: {template_json_path}")

if __name__ == '__main__':
    main()
