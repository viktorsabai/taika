import json
from pathlib import Path
from collections import Counter
less=json.loads(Path('lessons.json').read_text(encoding='utf-8'))
steps=json.loads(Path('steps.json').read_text(encoding='utf-8'))
cat=json.loads(Path('taika/Resourses/taika_basa_course.json').read_text(encoding='utf-8'))
eids={c['id'] for c in cat if c.get('category')=='На одной волне'}
by={s['lesson_id']:s for s in steps['stepsets']}
lines=['# E review matrix\n','| Course | Lesson | Outcome | Cards | Card labels |','|---|---|---|---:|---|']
for c in less['courses']:
 if c['course_id'] not in eids: continue
 for l in c['lessons']:
  items=by[l['lesson_id']]['items']; labels=[]
  for i in items:
   text=i.get('ru') or i.get('text') or ''
   labels.append(f"{i.get('order','-')}. {i.get('kind')}: {text}")
  lines.append(f"| {c['course_id']} {c['course_title']} | {l['lesson_id']} {l['title']} | {l.get('outcomes',[''])[0]} | {len(items)} | {'<br>'.join(labels)} |")
Path('e_review_matrix.md').write_text('\n'.join(lines)+'\n',encoding='utf-8')
print('wrote',len(lines)-3,'lesson rows')
