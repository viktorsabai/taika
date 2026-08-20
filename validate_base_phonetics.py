import json,re
from collections import Counter,defaultdict
from pathlib import Path
less=json.loads(Path('lessons.json').read_text(encoding='utf-8'))
steps=json.loads(Path('steps.json').read_text(encoding='utf-8'))
step_by={s['lesson_id']:s for s in steps['stepsets']}
base_courses=[c for c in less['courses'] if c['course_id'].startswith('course_b_')]
allowed={'→','↗','↘'}
issues=[]; totals=Counter(); by_course=Counter(); examples=defaultdict(list)
for c in base_courses:
 for l in c['lessons']:
  for i in step_by[l['lesson_id']]['items']:
   p=i.get('phonetic')
   if not p: continue
   totals['phonetic_records']+=1; by_course[c['course_id']]+=1
   tokens=p.split()
   bad=[t for t in tokens if t[-1:] not in allowed]
   if bad:
    totals['records_with_missing_arrows']+=1; by_course[c['course_id']]+=0
    row=(c['course_id'],l['lesson_id'],i.get('order'),i.get('ru'),p,bad)
    issues.append(row); examples[c['course_id']].append(row)
   for t in tokens:
    if t: totals['tokens']+=1; totals['tokens_with_arrow']+= t[-1:] in allowed
print('TOTALS',dict(totals))
print('COURSE_RECORDS',dict(by_course))
print('ISSUES',len(issues))
for cid in sorted(examples):
 print('\nCOURSE',cid,'ISSUES',len(examples[cid]))
 for row in examples[cid][:25]: print(row)
# last character frequency
last=Counter()
for c in base_courses:
 for l in c['lessons']:
  for i in step_by[l['lesson_id']]['items']:
   p=i.get('phonetic') or ''
   for t in p.split():
    if t: last[t[-1]]+=1
print('\nLAST_CHARS',dict(last))
Path('base_phonetic_issues.json').write_text(json.dumps(issues,ensure_ascii=False,indent=2),encoding='utf-8')
