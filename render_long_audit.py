import json
from pathlib import Path
less=json.loads(Path('lessons.json').read_text(encoding='utf-8'))
steps=json.loads(Path('steps.json').read_text(encoding='utf-8'))
cat=json.loads(Path('taika/Resourses/taika_basa_course.json').read_text(encoding='utf-8'))
ids={c['id'] for c in cat if c.get('category')=='Тайский для долгожителей'}
by={s['lesson_id']:s for s in steps['stepsets']}
out=['# Long full card dump\n']
for c in less['courses']:
    if c['course_id'] not in ids: continue
    out.append(f"\n## {c['course_id']} — {c.get('course_title')}\nDescription: {c.get('description')}\n")
    for l in c['lessons']:
        out.append(f"\n### {l['lesson_id']} — {l['title']}\nSubtitle: {l.get('subtitle')}\nOutcome: {l.get('outcomes')}\nPrerequisites: {l.get('prerequisites')}\n")
        for i in by[l['lesson_id']]['items']:
            out.append(f"{i.get('order')}. [{i.get('kind')}] RU: {i.get('ru','')} | THAI: {i.get('thai','')} | PHON: {i.get('phonetic','')} | TIP: {i.get('tip','')}\n")
Path('long_full_card_dump.md').write_text('\n'.join(out),encoding='utf-8')
print('wrote',len(out),'blocks')
