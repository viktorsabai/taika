import json
from collections import Counter,defaultdict
from pathlib import Path
less=json.loads(Path('lessons.json').read_text(encoding='utf-8'))
steps=json.loads(Path('steps.json').read_text(encoding='utf-8'))
step_by={s['lesson_id']:s for s in steps['stepsets']}
base=[c for c in less['courses'] if c['course_id'].startswith('course_b_')]
print('courses',len(base),'lessons',sum(len(c['lessons']) for c in base))
print('cards',sum(len(step_by[l['lesson_id']]['items']) for c in base for l in c['lessons']))
print('empty_course_descriptions',[(c['course_id'],not bool(c.get('description'))) for c in base])
print('empty_lesson_outcomes',sum(not l.get('outcomes') for c in base for l in c['lessons']))
print('empty_prerequisites',sum(not l.get('prerequisites') for c in base for l in c['lessons']))
print('empty_assistant_tips',sum(not l.get('assistant_tips') for c in base for l in c['lessons']))
print('empty_content_blocks',sum(len(l.get('content',[]))<3 for c in base for l in c['lessons']))
print('card_count_mismatches',[(l['lesson_id'],l['card_count'],len(step_by[l['lesson_id']]['items'])) for c in base for l in c['lessons'] if l['card_count']!=len(step_by[l['lesson_id']]['items'])])
for c in base:
 kinds=Counter(i.get('kind') for l in c['lessons'] for i in step_by[l['lesson_id']]['items'])
 print(c['course_id'],'kinds',dict(kinds))
# exact phrase duplicates inside base
seen=defaultdict(list)
for c in base:
 for l in c['lessons']:
  for i in step_by[l['lesson_id']]['items']:
   key=(i.get('ru'),i.get('phonetic'),i.get('thai'))
   if key[0] and key[1]: seen[key].append((c['course_id'],l['lesson_id'],i.get('order')))
print('duplicate_phrase_clusters',sum(len(v)>1 for v in seen.values()))
for k,v in sorted(seen.items(),key=lambda kv:-len(kv[1]))[:30]:
 if len(v)>1: print('DUP',k,'=>',v)
# course-level titles and lesson subtitle map
for c in base:
 print('\nCOURSE',c['course_id'],c['course_title'],'|',c.get('description'))
 for l in c['lessons']:
  blocks={b['kind']:b.get('text','') for b in l.get('content',[])}
  print(' ',l['order'],l['lesson_id'],l['title'],'|',l['subtitle'],'|',blocks.get('intro',''),'|',blocks.get('outline',''),'|',blocks.get('apply',''))
