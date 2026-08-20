import json
from pathlib import Path
import sys
sys.path.insert(0, str(Path(__file__).resolve().parents[1] / 'scripts'))
from fix_phonetic_tones import normalize_phonetic
D=json.loads((Path(__file__).resolve().parents[1]/'steps.json').read_text(encoding='utf-8'))
for s in D['stepsets']:
    if not s.get('course_id','').startswith('course_e_'):
        continue
    for i in s.get('items',[]):
        p=i.get('phonetic')
        if p is not None and normalize_phonetic(p)!=p:
            print(s['course_id'], s['lesson_id'], i.get('order'), i.get('ru'), repr(p), '=>', repr(normalize_phonetic(p)))
