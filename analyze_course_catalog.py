import json
import re
from collections import Counter, defaultdict
from difflib import SequenceMatcher
from pathlib import Path

DATA = Path('taika/Resourses/taika_basa_course.json')
OUT = Path('course_catalog_analysis.json')

courses = json.loads(DATA.read_text(encoding='utf-8'))

def norm(value):
    value = value or ''
    value = value.lower().replace('ё', 'е')
    value = re.sub(r'[^\w\s]', ' ', value, flags=re.UNICODE)
    return re.sub(r'\s+', ' ', value).strip()

outcome_counter = Counter()
category_counter = Counter()
pro_counter = Counter()
icon_counter = Counter()
all_titles = []
all_descriptions = []
near_pairs = []
for c in courses:
    category_counter[c.get('category')] += 1
    pro_counter[bool(c.get('is_pro'))] += 1
    icon_counter[c.get('icon_name')] += 1
    all_titles.append(c.get('title') or '')
    all_descriptions.append(c.get('description') or '')
    for outcome in c.get('learning_outcomes') or []:
        outcome_counter[norm(outcome.get('type'))] += int(outcome.get('count') or 0)

for i in range(len(courses)):
    for j in range(i + 1, len(courses)):
        left = courses[i]
        right = courses[j]
        for field, values in [('title', (left.get('title'), right.get('title'))), ('description', (left.get('description'), right.get('description'))), ('short_description', (left.get('short_description'), right.get('short_description')))]:
            a, b = map(norm, values)
            if a and b:
                ratio = SequenceMatcher(None, a, b).ratio()
                if ratio >= 0.72:
                    near_pairs.append({'field': field, 'left_id': left.get('id'), 'right_id': right.get('id'), 'similarity': round(ratio, 3), 'left': values[0], 'right': values[1]})

lesson_counts = [int(c.get('lesson_count') or 0) for c in courses]
durations = [int(c.get('duration_minutes') or 0) for c in courses]
report = {
    'course_count': len(courses),
    'category_counts': dict(category_counter),
    'pro_counts': {'free': pro_counter[False], 'pro': pro_counter[True]},
    'declared_lessons_total': sum(lesson_counts),
    'duration_total_minutes': sum(durations),
    'duration_min_max_avg': {'min': min(durations), 'max': max(durations), 'avg': round(sum(durations)/len(durations), 2)},
    'lesson_count_min_max_avg': {'min': min(lesson_counts), 'max': max(lesson_counts), 'avg': round(sum(lesson_counts)/len(lesson_counts), 2)},
    'outcome_counts': dict(outcome_counter),
    'icon_counts': dict(icon_counter),
    'near_duplicate_pairs': near_pairs,
    'courses': courses,
}
OUT.write_text(json.dumps(report, ensure_ascii=False, indent=2), encoding='utf-8')
print(json.dumps({k: v for k, v in report.items() if k != 'courses'}, ensure_ascii=False, indent=2))
