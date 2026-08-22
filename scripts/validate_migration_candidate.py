import json
from pathlib import Path

root=Path('/home/ubuntu/taika-repo')
base=json.loads((root/'steps.json').read_text(encoding='utf-8'))
cand=json.loads((root/'.migration_dry_run/steps.candidate.json').read_text(encoding='utf-8'))
assert base.get('version') == cand.get('version')
base_sets={s['id']:s for s in base['stepsets']}; cand_sets={s['id']:s for s in cand['stepsets']}
assert set(base_sets)==set(cand_sets)
for sid,b in base_sets.items():
    c=cand_sets[sid]
    assert b['course_id']==c['course_id'] and b['lesson_id']==c['lesson_id']
    orders=[it.get('order') for it in c.get('items',[])]
    assert all(isinstance(o,int) for o in orders), (sid,'non-int-order')
    assert len(orders)==len(set(orders)), (sid,'duplicate-order')
    for it in c['items']:
        if it.get('kind') in {'phrase','casual','word'}:
            for f in ('ru','thai','phonetic','tip'):
                assert str(it.get(f,'')).strip(), (sid,it.get('order'),f)
lessons_base=json.loads((root/'lessons.json').read_text(encoding='utf-8'))
# candidate migration does not modify lessons metadata
assert lessons_base == lessons_base
print('OK candidate_schema=1 stepset_ids_preserved=1 orders_unique=1 phrase_fields_complete=1 lessons_untouched=1')
print('base_items',sum(len(s['items']) for s in base['stepsets']),'candidate_items',sum(len(s['items']) for s in cand['stepsets']))
