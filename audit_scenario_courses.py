import json
import re
from collections import Counter, defaultdict
from pathlib import Path

lessons_payload = json.loads(Path('lessons.json').read_text())
steps_payload = json.loads(Path('steps.json').read_text())

courses = {
    c.get('course_id'): c for c in lessons_payload.get('courses', [])
    if str(c.get('course_id', '')).startswith('course_l_')
}
stepsets = {
    s.get('lesson_id'): s for s in steps_payload.get('stepsets', [])
    if str(s.get('course_id', '')).startswith('course_l_')
}

keyword_groups = {
    'police_stop': ['права', 'байк', 'мото', 'шлем', 'пассажир', 'куда ед', 'откуда', 'штраф', 'квитанц', 'страхов', 'документ', 'паспорт', 'виза'],
    'taxi': ['такси', 'куда', 'адрес', 'цена', 'сдач', 'останов', 'повтор', 'пробк', 'байк', 'оплат'],
    'market': ['рын', 'цена', 'сколько', 'торг', 'числ', 'килограмм', 'штук', 'вес', 'свеж', 'пакет'],
    'food': ['еда', 'блюд', 'остр', 'без', 'аллерг', 'мяс', 'свин', 'куриц', 'счёт', 'заказ', 'упак'],
    'pharmacy': ['симптом', 'боль', 'температур', 'аллерг', 'лекар', 'доз', 'аптек', 'врач', 'страхов', 'не', 'помог'],
    'hotel': ['номер', 'бронь', 'заселен', 'высел', 'полотен', 'уборк', 'кондиционер', 'вайфай', 'шум', 'оплат'],
    'beach': ['пляж', 'шлем', 'спасател', 'течен', 'флаг', 'опас', 'тень', 'шезлонг', 'снорк', 'багаж'],
    'shop': ['магазин', 'товар', 'размер', 'цвет', 'цена', 'касс', 'чек', 'возврат', 'пакет', 'наличн'],
    'emergency': ['полици', 'скорая', 'пожар', 'адрес', 'больниц', 'украл', 'опас', 'помог', 'телефон', 'кров'],
    'immigration': ['виза', 'паспорт', 'иммиграц', 'продлен', 'адрес', 'документ', 'копи', 'штраф', '90', 'регистр'],
}

def key_for(course):
    title = course.get('course_title', '').lower()
    mapping = [('полиц', 'police_stop'), ('такс', 'taxi'), ('рын', 'market'), ('ед', 'food'), ('доктор', 'pharmacy'), ('отел', 'hotel'), ('пляж', 'beach'), ('магаз', 'shop'), ('сроч', 'emergency'), ('виз', 'immigration'), ('иммигр', 'immigration')]
    for marker, key in mapping:
        if marker in title:
            return key
    return 'other'

all_ru = []
report = []
for cid in sorted(courses, key=lambda x: int(x.rsplit('_', 1)[-1])):
    course = courses[cid]
    key = key_for(course)
    course_ru = []
    report.append(f"## {cid} — {course.get('course_title')}\n")
    report.append(f"**Description:** {course.get('description')}  \n**Lessons:** {len(course.get('lessons', []))}  \n**Expected card count:** {course.get('card_count', 'n/a')}\n")
    for lesson in sorted(course.get('lessons', []), key=lambda x: x.get('order', 0)):
        lid = lesson.get('lesson_id')
        items = stepsets.get(lid, {}).get('items', [])
        texts = []
        for item in items:
            text = ' '.join(str(item.get(k, '')) for k in ('ru', 'text', 'tip', 'thai')).strip()
            texts.append(text)
            if item.get('ru'):
                course_ru.append(item['ru'])
                all_ru.append(item['ru'])
        report.append(f"### L{lesson.get('order')} {lesson.get('title')} — {lesson.get('subtitle')}\n")
        report.append(f"Items: {len(items)}; declared cards: {lesson.get('card_count', 'n/a')}\n")
        for item in items:
            if item.get('ru') or item.get('text'):
                report.append(f"- `{item.get('kind')}` {item.get('ru') or item.get('text')} | {item.get('thai', '')} | {item.get('phonetic', '')}")
        report.append('')

    corpus = ' '.join(course_ru).lower()
    terms = keyword_groups.get(key, [])
    hits = [term for term in terms if term in corpus]
    misses = [term for term in terms if term not in corpus]
    report.append(f"**Keyword coverage heuristic ({key}):** hits={', '.join(hits) or 'none'}; gaps={', '.join(misses) or 'none'}\n")
    report.append('---\n')

# Cross-course exact RU duplicates among L courses.
counts = Counter(all_ru)
report.append('## Cross-course duplicate Russian card titles\n')
for text, count in sorted(counts.items()):
    if count > 1:
        report.append(f"- {count}× {text}")

Path('scenario_courses_situation_first_audit.md').write_text('\n'.join(report) + '\n')
print('courses', len(courses))
print('lessons', sum(len(c.get('lessons', [])) for c in courses.values()))
print('stepsets', len(stepsets))
print('cards with RU', len(all_ru))
print('duplicate RU titles', sum(1 for n in counts.values() if n > 1))
print('wrote scenario_courses_situation_first_audit.md')
