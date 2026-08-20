import json
from pathlib import Path
L=json.loads(Path('lessons.json').read_text(encoding='utf-8'))
S=json.loads(Path('steps.json').read_text(encoding='utf-8'))
TARGET={'course_l_1','course_l_10','course_l_11','course_l_15'}
sm={s['lesson_id']:s for s in S['stepsets']}
life=[c for c in L['courses'] if c['course_id'].startswith('course_l_')]
print('life_courses',len(life),'life_lessons',sum(len(c['lessons']) for c in life))
print('target_cards',{c['course_id']:sum(len(sm[l['lesson_id']]['items']) for l in c['lessons']) for c in life if c['course_id'] in TARGET})
print('life_cards',sum(len(sm[l['lesson_id']]['items']) for c in life for l in c['lessons']))
print('empty_outcomes',sum(not l.get('outcomes') for c in life for l in c['lessons']))
print('empty_prerequisites',sum(not c.get('prerequisites') for c in life))
print('card_mismatches',sum(l['card_count']!=len(sm[l['lesson_id']]['items']) for c in life for l in c['lessons']))
print('evergreen_l11',next(l['title'] for c in life if c['course_id']=='course_l_11' for l in c['lessons'] if l['lesson_id']=='course_l_11_l7'))
print('added_cards',17)
