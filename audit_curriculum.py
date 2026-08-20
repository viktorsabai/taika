import json
import re
from collections import Counter, defaultdict
from difflib import SequenceMatcher
from pathlib import Path

ROOT = Path('audit_inputs')
OUT = Path('curriculum_audit_raw.json')

def load(name):
    return json.loads((ROOT / name).read_text(encoding='utf-8'))

def norm(v):
    if v is None:
        return ''
    v = str(v).lower().replace('ё', 'е')
    v = re.sub(r'[^\w\s]', ' ', v, flags=re.UNICODE)
    return re.sub(r'\s+', ' ', v).strip()

def walk(obj, path=''):
    if isinstance(obj, dict):
        yield path, obj
        for k, v in obj.items():
            yield from walk(v, f'{path}.{k}' if path else k)
    elif isinstance(obj, list):
        for i, v in enumerate(obj):
            yield from walk(v, f'{path}[{i}]')

def find_lists(obj):
    result = []
    for path, node in walk(obj):
        if isinstance(node, list):
            sample = node[0] if node else None
            result.append({'path': path, 'length': len(node), 'sample_type': type(sample).__name__, 'sample_keys': sorted(sample.keys()) if isinstance(sample, dict) else None})
    return result

def collect_strings(obj):
    values=[]
    for _, node in walk(obj):
        if isinstance(node, str) and node.strip(): values.append(node.strip())
    return values

files = {}
for name in ['lessons.json','steps.json','taikafm.json','curriculum_lemma_canon.json']:
    data = load(name)
    files[name] = {
        'top_type': type(data).__name__,
        'top_keys': sorted(data.keys()) if isinstance(data, dict) else None,
        'lists': find_lists(data),
        'string_count': len(collect_strings(data)),
    }

lessons = load('lessons.json')
steps = load('steps.json')
canon = load('curriculum_lemma_canon.json')

# Flexible extraction for v1 schemas.
course_nodes=[]
lesson_nodes=[]
for path,node in walk(lessons):
    if isinstance(node, dict):
        keys=set(node)
        if {'course_id','lessons'} <= keys or {'courseID','lessons'} <= keys:
            course_nodes.append((path,node))
        if any(k in keys for k in ['lesson_id','lessonID']) and ('title' in keys or 'steps' in keys):
            lesson_nodes.append((path,node))

step_nodes=[]
for path,node in walk(steps):
    if isinstance(node, dict):
        keys=set(node)
        if any(k in keys for k in ['lesson_id','lessonID']) and any(k in keys for k in ['items','steps']):
            step_nodes.append((path,node))

# collect likely content records recursively
content_records=[]
for path,node in walk(steps):
    if isinstance(node, dict):
        keys=set(node)
        if keys.intersection({'ru','thai','text','tip','phonetic','transliteration','audio'}):
            content_records.append((path,node))

field_counts=Counter()
for _, node in content_records:
    for key in node: field_counts[key]+=1

text_fields=['ru','thai','text','tip','phonetic','transliteration','meaning','translation']
text_values=[]
for path,node in content_records:
    for field in text_fields:
        value=node.get(field)
        if isinstance(value,str) and value.strip():
            text_values.append({'path':path,'field':field,'value':value.strip(),'norm':norm(value)})

exact_groups=defaultdict(list)
for item in text_values:
    if item['norm']:
        exact_groups[(item['field'],item['norm'])].append(item['path'])
exact_duplicates=[{'field':k[0],'value':k[1],'count':len(v),'paths':v[:20]} for k,v in exact_groups.items() if len(v)>1]

# duplicate learning records by pair of learner-facing fields
pair_groups=defaultdict(list)
for path,node in content_records:
    ru=norm(node.get('ru') or node.get('text') or node.get('meaning'))
    th=norm(node.get('thai'))
    ph=norm(node.get('phonetic') or node.get('transliteration'))
    if ru or th or ph:
        pair_groups[(ru,th,ph)].append(path)
record_duplicates=[{'key':list(k),'count':len(v),'paths':v[:20]} for k,v in pair_groups.items() if len(v)>1 and any(k)]

# lesson order and IDs from detected nodes
lesson_summary=[]
for path,node in lesson_nodes:
    lid=node.get('lesson_id',node.get('lessonID'))
    lesson_summary.append({'path':path,'lesson_id':lid,'title':node.get('title'),'course_id':node.get('course_id',node.get('courseID')),'keys':sorted(node.keys())})

step_summary=[]
for path,node in step_nodes:
    items=node.get('items',node.get('steps'))
    step_summary.append({'path':path,'lesson_id':node.get('lesson_id',node.get('lessonID')),'item_count':len(items) if isinstance(items,list) else None,'hint_count':len(node.get('hints') or []) if isinstance(node.get('hints'),list) else None,'keys':sorted(node.keys())})

lesson_ids=[x['lesson_id'] for x in lesson_summary if x['lesson_id']]
step_lesson_ids=[x['lesson_id'] for x in step_summary if x['lesson_id']]
report={
    'files':files,
    'detected_course_nodes':len(course_nodes),
    'detected_lesson_nodes':len(lesson_nodes),
    'detected_step_sets':len(step_nodes),
    'content_record_count':len(content_records),
    'content_field_counts':dict(field_counts),
    'lesson_id_duplicates':[{'id':k,'count':v} for k,v in Counter(lesson_ids).items() if v>1],
    'step_lesson_id_duplicates':[{'id':k,'count':v} for k,v in Counter(step_lesson_ids).items() if v>1],
    'lessons_without_steps':sorted(set(lesson_ids)-set(step_lesson_ids)),
    'steps_without_lessons':sorted(set(step_lesson_ids)-set(lesson_ids)),
    'exact_text_duplicates':exact_duplicates,
    'duplicate_records':record_duplicates,
    'lesson_summary':lesson_summary,
    'step_summary':step_summary,
}
OUT.write_text(json.dumps(report,ensure_ascii=False,indent=2),encoding='utf-8')
print(json.dumps({k:v for k,v in report.items() if k not in {'lesson_summary','step_summary','exact_text_duplicates','duplicate_records','files'}},ensure_ascii=False,indent=2))
print('FILE STRUCTURES:')
for name, info in files.items():
    print(name, info['top_keys'], info['lists'][:12])
