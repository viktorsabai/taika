import json
from pathlib import Path
less=json.loads(Path('lessons.json').read_text(encoding='utf-8'))
steps=json.loads(Path('steps.json').read_text(encoding='utf-8'))
counts={s['lesson_id']:len(s.get('items',[])) for s in steps['stepsets']}
with Path('base_inventory.txt').open('w',encoding='utf-8') as f:
 for c in less['courses']:
  if not c['course_id'].startswith('course_b_'): continue
  f.write(f"COURSE|{c['course_id']}|{c['course_title']}|{c.get('description','')}|lessons={len(c['lessons'])}|cards={sum(counts.get(l['lesson_id'],0) for l in c['lessons'])}\n")
  for l in c['lessons']:
   f.write(f"LESSON|{l['lesson_id']}|{l['title']}|{l.get('subtitle','')}|cards={counts.get(l['lesson_id'],0)}|intro={l.get('intro','')}|outline={l.get('outline','')}|apply={l.get('apply','')}\n")
print('wrote base_inventory.txt')
