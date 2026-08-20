import json,re
from pathlib import Path
terms={
'course_l_2':['метр','сдач','подож','останов','grab'],
'course_l_5':['аллерг','дозиров','к врачу','ухудш'],
'course_l_6':['другой номер','не работает','счёт','выезд'],
'course_l_7':['опас','помощ','флаг','течен'],
'course_l_9':['ждать','уже едут','адрес','1669'],
'course_l_10':['больно','останов','тренер','шкаф'],
'course_l_11':['фото','не буду','разреш'],
'course_l_12':['не так','исправ','короче','карт'],
'course_l_15':['откаж','транспорт','границ','фото'],
}
data=json.loads(Path('lessons.json').read_text()); steps=json.loads(Path('steps.json').read_text()); sm={s['lesson_id']:s for s in steps['stepsets']}
for c in data['courses']:
 cid=c.get('course_id')
 if cid not in terms: continue
 text=' '.join((i.get('ru') or i.get('text') or '') for l in c['lessons'] for i in sm[l['lesson_id']]['items']).lower()
 print(cid,'missing=',[t for t in terms[cid] if t not in text])
