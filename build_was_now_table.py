import json, subprocess
from pathlib import Path
BASE='95ffb64'
files=['lessons.json','steps.json','taika/Resourses/taika_basa_course.json']
def load(path, rev=None):
 if rev:
  raw=subprocess.check_output(['git','show',f'{rev}:{path}'])
  return json.loads(raw)
 return json.loads(Path(path).read_text())
base_less=load('lessons.json',BASE); cur_less=load('lessons.json'); base_steps=load('steps.json',BASE); cur_steps=load('steps.json')
def index(less,steps):
 sm={s['lesson_id']:s for s in steps['stepsets']}; out={}
 for c in less['courses']:
  cid=c.get('course_id','')
  if not cid.startswith('course_l_'): continue
  rows=[]
  for l in c['lessons']:
   s=sm[l['lesson_id']]; rows.append({'id':l['lesson_id'],'title':l.get('title',''),'subtitle':l.get('subtitle',''),'count':len(s['items']),'cards':[i.get('ru') or i.get('text') or '' for i in s['items']]})
  out[cid]={'title':c.get('title',''),'description':c.get('description',''),'lessons':rows}
 return out
b=index(base_less,base_steps); c=index(cur_less,cur_steps)
lines=['# Thai for Life — было → стало','',f'Baseline: `{BASE}` → current: `HEAD`','', '| Курс | Было | Стало | Материалы/ключевые branches |','|---|---|---|---|']
for cid in c:
 old=b.get(cid,{}); new=c[cid]; old_titles='; '.join(x['title'] for x in old.get('lessons',[])); new_titles='; '.join(x['title'] for x in new['lessons']); old_count=sum(x['count'] for x in old.get('lessons',[])); new_count=sum(x['count'] for x in new['lessons']); changed=[]
 for ol,nl in zip(old.get('lessons',[]),new['lessons']):
  if ol['cards']!=nl['cards'] or ol['title']!=nl['title'] or ol['subtitle']!=nl['subtitle']:
   added=[x for x in nl['cards'] if x not in ol['cards']]; removed=[x for x in ol['cards'] if x not in nl['cards']]
   changed.append(f"{nl['title']}: +{', '.join(added[:3]) if added else '—'}; −{', '.join(removed[:3]) if removed else '—'}")
 lines.append(f"| **{cid.replace('course_l_','L')}** | {old_count} cards; {old_titles} | {new_count} cards; {new_titles} | {' / '.join(changed[:4]) or 'Контракт и карточки без diff'} |")
Path('thai_for_life_was_now_table.md').write_text('\n'.join(lines)+'\n')
print('courses',len(c),'lessons',sum(len(v['lessons']) for v in c.values()),'current_items',sum(x['count'] for v in c.values() for x in v['lessons']))
