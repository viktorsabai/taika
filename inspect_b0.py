import json
from pathlib import Path
root=Path('audit_inputs')
lessons=json.loads((root/'lessons.json').read_text(encoding='utf-8'))
steps=json.loads((root/'steps.json').read_text(encoding='utf-8'))
print('COURSE')
for c in lessons['courses']:
    if c['course_id']=='course_b_0':
        print(c['course_title'])
        for l in c['lessons']:
            print('\nLESSON',l['lesson_id'],l['title'])
            print('subtitle:',l.get('subtitle'))
            print('duration:',l.get('duration_minutes'),'card_count:',l.get('card_count'))
            print('preview:',l.get('preview_phrase'))
            print('content:')
            for block in l.get('content',[]): print(' ',block.get('kind'),':',block.get('text'))
print('\nSTEPS')
for s in steps.get('stepsets',[]):
    if str(s.get('stepset_id','')).startswith('course_b_0') or str(s.get('lesson_id','')).startswith('course_b_0'):
        print('\nSTEPSET',s.get('stepset_id') or s.get('lesson_id'))
        for i in s.get('items',[]):
            print(i.get('kind'),'|',i.get('ru'),'|',i.get('thai'),'|',i.get('phonetic'),'| tip:',i.get('tip'))
