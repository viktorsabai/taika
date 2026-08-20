import json
from pathlib import Path

current_lessons=json.loads(Path('lessons.json').read_text())
backup_lessons=json.loads(Path('lessons.json.police-stop-pre-rebuild.bak').read_text())
current_steps=json.loads(Path('steps.json').read_text())
backup_steps=json.loads(Path('steps.json.police-stop-pre-rebuild.bak').read_text())
current_catalog=json.loads(Path('taika/Resourses/taika_basa_course.json').read_text())
backup_catalog=json.loads(Path('taika/Resourses/taika_basa_course.json').read_text()) if False else None

# The catalog backup was not created during the Police Stop pass. Restore non-L1 metadata
# from the category-pass pre-restore snapshot, which contains the pre-contextualization state.
category_snapshot=json.loads(Path('taika/Resourses/taika_basa_course.json.category-pass-pre-restore').read_text())

backup_course_map={c['course_id']:c for c in backup_lessons['courses']}
for course in current_lessons['courses']:
    cid=course.get('course_id','')
    if cid.startswith('course_l_') and cid != 'course_l_1' and cid in backup_course_map:
        source=backup_course_map[cid]
        course.clear(); course.update(source)

backup_step_map={s['lesson_id']:s for s in backup_steps['stepsets']}
for step in current_steps['stepsets']:
    cid=step.get('course_id','')
    if cid.startswith('course_l_') and cid != 'course_l_1' and step['lesson_id'] in backup_step_map:
        source=backup_step_map[step['lesson_id']]
        step.clear(); step.update(source)

# Restore non-L1 catalog records from the snapshot taken before contextualization.
cat_map={c.get('id'):c for c in category_snapshot}
for index,course in enumerate(current_catalog):
    cid=course.get('id')
    if cid and cid.startswith('course_l_') and cid != 'course_l_1' and cid in cat_map:
        current_catalog[index]=cat_map[cid]

Path('lessons.json').write_text(json.dumps(current_lessons,ensure_ascii=False,indent=2)+'\n')
Path('steps.json').write_text(json.dumps(current_steps,ensure_ascii=False,indent=2)+'\n')
Path('taika/Resourses/taika_basa_course.json').write_text(json.dumps(current_catalog,ensure_ascii=False,indent=2)+'\n')
print('restored non-police courses; preserved course_l_1')
