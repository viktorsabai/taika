import json
from pathlib import Path
LESSONS=Path('lessons.json'); STEPS=Path('steps.json'); CATALOG=Path('taika/Resourses/taika_basa_course.json')
lessons=json.loads(LESSONS.read_text()); steps=json.loads(STEPS.read_text()); catalog=json.loads(CATALOG.read_text()); sm={s['lesson_id']:s for s in steps['stepsets']}
changes=[]
def remove_ru(step, values):
 step['items']=[x for x in step['items'] if x.get('ru') not in values and x.get('text') not in values]
 for n,x in enumerate(step['items'],1): x['order']=n
# L7 beach: make safety explicit even where the corpus has no Thai phrase pair.
l7=sm['course_l_7_l4']; l7['items'].append({'kind':'tip','text':'Перед снорклингом спроси про флаг, течение и безопасную зону. Красный флаг — не заходи в воду, даже если пляж выглядит спокойным.','order':len(l7['items'])+1});
l7=sm['course_l_7_l7']; l7['items'].append({'kind':'tip','text':'Если стало плохо или унесло течением, не отплывай дальше: зови спасателя и показывай, где ты.','order':len(l7['items'])+1}); changes += ['L7 safety: water conditions','L7 safety: rescue branch']
# L8 store scene: remove meta phrases that cannot be sent to a cashier.
l8=sm['course_l_8_l6']; remove_ru(l8,{'От диалога до кассы','Нашёл заплатил'}); changes += ['L8 remove meta card','L8 remove unnatural status card']
# L9 emergency: remove a semantic mismatch rather than teaching wrong Thai.
l9=sm['course_l_9_l3']; remove_ru(l9,{'Человек плохо'}); l9['items'].append({'kind':'tip','text':'Не говори абстрактно «плохо»: назови конкретный симптом или травму и сразу скажи, нужна ли скорая.','order':len(l9['items'])+1}); changes += ['L9 remove RU↔Thai mismatch','L9 symptom guidance']
# L10: clarify one awkward Russian gloss without changing the validated Thai pair.
l10=sm['course_l_10_l6'];
for x in l10['items']:
 if x.get('ru')=='Устал хорошо': x['ru']='Приятно устал'; x['tip']='После лёгкой тренировки: устал, но самочувствие хорошее.'; changes.append('L10 clarify gloss')
for cid in ['course_l_7','course_l_8','course_l_9','course_l_10']:
 for c in lessons['courses']:
  if c.get('course_id')==cid:
   for l in c['lessons']: l['card_count']=len(sm[l['lesson_id']]['items'])
for c in catalog:
 if c.get('id')=='course_l_7': c['description']='Пляжный день: место, лежак, напитки, снорклинг и вода без риска.'
 if c.get('id')=='course_l_8': c['description']='Магазин в Таиланде: найти товар, понять цену, оплатить, взять чек и вернуть покупку.'
 if c.get('id')=='course_l_9': c['description']='Экстренная помощь: вызвать службу, дать адрес, описать проблему и дождаться помощи.'
 if c.get('id')=='course_l_10': c['description']='Зал без неловкости: абонемент, расписание, оборудование, тренер и безопасная тренировка.'
LESSONS.write_text(json.dumps(lessons,ensure_ascii=False,indent=2)+'\n'); STEPS.write_text(json.dumps(steps,ensure_ascii=False,indent=2)+'\n'); CATALOG.write_text(json.dumps(catalog,ensure_ascii=False,indent=2)+'\n')
print('changes:',changes)
