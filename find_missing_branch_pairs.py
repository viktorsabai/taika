import json
from pathlib import Path
data=json.loads(Path('steps.json').read_text())
for s in data['stepsets']:
 for i in s.get('items',[]):
  ru=(i.get('ru') or '').lower()
  if any(t in ru for t in ['счётчику','счетчику','исправ','не так','передел','метр','короче']):
   print(s['course_id'],s['lesson_id'],i.get('ru'),'|',i.get('thai'),'|',i.get('phonetic'))
