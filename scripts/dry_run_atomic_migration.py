import csv,json,shutil
from collections import defaultdict
from pathlib import Path
root=Path('/home/ubuntu/taika-repo'); outdir=root/'.migration_atomic_dry_run'; outdir.mkdir(exist_ok=True)
base_path=root/'steps.json'; candidate=outdir/'steps.atomic_candidate.json'; shutil.copy2(base_path,candidate)
steps=json.loads(candidate.read_text(encoding='utf-8'))
rows=list(csv.DictReader((root/'docs/nonbase_atomic_patch.tsv').open(encoding='utf-8'),delimiter='\t'))
by_lesson={s['lesson_id']:s for s in steps['stepsets']}; used=defaultdict(set)
for s in steps['stepsets']: used[s['lesson_id']]={i.get('order') for i in s['items'] if isinstance(i.get('order'),int)}
changes=[]; errors=[]
for r in rows:
 s=by_lesson.get(r['lesson_id'])
 if not s: errors.append((r['source_step_id'],'missing_lesson')); continue
 order=int(r['order']); payload={'order':order,'kind':r['kind'],'ru':r['ru'],'thai':r['thai'],'phonetic':r['phonetic'],'tip':r['tip']}
 if r['action']=='replace':
  matches=[i for i in s['items'] if i.get('order')==order]
  if len(matches)!=1: errors.append((r['source_step_id'],'replace_order_mismatch',str(order))); continue
  matches[0].update(payload); changes.append((r['course_id'],r['lesson_id'],'replace',r['source_step_id'],order))
 else:
  while order in used[r['lesson_id']]: order+=1
  payload['order']=order; s['items'].append(payload); used[r['lesson_id']].add(order); changes.append((r['course_id'],r['lesson_id'],'add',r['source_step_id'],order))
candidate.write_text(json.dumps(steps,ensure_ascii=False,indent=2)+'\n',encoding='utf-8')
summary=defaultdict(lambda:{'replace':0,'add':0})
for c,l,a,s,o in changes: summary[c][a]+=1
with (outdir/'summary.md').open('w',encoding='utf-8') as f:
 f.write('# Atomic migration dry-run\n\nProduction unchanged. Every input row is one atomic card.\n\n| Course | Replace | Add |\n|---|---:|---:|\n')
 for c in sorted(summary): f.write(f'| `{c}` | {summary[c]["replace"]} | {summary[c]["add"]} |\n')
 f.write(f'\nOperations: {len(changes)}. Errors: {len(errors)}.\n')
print(f'candidate={candidate} operations={len(changes)} errors={len(errors)} courses={len(summary)}')
