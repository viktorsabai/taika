import json
from pathlib import Path
lessons=json.loads(Path('lessons.json').read_text()); steps=json.loads(Path('steps.json').read_text()); sm={s['lesson_id']:s for s in steps['stepsets']}
step=sm['course_l_12_l6']; existing={x.get('ru') for x in step['items']}
new={'kind':'phrase','ru':'Я не так имел в виду','thai':'ไม่ได้หมายความแบบนั้น','phonetic':'май→ дай→ май→ кхвам→ бэп→ нан↘','tip':'Скажи это сразу после результата, если мастер понял фото или просьбу не так.'}
if new['ru'] not in existing: step['items'].append(new)
for n,x in enumerate(step['items'],1): x['order']=n
for c in lessons['courses']:
 if c.get('course_id')=='course_l_12':
  for l in c['lessons']: l['card_count']=len(sm[l['lesson_id']]['items'])
Path('lessons.json').write_text(json.dumps(lessons,ensure_ascii=False,indent=2)+'\n'); Path('steps.json').write_text(json.dumps(steps,ensure_ascii=False,indent=2)+'\n')
print('L12 correction branch added')
