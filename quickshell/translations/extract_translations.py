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
    translations = defaultdict(lambda: {
        'contexts': set(),
        'real_contexts': defaultdict(list),
        'occurrences': [],
        'plain_occurrences': []
    })
    qstr_patterns = [
        (re.compile(r'qsTr\(\s*"((?:\\.|[^"\\])*)"\s*\)'), '"'),
        (re.compile(r"qsTr\(\s*'((?:\\.|[^'\\])*)'\s*\)"), "'")
    ]
    # I18n.tr(term, context, true) -- the literal `true` flag uploads the
    # context as a real POEditor context, giving (term, context) its own
    # translation slot. Must be on one line with a literal `true`.
    i18n_real_context_patterns = [
        (
            re.compile(r'I18n\.tr\(\s*"((?:\\.|[^"\\])*)"\s*,\s*"((?:\\.|[^"\\])*)"\s*,\s*true\s*\)'),
            '"'
        ),
        (
            re.compile(r"I18n\.tr\(\s*'((?:\\.|[^'\\])*)'\s*,\s*'((?:\\.|[^'\\])*)'\s*,\s*true\s*\)"),
            "'"
        )
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

    # DankCommon terms are owned by the dank-qml-common repo (synced through
    # the DMS POEditor project); rglob not following the symlink is load-bearing.
    for qml_file in Path(root_dir).rglob('*.qml'):
        relative_path = qml_file.relative_to(root_dir)

        with open(qml_file, 'r', encoding='utf-8') as f:
            for line_num, line in enumerate(f, 1):
                for pattern, quote in qstr_patterns:
                    for match in pattern.finditer(line):
                        term = decode_string_literal(match.group(1), quote)
                        occ = {'file': str(relative_path), 'line': line_num}
                        translations[term]['occurrences'].append(occ)
                        translations[term]['plain_occurrences'].append(occ)

                real_spans = []
                for pattern, quote in i18n_real_context_patterns:
                    for match in pattern.finditer(line):
                        term = decode_string_literal(match.group(1), quote)
                        context = decode_string_literal(match.group(2), quote)
                        occ = {'file': str(relative_path), 'line': line_num}
                        translations[term]['real_contexts'][context].append(occ)
                        translations[term]['occurrences'].append(occ)
                        real_spans.append(match.span())

                context_spans = []
                for pattern, quote in i18n_context_patterns:
                    for match in pattern.finditer(line):
                        if any(spans_overlap(match.span(), span) for span in real_spans):
                            continue
                        term = decode_string_literal(match.group(1), quote)
                        context = decode_string_literal(match.group(2), quote)
                        occ = {'file': str(relative_path), 'line': line_num}
                        translations[term]['contexts'].add(context)
                        translations[term]['occurrences'].append(occ)
                        translations[term]['plain_occurrences'].append(occ)
                        context_spans.append(match.span())

                for pattern, quote in i18n_simple_patterns:
                    for match in pattern.finditer(line):
                        if any(spans_overlap(match.span(), span) for span in real_spans + context_spans):
                            continue
                        term = decode_string_literal(match.group(1), quote)
                        occ = {'file': str(relative_path), 'line': line_num}
                        translations[term]['occurrences'].append(occ)
                        translations[term]['plain_occurrences'].append(occ)

    return translations

def area_tags(occurrences):
    tags = set()
    for occ in occurrences:
        path = occ['file']
        if path.startswith('dms-plugins/'):
            tags.add('plugin-' + path.split('/')[1].lower())
        elif path.startswith(('Modules/Settings/', 'Modals/Settings/')):
            tags.add('settings')
        else:
            tags.add('shell')
    return sorted(tags)

def create_poeditor_json(translations):
    poeditor_data = []

    for term, data in sorted(translations.items()):
        if data['plain_occurrences']:
            references = [f"{occ['file']}:{occ['line']}" for occ in data['plain_occurrences']]
            contexts = sorted(data['contexts']) if data['contexts'] else []
            comment = " | ".join(contexts) if contexts else ""

            poeditor_data.append({
                "term": term,
                "context": term,
                "reference": ", ".join(references),
                "comment": comment,
                "tags": area_tags(data['plain_occurrences'])
            })

        for context in sorted(data['real_contexts']):
            references = [f"{occ['file']}:{occ['line']}" for occ in data['real_contexts'][context]]
            poeditor_data.append({
                "term": term,
                "context": context,
                "reference": ", ".join(references),
                "comment": "",
                "tags": area_tags(data['real_contexts'][context])
            })

    return poeditor_data

def create_template_json(translations):
    return [
        {
            "term": entry["term"],
            "translation": "",
            "context": entry["context"],
            "reference": "",
            "comment": entry["comment"]
        }
        for entry in create_poeditor_json(translations)
    ]

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
    print(f"  - Real-context entries: {sum(len(data['real_contexts']) for data in translations.values())}")
    print(f"  - POEditor entries: {len(poeditor_data)}")
    print(f"  - Source file: {en_json_path}")
    print(f"  - Template file: {template_json_path}")

if __name__ == '__main__':
    main()
