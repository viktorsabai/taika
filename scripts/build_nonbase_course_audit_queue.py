import json
import re
from collections import defaultdict
from pathlib import Path

ROOT=Path(__file__).resolve().parents[1]
COURSE_PATH=ROOT/'taika/Resourses/taika_basa_course.json'
STEPS_PATH=ROOT/'steps.json'
OUT=ROOT/'docs/course_audits'
OUT.mkdir(parents=True, exist_ok=True)

courses=json.loads(COURSE_PATH.read_text())
steps=json.loads(STEPS_PATH.read_text())['stepsets']
by_course=defaultdict(list)
for ss in steps:
    cid=ss.get('course_id')
    if not cid or cid.startswith('course_b_'): continue
    for item in ss.get('items',[]):
        if item.get('kind') in {'phrase','casual'} and item.get('ru'):
            ru=item['ru'].strip()
            words=len(re.findall(r'[А-Яа-яЁёA-Za-z0-9]+',ru))
            signals=len(re.findall(r'[,;:?!]|\s+и\s+|\s+или\s+',ru,flags=re.I))
            by_course[cid].append((ss.get('lesson_id'),item.get('order'),ru,words,signals))

# Previously completed/drafted items are kept visible but excluded from the next queue.
status={
 'course_l_1':'implemented — police survival rewrite',
 'course_l_10':'drafted — gym phrase-bank proposal',
 'course_e_3':'implemented — service survival rewrite',
 'course_b_7':'implemented — excluded by base category',
}
rows=[]
for c in courses:
    cid=c.get('id')
    if not cid or c.get('category')=='База от Тайки' or cid.startswith('course_b_'): continue
    rs=by_course.get(cid,[])
    avg=sum(x[3] for x in rs)/len(rs) if rs else 0
    long=sum(x[3]>=6 for x in rs)
    multi=sum(x[4]>=1 for x in rs)
    st=status.get(cid,'pending')
    rows.append((0 if st=='pending' else 1,-multi,-avg,cid,c.get('category'),c.get('title'),len(rs),avg,long,multi,st))
rows.sort()
md=['# Non-base course audit queue','', '> Sequential audit only. Each course gets an independent draft; production JSON is not changed by this queue builder.','', '| Order | Course | Category | Phrase cards | Avg words | Multi-action signals | Status |','|---:|---|---|---:|---:|---:|---|']
for idx,row in enumerate(rows,1):
    _,_,_,cid,cat,title,n,avg,long,multi,st=row
    md.append(f'| {idx} | `{cid}` — {title} | {cat} | {n} | {avg:.1f} | {multi} | {st} |')
    if st=='pending':
        path=OUT/f'{cid}_draft.md'
        if not path.exists():
            path.write_text(f'''# Draft audit — {cid}: {title}\n\n**Category:** {cat}\n\n## Scope\n\nThis is a draft only. Production JSON is unchanged. Review one course at a time for compound phrasing, inappropriate wording, semantic duplicates and a clear user outcome.\n\n## Current signals\n\n- Phrase/casual cards: {n}\n- Average Russian phrase length: {avg:.1f} words\n- Cards with compound-action signals: {multi}\n- Cards with 6+ words: {long}\n\n## Course owner\n\n_To be defined after comparing neighboring course owners._\n\n## Keep / simplify / remove / add\n\n_To be completed during manual review._\n\n## Proposed short phrase banks\n\n_To be completed during manual review and native-speaker QA._\n\n## Acceptance checks\n\n- [ ] One card expresses one action.\n- [ ] No semantic duplicate with another course owner.\n- [ ] No long compound sentence in the beginner/default layer.\n- [ ] Russian intent is clear before Thai translation is approved.\n- [ ] Existing IDs, refs and progress semantics remain untouched until approved.\n''')
md.append('')
(ROOT/'docs/nonbase_course_audit_queue.md').write_text('\n'.join(md)+'\n')
print('QUEUE_BUILT',len(rows),'courses')
print('PENDING',sum(r[-1]=='pending' for r in rows))
