import json
import re
from collections import Counter, defaultdict
from pathlib import Path

lessons=json.loads(Path('lessons.json').read_text())
steps=json.loads(Path('steps.json').read_text())
catalog=json.loads(Path('taika/Resourses/taika_basa_course.json').read_text())
step_map={s['lesson_id']:s for s in steps['stepsets']}
errors=[]
notes=[]
all_ru=[]
all_phonetic=[]
course_counts={}

for course in lessons['courses']:
    cid=course.get('course_id','')
    if not cid.startswith('course_l_'):
        continue
    lessons_list=course.get('lessons',[])
    course_counts[cid]=len(lessons_list)
    if not lessons_list:
        errors.append(f'{cid}: no lessons')
    for lesson in lessons_list:
        lid=lesson['lesson_id']; items=step_map.get(lid,{}).get('items',[])
        if lesson.get('card_count') != len(items):
            errors.append(f'{lid}: card_count {lesson.get("card_count")} != items {len(items)}')
        if not lesson.get('outcomes') or not all(str(x).strip() for x in lesson.get('outcomes',[])):
            errors.append(f'{lid}: empty outcomes')
        if not lesson.get('prerequisites'):
            errors.append(f'{lid}: empty prerequisites')
        if not items or items[0].get('kind') != 'tip':
            errors.append(f'{lid}: missing contextual first tip')
        tip_text=items[0].get('text','') if items else ''
        if lesson.get('title','') not in tip_text and cid != 'course_l_1':
            notes.append(f'{lid}: first tip may not name lesson title')
        for item in items:
            if item.get('kind') == 'tip':
                if not item.get('text'):
                    errors.append(f'{lid}: empty tip')
                continue
            ru=item.get('ru','').strip(); thai=item.get('thai','').strip(); phon=item.get('phonetic','').strip()
            if not ru or not thai or not phon:
                errors.append(f'{lid} order {item.get("order")}: incomplete card')
            if not re.search(r'[→↗↘↖↙↑↓]', phon):
                errors.append(f'{lid} order {item.get("order")}: no tone arrow')
            if '555' in (ru+thai+item.get('tip','')) and cid == 'course_l_1':
                errors.append(f'{lid}: 555 in police course')
            all_ru.append((cid,ru.lower()))
            all_phonetic.append((lid,phon))

# Cross-course duplicate report, not an automatic failure: a phrase may be valid in two contexts,
# but high-frequency filler should be reviewed with the lesson context.
counts=Counter(text for _,text in all_ru if text)
for text,count in counts.most_common():
    if count >= 4:
        notes.append(f'cross-course duplicate {count}x: {text}')

print('L courses:',len(course_counts))
print('L lessons:',sum(course_counts.values()))
print('L cards/items:',len(all_ru))
print('errors:',len(errors))
print('notes:',len(notes))
for item in errors: print('ERROR:',item)
print('--- top duplicate notes ---')
for item in notes[:80]: print('NOTE:',item)
raise SystemExit(1 if errors else 0)
