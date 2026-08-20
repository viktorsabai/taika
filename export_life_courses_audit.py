import json
from collections import Counter,defaultdict
from pathlib import Path
less=json.loads(Path('lessons.json').read_text(encoding='utf-8'))
steps=json.loads(Path('steps.json').read_text(encoding='utf-8'))
step_by={s['lesson_id']:s for s in steps['stepsets']}
with Path('life_courses_audit_raw.txt').open('w',encoding='utf-8') as f:
 for c in less['courses']:
  if not c['course_id'].startswith('course_l_'): continue
  f.write(f"\nCOURSE|{c['course_id']}|{c['course_title']}|{c.get('description','')}|lessons={len(c['lessons'])}\n")
  all_items=[]
  for l in c['lessons']:
   s=step_by[l['lesson_id']]; all_items+=s['items']
   blocks={b['kind']:b.get('text','') for b in l.get('content',[])}
   f.write(f"LESSON|{l['lesson_id']}|{l['order']}|{l['title']}|{l['subtitle']}|cards={len(s['items'])}|intro={blocks.get('intro','')}|outline={blocks.get('outline','')}|apply={blocks.get('apply','')}|outcomes={l.get('outcomes')}|prereq={l.get('prerequisites')}\n")
   kinds=Counter(i.get('kind') for i in s['items'])
   f.write(f"KINDS|{dict(kinds)}\n")
   for i in s['items']:
    f.write(f"CARD|{i.get('order')}|{i.get('kind')}|ru={i.get('ru')}|phonetic={i.get('phonetic')}|tip={i.get('tip')}\n")
  f.write(f"COURSE_KINDS|{dict(Counter(i.get('kind') for i in all_items))}|cards={len(all_items)}\n")
print('wrote life_courses_audit_raw.txt')
