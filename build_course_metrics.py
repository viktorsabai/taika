import json
from collections import Counter
from pathlib import Path
catalog=json.loads(Path('taika/Resourses/taika_basa_course.json').read_text(encoding='utf-8'))
lessons=json.loads(Path('audit_inputs/lessons.json').read_text(encoding='utf-8'))
steps={x.get('lesson_id'):x for x in json.loads(Path('audit_inputs/steps.json').read_text(encoding='utf-8')).get('stepsets',[])}
lesson_by_course={}
for c in lessons.get('courses',[]): lesson_by_course[c.get('course_id')]=c.get('lessons',[])
rows=[]
for c in catalog:
    cid=c['id']; ls=lesson_by_course.get(cid,[]); items=[]; kinds=Counter()
    for l in ls:
        for item in steps.get(l.get('lesson_id'),{}).get('items',[]) or []:
            items.append(item); kinds[item.get('kind')]+=1
    rows.append({**{k:c.get(k) for k in ['id','title','category','is_pro','lesson_count','duration_minutes','short_description']},'actual_lessons':len(ls),'actual_steps':len(items),'kinds':dict(kinds),'learning_outcomes':c.get('learning_outcomes',[])})
Path('course_metrics.json').write_text(json.dumps(rows,ensure_ascii=False,indent=2),encoding='utf-8')
print('| ID | Category | PRO | Course | Lessons | Min | Steps | Types | |')
print('|---|---|---:|---|---:|---:|---:|---|')
for r in rows:
    print(f"| {r['id']} | {r['category']} | {'yes' if r['is_pro'] else 'no'} | {r['title']} | {r['actual_lessons']} | {r['duration_minutes']} | {r['actual_steps']} | {', '.join(f'{k} {v}' for k,v in r['kinds'].items())} |")
