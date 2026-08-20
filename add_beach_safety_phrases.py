import json
from pathlib import Path
lessons=json.loads(Path('lessons.json').read_text()); steps=json.loads(Path('steps.json').read_text()); sm={s['lesson_id']:s for s in steps['stepsets']}
step=sm['course_l_7_l4'];
# Avoid duplicate insertion if script is re-run.
existing={x.get('ru') for x in step['items']}
new=[
 {'kind':'phrase','ru':'Опасность','thai':'อันตราย','phonetic':'ан→ та→ рай→','tip':'Скажи это, если вода или течение небезопасны.'},
 {'kind':'phrase','ru':'Помогите','thai':'ช่วยด้วย','phonetic':'чуай→ дуай↘','tip':'Кричи коротко и ясно, если нужна помощь в воде.'},
 {'kind':'phrase','ru':'Нужна помощь','thai':'ต้องการความช่วยเหลือ','phonetic':'тонг→ кан→ кхвам→ чуай→ лыа→','tip':'Более спокойная просьба к спасателю или сотруднику пляжа.'}
]
for x in new:
 if x['ru'] not in existing: step['items'].append(x)
for n,x in enumerate(step['items'],1): x['order']=n
for c in lessons['courses']:
 if c.get('course_id')=='course_l_7':
  for l in c['lessons']: l['card_count']=len(sm[l['lesson_id']]['items'])
Path('lessons.json').write_text(json.dumps(lessons,ensure_ascii=False,indent=2)+'\n'); Path('steps.json').write_text(json.dumps(steps,ensure_ascii=False,indent=2)+'\n')
print('L7 safety phrases:',len(new))
