import json
from collections import Counter,defaultdict
from pathlib import Path
less=json.loads(Path('lessons.json').read_text(encoding='utf-8'))
steps=json.loads(Path('steps.json').read_text(encoding='utf-8'))
step_by={s['lesson_id']:s for s in steps['stepsets']}
cs=[c for c in less['courses'] if c['course_id'].startswith('course_l_')]
seen=defaultdict(list); tips=Counter(); kinds=Counter(); low=[]
for c in cs:
 for l in c['lessons']:
  items=step_by[l['lesson_id']]['items']; kinds.update(i.get('kind') for i in items)
  if len(items)<8: low.append((l['lesson_id'],len(items),l['title']))
  for i in items:
   if i.get('ru') and i.get('phonetic'):
    seen[(i.get('ru'),i.get('phonetic'))].append((c['course_id'],l['lesson_id'],i.get('order')))
   if i.get('tip'): tips[i['tip']]+=1
print('kinds',dict(kinds))
print('low_density',low)
print('duplicate_clusters',sum(len(v)>1 for v in seen.values()))
for k,v in sorted(seen.items(),key=lambda x:-len(x[1]))[:40]:
 if len(v)>1: print('DUP',k,v)
print('generic_tip_repeats')
for k,v in tips.most_common(30):
 if v>2: print(v,k)
