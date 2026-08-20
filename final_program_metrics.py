import json
from collections import Counter, defaultdict
from pathlib import Path

ROOT = Path(__file__).parent
less = json.loads((ROOT/'lessons.json').read_text(encoding='utf-8'))
steps = json.loads((ROOT/'steps.json').read_text(encoding='utf-8'))
catalog = json.loads((ROOT/'taika/Resourses/taika_basa_course.json').read_text(encoding='utf-8'))
cat_by = {c['id']: c for c in catalog}
step_by = {s['lesson_id']: s for s in steps['stepsets']}
lesson_ids = {l['lesson_id'] for c in less['courses'] for l in c['lessons']}
all_ru = defaultdict(list)
all_thai = defaultdict(list)
rows=[]
for c in less['courses']:
    cid=c['course_id']; meta=cat_by.get(cid,{})
    items=[]; stale=[]; empty_outcomes=0
    for l in c['lessons']:
        its=step_by.get(l['lesson_id'],{}).get('items',[]) or []
        items.extend(its)
        if l.get('card_count') != len(its): stale.append({'lesson':l['lesson_id'],'declared':l.get('card_count'),'actual':len(its)})
        if not l.get('outcomes'): empty_outcomes += 1
        for i in its:
            ru=(i.get('ru') or '').strip().lower()
            thai=(i.get('thai') or '').strip()
            if ru and i.get('kind') in {'phrase','casual'}: all_ru[ru].append({'course':cid,'lesson':l['lesson_id'],'kind':i.get('kind')})
            if thai: all_thai[thai].append({'course':cid,'lesson':l['lesson_id'],'phonetic':i.get('phonetic'),'ru':i.get('ru')})
    rows.append({'id':cid,'category':meta.get('category'),'title':meta.get('title'),'lessons':len(c['lessons']),'cards':len(items),'kinds':dict(Counter(i.get('kind') for i in items)),'empty_outcomes':empty_outcomes,'stale_card_counts':stale,'casual':sum(i.get('kind')=='casual' for i in items)})
invalid_prereq=[]
for c in less['courses']:
    for l in c['lessons']:
        for p in l.get('prerequisites',[]) or []:
            if p not in lesson_ids: invalid_prereq.append({'lesson':l['lesson_id'],'prerequisite':p})
output={'summary':{'courses':len(rows),'lessons':sum(r['lessons'] for r in rows),'cards':sum(r['cards'] for r in rows),'categories':dict(Counter(r['category'] for r in rows)),'stale_card_count_total':sum(len(r['stale_card_counts']) for r in rows),'empty_outcomes_total':sum(r['empty_outcomes'] for r in rows),'invalid_prerequisites':len(invalid_prereq),'missing_stepsets':len(lesson_ids-set(step_by)),'orphan_stepsets':len(set(step_by)-lesson_ids),'casual_cards_total':sum(r['casual'] for r in rows)},'courses':rows,'invalid_prerequisites':invalid_prereq,'cross_course_duplicate_phrases':{k:v for k,v in all_ru.items() if len({x['course'] for x in v})>1},'inconsistent_thai_phonetics':{k:v for k,v in all_thai.items() if len({x['phonetic'] for x in v})>1}}
(ROOT/'final_program_metrics.json').write_text(json.dumps(output,ensure_ascii=False,indent=2),encoding='utf-8')
print(json.dumps(output['summary'],ensure_ascii=False,indent=2))
for cat in output['summary']['categories']:
    rr=[r for r in rows if r['category']==cat]
    print(cat, {'courses':len(rr),'lessons':sum(r['lessons'] for r in rr),'cards':sum(r['cards'] for r in rr),'casual':sum(r['casual'] for r in rr),'empty_outcomes':sum(r['empty_outcomes'] for r in rr),'stale_card_counts':sum(len(r['stale_card_counts']) for r in rr)})
print('cross duplicates',len(output['cross_course_duplicate_phrases']))
print('inconsistent Thai phonetics',len(output['inconsistent_thai_phonetics']))
