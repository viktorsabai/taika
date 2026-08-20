import json
from pathlib import Path
less=json.loads(Path('lessons.json').read_text(encoding='utf-8'))
steps=json.loads(Path('steps.json').read_text(encoding='utf-8'))
step_by={s['lesson_id']:s for s in steps['stepsets']}
with Path('remaining_base_detail.txt').open('w',encoding='utf-8') as f:
 for c in less['courses']:
  if c['course_id'] not in {'course_b_3','course_b_4','course_b_5','course_b_6','course_b_7'}: continue
  f.write(f"\nCOURSE {c['course_id']} | {c['course_title']} | {c.get('description','')}\n")
  for l in c['lessons']:
   blocks={b['kind']:b.get('text','') for b in l.get('content',[])}
   f.write(f"\nLESSON {l['lesson_id']} | {l['order']} | {l['title']} | {l['subtitle']} | cards={len(step_by[l['lesson_id']]['items'])}\n")
   f.write(f"INTRO: {blocks.get('intro','')}\nOUTLINE: {blocks.get('outline','')}\nAPPLY: {blocks.get('apply','')}\n")
   for i in step_by[l['lesson_id']]['items']:
    f.write(f"CARD {i.get('order')} | {i.get('kind')} | ru={i.get('ru')} | phonetic={i.get('phonetic')} | tip={i.get('tip')} | text={i.get('text')}\n")
print('wrote remaining_base_detail.txt')
