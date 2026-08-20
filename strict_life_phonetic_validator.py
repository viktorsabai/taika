import json
import re
from pathlib import Path

allowed=set('→↗↘↖↙↑↓')
data=json.loads(Path('steps.json').read_text())
issues=[]; records=0
for step in data['stepsets']:
    if not step.get('course_id','').startswith('course_l_'): continue
    for item in step.get('items',[]):
        phon=(item.get('phonetic') or '').strip()
        if not phon: continue
        records+=1
        for token in phon.split():
            if token[-1:] not in allowed:
                issues.append((step['course_id'],step['lesson_id'],item.get('order'),item.get('ru'),'missing_arrow',token,phon))
            if any(ch in token for ch in '[]/(){}'):
                issues.append((step['course_id'],step['lesson_id'],item.get('order'),item.get('ru'),'unsupported_markup',token,phon))
print('phonetic_records',records)
print('issues',len(issues))
for x in issues[:200]: print(x)
Path('strict_life_phonetic_report.json').write_text(json.dumps(issues,ensure_ascii=False,indent=2)+'\n')
raise SystemExit(1 if issues else 0)
