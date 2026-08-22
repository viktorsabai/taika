import csv, json, re
from collections import defaultdict
from pathlib import Path
from contextual_phrase_overrides import CONTEXTUAL
from context_quality_overrides import CONTEXT_OVERRIDES
from atomic_row_overrides import ROW_OVERRIDES
from phonetic_overrides import PHONETIC_OVERRIDES
from atomic_content_overrides import CONTENT_OVERRIDES

root=Path('/home/ubuntu/taika-repo')
base=json.loads((root/'steps.json').read_text(encoding='utf-8'))
base_orders={s['lesson_id']:max([it.get('order',0) for it in s.get('items',[]) if isinstance(it.get('order'),int)] or [0]) for s in base['stepsets']}
source=list(csv.DictReader((root/'docs/nonbase_production_record_gate.tsv').open(encoding='utf-8'),delimiter='\t'))
# Preserve the original order for replacements; append all additional atomic cards safely.
used_orders=defaultdict(set)
for s in base['stepsets']:
    used_orders[s['lesson_id']]={it.get('order') for it in s.get('items',[]) if isinstance(it.get('order'),int)}

def split_ru(value):
    return [x.strip().strip('«»') for x in value.split('/') if x.strip()]
def clean_variant(value):
    value=value.strip()
    value=re.sub(r'ครับ/ค่ะ|ครับ/คะ|ครับ / ค่ะ|ครับ / คะ', 'ครับ', value)
    value=re.sub(r'khráp/kha|khráp/khâ|khrap/kha|khrap/ka|khráp / kha|khráp / khâ|khrap / kha|khrap / ka', 'khráp', value)
    value=re.sub(r'krap/kha|krap/ka|krap / kha|krap / ka', 'krap', value)
    value=value.replace('ผม/ฉัน','ผม').replace('ผม / ฉัน','ผม').replace('ฉัน/ผม','ผม').replace('ฉัน / ผม','ผม')
    value=value.replace('/', ' ')
    return ' '.join(value.split())

def split_field(value, n):
    # Semantic card separators use spaces around slash; gender alternatives do not.
    parts=[x.strip() for x in value.split(' / ') if x.strip()]
    if n>1 and len(parts)==n: return [clean_variant(x) for x in parts]
    # Gender alternatives are not separate cards; choose the first polite variant so no slash remains.
    one=parts[0] if parts else value
    return [clean_variant(one)] * n

def next_order(lesson):
    x=base_orders.get(lesson,0)+1
    while x in used_orders[lesson]: x+=1
    used_orders[lesson].add(x); base_orders[lesson]=x
    return x

out=[]
for r in source:
    lesson=r['lesson_id']; parts=split_ru(r['ru'])
    content_override=CONTENT_OVERRIDES.get(r['source_step_id'])
    if content_override:
        parts=content_override['ru_parts']
        thai_parts=content_override['thai_parts']
        phon_parts=content_override['phonetic_parts']
    else:
        thai_parts=split_field(r['thai'],len(parts)); phon_parts=split_field(r['phonetic'],len(parts))
    old_order=int(r['order'])
    is_existing=not r['source_step_id'].startswith('NEW_')
    for i,part in enumerate(parts):
        if i==0 and is_existing:
            order=old_order; stable_id=r['source_step_id']; action='replace'
        else:
            order=next_order(lesson); stable_id=r['source_step_id'] if i==0 else f'{r["source_step_id"]}__part_{i+1}'; action='add'
        thai=thai_parts[i] if i<len(thai_parts) else thai_parts[0]
        phon=phon_parts[i] if i<len(phon_parts) else phon_parts[0]
        override=CONTEXTUAL.get((r['course_id'], part))
        if override:
            part, thai = override
            from pythainlp.transliterate import romanize
            phon = romanize(thai)
        row_override=ROW_OVERRIDES.get(r['source_step_id'])
        context_override=CONTEXT_OVERRIDES.get(stable_id) or CONTEXT_OVERRIDES.get(r['source_step_id'])
        if context_override:
            part=context_override['ru']; thai=context_override['thai']; phon=context_override['phonetic']
        elif row_override and i == 0:
            part=row_override['ru']; thai=row_override['thai']; phon=row_override['phonetic']
        if not context_override:
            phon = PHONETIC_OVERRIDES.get(r['source_step_id'], phon)
        if context_override:
            tip=context_override['tip']
        elif content_override:
            tip=content_override['tip_parts'][i]
        else:
            tip=(row_override['tip'] if row_override and i == 0 else r['tip']).replace('/', ' или ')
        out.append({
          'course_id':r['course_id'],'lesson_id':lesson,'source_step_id':stable_id,'parent_source_step_id':r['source_step_id'],
          'action':action,'kind':r['kind'],'order':order,'ru':part,'thai':thai,'phonetic':phon,'tip':tip,
          'scenario':r.get('scenario',''),'lifehack_or_glitch':r.get('lifehack_or_glitch',''),'qa_status':'native_review_required'
        })
fields=list(out[0])
out_tsv=root/'docs/nonbase_atomic_patch.tsv'
with out_tsv.open('w',encoding='utf-8',newline='') as f:
    w=csv.DictWriter(f,fieldnames=fields,delimiter='\t'); w.writeheader(); w.writerows(out)
summary=root/'docs/nonbase_atomic_patch_summary.md'
with summary.open('w',encoding='utf-8') as f:
    f.write('# Atomic patch summary\n\n')
    f.write('Every row is one card. No slash-separated lists are allowed in `ru`, `thai`, `phonetic`, or `tip`.\n\n')
    f.write(f'- Source records: {len(source)}\n- Atomic output cards: {len(out)}\n- Added by true enumeration splits: {len(out)-len(source)}\n- Courses: {len({r["course_id"] for r in out})}\n')
print(f'source={len(source)} atomic={len(out)} added_by_split={len(out)-len(source)} courses={len({r["course_id"] for r in out})}')
