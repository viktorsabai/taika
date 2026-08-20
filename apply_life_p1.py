import json
from pathlib import Path

LESSONS = Path('lessons.json')
STEPS = Path('steps.json')
TARGET = {'course_l_3','course_l_6','course_l_8','course_l_12','course_l_7'}

# P1 editorial intent: keep the existing curriculum architecture, but make paid scenarios
# survivable in real life: failure -> repair -> confirmation -> complete scene.
ADDITIONS = {
 'course_l_3_l3': [
  {'order': 99, 'kind':'phrase', 'ru':'Цена не та, что на табличке', 'thai':'ราคาไม่ตรงป้าย', 'phonetic':'раа→ каа→ май↘ тронг→ пай↗', 'tip':'Спокойно сверяй цену: это не обвинение, а проверка.'},
  {'order': 100, 'kind':'casual', 'ru':'Можно чуть дешевле?', 'thai':'ลดหน่อยได้ไหม', 'phonetic':'лот→ ной↘ дай→ май↗', 'tip':'casual: [[ной]] смягчает просьбу «немного»; говори легко, без давления.'},
 ],
 'course_l_3_l6': [
  {'order': 99, 'kind':'phrase', 'ru':'Давайте пересчитаем', 'thai':'คิดใหม่ด้วยกัน', 'phonetic':'кхит↘ май↘ дуай→ кан→', 'tip':'Repair-фраза, если сумма или количество не совпали.'},
  {'order': 100, 'kind':'phrase', 'ru':'Вот столько, правильно?', 'thai':'เท่านี้ใช่ไหม', 'phonetic':'тао→ ни→ чай→ май↗', 'tip':'Покажи деньги или товар и попроси подтверждение.'},
  {'order': 101, 'kind':'casual', 'ru':'Окей, беру', 'thai':'โอเค เอาอันนี้', 'phonetic':'о→ кэ→ ау→ ан→ ни→', 'tip':'casual: короткая современная связка для финала покупки.'},
 ],
 'course_l_6_l3': [
  {'order': 99, 'kind':'phrase', 'ru':'Кондиционер не работает', 'thai':'แอร์ไม่ทำงาน', 'phonetic':'эа→ май↘ тхам→ нган→', 'tip':'Скажи факт и сразу покажи номер комнаты — так ремонт стартует быстрее.'},
  {'order': 100, 'kind':'phrase', 'ru':'Можно починить сегодня?', 'thai':'ซ่อมวันนี้ได้ไหม', 'phonetic':'сом↘ ва→ ни́→ дай→ май↗', 'tip':'Если сегодня нельзя, следующим шагом спроси время прихода мастера.'},
 ],
 'course_l_6_l7': [
  {'order': 99, 'kind':'phrase', 'ru':'Я подожду в комнате', 'thai':'ผมจะรอที่ห้อง', 'phonetic':'пхом↘ ча→ ро→ тхи↘ хонг↘', 'tip':'Финальная договорённость: где именно ты будешь ждать.'},
  {'order': 100, 'kind':'phrase', 'ru':'Позвоните, когда будет готово', 'thai':'โทรบอกเมื่อเสร็จแล้ว', 'phonetic':'тхоо→ бок↘ мыа→ сет↘ леу↘', 'tip':'Repair на случай, если мастер не может назвать точное время.'},
 ],
 'course_l_8_l2': [
  {'order': 99, 'kind':'phrase', 'ru':'На полке другая цена', 'thai':'ที่ชั้นมีราคาอีกอัน', 'phonetic':'тхи↘ чан↘ ми→ раа→ каа→ ик↘ ан→', 'tip':'Покажи ценник и спокойно обозначь расхождение.'},
  {'order': 100, 'kind':'phrase', 'ru':'Проверьте, пожалуйста', 'thai':'ช่วยเช็คให้หน่อย', 'phonetic':'чуай↘ чек↗ хай↘ ной↘', 'tip':'Вежливый repair: попроси сотрудника проверить цену в системе.'},
 ],
 'course_l_8_l7': [
  {'order': 99, 'kind':'phrase', 'ru':'Я хочу обменять товар', 'thai':'ขอเปลี่ยนสินค้า', 'phonetic':'кхо̌о↘ плиан↘ син→ кхаа́↘', 'tip':'Для обмена сначала назови действие, затем покажи товар и чек.'},
  {'order': 100, 'kind':'phrase', 'ru':'Размер не подходит', 'thai':'ไซซ์ไม่พอดี', 'phonetic':'сай↗ май↘ пхо̌о→ ди→', 'tip':'Причину можно назвать коротко; не нужно длинно объяснять.'},
  {'order': 101, 'kind':'casual', 'ru':'Всё ок, спасибо', 'thai':'โอเค ขอบคุณนะ', 'phonetic':'о→ кэ→ кхоп→ кхун→ на́↘', 'tip':'casual: [[на]] делает благодарность мягче и дружелюбнее.'},
 ],
 'course_l_12_l3': [
  {'order': 99, 'kind':'phrase', 'ru':'Сделайте мягче, пожалуйста', 'thai':'เบาลงหน่อยครับ', 'phonetic':'бау→ лонг→ ной↘ кхрап↗', 'tip':'Ключевая repair-фраза для массажа: скажи её сразу, не терпя дискомфорт.'},
  {'order': 100, 'kind':'phrase', 'ru':'Больно, остановитесь', 'thai':'เจ็บ หยุดก่อนครับ', 'phonetic':'чеп↘ йут↘ кон↘ кхрап↗', 'tip':'Безопасность важнее вежливости: коротко и ясно попроси остановиться.'},
 ],
 'course_l_12_l6': [
  {'order': 99, 'kind':'phrase', 'ru':'Вот так хорошо', 'thai':'แบบนี้ดีครับ', 'phonetic':'бэп↘ ни́→ ди→ кхрап↗', 'tip':'Подтверди желаемый результат после корректировки.'},
  {'order': 100, 'kind':'phrase', 'ru':'Можно оплатить картой?', 'thai':'จ่ายบัตรได้ไหม', 'phonetic':'чай↘ бат↘ дай→ май↗', 'tip':'Финал салона: уточни способ оплаты до того, как достанешь карту.'},
 ],
 'course_l_7_l2': [
  {'order': 99, 'kind':'phrase', 'ru':'Можно пересесть в тень?', 'thai':'ย้ายไปนั่งร่มได้ไหม', 'phonetic':'йа́й↗ пай→ нанг↘ ром↘ дай→ май↗', 'tip':'Если солнце стало сильным, сначала спроси разрешение, а не молча занимай место.'},
  {'order': 100, 'kind':'phrase', 'ru':'Я вернусь через час', 'thai':'เดี๋ยวกลับมาครับ', 'phonetic':'ди̌ао↗ клап↘ маа→ кхрап↗', 'tip':'Repair при аренде: обозначь, что место нужно сохранить.'},
 ],
 'course_l_7_l6': [
  {'order': 99, 'kind':'phrase', 'ru':'Можно ещё один кокос?', 'thai':'เอามะพร้าวอีกลูกได้ไหม', 'phonetic':'ау→ ма́↘ пхраао↘ ик↘ лук↘ дай→ май↗', 'tip':'Попроси ещё один кокос и дождись подтверждения цены.'},
  {'order': 100, 'kind':'casual', 'ru':'Сегодня чилл', 'thai':'วันนี้ชิล', 'phonetic':'ва́н→ ни́→ чхин→', 'tip':'casual/slang: [[чил]] — современное «расслабленно, чилл»; используй только в дружеской обстановке.'},
 ],
}

def add_unique(items, additions):
    existing={(i.get('ru'), i.get('phonetic')) for i in items}
    for item in additions:
        key=(item['ru'], item['phonetic'])
        if key not in existing:
            item=dict(item)
            item['order']=len(items)+1
            items.append(item)
            existing.add(key)

def main():
    lessons=json.loads(LESSONS.read_text(encoding='utf-8'))
    steps=json.loads(STEPS.read_text(encoding='utf-8'))
    step_map={s['lesson_id']:s for s in steps['stepsets']}
    changed=0; added=0
    for lesson_id, additions in ADDITIONS.items():
        before=len(step_map[lesson_id]['items'])
        add_unique(step_map[lesson_id]['items'], additions)
        added += len(step_map[lesson_id]['items'])-before
        changed += 1
    for course in lessons['courses']:
        if course['course_id'] in TARGET:
            for lesson in course['lessons']:
                lesson['card_count']=len(step_map[lesson['lesson_id']]['items'])
    LESSONS.write_text(json.dumps(lessons,ensure_ascii=False,indent=2)+'\n',encoding='utf-8')
    STEPS.write_text(json.dumps(steps,ensure_ascii=False,indent=2)+'\n',encoding='utf-8')
    print('updated_lessons',changed)
    print('added_cards',added)
    print('target_courses',sorted(TARGET))

if __name__=='__main__': main()
