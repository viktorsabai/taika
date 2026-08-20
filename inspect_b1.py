import json
from pathlib import Path
root=Path('.')
lessons=json.loads((root/'lessons.json').read_text(encoding='utf-8'))
steps=json.loads((root/'steps.json').read_text(encoding='utf-8'))
for c in lessons['courses']:
    if c['course_id']=='course_b_1':
        print('COURSE',c['course_title'])
        print('description:',c.get('description'))
        for l in c['lessons']:
            print('\nLESSON',l['lesson_id'],l['title'])
            print('subtitle:',l.get('subtitle'),'cards:',l.get('card_count'),'preview:',l.get('preview_phrase'))
            for block in l.get('content',[]): print(block.get('kind'),':',block.get('text'))
for s in steps['stepsets']:
    if s['lesson_id'].startswith('course_b_1_'):
        print('\nSTEPSET',s['lesson_id'])
        for i in s.get('items',[]):
            print(i.get('order'),'|',i.get('kind'),'|',i.get('tip',''),'|',(i.get('text') or '').replace('\n',' / '))
