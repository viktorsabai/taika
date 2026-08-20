import json
from pathlib import Path
data=json.loads(Path('steps.json').read_text())
for s in data['stepsets']:
 for i in s.get('items',[]):
  ru=i.get('ru','').lower()
  if any(x in ru for x in ['мне плохо','плохо себя','плохо чувств','нехорошо','болит']):
   print(s['course_id'],s['lesson_id'],i.get('order'),i.get('ru'),'|',i.get('thai'),'|',i.get('phonetic'))
