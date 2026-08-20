import json
from pathlib import Path
lessons=json.loads(Path('lessons.json').read_text()); steps=json.loads(Path('steps.json').read_text()); sm={s['lesson_id']:s for s in steps['stepsets']}
step=sm['course_l_10_l6']; step['items']=[x for x in step['items'] if x.get('ru')!='От входа до выхода']
for n,x in enumerate(step['items'],1): x['order']=n
for c in lessons['courses']:
 if c.get('course_id')=='course_l_10':
  for l in c['lessons']: l['card_count']=len(sm[l['lesson_id']]['items'])
Path('lessons.json').write_text(json.dumps(lessons,ensure_ascii=False,indent=2)+'\n'); Path('steps.json').write_text(json.dumps(steps,ensure_ascii=False,indent=2)+'\n')
print('removed course_l_10_l6 meta card')
