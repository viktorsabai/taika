import json, re
from collections import defaultdict, Counter
from pathlib import Path

ROOT = Path(__file__).parent
less = json.loads((ROOT / 'lessons.json').read_text(encoding='utf-8'))
steps = json.loads((ROOT / 'steps.json').read_text(encoding='utf-8'))
step_by = {s['lesson_id']: s for s in steps['stepsets']}
allowed = {'→', '↗', '↘'}
issues = []
thai_map = defaultdict(list)
stats = Counter()
for course in less.get('courses', []):
    cid = course['course_id']
    for lesson in course.get('lessons', []):
        lid = lesson['lesson_id']
        for item in step_by.get(lid, {}).get('items', []) or []:
            p = (item.get('phonetic') or '').strip()
            if not p:
                continue
            stats['records'] += 1
            tokens = p.split()
            for token in tokens:
                stats['tokens'] += 1
                if token[-1:] not in allowed:
                    issues.append({'type':'missing_arrow','course':cid,'lesson':lid,'order':item.get('order'),'ru':item.get('ru'),'phonetic':p,'token':token})
                if any(ch in token for ch in '[]/(){}'):
                    issues.append({'type':'unsupported_markup','course':cid,'lesson':lid,'order':item.get('order'),'ru':item.get('ru'),'phonetic':p,'token':token})
            thai = item.get('thai')
            if thai:
                thai_map[thai].append((p, cid, lid, item.get('order'), item.get('ru')))
for thai, rows in thai_map.items():
    phonetics = {r[0] for r in rows}
    if len(phonetics) > 1:
        issues.append({'type':'inconsistent_duplicate','thai':thai,'rows':[{'phonetic':p,'course':c,'lesson':l,'order':o,'ru':r} for p,c,l,o,r in rows]})
        stats['inconsistent_duplicates'] += 1
report = {'stats': dict(stats), 'format_issues': [x for x in issues if x['type'] in {'missing_arrow','unsupported_markup'}], 'inconsistent_duplicates': [x for x in issues if x['type']=='inconsistent_duplicate']}
(ROOT/'all_phonetics_report.json').write_text(json.dumps(report,ensure_ascii=False,indent=2), encoding='utf-8')
print('STATS', dict(stats))
print('FORMAT_ISSUES', len(report['format_issues']))
print('INCONSISTENT_DUPLICATES', len(report['inconsistent_duplicates']))
for x in report['format_issues'][:100]: print(x)
for x in report['inconsistent_duplicates'][:30]: print(x)
