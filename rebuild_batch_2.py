import json
from pathlib import Path
LESSONS=Path('lessons.json'); STEPS=Path('steps.json'); CATALOG=Path('taika/Resourses/taika_basa_course.json')
lessons=json.loads(LESSONS.read_text()); steps=json.loads(STEPS.read_text()); catalog=json.loads(CATALOG.read_text()); sm={s['lesson_id']:s for s in steps['stepsets']}
def remove_ru(step, values):
 step['items']=[x for x in step['items'] if x.get('ru') not in values]
 for n,x in enumerate(step['items'],1): x['order']=n
changes=[]
# L3 market: remove non-action filler and align gloss with Thai.
l3=sm['course_l_3_l3']; remove_ru(l3,{'Улыбка'}); 
for x in l3['items']:
 if x.get('ru')=='Давай по-честному': x['ru']='Реальная цена'; x['tip']='Здесь Thai означает «реальная цена», а не просьбу улыбнуться или шутку.'
changes += ['L3 remove non-action filler','L3 align real-price gloss']
l3=sm['course_l_3_l6']; remove_ru(l3,{'Король рынка'}); changes.append('L3 remove meta brand card')
# L11 festival: fix factually wrong event vocabulary.
l11=sm['course_l_11_l2'];
for x in l11['items']:
 if x.get('ru')=='Фонарики': x['ru']='Кратонг'; x['tip']='กระทง — это сам кратонг, который запускают по воде; не общее слово «фонарики».'
 if x.get('ru')=='Новолуние': x['ru']='Полнолуние'; x['tip']='Лой Кратонг связан с полной луной; не путай с новолунием.'
l11=sm['course_l_11_l1'];
for x in l11['items']:
 if x.get('ru')=='Веселья': x['ru']='Весело'; x['tip']='สนุก — «весело/приятно», так фраза звучит естественно по-русски.'
changes += ['L11 fix krathong gloss','L11 fix full-moon fact','L11 fix fun gloss']
# L12 salon: remove meta journey phrase and clarify a natural question.
l12=sm['course_l_12_l6']; remove_ru(l12,{'От входа до выхода'}); changes.append('L12 remove meta journey card')
for x in l12['items']:
 if x.get('ru')=='Удобно когда?': x['ru']='Когда вам удобно?'; x['tip']='Уточни удобное время для следующей записи.'
changes.append('L12 clarify scheduling gloss')
for cid in ['course_l_2','course_l_3','course_l_11','course_l_12']:
 for c in lessons['courses']:
  if c.get('course_id')==cid:
   for l in c['lessons']: l['card_count']=len(sm[l['lesson_id']]['items'])
for c in catalog:
 if c.get('id')=='course_l_3': c['description']='Рынок без хаоса: числа, единицы, цена, мягкий торг, выбор фруктов и честный итог.'
 if c.get('id')=='course_l_11': c['description']='Праздники Таиланда: Сонгкран, Лой Кратонг, Йи Пенг, поздравления, фото и уважительные границы.'
 if c.get('id')=='course_l_12': c['description']='Салон без сюрпризов: фото, длина, форма, массаж, границы, цена, результат и оплата.'
LESSONS.write_text(json.dumps(lessons,ensure_ascii=False,indent=2)+'\n'); STEPS.write_text(json.dumps(steps,ensure_ascii=False,indent=2)+'\n'); CATALOG.write_text(json.dumps(catalog,ensure_ascii=False,indent=2)+'\n')
print('changes:',changes)
