import json,re
from pathlib import Path
p=re.compile(r'опас|спас|флаг|течен|не уме|помощ|плохо|не могу|кров|тон')
data=json.loads(Path('steps.json').read_text())
for s in data['stepsets']:
 if not s.get('course_id','').startswith('course_'): continue
 for i in s.get('items',[]):
  ru=i.get('ru','')
  if p.search(ru.lower()): print(s['course_id'],s['lesson_id'],i.get('order'),ru,'|',i.get('thai',''),'|',i.get('phonetic',''))
