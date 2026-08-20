import json
from pathlib import Path

root = Path(__file__).parent
analysis = json.loads((root / 'remaining_categories_analysis.json').read_text(encoding='utf-8'))
want = {'Тайский для души', 'На одной волне'}
out = ['# Raw Methodology Dump: Тайский для души + На одной волне', '', '> Источник: текущие `lessons.json`, `steps.json` и каталог курсов. Этот файл отражает as-is состояние до рекомендаций.', '']
for c in analysis['courses']:
    if c['category'] not in want:
        continue
    out += [f"## {c['id']} — {c['title']}", '', c.get('description') or '', '', f"**PRO:** {c['is_pro']}  |  **Уроков:** {c['lessons']}  |  **Карточек:** {c['cards']}  |  **Типы:** `{c['kinds']}`", '']
    for l in c['lessons_detail']:
        out += [f"### {l['id']} — {l['title']}", '', f"**Subtitle:** {l['subtitle'] or '—'}  |  **Cards:** {l['cards']}  |  **Kinds:** `{l['kinds']}`", f"**Outcomes:** {l['outcomes'] or 'EMPTY'}  |  **Prerequisites:** {l['prerequisites'] or 'EMPTY'}", '']
        for i in l['items']:
            out.append(f"- `{i['order']}` **{i['kind']}** — RU: {i.get('ru') or '—'}; phonetic: `{i.get('phonetic') or '—'}`; tip: {i.get('tip') or '—'}")
        out.append('')
(root / 'remaining_categories_raw.md').write_text('\n'.join(out) + '\n', encoding='utf-8')
print('wrote remaining_categories_raw.md')
