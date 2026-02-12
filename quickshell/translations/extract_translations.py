#!/usr/bin/env python3
import ast
import re
import json
from pathlib import Path
from collections import defaultdict


def decode_string_literal(content, quote):
    try:
        return ast.literal_eval(f"{quote}{content}{quote}")
    except (ValueError, SyntaxError):
        return content


def spans_overlap(a, b):
    return a[0] < b[1] and b[0] < a[1]


def extract_qstr_strings(root_dir):
    translations = defaultdict(lambda: {'contexts': set(), 'occurrences': []})
    qstr_patterns = [
        (re.compile(r'qsTr\(\s*"((?:\\.|[^"\\])*)"\s*\)'), '"'),
        (re.compile(r"qsTr\(\s*'((?:\\.|[^'\\])*)'\s*\)"), "'")
    ]
    i18n_context_patterns = [
        (
            re.compile(r'I18n\.tr\(\s*"((?:\\.|[^"\\])*)"\s*,\s*"((?:\\.|[^"\\])*)"\s*\)'),
            '"'
        ),
        (
            re.compile(r"I18n\.tr\(\s*'((?:\\.|[^'\\])*)'\s*,\s*'((?:\\.|[^'\\])*)'\s*\)"),
            "'"
        )
    ]
    i18n_simple_patterns = [
        (re.compile(r'I18n\.tr\(\s*"((?:\\.|[^"\\])*)"\s*\)'), '"'),
        (re.compile(r"I18n\.tr\(\s*'((?:\\.|[^'\\])*)'\s*\)"), "'")
    ]

    for qml_file in Path(root_dir).rglob('*.qml'):
        relative_path = qml_file.relative_to(root_dir)

        with open(qml_file, 'r', encoding='utf-8') as f:
            for line_num, line in enumerate(f, 1):
                for pattern, quote in qstr_patterns:
                    for match in pattern.finditer(line):
                        term = decode_string_literal(match.group(1), quote)
                        translations[term]['occurrences'].append({
                            'file': str(relative_path),
                            'line': line_num
                        })

                context_spans = []
                for pattern, quote in i18n_context_patterns:
                    for match in pattern.finditer(line):
                        term = decode_string_literal(match.group(1), quote)
                        context = decode_string_literal(match.group(2), quote)
                        translations[term]['contexts'].add(context)
                        translations[term]['occurrences'].append({
                            'file': str(relative_path),
                            'line': line_num
                        })
                        context_spans.append(match.span())

                for pattern, quote in i18n_simple_patterns:
                    for match in pattern.finditer(line):
                        if any(spans_overlap(match.span(), span) for span in context_spans):
                            continue
                        term = decode_string_literal(match.group(1), quote)
                        translations[term]['occurrences'].append({
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
