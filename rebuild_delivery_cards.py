import json
from pathlib import Path
LESSONS=Path('lessons.json'); STEPS=Path('steps.json'); CATALOG=Path('taika/Resourses/taika_basa_course.json')
lessons=json.loads(LESSONS.read_text()); steps=json.loads(STEPS.read_text()); catalog=json.loads(CATALOG.read_text())
sm={s['lesson_id']:s for s in steps['stepsets']}
def get(step, order): return next(x for x in step['items'] if x.get('order')==order)
changes=[]
# L2 address: delivery needs tower/floor/entrance/contact, not only postal vocabulary.
l2=sm['course_l_14_l2']
get(l2,4).update({'ru':'Этаж','thai':'ชั้น','phonetic':'чан↘','tip':'Для курьера этаж важнее длинного адреса: назови его после башни или дома.'})
get(l2,8).update({'ru':'У входа','thai':'หน้าประตู','phonetic':'на→ пра→ ту→','tip':'Скажи, где именно ждёшь курьера.'})
get(l2,9).update({'ru':'Телефон','thai':'เบอร์โทร','phonetic':'бо→ то→','tip':'Оставь контакт, если курьер не может попасть внутрь.'})
changes += ['L2: этаж','L2: вход','L2: телефон']
# L3: tracking must end in a useful request, not a generic thank-you.
l3=sm['course_l_14_l3']; get(l3,8).update({'ru':'Покажите трек','thai':'แสดงเลขติดตาม','phonetic':'са→ дэнг→ лек→ ти→ там→','tip':'Если статус непонятен, попроси показать или прислать tracking number.'}); changes.append('L3: tracking request')
# L4: make meeting/locker phrases concrete.
l4=sm['course_l_14_l4']; get(l4,6).update({'ru':'Жду у входа','thai':'รอหน้าประตู','phonetic':'ро→ на→ пра→ ту→','tip':'Дай курьеру одну понятную точку встречи.'}); get(l4,9).update({'ru':'Оставьте в ячейке','tip':'Thai phrase говорит об оставлении в locker/ячейке, не у консьержа.'}); changes += ['L4: meeting point','L4: semantic correction']
# L6: remove meta phrase, keep real receiving/inspection actions.
l6=sm['course_l_14_l6']; l6['items']=[x for x in l6['items'] if x.get('ru')!='От заказа до получения']; [x.update(order=i) for i,x in enumerate(l6['items'],1)]; changes.append('L6: remove meta card')
# L7: replace generic thanks with a useful tracking/support request and add a safety/resolution tip.
l7=sm['course_l_14_l7']; get(l7,8).update({'ru':'Покажите трек','thai':'แสดงเลขติดตาม','phonetic':'са→ дэнг→ лек→ ти→ там→','tip':'Для задержки нужен номер, по которому support найдёт посылку.'}); l7['items'].append({'kind':'tip','text':'Если посылка повреждена или не пришла, сохрани фото/трек и попроси конкретное решение: повторную доставку, замену или возврат.','order':len(l7['items'])+1}); changes += ['L7: support request','L7: damage/return tip']
for step in [l2,l3,l4,l6,l7]:
    step['hints']=['Сначала назови номер/адрес или факт проблемы, затем попроси один конкретный следующий шаг.','Не смешивай адрес, встречу, оплату и failure branch в одну карточку.']
for course in lessons['courses']:
    if course.get('course_id')=='course_l_14':
        course['description']='Доставка в Таиланде от заказа до получения: адрес, башня/этаж, трек, курьер, проверка посылки и delay/damage support.'
        for lesson in course['lessons']: lesson['card_count']=len(sm[lesson['lesson_id']]['items'])
for course in catalog:
    if course.get('id')=='course_l_14':
        course['description']='Доставка в Таиланде от заказа до получения: адрес, башня/этаж, трек, курьер, проверка посылки и delay/damage support.'
        course['lesson_count']=7
        course['learning_outcomes']=[{'type':'Delivery journey','count':7},{'type':'Delay, damage and support branches','count':7}]
LESSONS.write_text(json.dumps(lessons,ensure_ascii=False,indent=2)+'\n'); STEPS.write_text(json.dumps(steps,ensure_ascii=False,indent=2)+'\n'); CATALOG.write_text(json.dumps(catalog,ensure_ascii=False,indent=2)+'\n')
print('changes:',changes)
