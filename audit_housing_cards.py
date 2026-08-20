import json
from pathlib import Path

lessons=json.loads(Path('lessons.json').read_text())
steps=json.loads(Path('steps.json').read_text())
step_map={s['lesson_id']:s for s in steps['stepsets']}
course=next(c for c in lessons['courses'] if c['course_id']=='course_l_13')
lines=[f"# Baseline: {course['course_id']} — {course['course_title']}", '', f"Description: {course.get('description','')}", f"Prerequisites: {course.get('prerequisites',[])}", '']
for lesson in course['lessons']:
    step=step_map[lesson['lesson_id']]
    lines += [f"## L{lesson['order']} {lesson['lesson_id']} — {lesson['title']}", f"Subtitle: {lesson.get('subtitle','')}", f"Outcome: {lesson.get('outcomes',[])}", f"Card count: {lesson.get('card_count')} / {len(step.get('items',[]))}", '']
    for item in step.get('items',[]):
        if item.get('kind')=='tip':
            lines.append(f"{item.get('order')}. [TIP] {item.get('text','')}")
        else:
            lines.append(f"{item.get('order')}. [{item.get('kind')}] RU: {item.get('ru','')} | THAI: {item.get('thai','')} | PHON: {item.get('phonetic','')} | NOTE: {item.get('tip','')}")
    lines.append('')
Path('housing_course_baseline_ru.md').write_text('\n'.join(lines)+'\n')
print('wrote housing_course_baseline_ru.md')
