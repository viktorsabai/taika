import json
from pathlib import Path
r=json.loads(Path('content_quality_analysis.json').read_text(encoding='utf-8'))
for key in ['key_thai','key_ru','key_phonetic']:
    print('\n###', key)
    for x in r['duplicate_examples'][key][:40]:
        print(x['count'], '|', x['value'], '|', '; '.join(x['locations']))
print('\n### Complete duplicate records')
for x in r['complete_record_duplicates'][:80]: print(x['count'], x['key'], '; '.join(x['locations']))
print('\n### Course metrics')
for line in Path('course_metrics_table.md').read_text(encoding='utf-8').splitlines(): print(line)
