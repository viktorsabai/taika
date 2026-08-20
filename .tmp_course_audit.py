import json
from pathlib import Path

path = Path('taika/Resourses/taika_basa_course.json')
data = json.loads(path.read_text(encoding='utf-8'))
if isinstance(data, dict):
    records = data.get('courses', data.get('items', []))
else:
    records = data
for category in ('На одной волне', 'Тайский для души'):
    print(f'CATEGORY\t{category}')
    for item in records:
        if item.get('category') != category:
            continue
        outcomes = '; '.join(f"{x.get('type')} ({x.get('count')})" for x in item.get('learning_outcomes', []))
        print('\t'.join([
            item.get('id', ''),
            item.get('title', ''),
            str(item.get('lesson_count', '')),
            str(item.get('duration_minutes', '')),
            'PRO' if item.get('is_pro') else 'FREE',
            item.get('short_description', ''),
            outcomes,
        ]))
    print()
print(f'TOTAL_RECORDS\t{len(records)}')
