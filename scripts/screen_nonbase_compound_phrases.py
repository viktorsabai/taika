import json, re
from pathlib import Path
from collections import defaultdict
ROOT=Path(__file__).resolve().parents[1]
steps=json.loads((ROOT/'steps.json').read_text())['stepsets']
flagged=defaultdict(list)
for ss in steps:
    cid=ss.get('course_id','')
    if not cid or cid.startswith('course_b_'): continue
    for item in ss.get('items',[]):
        if item.get('kind') not in {'phrase','casual'} or not item.get('ru'): continue
        ru=' '.join(item['ru'].split())
        words=re.findall(r'[А-Яа-яЁёA-Za-z0-9]+',ru)
        conjunctions=re.findall(r'\b(и|или|но|потому что|если|когда|чтобы|давайте|можно|нужно)\b',ru.lower())
        punctuation=re.findall(r'[,;:?!]',ru)
        action_verbs=re.findall(r'\b(можно|нужно|надо|давайте|попросите|покажите|скажите|принесите|заменить|оплатить|проверить|позвонить|продлить|записать|перенести|остановить|подождать|отправить|получить|взять|дать|сделать|открыть|закрыть)\w*\b',ru.lower())
        if len(words)>=6 or len(conjunctions)>=1 or len(punctuation)>=2 or len(action_verbs)>=2:
            flagged[cid].append({'lesson_id':ss.get('lesson_id'),'order':item.get('order'),'ru':ru,'words':len(words),'signals':sorted(set(conjunctions+punctuation+action_verbs))})
out=[]
for cid,items in sorted(flagged.items()):
    out.append(f'## {cid} — flagged {len(items)}')
    for x in items:
        out.append(f"- {x['lesson_id']} order {x['order']} ({x['words']} words; {', '.join(x['signals'])}): {x['ru']}")
    out.append('')
(ROOT/'docs/nonbase_compound_phrase_screen.md').write_text('\n'.join(out)+'\n')
print('FLAGGED_COURSES',len(flagged),'FLAGGED_CARDS',sum(map(len,flagged.values())))
for cid,items in sorted(flagged.items(), key=lambda kv:(-len(kv[1]),kv[0])):
    print(cid,len(items))
