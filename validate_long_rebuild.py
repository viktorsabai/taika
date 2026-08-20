import json,re
from pathlib import Path
from collections import Counter
less=json.loads(Path('lessons.json').read_text(encoding='utf-8'))
steps=json.loads(Path('steps.json').read_text(encoding='utf-8'))
cat=json.loads(Path('taika/Resourses/taika_basa_course.json').read_text(encoding='utf-8'))
ids={c['id'] for c in cat if c.get('category')=='Тайский для долгожителей'}
cat_by={c['id']:c for c in cat}; step_by={s['lesson_id']:s for s in steps['stepsets']}
all_lesson_ids={l['lesson_id'] for c in less['courses'] for l in c['lessons']}
issues=[]; m=Counter()
universal=re.compile(r'тайц(?:ы|ев|ам)|все тайцы|тайцы всегда',re.I)
for c in less['courses']:
 if c['course_id'] not in ids: continue
 m['courses']+=1
 if not c.get('description'): issues.append(('course_description',c['course_id']))
 if len(c['lessons']) not in {6,7}: issues.append(('lesson_count',c['course_id'],len(c['lessons'])))
 if cat_by[c['course_id']].get('description') != c.get('description'): issues.append(('catalog_description',c['course_id']))
 for l in c['lessons']:
  m['lessons']+=1; items=step_by[l['lesson_id']]['items']; m['cards']+=len(items)
  if not l.get('outcomes') or not all(str(x).strip() for x in l['outcomes']): issues.append(('outcome',l['lesson_id']))
  if l.get('card_count') != len(items): issues.append(('card_count',l['lesson_id'],l.get('card_count'),len(items)))
  for p in l.get('prerequisites',[]) or []:
   if p not in all_lesson_ids: issues.append(('bad_prereq',l['lesson_id'],p))
  for i in items:
   if i.get('kind') in {'word','phrase','casual'}:
    m[f"kind_{i.get('kind')}"]+=1
    phon=i.get('phonetic','')
    for tok in phon.split():
     if tok[-1:] not in {'→','↗','↘'} and not tok.endswith('?') and tok not in {'90→','4x6→','TM.30→','OTP↘','SMS→','QR→','2025–2026→','2026→'}:
      issues.append(('arrow',l['lesson_id'],i.get('order'),tok,phon))
   for field in ('ru','tip','text'):
    if universal.search(str(i.get(field,''))): issues.append(('universal_claim',l['lesson_id'],i.get('order'),field,i.get(field)))
  if l['lesson_id'] == c['lessons'][-1]['lesson_id'] and not re.search(r'сцен|разговор|сервис|юмор|смысл|связ',l['title'],re.I): issues.append(('final_scene_title',l['lesson_id'],l['title']))
print('METRICS',dict(m)); print('ISSUES',len(issues))
for x in issues[:100]: print(x)
Path('long_rebuild_validation.json').write_text(json.dumps({'metrics':dict(m),'issues':issues},ensure_ascii=False,indent=2),encoding='utf-8')
if issues: raise SystemExit(1)
print('LONG_REBUILD_OK')
