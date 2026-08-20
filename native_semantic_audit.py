import json,re
from pathlib import Path
from collections import Counter,defaultdict
lessons=json.loads(Path('lessons.json').read_text()); steps=json.loads(Path('steps.json').read_text()); sm={s['lesson_id']:s for s in steps['stepsets']}
red_meta=re.compile(r'от входа|от заказа до|от диалога|сценка|король рынка|мягко в чате|весело сегодня|всё ок|понятно$',re.I)
report=[]; stats=Counter(); course_stats=defaultdict(Counter)
for c in lessons['courses']:
 if not c.get('course_id','').startswith('course_l_'): continue
 for l in c['lessons']:
  for i in sm[l['lesson_id']]['items']:
   ru=(i.get('ru') or i.get('text') or '').strip()
   if not ru: continue
   stats['items']+=1; course_stats[c['course_id']]['items']+=1
   if i.get('kind')!='tip' and red_meta.search(ru):
    report.append({'type':'meta_or_abstract','course':c['course_id'],'lesson':l['lesson_id'],'order':i.get('order'),'ru':ru,'thai':i.get('thai','')}); stats['meta_flags']+=1
   if i.get('kind')=='casual': stats['casual']+=1
   if i.get('kind')=='tip': stats['tips']+=1
for cid,n in course_stats.items(): print(cid,dict(n))
print('stats',dict(stats)); print('flags',len(report))
for x in report: print(x)
Path('native_semantic_flags.json').write_text(json.dumps(report,ensure_ascii=False,indent=2)+'\n')
