import json
from pathlib import Path
from collections import Counter

ROOT = Path(__file__).resolve().parents[1]
OUT = ROOT / 'audit_outputs'
OUT.mkdir(exist_ok=True)
lessons_data = json.loads((ROOT / 'lessons.json').read_text(encoding='utf-8'))
steps_data = json.loads((ROOT / 'steps.json').read_text(encoding='utf-8'))
resource = json.loads((ROOT / 'taika/Resourses/taika_basa_course.json').read_text(encoding='utf-8'))
resource_by_id = {x['id']: x for x in resource}
course_ids = [x['id'] for x in resource if x.get('category') == 'На одной волне']
course_by_id = {x['course_id']: x for x in lessons_data['courses']}
steps_by_lesson = {x['lesson_id']: x for x in steps_data['stepsets']}

def item_text(item):
    if item.get('kind') in ('tip', 'hack', 'slang'):
        return item.get('text', '')
    return ' | '.join(str(item.get(k, '')) for k in ('kind','ru','thai','phonetic','tip') if item.get(k))

lines = ['# Audit extract — На одной волне', '', f'Курсов: {len(course_ids)}', '']
for cid in course_ids:
    meta = resource_by_id[cid]
    course = course_by_id.get(cid, {})
    lessons = sorted(course.get('lessons', []), key=lambda x: x.get('order', 0))
    all_items = []
    lines += [f"## {cid} — {meta['title']}", '', f"**Описание:** {meta.get('description','')}", '', '| # | Урок | Cards | Steps | Types | Prereq |', '|---:|---|---:|---:|---|---|']
    for lesson in lessons:
        sid = lesson.get('lesson_id')
        ss = steps_by_lesson.get(sid, {})
        items = ss.get('items', [])
        all_items.extend(items)
        types = ', '.join(f'{k}:{v}' for k,v in Counter(i.get('kind','?') for i in items).items())
        prereq = '; '.join(lesson.get('prerequisites', [])) or '—'
        lines.append(f"| {lesson.get('order','')} | {lesson.get('title','')} — {lesson.get('subtitle','')} | {lesson.get('card_count','')} | {len(items)} | {types} | {prereq} |")
    lines += ['', f"**Итого items:** {len(all_items)}; **types:** {dict(Counter(i.get('kind','?') for i in all_items))}", '']
    for lesson in lessons:
        sid = lesson.get('lesson_id')
        ss = steps_by_lesson.get(sid, {})
        items = ss.get('items', [])
        lines += [f"### Урок {lesson.get('order','')}: {lesson.get('title','')}", '', f"**Цель:** {'; '.join(lesson.get('outcomes', [])) or '—'}", f"**Контент:** {' / '.join(c.get('text','') for c in lesson.get('content', []))}", '', '| # | Kind | Материал |', '|---:|---|---|']
        for idx, item in enumerate(items, 1):
            lines.append(f"| {idx} | {item.get('kind','')} | {item_text(item).replace('|','／')} |")
        lines.append('')
(OUT / 'on_one_wave_audit_extract.md').write_text('\n'.join(lines), encoding='utf-8')
print('Wrote', OUT / 'on_one_wave_audit_extract.md')
print('courses', len(course_ids), 'course ids', course_ids)
for cid in course_ids:
    course = course_by_id[cid]
    lessons = course.get('lessons', [])
    all_items = [i for l in lessons for i in steps_by_lesson.get(l['lesson_id'], {}).get('items', [])]
    print(cid, resource_by_id[cid]['title'], 'lessons', len(lessons), 'cards', sum(l.get('card_count',0) for l in lessons), 'items', len(all_items), 'types', dict(Counter(i.get('kind','?') for i in all_items)))
