import json, subprocess
from pathlib import Path

files=['lessons.json','steps.json','taika/Resourses/taika_basa_course.json']
prod='HEAD'
# Compare parsed records outside E courses. Formatting/order noise is ignored.
def load_work(path): return json.loads(Path(path).read_text(encoding='utf-8'))
def load_prod(path): return json.loads(subprocess.check_output(['git','show',f'{prod}:{path}']).decode('utf-8'))

def key_course(obj): return obj.get('course_id') or obj.get('id')
def is_e(obj): return str(key_course(obj)).startswith('course_e_')

issues=[]
for f in files:
    w=load_work(f); p=load_prod(f)
    if f=='lessons.json':
        for wc,pc in zip(w['courses'],p['courses']):
            if not is_e(wc) and wc != pc: issues.append((f, key_course(wc)))
            if is_e(wc) and key_course(wc)!=key_course(pc): issues.append((f,'course_order_changed'))
    elif f=='steps.json':
        for ws,ps in zip(w['stepsets'],p['stepsets']):
            if not is_e(ws) and ws != ps: issues.append((f,ws['lesson_id']))
    else:
        for wc,pc in zip(w,p):
            if not is_e(wc) and wc != pc: issues.append((f,key_course(wc)))
print('NON_E_SCOPE_ISSUES',len(issues))
for x in issues[:50]: print(x)
if issues: raise SystemExit(1)
print('E_SCOPE_OK')
