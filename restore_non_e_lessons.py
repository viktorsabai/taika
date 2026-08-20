import json, subprocess
from pathlib import Path
current=json.loads(Path('lessons.json').read_text(encoding='utf-8'))
base=json.loads(subprocess.check_output(['git','show','HEAD:lessons.json']).decode('utf-8'))
cur_by={c['course_id']:c for c in current['courses']}
merged=[]
for base_course in base['courses']:
    cid=base_course['course_id']
    if cid.startswith('course_e_'):
        merged.append(cur_by[cid])
    else:
        merged.append(base_course)
Path('lessons.json').write_text(json.dumps({'courses':merged},ensure_ascii=False,indent=2)+'\n',encoding='utf-8')
print('restored non-E lessons; kept E lessons:',sum(1 for c in merged if c['course_id'].startswith('course_e_')))
