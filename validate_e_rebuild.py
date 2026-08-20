import json,re
from pathlib import Path
from collections import Counter
less=json.loads(Path('lessons.json').read_text(encoding='utf-8'))
steps=json.loads(Path('steps.json').read_text(encoding='utf-8'))
cat=json.loads(Path('taika/Resourses/taika_basa_course.json').read_text(encoding='utf-8'))
cat_by={c['id']:c for c in cat}; step_by={s['lesson_id']:s for s in steps['stepsets']}
eids={c['id'] for c in cat if c.get('category')=='На одной волне'}
issues=[]; metrics=Counter()
old_labels={'Тайский вайб','Пять ключевых','Ритм речи','Диалог','Скрытый смысл','Подтекст','Выход','Из тупика','Решение','Уровни вежливости','Культурный код','Контекст','Фаранг-резкость','Сервис сценка'}
for c in less['courses']:
 if c['course_id'] not in eids: continue
 metrics['courses']+=1
 if not cat_by[c['course_id']].get('is_pro'): issues.append(('not_pro',c['course_id']))
 if len(c['lessons']) != 6: issues.append(('lesson_count',c['course_id'],len(c['lessons'])))
 for l in c['lessons']:
  metrics['lessons']+=1
  items=step_by[l['lesson_id']]['items']; metrics['cards']+=len(items)
  if not l.get('outcomes') or not all(str(x).strip() for x in l.get('outcomes',[])): issues.append(('outcome',l['lesson_id']))
  if l.get('card_count') != len(items): issues.append(('card_count',l['lesson_id'],l.get('card_count'),len(items)))
  if any(x in l.get('title','') for x in old_labels): issues.append(('old_title',l['lesson_id'],l['title']))
  for p in l.get('prerequisites',[]) or []:
   if p not in {x['lesson_id'] for cc in less['courses'] for x in cc['lessons']}: issues.append(('bad_prereq',l['lesson_id'],p))
  for i in items:
   if i.get('kind') in {'word','phrase','casual'}:
    metrics[f"kind_{i.get('kind')}"]+=1
    phon=i.get('phonetic','')
    for tok in phon.split():
     if tok[-1:] not in {'→','↗','↘'} and not tok.endswith('?'):
      issues.append(('arrow',l['lesson_id'],i.get('order'),tok,phon))
    if '/' in phon: issues.append(('slash',l['lesson_id'],i.get('order'),phon))
   if i.get('ru') in old_labels: issues.append(('old_card',l['lesson_id'],i.get('order'),i.get('ru')))
print('METRICS',dict(metrics))
print('ISSUES',len(issues))
for x in issues[:100]: print(x)
Path('e_rebuild_validation.json').write_text(json.dumps({'metrics':dict(metrics),'issues':issues},ensure_ascii=False,indent=2),encoding='utf-8')
if issues: raise SystemExit(1)
print('E_REBUILD_OK')
