from pathlib import Path
import re
from collections import defaultdict

ROOT = Path('/home/ubuntu/taika-repo')
DRAFTS = ROOT / 'docs' / 'course_audits'

rows = []
for path in sorted(DRAFTS.glob('*_draft.md')):
    text = path.read_text(encoding='utf-8')
    current_course = path.stem.replace('_draft', '')
    in_table = False
    for line in text.splitlines():
        line = line.strip()
        if not line or line.startswith('<!--'):
            continue
        if 'Короткие cards' in line or 'phrase banks' in line.lower() or 'Короткие фразы' in line:
            in_table = True
            continue
        if in_table and line.startswith('|') and line.count('|') >= 2:
            cells = [c.strip() for c in line.strip('|').split('|')]
            if len(cells) >= 2 and cells[0].lower() not in {'урок', 'section'} and not set(cells[0]) <= {'-',' '}:
                phrases = re.findall(r'«([^»]+)»', ' | '.join(cells[1:]))
                if not phrases:
                    phrases = [p.strip() for p in re.split(r'\s*[·;/]\s*', ' | '.join(cells[1:])) if p.strip()]
                for phrase in phrases:
                    phrase = re.sub(r'\s+', ' ', phrase).strip(' .')
                    if len(phrase) >= 3:
                        rows.append((phrase.lower(), phrase, current_course, cells[0]))
        elif in_table and line.startswith('#'):
            in_table = False

by_phrase = defaultdict(list)
for norm, phrase, course, lesson in rows:
    by_phrase[norm].append((course, lesson, phrase))

out = []
out.append('# Proposed phrase overlap inventory\n')
out.append('Exact phrase matches across drafts; these are candidates for owner review, not automatic deletion.\n')
for norm, matches in sorted(by_phrase.items(), key=lambda kv: (-len(kv[1]), kv[0])):
    courses = sorted(set(m[0] for m in matches))
    if len(courses) > 1:
        out.append(f'## {matches[0][2]} — {len(courses)} courses\n')
        for course, lesson, phrase in matches:
            out.append(f'- `{course}` / {lesson}: {phrase}')
        out.append('')
Path('/tmp/proposed_phrase_overlaps.md').write_text('\n'.join(out), encoding='utf-8')
print(f'Extracted {len(rows)} proposed phrase rows from {len(list(DRAFTS.glob("*_draft.md")))} drafts')
print(f'Cross-course exact overlap groups: {sum(1 for v in by_phrase.values() if len(set(x[2] for x in v)) > 1)}')
print('\n'.join(out[:180]))

# Also write a compact CSV-like table for further classification.
with (ROOT / 'docs' / 'proposed_phrase_overlap_inventory.tsv').open('w', encoding='utf-8') as f:
    f.write('normalized_phrase\tphrase\tcourse\tlesson\n')
    for norm, phrase, course, lesson in rows:
        f.write(f'{norm}\t{phrase}\t{course}\t{lesson}\n')
