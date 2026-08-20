import json
from pathlib import Path


def load(path):
    return json.loads(Path(path).read_text(encoding='utf-8'))

old_steps=load('steps.json.b0-b2-b1-prechange.bak')
new_steps=load('steps.json')
old_map={s['lesson_id']:s for s in old_steps['stepsets']}
new_map={s['lesson_id']:s for s in new_steps['stepsets']}
target_prefixes=('course_b_0_','course_b_1_','course_b_2_')
changed_non_target=[lid for lid in old_map if not lid.startswith(target_prefixes) and old_map[lid]!=new_map[lid]]
old_lessons=load('lessons.json.b0-b2-b1-prechange.bak')
new_lessons=load('lessons.json')
old_non_target=[c for c in old_lessons['courses'] if not c['course_id'].startswith(('course_b_0','course_b_1','course_b_2'))]
new_non_target=[c for c in new_lessons['courses'] if not c['course_id'].startswith(('course_b_0','course_b_1','course_b_2'))]
assert old_non_target==new_non_target, 'non-target courses changed'
for s in new_steps['stepsets']:
    if s['lesson_id'].startswith(target_prefixes):
        orders=[i['order'] for i in s['items']]
        assert orders==list(range(1,len(orders)+1)), s['lesson_id']
for c in new_lessons['courses']:
    if c['course_id'].startswith(('course_b_0','course_b_1','course_b_2')):
        for l in c['lessons']:
            assert l['outcomes'], l['lesson_id']
            assert l['card_count']==len(new_map[l['lesson_id']]['items']), l['lesson_id']
            assert len(l['content'])==3, l['lesson_id']
print('changed_non_target_steps',changed_non_target)
print('non_target_courses_unchanged',True)
for cid in ['course_b_0','course_b_1','course_b_2']:
    c=next(c for c in new_lessons['courses'] if c['course_id']==cid)
    print(cid,[(l['lesson_id'],l['card_count'],l['prerequisites'],l['outcomes'][0]) for l in c['lessons']])
print('REGRESSION_OK')
