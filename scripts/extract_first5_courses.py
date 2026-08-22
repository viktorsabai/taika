import json
from pathlib import Path
wanted={'course_l_7','course_l_6','course_l_11','course_l_13','course_l_15'}
root=Path(__file__).resolve().parents[1]
steps=json.loads((root/'steps.json').read_text())['stepsets']
with (root/'/tmp' if False else Path('/tmp/first5_course_inventory.txt')).open('w') as out:
    for ss in steps:
        if ss.get('course_id') in wanted:
            out.write(f"STEPSET {ss['id']} {ss.get('lesson_id')}\n")
            for i in ss.get('items',[]):
                if i.get('kind') in {'phrase','casual'}:
                    out.write(f"{i.get('order')} | {i.get('ru')}\n")
