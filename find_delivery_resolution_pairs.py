import json
import re
from pathlib import Path
patterns=re.compile(r'возврат|верн|повреж|слом|разбит|замен|деньги|refund|не тот|непол')
data=json.loads(Path('steps.json').read_text())
for step in data['stepsets']:
    if not step.get('course_id','').startswith('course_'): continue
    for item in step.get('items',[]):
        ru=item.get('ru','')
        if patterns.search(ru.lower()):
            print(step['course_id'],step['lesson_id'],item.get('order'),ru,'|',item.get('thai',''),'|',item.get('phonetic',''))
