import re
from pathlib import Path

swift_files = list(Path('taika').rglob('*.swift'))
text_by_file = {str(p): p.read_text(errors='ignore') for p in swift_files}

routes = ['lessons', 'lesson', 'course', 'game', 'favoritesAll']
print('ROUTE REFERENCES')
for route in routes:
    refs = []
    for path, text in text_by_file.items():
        for line_no, line in enumerate(text.splitlines(), 1):
            if re.search(r'\.' + route + r'\b', line):
                refs.append(f'{path}:{line_no}:{line.strip()}')
    print(route, len(refs))
    for ref in refs[:20]:
        print(' ', ref)

print('REQUESTED TAB')
for path, text in text_by_file.items():
    for line_no, line in enumerate(text.splitlines(), 1):
        if 'requestTab(' in line or 'requestedTab' in line:
            print(f'{path}:{line_no}:{line.strip()}')

print('OVERLAY CASES')
overlay_file = Path('taika/Theme/OverlayPresenter.swift').read_text(errors='ignore')
for case in re.findall(r'case\s+([A-Za-z0-9_]+)', overlay_file):
    print(case)

print('FIRST ENTRY')
for path, text in text_by_file.items():
    for line_no, line in enumerate(text.splitlines(), 1):
        if any(x in line for x in ('courseFirstTip', 'speakerFirstTip', 'TaikaProductDemoFlags', 'onboardingDone', 'welcomeSeen')):
            print(f'{path}:{line_no}:{line.strip()}')
