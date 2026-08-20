import json
from pathlib import Path
lessons=json.loads(Path('lessons.json').read_text()); steps=json.loads(Path('steps.json').read_text()); sm={s['lesson_id']:s for s in steps['stepsets']}
course=next(c for c in lessons['courses'] if c['course_id']=='course_l_14')
out=[f"# Baseline: {course['course_id']} — {course['course_title']}",f"Description: {course.get('description','')}",'']
for l in course['lessons']:
 s=sm[l['lesson_id']]; out += [f"## L{l['order']} {l['lesson_id']} — {l['title']}",f"Subtitle: {l.get('subtitle','')}",f"Outcome: {l.get('outcomes',[])}",f"Card count: {l.get('card_count')} / {len(s['items'])}",'']
 for i in s['items']:
  if i.get('kind')=='tip': out.append(f"{i.get('order')}. [TIP] {i.get('text','')}")
  else: out.append(f"{i.get('order')}. [{i.get('kind')}] RU: {i.get('ru','')} | THAI: {i.get('thai','')} | PHON: {i.get('phonetic','')} | NOTE: {i.get('tip','')}")
 out.append('')
Path('delivery_course_baseline_ru.md').write_text('\n'.join(out)+'\n')
print('wrote delivery_course_baseline_ru.md')
