import json
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
OUT = ROOT / 'audit_outputs'
OUT.mkdir(exist_ok=True)

for filename in ['lessons.json', 'steps.json', 'taika/Resourses/taika_basa_course.json']:
    data = json.loads((ROOT / filename).read_text(encoding='utf-8'))
    print(f'\n=== {filename} ===')
    print('type:', type(data).__name__, 'top keys:', list(data)[:20] if isinstance(data, dict) else None)
    if isinstance(data, dict):
        for key, value in data.items():
            if isinstance(value, list):
                print('list', key, 'len', len(value))
        if filename.endswith('taika_basa_course.json'):
            print('sample:', json.dumps(data, ensure_ascii=False)[:1800])

resource = json.loads((ROOT / 'taika/Resourses/taika_basa_course.json').read_text(encoding='utf-8'))
print('\n=== CATEGORY RECORDS ===')
if isinstance(resource, list):
    records = resource
elif isinstance(resource, dict):
    records = resource.get('courses', resource.get('items', []))
else:
    records = []
print('records', len(records))
for record in records:
    if record.get('category') == 'На одной волне':
        print(json.dumps(record, ensure_ascii=False, indent=2)[:5000])
