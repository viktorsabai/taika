import json
from pathlib import Path
ids={'course_l_4','course_l_5','course_l_6','course_l_15'}
lessons=json.loads(Path('lessons.json').read_text()); steps=json.loads(Path('steps.json').read_text()); sm={s['lesson_id']:s for s in steps['stepsets']}
out=[]
for c in lessons['courses']:
 if c.get('course_id') not in ids: continue
 out += [f"## {c['course_id']} — {c['course_title']}",f"Description: {c.get('description','')}",'']
 for l in c['lessons']:
  out += [f"### L{l['order']} {l['lesson_id']} — {l['title']}",f"Subtitle: {l.get('subtitle','')}"]
  for i in sm[l['lesson_id']]['items']:
   if i.get('kind')=='tip': out.append(f"{i.get('order')}. TIP: {i.get('text','')}")
   else: out.append(f"{i.get('order')}. {i.get('kind')} | {i.get('ru','')} | {i.get('thai','')} | {i.get('phonetic','')}")
  out.append('')
Path('remaining_batch_3_baseline.md').write_text('\n'.join(out)+'\n')
print('wrote remaining_batch_3_baseline.md')
