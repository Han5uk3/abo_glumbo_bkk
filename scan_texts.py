import os
import re

def find_hardcoded_texts(directory):
    hardcoded = []
    text_pattern = re.compile(r"Text\(\s*(['\"].*?['\"])\s*[,)]")
    
    for root, dirs, files in os.walk(directory):
        for file in files:
            if file.endswith(".dart"):
                filepath = os.path.join(root, file)
                try:
                    with open(filepath, 'r', encoding='utf-8') as f:
                        content = f.read()
                        matches = text_pattern.findall(content)
                        for match in matches:
                            if not match.startswith(('\'${', '\"${')) and 'AppLocalizations' not in match:
                                hardcoded.append((filepath, match))
                except Exception as e:
                    pass
    return hardcoded

d1 = r'c:\Hansuke\Work\abo_glumbo_bkk\lib'
d2 = r'c:\Hansuke\Work\abo_glumbo_technician_bbk\lib'

with open('texts_found.txt', 'w', encoding='utf-8') as out:
    out.write('--- User App ---\n')
    for path, text in find_hardcoded_texts(d1):
        out.write(f'{path}: {text}\n')

    out.write('--- Tech App ---\n')
    for path, text in find_hardcoded_texts(d2):
        out.write(f'{path}: {text}\n')
