import json
from pathlib import Path
p=Path('lessons.json')
data=json.loads(p.read_text(encoding='utf-8'))
changed=False
for course in data['courses']:
    if course['course_id'] == 'course_e_5':
        for lesson in course['lessons']:
            if lesson['lesson_id'] == 'course_e_5_l6':
                lesson['title'] = 'Уточнить смысл в сцене'
                for block in lesson.get('content', []):
                    if block.get('kind') == 'apply':
                        block['text'] = 'Сегодня попробуй сцену «Уточнить смысл в сцене» вслух: сначала медленно со стрелками, потом естественным темпом.'
                changed=True
if not changed:
    raise SystemExit('course_e_5_l6 not found')
p.write_text(json.dumps(data, ensure_ascii=False, indent=2) + '\n', encoding='utf-8')
print('fixed course_e_5_l6 title')
