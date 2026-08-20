import json,re
from pathlib import Path
less=json.loads(Path('lessons.json').read_text(encoding='utf-8'))
steps=json.loads(Path('steps.json').read_text(encoding='utf-8'))
cat=json.loads(Path('taika/Resourses/taika_basa_course.json').read_text(encoding='utf-8'))
eids={c['id'] for c in cat if c.get('category')=='На одной волне'}
by={s['lesson_id']:s for s in steps['stepsets']}
issues=[]
universal=re.compile(r'тайц(?:ы|ев|ам)|всегда|обязателен|не всегда значит «?нет|возможно» = «?нет',re.I)
for c in less['courses']:
    if c['course_id'] not in eids: continue
    if len(c['lessons']) != 6: issues.append(('course_lessons',c['course_id']))
    for l in c['lessons']:
        items=by[l['lesson_id']]['items']
        core=[i for i in items if i.get('kind') in {'word','phrase','casual'}]
        if not core: issues.append(('no_core',l['lesson_id']))
        outcome=' '.join(l.get('outcomes',[]))
        if not re.search(r'шь|шься|шься|попрос|провед|скаж|пойм|уточн|замен|добав|выбер|распозна|поддерж|законч|сравн|держ',outcome,re.I): issues.append(('weak_outcome',l['lesson_id'],outcome))
        for i in items:
            for field in ('ru','tip','text'):
                if universal.search(str(i.get(field,''))):
                    issues.append(('universal_claim',l['lesson_id'],i.get('order'),field,i.get(field)))
    final=c['lessons'][-1]
    if not re.search(r'сцен|разговор|связ|сервис|смысл|тайск',final['title'],re.I): issues.append(('final_transfer_title',c['course_id'],final['title']))
print('EDUCATIONAL_GATE_ISSUES',len(issues))
for i in issues[:100]: print(i)
Path('e_educational_gate.json').write_text(json.dumps({'issues':issues},ensure_ascii=False,indent=2),encoding='utf-8')
if issues: raise SystemExit(1)
print('E_EDUCATIONAL_GATE_OK')
