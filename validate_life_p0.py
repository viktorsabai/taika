import json,subprocess
from collections import Counter
from pathlib import Path
less=json.loads(Path('lessons.json').read_text(encoding='utf-8'))
steps=json.loads(Path('steps.json').read_text(encoding='utf-8'))
step_by={s['lesson_id']:s for s in steps['stepsets']}
life=[c for c in less['courses'] if c['course_id'].startswith('course_l_')]
target={'course_l_2','course_l_4','course_l_13','course_l_14','course_l_5','course_l_9'}
print('life_courses',len(life),'life_lessons',sum(len(c['lessons']) for c in life),'life_cards',sum(len(step_by[l['lesson_id']]['items']) for c in life for l in c['lessons']))
print('empty_outcomes',sum(not l.get('outcomes') for c in life for l in c['lessons']))
print('empty_prerequisites',sum(not c.get('prerequisites') for c in life))
print('card_mismatches',sum(l['card_count']!=len(step_by[l['lesson_id']]['items']) for c in life for l in c['lessons']))
print('target_cards', {c['course_id']:sum(len(step_by[l['lesson_id']]['items']) for l in c['lessons']) for c in life if c['course_id'] in target})
print('added_tip_records',sum(1 for c in life if c['course_id'] in target for l in c['lessons'] for i in step_by[l['lesson_id']]['items'] if i.get('kind')=='tip'))
# strict arrow validator should still pass, since added tips have no phonetic.
