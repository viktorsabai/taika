import json
from pathlib import Path
p=Path('steps.json')
data=json.loads(p.read_text(encoding='utf-8'))
by={s['lesson_id']:s for s in data['stepsets']}
fixes={
 ('course_b_1_l4',10):'май↘ кау→ джай→',
 ('course_b_1_l4',11):'пхут→ ик→ кхранг→ дай→ май↗',
 ('course_b_1_l4',12):'пхут→ ча↗ ча↗ ной→',
 ('course_b_1_l4',13):'кау→ джай→ лэу→',
 ('course_b_3_l7',12):'пэп↗ нунг→',
 ('course_b_4_l1',1):'сун→',
 ('course_b_4_l1',2):'нынг→',
 ('course_b_4_l1',3):'сонг→',
 ('course_b_4_l1',4):'саам→',
 ('course_b_4_l1',5):'сии↗',
 ('course_b_4_l1',6):'хаа↗',
 ('course_b_4_l1',7):'хок↘',
 ('course_b_4_l1',8):'джэт↘',
 ('course_b_4_l1',9):'пээт↘',
 ('course_b_4_l1',10):'као↗',
 ('course_b_4_l1',11):'сип→',
 ('course_b_4_l2',1):'сип→',
 ('course_b_4_l2',2):'сип→ эт↘',
 ('course_b_4_l2',3):'сип→ сонг→',
 ('course_b_4_l2',4):'йи→ сип→',
 ('course_b_4_l2',5):'йи→ сип→ эт↘',
 ('course_b_4_l2',6):'йи→ сип→ сонг→',
 ('course_b_4_l2',7):'саам→ сип→',
 ('course_b_4_l2',8):'рой↘',
 ('course_b_4_l2',9):'сонг→ рой↘ эт↘',
 ('course_b_4_l2',10):'пхан→',
 ('course_b_4_l2',11):'мыэн↘',
 ('course_b_4_l2',12):'лан↗',
 ('course_b_4_l3',12):'пэп↗ нунг→',
 ('course_b_5_l2',12):'ау→ лёй→',
 ('course_b_5_l3',12):'май↘ кхой→ кау→ джай→',
 ('course_b_6_l1',11):'сэп↘',
 ('course_b_6_l5',12):'о-кэ→',
 ('course_b_6_l6',13):'чил→',
 ('course_b_7_l1',6):'дай→ лёй→',
 ('course_b_7_l5',6):'май→ пен→ рай→',
}
seen=[]
for s in data['stepsets']:
 for i in s['items']:
  key=(s['lesson_id'],i.get('order'))
  if key in fixes:
   i['phonetic']=fixes[key]; seen.append(key)
missing=set(fixes)-set(seen)
assert not missing, missing
p.write_text(json.dumps(data,ensure_ascii=False,indent=2)+'\n',encoding='utf-8')
print('fixed',len(seen))
