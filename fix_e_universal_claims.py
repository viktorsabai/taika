import json
from pathlib import Path
p=Path('steps.json'); data=json.loads(p.read_text(encoding='utf-8'))
by={s['lesson_id']:s for s in data['stepsets']}
def set_item(lid,order,**changes):
    for i in by[lid]['items']:
        if i.get('order')==order: i.update(changes); return
    raise KeyError((lid,order))
set_item('course_e_5_l4',6,tip='Косвенный ответ иногда может быть мягким отказом; после этой карточки уточни смысл или срок.')
set_item('course_e_5_l5',5,ru='Прямой отказ — не единственный вариант',tip='Культурная подсказка, а не правило: проверь смысл словами и контекстом.')
set_item('course_e_5_l5',6,ru='Улыбка сама по себе не означает «да»',tip='Улыбка может поддерживать контакт, но согласие лучше проверить коротким вопросом.')
set_item('course_e_5_l5',8,ru='«Возможно» — сигнал уточнить',tip='Не переводи ответ автоматически: спроси о сроке, готовности или следующем шаге.')
set_item('course_e_1_l5',7,tip='Короткая фраза помогает сохранить ясность в разговоре.')
p.write_text(json.dumps(data,ensure_ascii=False,indent=2)+'\n',encoding='utf-8')
print('fixed probabilistic/cultural wording')
