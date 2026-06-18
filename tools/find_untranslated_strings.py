import os
import re

# Configuration
PROJECT_ROOT = os.path.abspath(os.path.join(os.path.dirname(__file__), '..', 'koon_mobile', 'lib'))

EXCLUDE_DIRS = {'build', 'assets', 'test', 'windows', 'macos', 'linux', 'web', 'android', 'ios', '.dart_tool', '.idea', '.git', 'localization', 'models'}
EXCLUDE_KEYWORDS = ['assets/', 'asset/', 'http://', 'https://', 'services/', 'service/', 'model/', 'models/', 'package:', 'use strict', '!important', 'display:', 'visibility:', 'pointer-events:', 'overflow:', 'width:', 'height:', 'margin:', 'padding:', 'border:']
EXCLUDE_FILES = ['api_service', 'service_', 'date', 'firebase_options', 'app_translations', 'api_constants', 'backend_service', 'auth_service', 'address_service']
STRING_PATTERN = re.compile(r'(?<![\w.])(["\'])(?:\\.|(?!\1).)*\1')
TRANSLATED_PATTERN = re.compile(r'\.(tr|tr\(\))')
IMPORT_PATTERN = re.compile(r'^\s*import\s+')

DEBUG_LINE_PATTERN = re.compile(r'\b(print|debugPrint|log)\s*\(')
ASSET_EXT_PATTERN = re.compile(r'\.(png|jpe?g|gif|webp|svg|json|avif)\b', re.IGNORECASE)
API_PATH_PATTERN = re.compile(r'^\s*/')
TOKEN_PATTERN = re.compile(r'^[A-Za-z0-9_\-]{25,}$')
LOWER_IDENTIFIER_PATTERN = re.compile(r'^[a-z0-9_\-/]{2,}$')
INTERPOLATION_TOKEN_PATTERN = re.compile(r'(\$\{[^}]*\}|\$[A-Za-z_]\w*)')
EMAIL_PATTERN = re.compile(r'^[^\s@]+@[^\s@]+\.[^\s@]+$')
MAP_INDEX_ACCESS_PATTERN = re.compile(r'\[\s*(["\'])\w+\1\s*\]')
IDENTIFIER_PATTERN = re.compile(r'^[A-Za-z_][A-Za-z0-9_]*$')
STORAGE_CONTEXT_PATTERN = re.compile(r'\b(Hive|GetStorage|SharedPreferences|prefs|pref|storage|box)\b|\.\s*(read|write|remove|delete|put)\s*\(', re.IGNORECASE)
FONT_CONTEXT_PATTERN = re.compile(r'\bfontFamily\b', re.IGNORECASE)
COUNTRY_CODE_PATTERN = re.compile(r'^[A-Z]{2}$')
CURRENCY_CODE_PATTERN = re.compile(r'^[A-Z]{3}$')
TIME_PATTERN = re.compile(r'^\d{1,2}:\d{2}(?:\s*[AP]M)?$', re.IGNORECASE)
DATE_FORMAT_PATTERN = re.compile(r'^[yYMdDEeHhmsaSkK:\/\-\s,\.]+$')
CAMEL_CASE_PATTERN = re.compile(r'^(?=.*[a-z])(?=.*[A-Z])[A-Za-z0-9]+$')


def should_exclude(path):
    parts = set(path.replace('\\', '/').split('/'))
    return bool(parts & EXCLUDE_DIRS)

def find_untranslated_strings():
    results = []
    for root, dirs, files in os.walk(PROJECT_ROOT):
        # Exclude unwanted directories
        dirs[:] = [d for d in dirs if d not in EXCLUDE_DIRS]
        for file in files:
            if file.endswith('.dart'):
                # Exclude service files and date files
                if any(ex in file for ex in EXCLUDE_FILES):
                    continue
                file_path = os.path.join(root, file)
                with open(file_path, encoding='utf-8') as f:
                    in_block_comment = False
                    for i, line in enumerate(f, 1):
                        stripped = line.lstrip()
                        if in_block_comment:
                            if '*/' in line:
                                in_block_comment = False
                            continue
                        if stripped.startswith('//'):
                            continue
                        if '/*' in line:
                            if '*/' not in line or line.index('/*') < line.index('*/'):
                                in_block_comment = True
                                continue
                        if IMPORT_PATTERN.match(line):
                            continue
                        if DEBUG_LINE_PATTERN.search(line):
                            continue
                        if FONT_CONTEXT_PATTERN.search(line):
                            continue
                        for match in STRING_PATTERN.finditer(line):
                            text = match.group(0)
                            content = text.strip('"\'')
                            # Exclude empty, import, already translated, assets, external links, services, model
                            if TRANSLATED_PATTERN.search(line):
                                continue
                            if any(keyword in text for keyword in EXCLUDE_KEYWORDS):
                                continue
                            if ASSET_EXT_PATTERN.search(content):
                                continue
                            if API_PATH_PATTERN.match(content):
                                continue
                            if EMAIL_PATTERN.match(content):
                                continue
                            if TOKEN_PATTERN.match(content):
                                continue
                            if COUNTRY_CODE_PATTERN.match(content):
                                continue
                            if CURRENCY_CODE_PATTERN.match(content):
                                continue
                            if 'label_en' in line or 'label_ar' in line:
                                continue
                            if TIME_PATTERN.match(content):
                                continue
                            if DATE_FORMAT_PATTERN.match(content) and any(ch.isalpha() for ch in content):
                                continue
                            if content.strip().isdigit():
                                continue
                            if '${' in content and '}' not in content:
                                continue
                            if MAP_INDEX_ACCESS_PATTERN.search(line):
                                if re.search(r'\[\s*' + re.escape(text[0]) + re.escape(content) + re.escape(text[0]) + r'\s*\]', line):
                                    continue
                            if STORAGE_CONTEXT_PATTERN.search(line) and IDENTIFIER_PATTERN.match(content):
                                continue
                            if CAMEL_CASE_PATTERN.match(content):
                                continue
                            if LOWER_IDENTIFIER_PATTERN.match(content) and ('_' in content or '/' in content or '-' in content or content.islower()):
                                if ' ' not in content:
                                    continue
                            if line[match.end():].lstrip().startswith(':'):
                                continue
                            content_without_vars = INTERPOLATION_TOKEN_PATTERN.sub('', content)
                            content_without_vars = re.sub(r'[\s\d\W]+', '', content_without_vars)
                            if content_without_vars == '':
                                continue
                            if len(content) < 2:
                                continue
                            results.append({
                                'file': file_path,
                                'line': i,
                                'text': text
                            })
    return results


def main():
    untranslated = find_untranslated_strings()
    output_file = os.path.join(os.path.dirname(__file__), 'untranslated_strings.txt')
    if not untranslated:
        with open(output_file, 'w', encoding='utf-8') as out:
            out.write('No untranslated strings found.\n')
        print('No untranslated strings found.')
        return
    with open(output_file, 'w', encoding='utf-8') as out:
        out.write('Untranslated strings:\n')
        for item in untranslated:
            out.write(f"{item['file']}:{item['line']}: {item['text']}\n")
    print(f"Results written to {output_file}")

if __name__ == '__main__':
    main()
