import json
from collections import Counter
from pathlib import Path

lessons=json.loads(Path('lessons.json').read_text())
steps=json.loads(Path('steps.json').read_text())
step_map={s['lesson_id']:s for s in steps['stepsets']}
rows=[]; errors=[]; ru=[]
for c in lessons['courses']:
    if not c.get('course_id','').startswith('course_l_'): continue
    items=0
    for l in c['lessons']:
        got=len(step_map.get(l['lesson_id'],{}).get('items',[])); items+=got
        if l.get('card_count')!=got: errors.append((l['lesson_id'],l.get('card_count'),got))
        for i in step_map[l['lesson_id']]['items']:
            if i.get('ru'): ru.append(i['ru'].lower())
    rows.append((c['course_id'],len(c['lessons']),items))
print('courses=',len(rows),'lessons=',sum(x[1] for x in rows),'items=',sum(x[2] for x in rows))
print('card_count_errors=',len(errors),errors[:20])
print('contextual_tips=',sum(1 for c in lessons['courses'] if c.get('course_id','').startswith('course_l_') for l in c['lessons'] if step_map[l['lesson_id']]['items'] and step_map[l['lesson_id']]['items'][0].get('kind')=='tip'))
print('duplicate_ru_4plus=',[(x,n) for x,n in Counter(ru).most_common() if n>=4][:20])
for row in rows: print(*row)
Path('final_life_category_audit.txt').write_text('\n'.join(['%s|%s|%s'%r for r in rows])+'\n')
raise SystemExit(1 if errors else 0)
