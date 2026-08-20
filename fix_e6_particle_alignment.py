import json
from pathlib import Path
p=Path('steps.json'); data=json.loads(p.read_text(encoding='utf-8'))
for s in data['stepsets']:
    if s['lesson_id']=='course_e_6_l3':
        for i in s['items']:
            if i.get('order')==3:
                i['ru']='Нужен хвостик'
                i['tip']='В этой модели тайская фраза называет необходимость вежливого окончания; в живой речи решение всё равно зависит от адресата и ситуации.'
            if i.get('order')==9:
                i['ru']='Хвостик в каждой фразе'
                i['tip']='Это тема для проверки, а не универсальный приказ: не ставь частицу механически в каждую реплику.'
p.write_text(json.dumps(data,ensure_ascii=False,indent=2)+'\n',encoding='utf-8')
print('aligned E6 particle labels')
