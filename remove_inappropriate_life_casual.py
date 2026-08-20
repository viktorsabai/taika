import json
from pathlib import Path
lessons_path=Path('lessons.json'); steps_path=Path('steps.json')
lessons=json.loads(lessons_path.read_text()); steps=json.loads(steps_path.read_text())
step_map={s['lesson_id']:s for s in steps['stepsets']}
changed=[]
for course in lessons['courses']:
    if course.get('course_id') not in {'course_l_2','course_l_15'}: continue
    for lesson in course['lessons']:
        step=step_map[lesson['lesson_id']]
        new=[]
        for item in step['items']:
            text=(item.get('text','')+' '+item.get('ru','')+' '+item.get('thai','')).lower()
            if '555' not in text:
                new.append(item); continue
            if lesson['lesson_id']=='course_l_2_l6' and item.get('kind')=='tip':
                item['text']='Сначала договорись о маршруте и цене; не добавляй шутку в середину поездки.'
                new.append(item)
            elif lesson['lesson_id']=='course_l_15_l6':
                # Replace chat-code filler with a useful exit tip while preserving order/card shape.
                new.append({'kind':'tip','text':'В баре сначала проверь счёт и транспорт домой; chat-код 555 не заменяет живую благодарность.','order':item.get('order',1)})
            else:
                new.append(item)
            changed.append(lesson['lesson_id'])
        step['items']=new
        for index,item in enumerate(step['items'],1): item['order']=index
        lesson['card_count']=len(step['items'])
lessons_path.write_text(json.dumps(lessons,ensure_ascii=False,indent=2)+'\n')
steps_path.write_text(json.dumps(steps,ensure_ascii=False,indent=2)+'\n')
print('changed:',changed)
