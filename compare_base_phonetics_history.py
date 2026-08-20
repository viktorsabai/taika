import json, subprocess
from collections import defaultdict
allowed={'→','↗','↘'}
def load_current(): return json.loads(open('steps.json',encoding='utf-8').read())
def load_prev(): return json.loads(subprocess.check_output(['git','show','HEAD~1:steps.json']).decode('utf-8'))
def invalid(data):
 out=[]
 for s in data['stepsets']:
  if not s['lesson_id'].startswith('course_b_'): continue
  for i in s['items']:
   p=i.get('phonetic') or ''
   bad=[t for t in p.split() if t and t[-1] not in allowed]
   if bad: out.append((s['lesson_id'],i.get('order'),i.get('ru'),p))
 return out
cur=invalid(load_current()); prev=invalid(load_prev())
print('current_invalid_records',len(cur))
print('previous_invalid_records',len(prev))
print('new_invalid_records',len(set(cur)-set(prev)))
for row in sorted(set(cur)-set(prev)): print(row)
print('previous_only_invalid',len(set(prev)-set(cur)))
