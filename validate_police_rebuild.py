import json
import re
from collections import Counter
from pathlib import Path

lessons = json.loads(Path('lessons.json').read_text())
steps = json.loads(Path('steps.json').read_text())
catalog = json.loads(Path('taika/Resourses/taika_basa_course.json').read_text())

errors = []
course = next((c for c in lessons['courses'] if c.get('course_id') == 'course_l_1'), None)
if not course:
    errors.append('missing course_l_1')
else:
    if len(course.get('lessons', [])) != 7:
        errors.append(f"expected 7 lessons, got {len(course.get('lessons', []))}")

step_map = {s.get('lesson_id'): s for s in steps['stepsets'] if s.get('course_id') == 'course_l_1'}
required_by_lesson = {
    'course_l_1_l1': ['останов', 'здрав', 'случил'],
    'course_l_1_l2': ['права', 'байк', 'аренд'],
    'course_l_1_l3': ['шлем', 'один', 'пассажир', 'куда'],
    'course_l_1_l4': ['не понял', 'медлен', 'сделать'],
    'course_l_1_l5': ['наруш', 'штраф', 'оплат', 'квитан'],
    'course_l_1_l6': ['паспорт', 'виза', 'оригинал', 'копи'],
    'course_l_1_l7': ['останов', 'права', 'пассажир', 'штраф', 'паспорт'],
}
all_ru = []
for lesson in course.get('lessons', []) if course else []:
    lid = lesson['lesson_id']
    items = step_map.get(lid, {}).get('items', [])
    if lesson.get('card_count') != len(items):
        errors.append(f'{lid}: card_count={lesson.get("card_count")} items={len(items)}')
    if not items or items[0].get('kind') != 'tip':
        errors.append(f'{lid}: first item is not contextual tip')
    corpus = ' '.join(str(item.get('ru', item.get('text', ''))) for item in items).lower()
    for term in required_by_lesson.get(lid, []):
        if term not in corpus:
            errors.append(f'{lid}: missing required term {term}')
    for item in items:
        if item.get('kind') == 'tip':
            if not item.get('text'):
                errors.append(f'{lid}: empty tip')
            continue
        if not item.get('ru') or not item.get('thai') or not item.get('phonetic'):
            errors.append(f'{lid} order {item.get("order")}: incomplete card')
        if not re.search(r'[→↗↘↖↙↑↓]', item.get('phonetic', '')):
            errors.append(f'{lid} order {item.get("order")}: missing tone arrow')
        if '555' in (item.get('ru', '') + item.get('thai', '') + item.get('tip', '')):
            errors.append(f'{lid} order {item.get("order")}: casual 555 in police context')
        all_ru.append(item.get('ru', '').strip().lower())

counts = Counter(x for x in all_ru if x)
duplicates = sorted((x, n) for x, n in counts.items() if n > 1)
# Repeated phrases are allowed only in the capstone when they are explicitly part of branches.
for text, count in duplicates:
    if text not in {'остановитесь здесь, пожалуйста', 'не понял, повторите медленнее', 'что мне нужно сделать?'}:
        errors.append(f'duplicate RU card within Police Stop: {count}x {text}')

catalog_course = next((c for c in catalog if c.get('id') == 'course_l_1'), None)
if not catalog_course or catalog_course.get('lesson_count') != 7:
    errors.append('catalog course_l_1 lesson_count mismatch')

print('lessons:', len(course.get('lessons', [])) if course else 0)
print('items:', len(all_ru))
print('duplicate candidates:', duplicates)
print('errors:', len(errors))
for error in errors:
    print('ERROR:', error)
raise SystemExit(1 if errors else 0)
