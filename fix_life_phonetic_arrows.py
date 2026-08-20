import json
from pathlib import Path
p=Path('steps.json'); data=json.loads(p.read_text())
changed=[]
for step in data['stepsets']:
    if step.get('course_id') not in {'course_l_1','course_l_15'}: continue
    for item in step.get('items',[]):
        phon=item.get('phonetic','')
        new=phon.replace('кхонг↗→','кхонг↗').replace('кхонг̌→','кхонг↗').replace('кхонг̌','кхонг↗').replace('пхом/чхан→','пхом→ чхан→').replace('чхёй̌','чхёй↗')
        if new != phon:
            item['phonetic']=new; changed.append((step['lesson_id'],item.get('ru'),phon,new))
p.write_text(json.dumps(data,ensure_ascii=False,indent=2)+'\n')
print('changed:',len(changed))
for x in changed: print(x)
