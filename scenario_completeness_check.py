import json,re
from pathlib import Path
contracts={
'course_l_1':['права','байк','шлем','пассажир','маршрут','штраф','паспорт'],
'course_l_2':['цена','маршрут','останов','оплат','grab'],
'course_l_3':['числ','цена','кило','торг','сдач'],
'course_l_4':['остр','аллерг','фудкорт','счёт'],
'course_l_5':['симптом','лекар','дозиров','аллерг','врач'],
'course_l_6':['брон','ключ','уборк','кондиционер','выезд'],
'course_l_7':['лежак','напит','снорк','опас','помощ','счёт'],
'course_l_8':['товар','цен','касс','оплат','чек','возврат'],
'course_l_9':['помощ','полици','скорая','адрес','пожар','ожид'],
'course_l_10':['абонемент','распис','оборуд','тренер','душ','больно'],
'course_l_11':['сонгкран','кратонг','йи пенг','фото','праздник'],
'course_l_12':['стриж','длин','массаж','бород','цен','оплат'],
'course_l_13':['протеч','оплат','кондиционер','мастер','доступ','сосед'],
'course_l_14':['заказ','адрес','трек','курьер','получ','повреж'],
'course_l_15':['напит','цен','small talk','границ','счёт','транспорт'],
}
lessons=json.loads(Path('lessons.json').read_text()); steps=json.loads(Path('steps.json').read_text()); sm={s['lesson_id']:s for s in steps['stepsets']}
for c in lessons['courses']:
 cid=c.get('course_id')
 if cid not in contracts: continue
 text=' '.join([c.get('course_title',''),c.get('description','')]+[l.get('title','')+' '+l.get('subtitle','')+' '+' '.join((i.get('ru') or i.get('text') or '') for i in sm[l['lesson_id']]['items']) for l in c['lessons']]).lower()
 missing=[term for term in contracts[cid] if term not in text]
 print(cid,'missing=',missing)
