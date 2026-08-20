import json
from pathlib import Path
LESSONS= json.loads(Path('lessons.json').read_text(encoding='utf-8'))
STEPS= json.loads(Path('steps.json').read_text(encoding='utf-8'))
TARGET={'course_l_3','course_l_6','course_l_8','course_l_12','course_l_7'}
step_by={s['lesson_id']:s for s in STEPS['stepsets']}
life=[c for c in LESSONS['courses'] if c['course_id'].startswith('course_l_')]
print('life_courses',len(life),'life_lessons',sum(len(c['lessons']) for c in life))
print('target_cards',{c['course_id']:sum(len(step_by[l['lesson_id']]['items']) for l in c['lessons']) for c in life if c['course_id'] in TARGET})
print('life_cards',sum(len(step_by[l['lesson_id']]['items']) for c in life for l in c['lessons']))
print('empty_outcomes',sum(not l.get('outcomes') for c in life for l in c['lessons']))
print('empty_prerequisites',sum(not c.get('prerequisites') for c in life))
print('card_mismatches',sum(l['card_count']!=len(step_by[l['lesson_id']]['items']) for c in life for l in c['lessons']))
print('target_added_kind_counts',{k:sum(1 for c in life if c['course_id'] in TARGET for l in c['lessons'] for i in step_by[l['lesson_id']]['items'] if i.get('kind')==k and i.get('order')>8) for k in ['phrase','casual','tip','word']})
