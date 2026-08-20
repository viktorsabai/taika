import json
from pathlib import Path

sp=Path('steps.json'); lp=Path('lessons.json')
steps=json.loads(sp.read_text(encoding='utf-8'))
less=json.loads(lp.read_text(encoding='utf-8'))
by={s['lesson_id']:s for s in steps['stepsets']}

def item(lid, order):
    for i in by[lid]['items']:
        if i.get('order') == order: return i
    raise KeyError((lid,order))

def set_item(lid, order, **changes): item(lid,order).update(changes)

def remove_orders(lid, orders):
    rows=[i for i in by[lid]['items'] if i.get('order') not in set(orders)]
    for n,i in enumerate(rows,1): i['order']=n
    by[lid]['items']=rows

# E6: teach a conditional register choice, not a universal rule.
set_item('course_e_6_l3',3,ru='Нужен ли хвостик?',tip='Сначала смотри на ситуацию и отношения: вежливый хвост помогает, но не является автоматической обязанностью в каждой реплике.')
set_item('course_e_6_l3',8,ru='Без хвостика звучит резко',tip='Без хвостика фраза иногда звучит короче и жёстче; проверь контекст и добавь мягкость голосом или частицей.')
set_item('course_e_6_l3',9,ru='Хвостик в каждой фразе?',tip='Не ставь частицу механически: важны адресат, ситуация, интонация и то, говоришь ли ты на каа или кхрап.')
set_item('course_e_6_l4',4,ru='Говорить о чувствах',tip='Пхуут кхвам ру суек — назвать чувство спокойно, без длинной драматичной истории.')
set_item('course_e_6_l4',5,ru='Выразить чувство',tip='Са дэнг — показать, что ты чувствуешь; после этого добавь конкретную благодарность или реакцию.')
set_item('course_e_6_l5',3,ru='Фаранг говорит жёстко',tip='Это описание звучания, а не ярлык для человека: смотри на громкость, приказной тон и реакцию собеседника.')
set_item('course_e_6_l5',4,ru='Избегать',tip='Лик лианг — «избегать»: используй как внутреннюю подсказку, чтобы заменить приказ просьбой или вопросом.')
set_item('course_e_6_l5',6,ru='Жёсткость пугает',tip='Резкий тон может закрыть разговор или напугать собеседника; проверь реакцию и снизь громкость, если это безопасно.')

# E1/E2: remove labels that teach a topic instead of a transferable action.
set_item('course_e_1_l2',1,ru='Мягкий хвостик na',tip='Na смягчает обращение; женская и мужская вежливые формы добавляются по контексту.')
set_item('course_e_1_l3',1,ru='Можно, пожалуйста?',tip='Короткий вопрос с na звучит мягче, чем прямое «можно?» без контекста.')
set_item('course_e_2_l1',5,ru='Рабочая задача',tip='Ngan — работа или рабочая задача; добавь предмет и срок, чтобы просьба стала конкретной.')
set_item('course_e_2_l2',6,ru='Спросить',tip='Tham — спросить; после вопроса дай человеку время ответить, не перебивай новым дедлайном.')
set_item('course_e_2_l5',4,ru='Поболтать с коллегами',tip='Кхуй лен — лёгкая беседа до или после задачи, не замена рабочему уточнению.')

# E2 L3: remove irrelevant identity question; lesson outcome reflects the remaining useful branch.
remove_orders('course_e_2_l3',[8])
for c in less['courses']:
    if c['course_id']=='course_e_2':
        for l in c['lessons']:
            if l['lesson_id']=='course_e_2_l3':
                l['outcomes']=['Напомнишь о сроке и уточнишь, кто отвечает за следующий шаг, без жёсткого «почему ещё нет».']

# E4 final scene is conflict repair, not bargaining; remove unrelated price cards.
remove_orders('course_e_4_l6',[6,7])
# E5 cultural lessons need probabilistic language, not universal claims.
set_item('course_e_5_l5',8,ru='«Возможно» не всегда значит «да»',tip='Косвенный ответ — сигнал проверить смысл, а не готовый перевод слова «нет».')
set_item('course_e_5_l6',6,ru='Ответить мягко и ясно',tip='Сохрани гармонию не копированием «тайского стиля», а спокойной репликой и ясным следующим шагом.')
# E5 L1 gets one actual soft request instead of unrelated shopping/time fillers.
set_item('course_e_5_l1',6,kind='phrase',ru='Можно попросить?',thai='ขอรบกวนหน่อยได้ไหม',phonetic='кхо→ роп→ куан→ ной→ дай→ май↗',tip='Мягкая просьба: сначала обозначь, что не хочешь обременить, затем попроси конкретное действие.')
remove_orders('course_e_5_l1',[7,8])

# Synchronize lesson card counts after intentional removals.
for c in less['courses']:
    for l in c['lessons']:
        if l['lesson_id'] in by:
            l['card_count']=len(by[l['lesson_id']]['items'])

sp.write_text(json.dumps({'stepsets':list(by.values())},ensure_ascii=False,indent=2)+'\n',encoding='utf-8')
lp.write_text(json.dumps(less,ensure_ascii=False,indent=2)+'\n',encoding='utf-8')
print('applied targeted E quality fixes; removed 5 irrelevant cards and added 1 contextual soft-request card')
