import json
from pathlib import Path
LESSONS=Path('lessons.json'); STEPS=Path('steps.json'); CATALOG=Path('taika/Resourses/taika_basa_course.json')
lessons=json.loads(LESSONS.read_text()); steps=json.loads(STEPS.read_text()); catalog=json.loads(CATALOG.read_text()); sm={s['lesson_id']:s for s in steps['stepsets']}
def remove_ru(step, values):
 step['items']=[x for x in step['items'] if x.get('ru') not in values]
 for n,x in enumerate(step['items'],1): x['order']=n
changes=[]
# L5 medical: remove unsafe fixed-course wording and replace with guidance tip.
l5=sm['course_l_5_l7']; remove_ru(l5,{'Таблетки на неделю'}); l5['items'].append({'kind':'tip','text':'Не назначай срок сам: спроси, сколько дней принимать, что делать при ухудшении и когда обратиться к врачу.','order':len(l5['items'])+1}); changes += ['L5 remove unsafe fixed-duration card','L5 add medication-safety tip']
# L6 hotel: fix role/meaning and remove meta phrase.
l6=sm['course_l_6_l3']
for x in l6['items']:
 if x.get('ru')=='Спасибо почините': x['ru']='Спасибо, что починили'; x['tip']='Это благодарность после ремонта, не просьба о ремонте.'
remove_ru(sm['course_l_6_l6'],{'В отеле сценка'}); changes += ['L6 fix repair gratitude gloss','L6 remove meta hotel-scene card']
# L15 nightlife: remove journey meta card, preserve boundaries and transport tips.
remove_ru(sm['course_l_15_l6'],{'От заказа до прощания'}); sm['course_l_15_l6']['items'].append({'kind':'tip','text':'Перед выходом проверь счёт и закажи безопасный транспорт; если не хочешь продолжать разговор или фото, коротко скажи об отказе и уходи.','order':len(sm['course_l_15_l6']['items'])+1}); changes += ['L15 remove meta journey card','L15 add safe-exit tip']
for cid in ['course_l_4','course_l_5','course_l_6','course_l_15']:
 for c in lessons['courses']:
  if c.get('course_id')==cid:
   for l in c['lessons']: l['card_count']=len(sm[l['lesson_id']]['items'])
for c in catalog:
 if c.get('id')=='course_l_4': c['description']='Тайская еда без сюрпризов: блюда, острота, ограничения, добавки, фудкорт, аллергии и счёт.'
 if c.get('id')=='course_l_5': c['description']='Аптека и клиника безопасно: симптом, лекарство, дозировка, аллергии и следующий шаг без самодиагностики.'
 if c.get('id')=='course_l_6': c['description']='Отель без хаоса: заселение, ключ, уборка, кондиционер, ранний заезд, счёт и checkout.'
 if c.get('id')=='course_l_15': c['description']='Вечер без потери контроля: заказ, small talk, границы, счёт и безопасный выход.'
LESSONS.write_text(json.dumps(lessons,ensure_ascii=False,indent=2)+'\n'); STEPS.write_text(json.dumps(steps,ensure_ascii=False,indent=2)+'\n'); CATALOG.write_text(json.dumps(catalog,ensure_ascii=False,indent=2)+'\n')
print('changes:',changes)
