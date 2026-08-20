import json
from pathlib import Path
from copy import deepcopy

less_path=Path('lessons.json'); steps_path=Path('steps.json')
less=json.loads(less_path.read_text(encoding='utf-8'))
steps=json.loads(steps_path.read_text(encoding='utf-8'))
step_by={s['lesson_id']:s for s in steps['stepsets']}

# P0 course prerequisites after B0 -> B2 -> B1 foundation.
prereqs={
 'course_l_1':['course_b_1'],
 'course_l_15':['course_b_1'],
 'course_l_2':['course_b_1'],
 'course_l_3':['course_b_1','course_b_4'],
 'course_l_4':['course_b_1','course_b_6'],
 'course_l_5':['course_b_1','course_b_5'],
 'course_l_6':['course_b_1'],
 'course_l_14':['course_b_1','course_b_4'],
 'course_l_7':['course_b_1'],
 'course_l_8':['course_b_1','course_b_4'],
 'course_l_9':['course_b_1','course_b_5'],
 'course_l_10':['course_b_1','course_b_5'],
 'course_l_11':['course_b_1'],
 'course_l_12':['course_b_1'],
 'course_l_13':['course_b_1','course_b_5'],
}
# Targeted P0 additions: text-only tips in existing tip schema, no new phonetic records.
additions={
 'course_l_2_l3':[
  'Если водитель не видит адрес, назови сначала кондо или большой ориентир, а потом башню и вход.',
  'Если планы изменились, сначала скажи новую точку, затем попроси подтвердить, что водитель понял.'
 ],
 'course_l_4_l5':[
  'Если есть аллергия, скажи об этом до заказа и повтори ингредиент, который нельзя добавлять.',
  'Для street food сначала назови блюдо и ограничение, а не объясняй всю историю длинной фразой.'
 ],
 'course_l_13_l6':[
  'В сообщении хозяину держи порядок: проблема → номер комнаты → фото → когда можно прийти.',
  'Если вопрос не решают, спокойно уточни срок следующего шага и кому можно написать дальше.'
 ],
 'course_l_14_l5':[
  'Для кондо сначала назови башню, этаж и лобби — курьеру важнее вход, чем длинный адрес.',
  'Если курьер задерживается, спроси время ожидания и напиши, где именно ты его ждёшь.'
 ],
 'course_l_5_l5':[
  'Врачу важны три вещи: когда началось, насколько сильно и что ты уже принимал.',
  'Не пытайся угадывать диагноз: опиши симптом и уточни, как принимать лекарство и когда обратиться снова.'
 ],
 'course_l_9_l6':[
  'В срочном сообщении сначала назови место и ориентир, потом объясни, что произошло.',
  'Если тебя не поняли, повтори только адрес, номер телефона и тип помощи — короткими блоками.'
 ],
}
# More specific outcome wording for the six P0 courses.
course_focus={
 'course_l_2':'завершить поездку на такси или Grab, включая неверный адрес, ожидание и изменение точки',
 'course_l_4':'заказать еду, обозначить остроту/ограничения и исправить ошибку в заказе',
 'course_l_13':'сообщить о проблеме в кондо, договориться о ремонте и эскалировать вопрос',
 'course_l_14':'получить доставку в кондо и решить вопрос с адресом, задержкой или повреждением',
 'course_l_5':'точно описать состояние в аптеке или клинике и уточнить следующий шаг',
 'course_l_9':'передать экстренную информацию с адресом и попросить нужную службу',
}

def set_content(lesson, course_id):
    title=lesson['title']; subtitle=lesson.get('subtitle','')
    goal=course_focus.get(course_id, f'решить ситуацию «{title}»')
    # Keep existing content kinds, but make the three visible blocks specific.
    by_kind={b.get('kind'):b for b in lesson.get('content',[])}
    if 'intro' in by_kind:
        by_kind['intro']['text']=f'Урок «{title}»: {subtitle}. Фокус — {goal}.'
    if 'outline' in by_kind:
        by_kind['outline']['text']=f'Ключевые карточки → вариация ситуации → repair-фраза → короткая сцена «{title}».'
    if 'apply' in by_kind:
        by_kind['apply']['text']=f'Собери вслух сцену «{title}»: используй основную фразу и одну вариацию, если ситуация пошла не по плану.'

for course in less['courses']:
    cid=course['course_id']
    if not cid.startswith('course_l_'): continue
    course['prerequisites']=prereqs[cid]
    for lesson in course['lessons']:
        lid=lesson['lesson_id']; s=step_by[lid]
        lesson['card_count']=len(s['items'])
        lesson['outcomes']=[f'Пользователь может {course_focus.get(cid, "решить ситуацию «"+lesson["title"]+"»")}.']
        if cid in course_focus:
            set_content(lesson,cid)
        if lid in additions:
            items=s['items']
            next_order=max((i.get('order',0) for i in items),default=0)+1
            for text in additions[lid]:
                items.append({'kind':'tip','text':text,'order':next_order}); next_order+=1
            lesson['card_count']=len(items)

less_path.write_text(json.dumps(less,ensure_ascii=False,indent=2)+'\n',encoding='utf-8')
steps_path.write_text(json.dumps(steps,ensure_ascii=False,indent=2)+'\n',encoding='utf-8')
print('updated_courses',len([c for c in less['courses'] if c['course_id'].startswith('course_l_')]))
print('updated_lessons',sum(len(c['lessons']) for c in less['courses'] if c['course_id'].startswith('course_l_')))
print('added_cards',sum(len(v) for v in additions.values()))
print('target_courses',sorted(course_focus))
