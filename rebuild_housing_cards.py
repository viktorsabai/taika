import json
from pathlib import Path

LESSONS=Path('lessons.json'); STEPS=Path('steps.json')
lessons=json.loads(LESSONS.read_text()); steps=json.loads(STEPS.read_text())
step_map={s['lesson_id']:s for s in steps['stepsets']}
changed=[]

def item(step, order):
    return next(x for x in step['items'] if x.get('order')==order)

# L1: convert isolated nouns into usable tenant-to-landlord utterances.
l1=step_map['course_l_13_l1']
i=item(l1,6); i.update({'kind':'phrase','ru':'Капает вода','thai':'น้ำหยด','phonetic':'нам→ йот→','tip':'Скажи, если вода уже капает и проблема может быстро усилиться.'})
i=item(l1,7); i.update({'kind':'phrase','ru':'Почините пожалуйста','thai':'ช่วยซ่อมหน่อย','phonetic':'чуай→ сом→ ной→','tip':'Мягкая просьба хозяину или мастеру: сначала факт, потом действие.'})
i=item(l1,8); i.update({'kind':'phrase','ru':'Когда почините?','thai':'ซ่อมเมื่อไหร่','phonetic':'сом→ мыа→ рай↗','tip':'После сообщения о протечке попроси понятный срок ремонта.'})
changed += ['course_l_13_l1:6','course_l_13_l1:7','course_l_13_l1:8']

# L4: clarify role so the phrase is an expected landlord/manager response.
l4=step_map['course_l_13_l4']; i=item(l4,6)
i.update({'ru':'Сообщите, когда приедете','tip':'Это ответ хозяину или мастеру: договорились о визите — попроси написать перед приездом.'})
changed.append('course_l_13_l4:6')

# L6: remove meta-language that the learner cannot send as a real message.
l6=step_map['course_l_13_l6']
l6['items']=[x for x in l6['items'] if not (x.get('ru')=='Мягко в чате')]
for index,x in enumerate(l6['items'],1): x['order']=index
changed.append('course_l_13_l6:remove-meta-card')

for step in [l1,l4,l6]:
    step['hints']=[
      'Сначала назови проблему или результат, затем попроси конкретное действие и срок.',
      'Не смешивай сообщение хозяину, ответ мастера и follow-up в одну карточку.'
    ]
for course in lessons['courses']:
    if course.get('course_id')=='course_l_13':
        for lesson in course['lessons']:
            lesson['card_count']=len(step_map[lesson['lesson_id']]['items'])
        course['description']='Аренда жилья без хаоса: протечка, кондиционер, оплата, мастер, доступ, follow-up и соседи.'
LESSONS.write_text(json.dumps(lessons,ensure_ascii=False,indent=2)+'\n')
STEPS.write_text(json.dumps(steps,ensure_ascii=False,indent=2)+'\n')
print('changed:',changed)
