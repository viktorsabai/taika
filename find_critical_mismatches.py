import json,re
from pathlib import Path
data=json.loads(Path('steps.json').read_text())
for s in data['stepsets']:
 if s.get('course_id') not in {'course_l_9','course_l_8','course_l_10'}: continue
 for i in s.get('items',[]):
  ru=i.get('ru','')
  if any(x in ru.lower() for x in ['плохо','мне больно','боль','страх','заплатил','всё вместе','счёт','от диалога']):
   print(s['course_id'],s['lesson_id'],i.get('order'),ru,'|',i.get('thai',''),'|',i.get('phonetic',''))
