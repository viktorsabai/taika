import json
from collections import Counter, defaultdict
from pathlib import Path

lessons = json.loads(Path('audit_inputs/lessons.json').read_text(encoding='utf-8'))
steps = json.loads(Path('audit_inputs/steps.json').read_text(encoding='utf-8'))

courses = lessons.get('courses', [])
step_map = {s.get('lesson_id'): s for s in steps.get('stepsets', [])}
lines=[]
lines.append('# Curriculum data summary\n')
lines.append(f'Courses: {len(courses)}; lesson bundles: {sum(len(c.get("lessons", [])) for c in courses)}; step sets: {len(step_map)}\n')
all_kinds=Counter(); all_ru=[]; all_th=[]
for course in courses:
    cid=course.get('course_id')
    ctitle=course.get('title')
    lessons_list=course.get('lessons', [])
    lines.append(f'## {cid} — {ctitle} ({len(lessons_list)} lessons)')
    for idx, lesson in enumerate(lessons_list, 1):
        lid=lesson.get('lesson_id')
        s=step_map.get(lid,{})
        items=s.get('items') or []
        kinds=Counter(i.get('kind') for i in items)
        all_kinds.update(kinds)
        ru=[i.get('ru') for i in items if i.get('ru')]
        th=[i.get('thai') for i in items if i.get('thai')]
        all_ru.extend(ru); all_th.extend(th)
        title=lesson.get('title') or lesson.get('name') or '—'
        outcome=lesson.get('outcome') or lesson.get('objective') or lesson.get('description') or ''
        lines.append(f'- {idx}. `{lid}` — {title} | steps={len(items)} | kinds={dict(kinds)} | outcome={outcome}')
    lines.append('')
lines.append('## Global kind mix')
lines.append(str(dict(all_kinds)))
Path('curriculum_summary.md').write_text('\n'.join(lines), encoding='utf-8')
print('\n'.join(lines[:45]))
print('GLOBAL_KINDS', dict(all_kinds))
