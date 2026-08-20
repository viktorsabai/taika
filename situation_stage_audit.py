import json
from pathlib import Path

lessons_payload = json.loads(Path('lessons.json').read_text())
steps_payload = json.loads(Path('steps.json').read_text())

courses = {c['course_id']: c for c in lessons_payload.get('courses', []) if c.get('course_id', '').startswith('course_l_')}
stepsets = {s['lesson_id']: s for s in steps_payload.get('stepsets', []) if s.get('course_id', '').startswith('course_l_')}

rules = {
'course_l_1': ('roadside police stop', {'entry':['останов', 'провер'], 'documents':['права','документ','паспорт'], 'vehicle':['байк','мото','шлем','пассажир'], 'repair':['не понял','повтор','медлен','что мне'], 'resolution':['штраф','квитанц','оплат','ехать дальше']}),
'course_l_2': ('taxi ride', {'entry':['такси','поех','адрес'], 'price':['цен','сколько','бат'], 'route':['прям','налев','направ','останов'], 'repair':['не понял','повтор','пробк'], 'resolution':['оплат','сдач','чек']}),
'course_l_3': ('market purchase', {'entry':['рын','здрав','куп'], 'price':['цен','сколько','бат','торг'], 'quantity':['килограмм','штук','вес','числ'], 'quality':['свеж','выб','попроб'], 'resolution':['пакет','оплат','сдач']}),
'course_l_4': ('food order', {'entry':['ресторан','заказ','меню','еда'], 'preferences':['остр','без','свин','куриц','мяс','аллерг'], 'clarify':['что это','ещё','вода'], 'resolution':['счёт','оплат','упак']}),
'course_l_5': ('pharmacy/doctor', {'entry':['аптек','врач','бол'], 'symptoms':['боль','температур','симптом'], 'medicine':['лекар','таблет','доз'], 'safety':['аллерг','не помог','срочно','больниц'], 'resolution':['оплат','рецепт']}),
'course_l_6': ('hotel stay', {'entry':['отел','брон','засел'], 'room':['номер','ключ'], 'service':['полотен','уборк','кондиционер','вайфай'], 'repair':['не работает','шум','почин'], 'resolution':['оплат','высел','чек']}),
'course_l_7': ('beach day', {'entry':['пляж','море','тур'], 'service':['тень','шезлонг','кокос','снорк'], 'safety':['опас','флаг','течен','спасател','шлем'], 'repair':['помог','потер','не могу'], 'resolution':['оплат','верн','уход']}),
'course_l_8': ('shop purchase', {'entry':['магаз','товар','найти'], 'selection':['размер','цвет','подойд'], 'price':['цен','сколько'], 'checkout':['касс','чек','пакет','наличн','карт'], 'problem':['возврат','не работает','обмен']}),
'course_l_9': ('emergency', {'entry':['полици','скорая','пожар','помог'], 'location':['адрес','место','телефон'], 'description':['кров','боль','опас','украл'], 'instructions':['ждать','сюда','ближе'], 'resolution':['больниц','приех','спасибо']}),
'course_l_10': ('gym', {'entry':['зал','абонем','регист'], 'activity':['тренир','занят','тренер','йог','муайт'], 'facilities':['душ','шкаф','полотен'], 'repair':['не работает','можно'], 'resolution':['оплат','расписан']}),
'course_l_11': ('festival', {'entry':['празд','сонгкран','лой','фестив'], 'activity':['куда','идём','фонар','фото'], 'social':['поздрав','имя','откуда'], 'safety':['безопас','не трог','толп'], 'resolution':['встрет','пока','до свид']}),
'course_l_12': ('salon', {'entry':['салон','стриж','массаж'], 'spec':['короч','длин','форма','фото','бород'], 'service':['мыть','массаж'], 'price':['цен','сколько','время'], 'repair':['не так','ещё','стоп']}),
'course_l_13': ('landlord/repair', {'entry':['дом','хозяин','протеч','ремонт'], 'problem':['кондиционер','слом','шум','сосед'], 'time':['когда','приед','завтра'], 'repair':['не работает','срочно','фото'], 'resolution':['оплат','готов','спасибо']}),
'course_l_14': ('delivery', {'entry':['заказ','посыл','достав','курьер'], 'address':['адрес','дом','подъезд','этаж'], 'tracking':['трек','где','когда'], 'problem':['не приш','опозд','не могу'], 'resolution':['оплат','получ','верн']}),
'course_l_15': ('nightlife/bar', {'entry':['бар','напит','заказ'], 'price':['цен','сколько','бат'], 'social':['имя','откуда','музык','танц'], 'safety':['безопас','нет','помог','такси'], 'resolution':['счёт','оплат','пока']}),
}

out = ['# Situation-first audit matrix — Тайский для жизни\n', '| Курс | Stage coverage | Critical gaps | Preliminary priority |', '|---|---|---|---|']
for cid in sorted(courses, key=lambda x: int(x.rsplit('_', 1)[-1])):
    course = courses[cid]
    corpus_parts = []
    for lesson in course.get('lessons', []):
        corpus_parts.append(lesson.get('title', ''))
        corpus_parts.append(lesson.get('subtitle', ''))
        for item in stepsets.get(lesson.get('lesson_id'), {}).get('items', []):
            corpus_parts.extend(str(item.get(k, '')) for k in ('ru','text','tip','thai'))
    corpus = ' '.join(corpus_parts).lower()
    name, stages = rules.get(cid, (course.get('course_title'), {}))
    covered = [stage for stage, words in stages.items() if any(word in corpus for word in words)]
    missing = [stage for stage in stages if stage not in covered]
    priority = 'P0' if cid == 'course_l_1' else ('P1' if len(missing) >= 2 else 'P2')
    out.append(f"| `{cid}` {course.get('course_title')} | {', '.join(covered) or 'none'} | {', '.join(missing) or 'нет по keyword pass'} | **{priority}** |")

out += ['', '## Interpretation', '', 'Keyword coverage is a screening signal, not a substitute for human linguistic review. A course is not accepted merely because a word appears; each stage must contain usable Russian prompt, Thai phrase, phonetic form, and a realistic response branch. Police Stop is a confirmed P0 because its core vehicle-stop journey is replaced by immigration-document content.']
Path('situation_stage_gap_matrix_ru.md').write_text('\n'.join(out) + '\n')
print('\n'.join(out))
