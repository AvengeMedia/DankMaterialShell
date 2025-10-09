#!/usr/bin/env python3
import os
import re
from pathlib import Path

def replace_qstr_in_file(file_path, root_dir):
    with open(file_path, 'r', encoding='utf-8') as f:
        content = f.read()

    original_content = content
    relative_path = file_path.relative_to(root_dir)

    qstr_pattern = re.compile(r'qsTr\("([^"]+)"\)')

    def replacement(match):
        term = match.group(1)
        context = term
        return f'I18n.tr("{term}", "{context}")'

    content = qstr_pattern.sub(replacement, content)

    if content != original_content:
        with open(file_path, 'w', encoding='utf-8') as f:
            f.write(content)
        return True
    return False

def main():
    script_dir = Path(__file__).parent
    root_dir = script_dir.parent

    modified_count = 0

    for qml_file in root_dir.rglob('*.qml'):
        if 'translations' in str(qml_file):
            continue

        try:
            if replace_qstr_in_file(qml_file, root_dir):
                modified_count += 1
                print(f"Modified: {qml_file.relative_to(root_dir)}")
        except Exception as e:
            print(f"Error processing {qml_file}: {e}")

    print(f"\nTotal files modified: {modified_count}")

if __name__ == '__main__':
    main()
