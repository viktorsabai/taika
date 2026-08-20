import json
from pathlib import Path
steps=json.loads(Path('steps.json').read_text(encoding='utf-8'))
for lid in ['course_e_6_l3','course_e_6_l4','course_e_6_l5','course_e_6_l6']:
    print('\n##', lid)
    for s in steps['stepsets']:
        if s['lesson_id']==lid:
            for i in s['items']:
                print(i.get('order'), i.get('kind'), '|', i.get('ru'), '|', i.get('thai'), '|', i.get('phonetic'), '|', i.get('tip'))
