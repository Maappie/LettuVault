import os
import re

def update_file(path):
    with open(path, 'r', encoding='utf-8') as f:
        content = f.read()

    new_content = re.sub(r'\.withOpacity\(([^)]+)\)', r'.withValues(alpha: \1)', content)
    
    if new_content != content:
        with open(path, 'w', encoding='utf-8') as f:
            f.write(new_content)
        print(f"Updated {path}")

def process_dir(directory):
    for root, _, files in os.walk(directory):
        for f in files:
            if f.endswith('.dart'):
                update_file(os.path.join(root, f))

process_dir(r'c:\Users\Renz\LettuVault\mobile\LettuVault_Unfinished\lib')
