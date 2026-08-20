import json
from pathlib import Path
p=Path('steps.json')
data=json.loads(p.read_text(encoding='utf-8'))
by={(s['lesson_id'],i.get('order')):i for s in data['stepsets'] for i in s['items']}
updates={
 ('course_e_2_l2',5): {'ru':'Почти готово','tip':'Это ответ «почти готово»; после него уточни точный срок.'},
 ('course_e_2_l3',6): {'ru':'Без обвинений','tip':'Сначала убери обвинение, затем спокойно попроси обновление и срок.'},
 ('course_e_2_l4',5): {'ru':'Хороший коллега','tip':'Тёплая оценка человека; для результата используй отдельную карточку «Отлично сделано».'},
 ('course_e_2_l5',6): {'ru':'Во сколько обед?','tip':'Нейтральный small talk о перерыве; после ответа можно вернуться к задаче.'},
 ('course_e_2_l6',4): {'ru':'Если ещё не готово','thai':'ยังไม่เสร็จ','phonetic':'янг→ май→ сет↘','tip':'Ветвь для ответа «ещё не готово»: уточни причину и новый срок.'},
 ('course_e_3_l1',5): {'ru':'Попросить мягко','tip':'Эта форма смягчает просьбу; объект и день добавь следующей карточкой.'},
 ('course_e_3_l2',6): {'ru':'Быстрый результат','tip':'Это оценка результата, а не вопрос о сроке; для срока используй отдельную вопросительную фразу.'},
 ('course_e_5_l5',3): {'ru':'Какой здесь смысл?','tip':'Спроси о смысле только после того, как услышал фразу в контексте.'},
 ('course_e_5_l5',4): {'ru':'Что ты имеешь в виду?','tip':'Уточняющий вопрос безопаснее, чем пытаться угадать подтекст.'},
}
for key,changes in updates.items():
    if key not in by: raise SystemExit(f'missing {key}')
    by[key].update(changes)
p.write_text(json.dumps(data,ensure_ascii=False,indent=2)+'\n',encoding='utf-8')
# Keep the final lesson title action-oriented rather than naming the topic.
for lesson in json.loads(Path('lessons.json').read_text(encoding='utf-8'))['courses']:
    if lesson['course_id'] == 'course_e_5':
        for row in lesson['lessons']:
            if row['lesson_id'] == 'course_e_5_l6':
                row['title'] = 'Уточнить смысл в сцене'
                Path('lessons.json').write_text(json.dumps(json.loads(Path('lessons.json').read_text(encoding='utf-8')), ensure_ascii=False, indent=2) + '\n', encoding='utf-8')
                break
print('fixed',len(updates),'E semantic pairs')
