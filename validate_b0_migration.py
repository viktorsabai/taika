import json
from pathlib import Path

def load(path):
    return json.loads(Path(path).read_text(encoding='utf-8'))

old_steps=load('steps.json.course_b0-prechange.bak')
new_steps=load('steps.json')
old_map={s['lesson_id']:s for s in old_steps['stepsets']}
new_map={s['lesson_id']:s for s in new_steps['stepsets']}
changed=[]
for lid in old_map:
    if lid.startswith('course_b_0_'):
        continue
    if old_map[lid] != new_map[lid]: changed.append(lid)

old_lessons=load('lessons.json.course_b0-prechange.bak')
new_lessons=load('lessons.json')
def non_b0(data):
    return [c for c in data['courses'] if c['course_id']!='course_b_0']

print('non_b0_steps_changed',changed)
print('non_b0_lessons_unchanged',non_b0(old_lessons)==non_b0(new_lessons))
for s in new_steps['stepsets']:
    if s['lesson_id'].startswith('course_b_0_'):
        assert all(i['kind']=='tip' for i in s['items'])
        assert all('**' in i['text'] for i in s['items']), s['lesson_id']
        assert not any('\u0e00' <= c <= '\u0e7f' for i in s['items'] for c in i['text'])
        print(s['lesson_id'],len(s['items']),'tips','bold_examples=yes','thai_script=no')
assert not changed
assert non_b0(old_lessons)==non_b0(new_lessons)
print('REGRESSION_OK')
