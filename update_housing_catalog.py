import json
from pathlib import Path
p=Path('taika/Resourses/taika_basa_course.json')
data=json.loads(p.read_text())
for course in data:
    if course.get('id')=='course_l_13':
        course['description']='Аренда жилья без хаоса: протечка, кондиционер, оплата, мастер, доступ, follow-up и соседи.'
        course['lesson_count']=7
        course['learning_outcomes']=[{'type':'Housing incident flow','count':7},{'type':'Repair, access and follow-up branches','count':7}]
p.write_text(json.dumps(data,ensure_ascii=False,indent=2)+'\n')
print('updated course_l_13 catalog')
