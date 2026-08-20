import json, subprocess
from pathlib import Path

def head_json(path):
    return json.loads(subprocess.check_output(['git','show',f'HEAD:{path}']).decode('utf-8'))

def current(path): return json.loads(Path(path).read_text(encoding='utf-8'))
issues=[]
for path, key, idfield in [('lessons.json','courses','course_id'),('steps.json','stepsets','lesson_id'),('taika/Resourses/taika_basa_course.json',None,'id')]:
    old=head_json(path); new=current(path)
    if key: oldmap={x[idfield]:x for x in old[key]}; newmap={x[idfield]:x for x in new[key]}
    else: oldmap={x[idfield]:x for x in old}; newmap={x[idfield]:x for x in new}
    for ident in sorted(set(oldmap)|set(newmap)):
        if oldmap.get(ident)!=newmap.get(ident):
            if not (ident.startswith('course_long_') or ident.startswith('course_long_')):
                issues.append((path,ident))
print('NON_LONG_SCOPE_ISSUES',len(issues))
for x in issues[:100]: print(x)
Path('long_scope_validation.json').write_text(json.dumps({'issues':issues},ensure_ascii=False,indent=2),encoding='utf-8')
if issues: raise SystemExit(1)
print('LONG_SCOPE_OK')
