import json
from pathlib import Path


def load(path):
    return json.loads(Path(path).read_text(encoding='utf-8'))

old_s=load('steps.json.b3-b7-prechange.bak')
new_s=load('steps.json')
old_map={s['lesson_id']:s for s in old_s['stepsets']}
new_map={s['lesson_id']:s for s in new_s['stepsets']}
remaining=('course_b_3_','course_b_4_','course_b_5_','course_b_6_','course_b_7_')
changed_earlier=[lid for lid in old_map if not lid.startswith(remaining) and old_map[lid]!=new_map[lid]]
assert not changed_earlier, changed_earlier
# Numerical rules that must be present.
b4_2=new_map['course_b_4_l2']['items']
text=' '.join((i.get('ru') or '')+' '+(i.get('phonetic') or '')+' '+(i.get('tip') or '') for i in b4_2)
for needle in ['Одиннадцать','Двадцать','Двадцать один','Сто','Тысяча','Миллион','сип эт','йи сип','йи сип эт']:
 assert needle.lower() in text.lower(), needle
new_l=load('lessons.json')
old_l=load('lessons.json.b3-b7-prechange.bak')
old_non=[c for c in old_l['courses'] if c['course_id'].startswith(('course_b_0','course_b_1','course_b_2'))]
new_non=[c for c in new_l['courses'] if c['course_id'].startswith(('course_b_0','course_b_1','course_b_2'))]
assert old_non==new_non, 'B0-B2 unexpectedly changed'
for c in new_l['courses']:
 if c['course_id'].startswith(remaining):
  for l in c['lessons']:
   items=new_map[l['lesson_id']]['items']
   assert l['card_count']==len(items), l['lesson_id']
   assert [i['order'] for i in items]==list(range(1,len(items)+1)), l['lesson_id']
   assert l.get('outcomes'), l['lesson_id']
   assert l.get('content') and len(l['content'])==3, l['lesson_id']
print('earlier_courses_unchanged',True)
print('number_rules_present',True)
for cid in ['course_b_3','course_b_4','course_b_5','course_b_6','course_b_7']:
 c=next(c for c in new_l['courses'] if c['course_id']==cid)
 print(cid,'lessons=',len(c['lessons']),'cards=',sum(l['card_count'] for l in c['lessons']),'outcomes=',len([l for l in c['lessons'] if l['outcomes']]))
print('REGRESSION_OK')
