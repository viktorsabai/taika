import json
from pathlib import Path
p=Path('steps.json'); data=json.loads(p.read_text(encoding='utf-8'))
by={s['lesson_id']:s for s in data['stepsets']}
fixes={
 ('course_b_2_l4',3):'са→ бай→ ди→ май↗',
 ('course_b_2_l4',4):'са→ бай→ ди→ май↗',
 ('course_b_6_l5',5):'пок→ га→ ти→',
 ('course_b_6_l5',12):'о→ кэ→',
 ('course_b_5_l3',6):'май↘ кау→ джай→',
 ('course_b_7_l5',6):'май→ пэн→ рай→',
}
seen=[]
for s in data['stepsets']:
 for i in s['items']:
  key=(s['lesson_id'],i.get('order'))
  if key in fixes: i['phonetic']=fixes[key]; seen.append(key)
assert set(seen)==set(fixes),(set(fixes)-set(seen))
p.write_text(json.dumps(data,ensure_ascii=False,indent=2)+'\n',encoding='utf-8')
print('normalized',len(seen))
