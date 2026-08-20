import json,re
from collections import defaultdict,Counter
from pathlib import Path

ALLOWED_ARROWS={'→','↗','↘'}
TOKEN_RE=re.compile(r'^[\u0400-\u04FF0-9A-Za-zА-Яа-яЁё\-…]+['+''.join(ALLOWED_ARROWS)+r'](?:\?)?$')
less=json.loads(Path('lessons.json').read_text(encoding='utf-8'))
steps=json.loads(Path('steps.json').read_text(encoding='utf-8'))
step_by={s['lesson_id']:s for s in steps['stepsets']}
base=[c for c in less['courses'] if c['course_id'].startswith('course_b_')]
issues=[]; dup=defaultdict(list); stats=Counter()
for c in base:
 for l in c['lessons']:
  for i in step_by[l['lesson_id']]['items']:
   p=i.get('phonetic') or ''
   if not p: continue
   stats['records']+=1
   tokens=p.split()
   for t in tokens:
    stats['tokens']+=1
    if t[-1:] not in ALLOWED_ARROWS:
     issues.append(('missing_arrow',c['course_id'],l['lesson_id'],i.get('order'),i.get('ru'),p,t))
    if any(ch in t for ch in ['[',']','/','(',')','{','}']):
     issues.append(('unsupported_markup',c['course_id'],l['lesson_id'],i.get('order'),i.get('ru'),p,t))
   thai=i.get('thai')
   if thai: dup[thai].append((p,c['course_id'],l['lesson_id'],i.get('order'),i.get('ru')))
for thai,rows in dup.items():
 ps={r[0] for r in rows}
 if len(ps)>1:
  stats['duplicate_thai_inconsistent']+=1
  issues.append(('duplicate_inconsistent',thai,rows))
print('STATS',dict(stats))
print('FORMAT_ISSUES',sum(x[0] in ('missing_arrow','unsupported_markup') for x in issues))
print('DUPLICATE_INCONSISTENCIES',sum(x[0]=='duplicate_inconsistent' for x in issues))
for x in issues[:120]: print(x)
Path('strict_base_phonetic_report.json').write_text(json.dumps(issues,ensure_ascii=False,indent=2),encoding='utf-8')
format_issues=[x for x in issues if x[0] in ('missing_arrow','unsupported_markup')]
if format_issues:
 raise SystemExit(1)
print('STRICT_FORMAT_OK')
