import json
from pathlib import Path
wanted={'course_l_3','course_l_12','course_l_8','course_e_5','course_long_4'}
root=Path(__file__).resolve().parents[1]
steps=json.loads((root/'steps.json').read_text())['stepsets']
out=Path('/tmp/next5_course_inventory.txt')
with out.open('w') as f:
    for ss in steps:
        if ss.get('course_id') in wanted:
            f.write(f"STEPSET {ss['id']} {ss.get('lesson_id')}\n")
            for i in ss.get('items',[]):
                if i.get('kind') in {'phrase','casual'}:
                    f.write(f"{i.get('order')} | {i.get('ru')}\n")
print(out)
