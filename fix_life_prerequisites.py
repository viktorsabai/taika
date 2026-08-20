import json
from pathlib import Path
p=Path('lessons.json')
data=json.loads(p.read_text())
changed=[]
for course in data['courses']:
    cid=course.get('course_id','')
    if not cid.startswith('course_l_') or not course.get('lessons'):
        continue
    course_prereq=course.get('prerequisites') or ['course_b_1']
    first=course['lessons'][0]
    if not first.get('prerequisites'):
        first['prerequisites']=course_prereq
        changed.append(first['lesson_id'])
p.write_text(json.dumps(data,ensure_ascii=False,indent=2)+'\n')
print('fixed:',len(changed), changed)
