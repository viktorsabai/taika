import copy
import json
from pathlib import Path

steps_path=Path('steps.json')
lessons_path=Path('lessons.json')
steps=json.loads(steps_path.read_text(encoding='utf-8'))
lessons=json.loads(lessons_path.read_text(encoding='utf-8'))
by={s['lesson_id']:s for s in steps['stepsets']}

# B0: keep only the orientation to tones; detailed hearing/pronunciation lives in B2.
b0_l2=by['course_b_0_l2']
b0_l2['items']=[
    {'order':1,'kind':'tip','tip':'Тон — часть смысла','text':'В тайском мелодия слога может менять значение. Поэтому важно не только, какие звуки ты говоришь, но и как движется голос.'},
    {'order':2,'kind':'tip','tip':'Сначала услышь движение','text':'На старте достаточно заметить три вещи: голос может идти ровно, подниматься или опускаться. Названия всех тонов сейчас запоминать не нужно.'},
    {'order':3,'kind':'tip','tip':'Не пугайся тонов','text':'Тон не нужно угадывать по русскому ударению. Сначала слушай короткую фразу целиком — позже отдельный курс поможет разбирать мелодику точнее.'},
    {'order':4,'kind':'tip','tip':'Теория должна сразу помогать','text':'Если тебя не поняли из-за звучания, скажи проще и повтори медленнее. Ошибка в тоне — это подсказка для следующей попытки, а не причина молчать.'},
]

# B1: add the minimal repair set to the existing Requests lesson.
l4=by['course_b_1_l4']
template=next(i for i in l4['items'] if i.get('kind')=='phrase')
repair=[
    ('Я не понимаю','ไม่เข้าใจ','май кау-джай','Скажи это, если не понял ответ или объяснение.'),
    ('Повторите пожалуйста','พูดอีกครั้งได้ไหม','пхут ик кхранг дай май?','Просьба повторить — нормальная часть разговора.'),
    ('Медленнее пожалуйста','พูดช้าๆหน่อย','пхут чаа-чаа ной','Просьба говорить медленнее, если фраза прозвучала слишком быстро.'),
    ('Понятно хорошо','เข้าใจแล้ว','кау-джай лэу','Коротко подтверждает, что ты понял и можно продолжать.'),
]
existing_ru={i.get('ru') for i in l4['items']}
for ru,thai,phonetic,tip in repair:
    if ru in existing_ru: continue
    item=copy.deepcopy(template)
    item.update({'order':len(l4['items'])+1,'kind':'phrase','ru':ru,'thai':thai,'phonetic':phonetic,'tip':tip})
    for optional in ['audio','text','scene','lines','conversation_next_order','conversation_is_prompt','is_question','reply_to']:
        if optional in item: item[optional]=None
    l4['items'].append(item)
for n,item in enumerate(l4['items'],start=1): item['order']=n

# B2: clarify every lesson as a pronunciation/intonation progression.
b2_course=next(c for c in lessons['courses'] if c['course_id']=='course_b_2')
b2_course['description']='Слуховой курс: различать и повторять тайскую интонацию в знакомых коротких фразах.'
b2_meta={
 'course_b_2_l1':('Три тона на примерах','Услышать, что одна мелодия может менять смысл.','Понять на знакомых коротких примерах, что тон является частью значения.'),
 'course_b_2_l2':('Падение и подъём','Ровно, вверх и вниз — три движения голоса.','Различить ровный, восходящий и нисходящий контур на коротких слогах.'),
 'course_b_2_l3':('Эмоции тоном','Как голос показывает удивление, боль и восторг.','Услышать, как интонация меняет эмоциональный оттенок знакомой фразы.'),
 'course_b_2_l4':('Быстрая речь','Слышать мелодику, даже когда слабые слоги сокращаются.','Узнать знакомую фразу в быстрой речи и не потерять её основной контур.'),
 'course_b_2_l5':('Интонация в просьбе','Мягкость просьбы: голос, пауза и короткие частицы.','Отличить нейтральную просьбу от более мягкой по мелодии и финальной частице.'),
 'course_b_2_l6':('Интонация в знакомых фразах','Собираем тон в приветствии, просьбе, вопросе и благодарности.','Перенести интонацию из отдельных примеров в знакомые survival-фразы без нового словаря.'),
}
for l in b2_course['lessons']:
    if l['lesson_id'] in b2_meta:
        title,subtitle,outcome=b2_meta[l['lesson_id']]
        l['title']=title
        l['subtitle']=subtitle
        l['outcomes']=[outcome]
        l['prerequisites']=[f'course_b_2_l{int(l["lesson_id"][-1])-1}'] if l['order']>1 else ['course_b_0_l3']
        if l['lesson_id']=='course_b_2_l6':
            l['content']=[
                {'kind':'intro','text':'Финальный урок B2 не вводит новую бытовую тему: он собирает интонацию в уже знакомых фразах.'},
                {'kind':'outline','text':'Приветствие · вопрос · просьба · благодарность · ровный, восходящий и нисходящий контур.'},
                {'kind':'apply','text':'Произнеси четыре знакомые фразы и сохрани их смысл, меняя только нужное движение голоса.'},
            ]

# B0 metadata and outcomes.
b0_course=next(c for c in lessons['courses'] if c['course_id']=='course_b_0')
b0_course['description']='Карта тайского без паники: базовая логика языка, частицы и короткое знакомство с тонами.'
b0_outcomes={
 'course_b_0_l1':'Понять базовый порядок фразы и увидеть, как частицы меняют время, отрицание и вопрос.',
 'course_b_0_l2':'Понять, что тайский тон является частью смысла, без необходимости учить все названия тонов.',
 'course_b_0_l3':'Узнать базовые вежливые частицы и разговорные способы сделать фразу мягче.',
}
for l in b0_course['lessons']:
    l['outcomes']=[b0_outcomes[l['lesson_id']]]
    l['prerequisites']=[] if l['order']==1 else [f'course_b_0_l{l["order"]-1}']

# B1 metadata and outcomes/prerequisites. Existing lesson content and B1 boundary edits stay intact.
b1_course=next(c for c in lessons['courses'] if c['course_id']=='course_b_1')
b1_course['description']='Первый survival-разговор: открыть контакт, попросить нужное, уточнить место/цену и продолжить разговор, если не понял ответ.'
b1_outcomes={
 'course_b_1_l1':'Поздороваться и открыть короткий бытовой контакт вежливо.',
 'course_b_1_l2':'Представиться, назвать страну и спросить имя собеседника.',
 'course_b_1_l3':'Спросить, как дела, коротко ответить и вернуть вопрос.',
 'course_b_1_l4':'Попросить базовую вещь и использовать repair-фразу, если ответ непонятен.',
 'course_b_1_l5':'Спросить, где находится место, туалет или вайфай, и показать нужную точку.',
 'course_b_1_l6':'Спросить цену, уточнить оплату и завершить покупку.',
 'course_b_1_l7':'Поблагодарить, извиниться и мягко завершить разговор.',
}
for l in b1_course['lessons']:
    l['outcomes']=[b1_outcomes[l['lesson_id']]]
    l['prerequisites']=(['course_b_0_l3','course_b_2_l6'] if l['order']==1 else [f'course_b_1_l{l["order"]-1}'])

# Normalize counts only for these three courses.
for course_id in ['course_b_0','course_b_1','course_b_2']:
    course=next(c for c in lessons['courses'] if c['course_id']==course_id)
    for l in course['lessons']:
        l['card_count']=len(by[l['lesson_id']]['items'])

steps_path.write_text(json.dumps(steps,ensure_ascii=False,indent=2)+'\n',encoding='utf-8')
lessons_path.write_text(json.dumps(lessons,ensure_ascii=False,indent=2)+'\n',encoding='utf-8')
print('B0 counts',[len(by[l['lesson_id']]['items']) for l in b0_course['lessons']])
print('B1 counts',[len(by[l['lesson_id']]['items']) for l in b1_course['lessons']])
print('B2 counts',[len(by[l['lesson_id']]['items']) for l in b2_course['lessons']])
