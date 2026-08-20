import json
from collections import Counter, defaultdict
from pathlib import Path
root=Path('audit_inputs')
steps=json.loads((root/'steps.json').read_text(encoding='utf-8'))
tfm=json.loads((root/'taikafm.json').read_text(encoding='utf-8'))
canon=json.loads((root/'curriculum_lemma_canon.json').read_text(encoding='utf-8'))

records=[]
for s in steps.get('stepsets',[]):
  for i in s.get('items',[]) or []:
    records.append(i)

def flatten_strings(obj):
  out=[]
  if isinstance(obj,dict):
    for k,v in obj.items():
      if isinstance(v,str) and v.strip(): out.append((k,v))
      else: out.extend(flatten_strings(v))
  elif isinstance(obj,list):
    for x in obj: out.extend(flatten_strings(x))
  return out

print('taikafm top sections')
for k,v in tfm.items():
  if isinstance(v,dict): print(k, 'dict keys=',len(v), list(v)[:12])
  elif isinstance(v,list): print(k, 'list=',len(v))
  else: print(k, type(v).__name__)
print('canon')
for k,v in canon.items():
  print(k, type(v).__name__, len(v) if hasattr(v,'__len__') else '')

# use Thai source forms from steps and dictionary keys if present
thai={i.get('thai') for i in records if i.get('thai')}
ru={i.get('ru') for i in records if i.get('ru')}
print('step unique thai',len(thai),'ru',len(ru))
for sec in ['main','course','resume','scenarios','dictionary','mine','lessons','step','fav','speaker','profile','games']:
  v=tfm.get(sec,{})
  msgs=v.get('messages',[]) if isinstance(v,dict) else []
  reactions=v.get('reactions',[]) if isinstance(v,dict) else []
  print('section_payload',sec,'messages',len(msgs),'reactions',len(reactions),'sample',msgs[:2])

# quantify metadata completeness in step items
fields=['kind','order','ru','thai','phonetic','tip']
for f in fields:
  print('field',f,'filled',sum(bool(i.get(f)) for i in records),'missing',sum(not i.get(f) for i in records))
print('kind',Counter(i.get('kind') for i in records))
print('step items with tip by kind', {k:sum(1 for i in records if i.get('kind')==k and i.get('tip')) for k in sorted({i.get('kind') for i in records})})
print('step items with tone arrows in phonetic',sum(any(x in (i.get('phonetic') or '') for x in '↗↘↙↖→') for i in records))
