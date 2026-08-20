import json,re
from pathlib import Path
from collections import Counter
less=json.loads(Path('lessons.json').read_text(encoding='utf-8'))
steps=json.loads(Path('steps.json').read_text(encoding='utf-8'))
cat=json.loads(Path('taika/Resourses/taika_basa_course.json').read_text(encoding='utf-8'))
ids={c['id'] for c in cat if c.get('category')=='Тайский для долгожителей'}
by={s['lesson_id']:s for s in steps['stepsets']}
meta=re.compile(r'сцен|вайб|контекст|пять|важн|диалог|словар|практик|код|стиль|говор|фраз|уровн|смысл|понят',re.I)
rows=[]; m=Counter()
for c in less['courses']:
    if c['course_id'] not in ids: continue
    m['courses']+=1
    for l in c['lessons']:
        items=by[l['lesson_id']]['items']; m['lessons']+=1; m['cards']+=len(items)
        m['casual']+=sum(i.get('kind')=='casual' for i in items); m['tips']+=sum(i.get('kind')=='tip' for i in items)
        labels=[i.get('ru') for i in items if i.get('ru') and meta.search(i.get('ru'))]
        rows.append({'course_id':c['course_id'],'course_title':c.get('course_title',c.get('title')),'course_description':c.get('description'),'lesson_id':l['lesson_id'],'title':l['title'],'subtitle':l.get('subtitle'),'outcomes':l.get('outcomes',[]),'prerequisites':l.get('prerequisites',[]),'card_count':l.get('card_count'),'actual_cards':len(items),'kinds':Counter(i.get('kind') for i in items),'casual':sum(i.get('kind')=='casual' for i in items),'meta_labels':labels,'cards':[(i.get('order'),i.get('kind'),i.get('ru'),i.get('thai'),i.get('phonetic')) for i in items]})
Path('long_inventory.json').write_text(json.dumps({'metrics':dict(m),'rows':rows},ensure_ascii=False,indent=2),encoding='utf-8')
with Path('long_inventory.md').open('w',encoding='utf-8') as f:
    f.write('# Long category inventory\n\n')
    f.write(f"Metrics: {dict(m)}\n\n")
    f.write('| Course | Lesson | Outcome | Cards | Casual | Meta-label candidates |\n|---|---|---|---:|---:|---|\n')
    for r in rows:
        f.write(f"| {r['course_id']} {r['course_title']} | {r['lesson_id']} {r['title']} | {'; '.join(r['outcomes'])} | {r['actual_cards']} | {r['casual']} | {'; '.join(r['meta_labels'])} |\n")
print('METRICS',dict(m)); print('ROWS',len(rows))
