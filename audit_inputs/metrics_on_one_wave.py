import json, re
from collections import Counter, defaultdict
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
OUT = ROOT / 'audit_outputs'
OUT.mkdir(exist_ok=True)
lessons = json.loads((ROOT/'lessons.json').read_text(encoding='utf-8'))['courses']
stepsets = json.loads((ROOT/'steps.json').read_text(encoding='utf-8'))['stepsets']
meta = {x['id']: x for x in json.loads((ROOT/'taika/Resourses/taika_basa_course.json').read_text(encoding='utf-8'))}
selected_ids = {x['id'] for x in meta.values() if x.get('category') == 'На одной волне'}
course_map = {c['course_id']: c for c in lessons if c['course_id'] in selected_ids}
step_map = {s['lesson_id']: s for s in stepsets}
arrows = set('↗↘→↙↖')

def norm(s):
    return re.sub(r'\s+', ' ', (s or '').strip().lower())

def learnable(i): return i.get('kind') in {'word','phrase','casual','slang'}

rows=[]; all_key=defaultdict(list); ru_key=defaultdict(list); tips=Counter(); phonetic_missing=[]; card_mismatch=[]
for cid, course in course_map.items():
    cmeta=meta[cid]
    course_items=[]
    for lesson in sorted(course.get('lessons', []), key=lambda x:x.get('order',0)):
        ss=step_map.get(lesson['lesson_id'], {})
        items=ss.get('items', [])
        total_items=len(items)
        n=sum(learnable(i) for i in items)
        if total_items != lesson.get('card_count'):
            card_mismatch.append((cid, lesson['lesson_id'], lesson.get('card_count'), total_items))
        counts=Counter(i.get('kind','?') for i in items)
        rows.append({
            'course_id':cid,'course':cmeta['title'],'lesson_id':lesson['lesson_id'],'order':lesson.get('order'),
            'title':lesson.get('title'),'subtitle':lesson.get('subtitle'),'cards':total_items,'learnable':n,'declared':lesson.get('card_count'),
            'types':dict(counts),'prerequisites':lesson.get('prerequisites',[]),'outcomes':lesson.get('outcomes',[])
        })
        for i in items:
            if learnable(i):
                key=(norm(i.get('ru')), norm(i.get('thai')))
                all_key[key].append((cid, lesson['lesson_id'], i.get('kind'), i.get('ru')))
                ru_key[norm(i.get('ru'))].append((cid, lesson['lesson_id'], i.get('ru'), i.get('thai')))
                if i.get('tip'): tips[norm(i['tip'])]+=1
                if not any(ch in (i.get('phonetic') or '') for ch in arrows):
                    phonetic_missing.append((cid,lesson['lesson_id'],i))
                course_items.append(i)
    learnable_count=sum(r['cards'] for r in rows if r['course_id']==cid)
    rows_for=[r for r in rows if r['course_id']==cid]
    print(f"{cid}\t{cmeta['title']}\tlessons={len(rows_for)}\tcards={learnable_count}\tavg={learnable_count/len(rows_for):.1f}\tmin={min(r['cards'] for r in rows_for)}\tmax={max(r['cards'] for r in rows_for)}\ttypes={dict(Counter(k for i in course_items for k in [i.get('kind','?')]))}")

print('\nTOTAL courses',len(course_map),'lessons',len(rows),'cards',sum(r['cards'] for r in rows))
print('card mismatches',len(card_mismatch),card_mismatch[:20])
print('phonetic missing arrow',len(phonetic_missing))
print('exact item duplicates across lessons',sum(1 for k,v in all_key.items() if len(set((x[0],x[1]) for x in v))>1))
print('RU duplicate across lessons',sum(1 for k,v in ru_key.items() if len(set((x[0],x[1]) for x in v))>1))
print('RU duplicate samples:')
for k,v in sorted(ru_key.items(), key=lambda kv:-len(set((x[0],x[1]) for x in kv[1])))[:30]:
    locs=sorted(set(f'{x[0]}/{x[1]}' for x in v))
    if len(locs)>1: print(' ',k, '=>', ', '.join(locs))
print('lesson type profiles:')
for r in rows:         print(f"{r['course_id']} L{r['order']} {r['title']} | total={r['cards']} learnable={r['learnable']} | {r['types']} | prereq={r['prerequisites']}")
(OUT/'on_one_wave_metrics.txt').write_text('', encoding='utf-8')
