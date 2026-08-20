import json
import re
from collections import Counter, defaultdict
from pathlib import Path

DATA = Path('taika/Resourses/taika_basa_course.json')
OUT = Path('course_audit_raw.json')

with DATA.open(encoding='utf-8') as f:
    payload = json.load(f)

report = {
    'top_type': type(payload).__name__,
    'course_count': len(payload) if isinstance(payload, list) else None,
    'courses': [],
    'global': {
        'all_ids': [],
        'duplicate_ids': [],
        'field_counts': Counter(),
        'titles': [],
        'descriptions': [],
        'strings': [],
    },
}

for course in payload:
    if not isinstance(course, dict):
        continue
    item = {
        'id': course.get('id'),
        'title': course.get('title'),
        'is_pro': course.get('is_pro'),
        'lesson_count_declared': course.get('lesson_count'),
        'duration_minutes': course.get('duration_minutes'),
        'category': course.get('category'),
        'keys': sorted(course.keys()),
    }
    report['courses'].append(item)
    report['global']['all_ids'].append(course.get('id'))
    report['global']['titles'].append(course.get('title'))
    report['global']['descriptions'].append(course.get('description'))
    for key in course.keys():
        report['global']['field_counts'][key] += 1
    for value in course.values():
        if isinstance(value, str):
            report['global']['strings'].append(value)

report['global']['duplicate_ids'] = [k for k, v in Counter(report['global']['all_ids']).items() if v > 1]
report['global']['field_counts'] = dict(report['global']['field_counts'])
OUT.write_text(json.dumps(report, ensure_ascii=False, indent=2), encoding='utf-8')
print(json.dumps({
    'top_type': report['top_type'],
    'course_count': report['course_count'],
    'course_ids': report['global']['all_ids'],
    'duplicate_ids': report['global']['duplicate_ids'],
    'field_counts': report['global']['field_counts'],
}, ensure_ascii=False, indent=2))
