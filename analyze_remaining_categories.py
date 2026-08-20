import json
import re
from collections import Counter, defaultdict
from pathlib import Path

ROOT = Path(__file__).parent
lessons = json.loads((ROOT / 'lessons.json').read_text(encoding='utf-8'))
steps = json.loads((ROOT / 'steps.json').read_text(encoding='utf-8'))
catalog = json.loads((ROOT / 'taika/Resourses/taika_basa_course.json').read_text(encoding='utf-8'))
step_by = {x.get('lesson_id'): x for x in steps.get('stepsets', [])}
cat_by = {x.get('id'): x for x in catalog}

rows = []
all_cards = []
for course in lessons.get('courses', []):
    cid = course.get('course_id')
    category = cat_by.get(cid, {}).get('category', 'unknown')
    course_cards = []
    lesson_rows = []
    for lesson in course.get('lessons', []):
        lid = lesson.get('lesson_id')
        items = step_by.get(lid, {}).get('items', []) or []
        course_cards.extend(items)
        all_cards.extend([{**item, '_course': cid, '_lesson': lid} for item in items])
        ru = [str(i.get('ru') or '').strip() for i in items if i.get('ru')]
        ph = [str(i.get('phonetic') or '').strip() for i in items if i.get('phonetic')]
        lesson_rows.append({
            'id': lid, 'order': lesson.get('order'), 'title': lesson.get('title'),
            'subtitle': lesson.get('subtitle'), 'cards': len(items),
            'kinds': dict(Counter(i.get('kind') for i in items)),
            'outcomes': lesson.get('outcomes') or [], 'prerequisites': lesson.get('prerequisites') or [],
            'duplicate_ru': [x for x, n in Counter(ru).items() if x and n > 1],
            'phonetic_missing_arrow': [p for p in ph if not re.search(r'[→↗↘]$', p)],
            'casual': [i.get('ru') for i in items if i.get('kind') == 'casual'],
            'tips': [i.get('tip') for i in items if i.get('kind') == 'tip' or i.get('tip')],
            'items': [{'order': i.get('order'), 'kind': i.get('kind'), 'ru': i.get('ru'), 'thai': i.get('thai'), 'phonetic': i.get('phonetic'), 'tip': i.get('tip')} for i in items]
        })
    ru_counter = Counter(str(i.get('ru') or '').strip() for i in course_cards if i.get('ru'))
    ph_counter = Counter(str(i.get('phonetic') or '').strip() for i in course_cards if i.get('phonetic'))
    rows.append({
        'id': cid, 'category': category, 'title': course.get('course_title'),
        'description': course.get('description'), 'is_pro': cat_by.get(cid, {}).get('is_pro'),
        'lessons': len(course.get('lessons', [])), 'cards': len(course_cards),
        'kinds': dict(Counter(i.get('kind') for i in course_cards)),
        'empty_outcomes': [l.get('lesson_id') for l in course.get('lessons', []) if not (l.get('outcomes') or [])],
        'empty_prerequisites_nonfirst': [l.get('lesson_id') for l in course.get('lessons', [])[1:] if not (l.get('prerequisites') or [])],
        'duplicate_ru': [{'value': x, 'count': n} for x, n in ru_counter.items() if x and n > 1],
        'duplicate_phonetic': [{'value': x, 'count': n} for x, n in ph_counter.items() if x and n > 1],
        'missing_arrows': [{'lesson': l['id'], 'value': p} for l in lesson_rows for p in l['phonetic_missing_arrow']],
        'lessons_detail': lesson_rows
    })

# Cross-course duplicate phrases, excluding tiny generic words and tips.
cross = defaultdict(list)
for c in rows:
    for l in c['lessons_detail']:
        for i in l['items']:
            val = str(i.get('ru') or '').strip().lower()
            if val and i.get('kind') in {'phrase', 'casual'} and len(val) >= 5:
                cross[val].append({'course': c['id'], 'lesson': l['id'], 'kind': i.get('kind')})

out = {
    'generated_from': {'lessons': 'lessons.json', 'steps': 'steps.json', 'catalog': 'taika/Resourses/taika_basa_course.json'},
    'summary': {
        'courses': len(rows), 'lessons': sum(x['lessons'] for x in rows), 'cards': sum(x['cards'] for x in rows),
        'categories': dict(Counter(x['category'] for x in rows)),
        'phonetic_missing_arrow_total': sum(len(x['missing_arrows']) for x in rows),
        'empty_outcomes_total': sum(len(x['empty_outcomes']) for x in rows),
        'empty_prerequisites_nonfirst_total': sum(len(x['empty_prerequisites_nonfirst']) for x in rows),
        'cross_course_duplicate_phrases': {k: v for k, v in cross.items() if len({x['course'] for x in v}) > 1}
    },
    'courses': rows
}
(ROOT / 'remaining_categories_analysis.json').write_text(json.dumps(out, ensure_ascii=False, indent=2), encoding='utf-8')

for category in ['Тайский для души', 'На одной волне']:
    print(f'\n## {category}')
    for c in rows:
        if c['category'] != category: continue
        print(f"{c['id']} | {c['title']} | lessons={c['lessons']} cards={c['cards']} kinds={c['kinds']} empty_outcomes={len(c['empty_outcomes'])} empty_prereq={len(c['empty_prerequisites_nonfirst'])} dup_ru={len(c['duplicate_ru'])} missing_arrows={len(c['missing_arrows'])}")
        for l in c['lessons_detail']:
            print(f"  {l['id']} | {l['title']} | cards={l['cards']} kinds={l['kinds']} | outcome={'yes' if l['outcomes'] else 'NO'} | prereq={'yes' if l['prerequisites'] else 'NO'} | casual={len(l['casual'])} | missing_arrows={len(l['phonetic_missing_arrow'])}")
print('\nSUMMARY', json.dumps(out['summary'], ensure_ascii=False))
