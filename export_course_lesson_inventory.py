import json
from pathlib import Path
x=json.loads(Path('audit_inputs/lessons.json').read_text(encoding='utf-8'))
with open('course_lesson_inventory.tsv','w',encoding='utf-8') as f:
    f.write('course_id\tcourse_block\tcourse_title\tlesson_id\tlesson_title\tlesson_count\trecord_count\n')
    for c in x.get('courses',[]):
        cid=c.get('course_id','')
        block=c.get('course_title') or ''
        lessons=c.get('lessons',[]) or []
        for l in lessons:
            f.write('\t'.join(str(v or '').replace('\t',' ') for v in [cid,block,c.get('course_title') or '',l.get('lesson_id') or l.get('id') or '',l.get('title') or l.get('name') or '',len(lessons),l.get('card_count') or ''])+'\n')
