import json
import re
import unicodedata
from collections import Counter, defaultdict
from difflib import SequenceMatcher
from pathlib import Path

root=Path('audit_inputs')
lessons=json.loads((root/'lessons.json').read_text(encoding='utf-8'))
steps=json.loads((root/'steps.json').read_text(encoding='utf-8'))
canon=json.loads((root/'curriculum_lemma_canon.json').read_text(encoding='utf-8'))

def norm(v):
    if v is None: return ''
    text=unicodedata.normalize('NFC',str(v).lower().replace('ё','е'))
    text=re.sub(r'[\\/|·•→↗↘↙↖—–\-]+',' ',text)
    text=re.sub(r'[^\w\u0E00-\u0E7F\s]',' ',text,flags=re.UNICODE)
    return re.sub(r'\s+',' ',text).strip()

course_rows=[]; lesson_rows=[]; records=[]
for course in lessons.get('courses',[]):
    cid=course.get('course_id'); course_rows.append(course)
    for li, lesson in enumerate(course.get('lessons',[]),1):
        lid=lesson.get('lesson_id'); s=next((x for x in steps.get('stepsets',[]) if x.get('lesson_id')==lid),{})
        items=s.get('items') or []
        kinds=Counter(i.get('kind') for i in items)
        orders=[i.get('order') for i in items if isinstance(i.get('order'),int)]
        lesson_rows.append({'course_id':cid,'course_index':course_rows.index(course),'lesson_index':li,'lesson_id':lid,'title':lesson.get('title'),'step_count':len(items),'kinds':dict(kinds),'order_dupes':[x for x,c in Counter(orders).items() if c>1],'order_gaps':[x for x in range(min(orders),max(orders)+1) if x not in orders] if orders else []})
        for item in items:
            records.append({'course_id':cid,'lesson_id':lid,'lesson_title':lesson.get('title'),'order':item.get('order'),'kind':item.get('kind'),'ru':item.get('ru'),'thai':item.get('thai'),'phonetic':item.get('phonetic'),'tip':item.get('tip'),'text':item.get('text')})

# duplicate learner-facing records across lessons
for r in records:
    r['key_ru']=norm(r['ru']); r['key_thai']=norm(r['thai']); r['key_phonetic']=norm(r['phonetic'])

def grouped(key):
    groups=defaultdict(list)
    for r in records:
        if r[key]: groups[r[key]].append(r)
    return {k:v for k,v in groups.items() if len(v)>1}

duplicates={}
for key in ['key_ru','key_thai','key_phonetic']:
    groups=grouped(key)
    duplicates[key]=[{'value':k,'count':len(v),'locations':[f"{x['course_id']}/{x['lesson_id']}#{x['order']}" for x in v[:12]],'samples':[x.get(key.replace('key_','')) for x in v[:5]]} for k,v in sorted(groups.items(),key=lambda kv:-len(kv[1]))]

# duplicate complete records
complete=defaultdict(list)
for r in records:
    key=(r['key_ru'],r['key_thai'],r['key_phonetic'])
    if any(key): complete[key].append(r)
complete_dupes=[{'key':list(k),'count':len(v),'locations':[f"{x['course_id']}/{x['lesson_id']}#{x['order']}" for x in v]} for k,v in complete.items() if len(v)>1]

# title repeats and close title pairs
all_titles=[(x['course_id'],x['lesson_id'],x['title']) for x in lesson_rows]
title_groups=defaultdict(list)
for cid,lid,t in all_titles:
    if t: title_groups[norm(t)].append((cid,lid,t))
exact_title_dupes=[v for v in title_groups.values() if len(v)>1]
close_titles=[]
for i in range(len(all_titles)):
    for j in range(i+1,len(all_titles)):
        a=norm(all_titles[i][2]); b=norm(all_titles[j][2])
        if a and b and a!=b and SequenceMatcher(None,a,b).ratio()>=.8:
            close_titles.append([all_titles[i],all_titles[j],round(SequenceMatcher(None,a,b).ratio(),3)])

step_counts=[x['step_count'] for x in lesson_rows]
kind_counts=Counter(r['kind'] for r in records)
course_kind=defaultdict(Counter)
for r in records: course_kind[r['course_id']][r['kind']]+=1

# course/lesson consistency against catalog
catalog=json.loads((Path('taika/Resourses/taika_basa_course.json')).read_text(encoding='utf-8'))
catalog_ids={c.get('id') for c in catalog}
lesson_course_ids={x['course_id'] for x in lesson_rows}
report={
 'course_count':len(course_rows), 'lesson_count':len(lesson_rows),'record_count':len(records),
 'step_count_stats':{'min':min(step_counts),'max':max(step_counts),'avg':round(sum(step_counts)/len(step_counts),2)},
 'kind_counts':dict(kind_counts), 'kind_percent':{k:round(v/len(records)*100,1) for k,v in kind_counts.items()},
 'course_ids_missing_from_catalog':sorted(lesson_course_ids-catalog_ids), 'catalog_ids_without_lessons':sorted(catalog_ids-lesson_course_ids),
 'order_duplicate_lesson_count':sum(bool(x['order_dupes']) for x in lesson_rows), 'order_gap_lesson_count':sum(bool(x['order_gaps']) for x in lesson_rows),
 'lesson_title_exact_duplicate_groups':exact_title_dupes, 'lesson_title_close_pairs':close_titles,
 'complete_record_duplicates':complete_dupes,
 'duplicate_counts':{k:len(v) for k,v in duplicates.items()},
 'duplicate_examples':{k:v[:30] for k,v in duplicates.items()},
 'course_kind_counts':{k:dict(v) for k,v in course_kind.items()},
 'lesson_rows':lesson_rows,
 'canon_keys':{k:len(v) if isinstance(v,(dict,list)) else type(v).__name__ for k,v in canon.items()},
}
Path('content_quality_analysis.json').write_text(json.dumps(report,ensure_ascii=False,indent=2),encoding='utf-8')
print(json.dumps({k:v for k,v in report.items() if k not in {'lesson_rows','duplicate_examples','complete_record_duplicates'}},ensure_ascii=False,indent=2))
