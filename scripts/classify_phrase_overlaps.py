from pathlib import Path
from collections import defaultdict
import re

src = Path('/home/ubuntu/taika-repo/docs/proposed_phrase_overlap_inventory.tsv')
rows=[]
for line in src.read_text(encoding='utf-8').splitlines()[1:]:
    if not line.strip(): continue
    norm, phrase, course, lesson = line.split('\t')
    rows.append((norm, phrase, course, lesson))
by=defaultdict(list)
for r in rows: by[r[0]].append(r)

universal = {
    'до связи','всё хорошо','подождите','до встречи','достаточно','ещё раз','я пойду','всё','до свидания','спасибо','хорошо','готово','не понял','правильно?','медленнее','помогите','сейчас','потом','когда?','во сколько?','сколько?','дорого'
}

def classify(norm, matches):
    courses={m[2] for m in matches}
    if norm in universal:
        return 'shared_repair_or_exit', 'allow shared phrase ID; do not duplicate as a special course outcome'
    if any(k in norm for k in ['аэропорт','отель','налево','направо','такси','сдачи','счёт','груминг','вет','страховк','виза','полици','пакет','пиво','лед','остро','шлем','рынок']):
        return 'domain_overlap_candidate', 'assign one owner; use contextual variant or cross-reference elsewhere'
    return 'functional_overlap_candidate', 'compare intent and context; reuse phrase ID only when function matches'

out=['# Phrase deduplication map — draft layer only\n','Exact matches are not automatically errors. Classification is based on function/owner, not text alone.\n']
counts=defaultdict(int)
for norm,matches in sorted(by.items(), key=lambda kv:(-len(set(x[2] for x in kv[1])),kv[0])):
    courses=set(m[2] for m in matches)
    if len(courses)<2: continue
    kind, decision=classify(norm,matches); counts[kind]+=1
    out.append(f'## {matches[0][1]}\n- **Class:** `{kind}`\n- **Decision:** {decision}\n')
    for _,phrase,course,lesson in matches:
        out.append(f'- `{course}` / {lesson}: {phrase}')
    out.append('')
out.append('## Summary\n')
for k,v in counts.items(): out.append(f'- `{k}`: {v} exact overlap groups')
Path('/home/ubuntu/taika-repo/docs/nonbase_phrase_deduplication_map.md').write_text('\n'.join(out),encoding='utf-8')
print('\n'.join(out[:240]))
