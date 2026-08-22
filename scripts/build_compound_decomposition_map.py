import json, re
from pathlib import Path
from collections import defaultdict

ROOT = Path('/home/ubuntu/taika-repo')
stepsets = json.loads((ROOT/'steps.json').read_text(encoding='utf-8'))['stepsets']
course_meta = json.loads((ROOT/'taika_basa_course.json').read_text(encoding='utf-8')) if (ROOT/'taika_basa_course.json').exists() else {}
flagged=[]
conj = re.compile(r'\b(и|или|но|потому что|если|когда|чтобы|давайте)\b', re.I)
verbs = re.compile(r'\b(можно|нужно|надо|давайте|попросите|покажите|скажите|принесите|заменить|оплатить|проверить|позвонить|продлить|записать|перенести|остановить|подождать|отправить|получить|взять|дать|сделать|открыть|закрыть|починить|пересчитать|вернуться|донести|записаться|обсудить)\w*\b', re.I)
for ss in stepsets:
    cid=ss.get('course_id','')
    if not cid or cid.startswith('course_b_'): continue
    for item in ss.get('items',[]):
        if item.get('kind') not in {'phrase','casual'} or not item.get('ru'): continue
        ru=' '.join(item['ru'].split())
        words=re.findall(r'[А-Яа-яЁёA-Za-z0-9]+',ru)
        c=conj.findall(ru)
        p=re.findall(r'[,;:?!]',ru)
        v=verbs.findall(ru)
        if len(words)>=6 or len(c)>=1 or len(p)>=2 or len(v)>=2:
            flagged.append({'course_id':cid,'lesson_id':ss.get('lesson_id'),'step_id':f"{ss.get('lesson_id')}_o{item.get('order')}",'order':item.get('order'),'original_text':ru,'words':len(words),'signals':sorted(set([x.lower() for x in c]+p+[x.lower() for x in v]))})

def classify(row):
    ru=row['original_text']; low=ru.lower(); words=row['words']; sig=row['signals']
    if ' или ' in low and words <= 4:
        return ('choice_list','keep_or_split_if_choice_is_not_clear', 'Короткий выбор; не считать сложносочинённой автоматически.')
    if ' и ' in low and words <= 4 and not any(x in low for x in ['можно','нужно','давайте','попрос','покаж','сдел','запис','верн','донес']):
        return ('noun_list','keep_as_one_target', 'Естественный список объектов; split только если нужна отдельная тренировка каждого объекта.')
    action_matches = re.findall(r'\b(можно|нужно|надо|давайте|попросите|покажите|скажите|принесите|заменить|оплатить|проверить|позвонить|продлить|записать|перенести|остановить|подождать|отправить|получить|взять|дать|сделать|открыть|закрыть|починить|пересчитать|вернуться|донести|записаться|обсудить)\w*',low)
    substantive = [x for x in action_matches if x not in {'можно','нужно','надо','давайте'}]
    compound_conj = re.search(r'\b(и|но|потому что|если|чтобы)\b', low)
    if ',' in ru or words >= 6 or len(set(substantive)) >= 2 or (compound_conj and words >= 5):
        return ('compound_action','split_into_atomic_cards', 'Каждая карточка должна содержать одно действие; контекст/причину вынести в tip или notes.')
    if '?' in ru and words >= 4:
        return ('long_question','shorten_question', 'Оставить один вопрос и один объект; дополнительные уточнения вынести в следующую карточку.')
    if '?' in ru:
        return ('short_question','keep_or_review', 'Короткий вопрос; не считать перегруженным автоматически, проверить naturalness.')
    return ('review','review_for_naturalness', 'Автофлаг недостаточен; проверить у методиста.')

def split_suggest(ru, kind):
    if kind=='choice_list':
        return f'Короткий выбор: «{ru}» — оставить одной карточкой; при необходимости разделить на названия вариантов.'
    if kind=='noun_list':
        parts=re.split(r'\s+и\s+',ru,flags=re.I)
        return ' / '.join('«'+p.strip()+'»' for p in parts)
    # conservative decomposition templates, preserving semantic atoms rather than inventing Thai
    if kind in {'short_question','long_question'}:
        return f'«{ru}» — оставить как одну карточку; при необходимости уточнение сделать отдельным step'
    parts=re.split(r'\s*,\s*|\s+и\s+|\s+но\s+|\s+потому что\s+|\s+если\s+|\s+когда\s+',ru,flags=re.I)
    parts=[p.strip(' .') for p in parts if p.strip(' .')]
    if len(parts)>1:
        return ' / '.join('«'+p+'»' for p in parts)
    if ru.endswith('?'):
        base=ru[:-1]
        base=re.sub(r'\b(пожалуйста|сегодня|завтра)\b','',base,flags=re.I).strip()
        return f'«{base}?»'
    return f'«{ru}» — упростить после native QA'

bycourse=defaultdict(list)
for row in flagged:
    kind,action,notes=classify(row)
    row.update({'problem_type':kind,'recommended_action':action,'atomic_replacements':split_suggest(row['original_text'],kind),'notes_replacement':notes,'owner':row['course_id'],'shared_phrase_ids':'TBD after canonical phrase pass','qa_status':'draft — Russian intent; Thai/native QA required'})
    bycourse[row['course_id']].append(row)

# TSV is the migration-ready working table.
tsv=ROOT/'docs/nonbase_compound_decomposition_map.tsv'
with tsv.open('w',encoding='utf-8') as f:
    cols=['course_id','lesson_id','step_id','order','original_text','problem_type','recommended_action','atomic_replacements','notes_replacement','owner','shared_phrase_ids','qa_status']
    f.write('\t'.join(cols)+'\n')
    for row in flagged:
        f.write('\t'.join(str(row.get(c,'' )).replace('\t',' ') for c in cols)+'\n')

md=['# Полная карта декомпозиции перегруженных карточек\n','**Scope:** все 30 не-базовых курсов; только аналитика/draft, production JSON не меняется.\n','**Rule:** одна карточка — одно речевое действие. Автофлаги требуют ручной проверки; короткие списки объектов и варианты не удаляются автоматически.\n']
md.append(f'## Сводка\n\n- Flagged cards: **{len(flagged)}**\n- Courses covered: **{len(bycourse)}**\n- `compound_action`: **{sum(r["problem_type"]=="compound_action" for r in flagged)}**\n- `long_question`: **{sum(r["problem_type"]=="long_question" for r in flagged)}**\n- `noun_list`: **{sum(r["problem_type"]=="noun_list" for r in flagged)}**\n- `choice_list`: **{sum(r["problem_type"]=="choice_list" for r in flagged)}**\n\n')
for cid, rows in sorted(bycourse.items()):
    md.append(f'## {cid} — {len(rows)} flagged cards\n')
    md.append('| Step | Было | Тип | Решение / atomic draft | Notes | QA |\n|---|---|---|---|---|---|')
    for r in rows:
        def esc(x): return str(x).replace('|','\\|').replace('\n',' ')
        md.append(f"| `{r['step_id']}` | {esc(r['original_text'])} | `{r['problem_type']}` | {esc(r['atomic_replacements'])} | {esc(r['notes_replacement'])} | {esc(r['qa_status'])} |")
    md.append('')
md.append('## Правило миграции\n\nЭта карта не является готовым JSON. Перед миграцией нужно подтвердить Thai naturalness, назначить canonical phrase IDs, обновить card_count только после решения keep/split, сохранить исходные IDs/refs и проверить progress/Speaker/reinforcement.\n')
(ROOT/'docs/nonbase_compound_decomposition_map.md').write_text('\n'.join(md)+'\n',encoding='utf-8')
print(f'FLAGGED_CARDS {len(flagged)}')
print(f'COURSES {len(bycourse)}')
for k in ['compound_action','long_question','noun_list','choice_list','review']:
    print(k,sum(r['problem_type']==k for r in flagged))
print('WROTE',md and 'docs/nonbase_compound_decomposition_map.md','docs/nonbase_compound_decomposition_map.tsv')
