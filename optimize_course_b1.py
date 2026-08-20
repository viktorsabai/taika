import copy
import json
from pathlib import Path

steps_path=Path('steps.json')
lessons_path=Path('lessons.json')
steps=json.loads(steps_path.read_text(encoding='utf-8'))
lessons=json.loads(lessons_path.read_text(encoding='utf-8'))
by={s['lesson_id']:s for s in steps['stepsets']}

# Move farewell phrases out of the lesson whose sole purpose is greeting.
l1=by['course_b_1_l1']
l7=by['course_b_1_l7']
farewell_ru={'Спокойной ночи','Пока','До встречи'}
moved=[]
kept=[]
for item in l1['items']:
    if item.get('kind')=='phrase' and item.get('ru') in farewell_ru:
        moved.append(copy.deepcopy(item))
    else:
        kept.append(item)
l1['items']=kept

# Keep the existing phrase schema and append the moved cards to the closing lesson.
for item in moved:
    item['order']=len(l7['items'])+1
    item['tip'] = {
        'Спокойной ночи':'Прощание перед сном — отдельная ситуация, не обычное «пока».',
        'Пока':'Короткое прощание, когда уходишь первым.',
        'До встречи':'Тёплое прощание, когда рассчитываете увидеться снова.'
    }[item['ru']]
    l7['items'].append(item)

# Remove the transport-specific card from the generic location lesson.
l5=by['course_b_1_l5']
l5['items']=[i for i in l5['items'] if i.get('ru')!='Останови здесь']

# Re-number only the affected lesson items while preserving their original fields.
for lid in ['course_b_1_l1','course_b_1_l5','course_b_1_l7']:
    for n,item in enumerate(by[lid]['items'],start=1):
        item['order']=n

# Keep course/lesson metadata aligned with the revised boundaries.
for course in lessons['courses']:
    if course['course_id']!='course_b_1':
        continue
    for lesson in course['lessons']:
        lid=lesson['lesson_id']
        if lid=='course_b_1_l1':
            lesson['subtitle']='Саватди и улыбка — открываем разговор'
            lesson['outline']='приветствие · вежливый кхрап/ка · casual привет · добрый вечер'
            lesson['card_count']=len(by[lid]['items'])
        elif lid=='course_b_1_l5':
            lesson['subtitle']='Где туалет, вайфай и как показать место'
            lesson['outline']='где · туалет · здесь · сюда пожалуйста · вайфай · пароль'
            lesson['card_count']=len(by[lid]['items'])
        elif lid=='course_b_1_l7':
            lesson['subtitle']='Спасибо, извини и мягко попрощайся'
            lesson['outline']='спасибо · большое спасибо · извини · ничего страшного · пока · до встречи · спокойной ночи'
            lesson['card_count']=len(by[lid]['items'])

steps_path.write_text(json.dumps(steps,ensure_ascii=False,indent=2)+'\n',encoding='utf-8')
lessons_path.write_text(json.dumps(lessons,ensure_ascii=False,indent=2)+'\n',encoding='utf-8')
print('l1_cards',len(l1['items']),'l5_cards',len(l5['items']),'l7_cards',len(l7['items']))
print('moved',[x['ru'] for x in moved])
