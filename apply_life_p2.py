import json
from pathlib import Path

LESSONS=Path('lessons.json')
STEPS=Path('steps.json')
TARGET={'course_l_1','course_l_10','course_l_11','course_l_15'}

ADDITIONS={
 'course_l_1_l3':[
  {'kind':'phrase','ru':'Не понял, повторите медленнее','thai':'ไม่เข้าใจ พูดช้าหน่อยครับ','phonetic':'май↘ кхао→ джай→ пхут↘ чаа́↘ ной↘ кхрап↗','tip':'Repair-фраза для проверки понимания: спокойно попроси повторить, не угадывай ответ.'},
  {'kind':'phrase','ru':'Покажите, где подписать?','thai':'เซ็นตรงไหนครับ','phonetic':'сен→ тронг→ най↗ кхрап↗','tip':'Полезно, если тебе дают форму: сначала уточни место подписи, потом ставь её.'},
 ],
 'course_l_1_l6':[
  {'kind':'phrase','ru':'Можно позвонить хозяину?','thai':'โทรหาเจ้าของได้ไหมครับ','phonetic':'тхоо→ ха̌а→ чао↘ кхонг̌→ дай→ май↗ кхрап↗','tip':'Если вопрос сложнее, попроси связаться с хозяином или человеком, который поможет.'},
  {'kind':'phrase','ru':'Я понял, спасибо','thai':'เข้าใจแล้ว ขอบคุณครับ','phonetic':'кхао→ джай→ леу↘ кхоп→ кхун→ кхрап↗','tip':'Закрой сцену коротким подтверждением: ты услышал и можешь ехать дальше.'},
 ],
 'course_l_10_l7':[
  {'kind':'phrase','ru':'Мне больно, остановимся','thai':'เจ็บ ขอหยุดก่อนครับ','phonetic':'чеп↘ кхо̌о↘ йут↘ кон↘ кхрап↗','tip':'Безопасность прежде результата: боль — причина остановить упражнение, а не терпеть.'},
  {'kind':'phrase','ru':'Можно перенести на завтра?','thai':'เลื่อนไปพรุ่งนี้ได้ไหม','phonetic':'лы̂ан↘ пай→ пхрунг→ ни́→ дай→ май↗','tip':'Нужная ветка для регулярной жизни: попроси перенос, если не успеваешь или плохо себя чувствуешь.'},
 ],
 'course_l_10_l6':[
  {'kind':'phrase','ru':'Сегодня только лёгкая тренировка','thai':'วันนี้ออกเบาๆ','phonetic':'ва́н→ ни́→ ок↘ бау→ бау→','tip':'Скажи это тренеру заранее, чтобы он подобрал безопасную нагрузку.'},
 ],
 'course_l_11_l4':[
  {'kind':'phrase','ru':'Можно просто посмотреть?','thai':'ขอดูอย่างเดียวได้ไหม','phonetic':'кхо̌о↘ ду→ я̀анг↘ диау→ дай→ май↗','tip':'Вежливый способ быть рядом с событием, не обещая участвовать.'},
  {'kind':'phrase','ru':'Я не буду участвовать, спасибо','thai':'ไม่เข้าร่วมครับ ขอบคุณ','phonetic':'май↘ кхао→ руам↘ кхрап↗ кхоп→ кхун→','tip':'Спокойный отказ звучит лучше длинних оправданий; улыбка и кхрап/ка достаточно.'},
 ],
 'course_l_11_l6':[
  {'kind':'phrase','ru':'Фото без вспышки можно?','thai':'ถ่ายรูปไม่ใช้แฟลชได้ไหม','phonetic':'тай→ руп↘ май↘ чай↗ флэш↘ дай→ май↗','tip':'Локальный etiquette: сначала спроси разрешение и уважай пространство других.'},
  {'kind':'phrase','ru':'Спасибо, я пойду','thai':'ขอบคุณครับ ผมไปก่อน','phonetic':'кхоп→ кхун→ кхрап↗ пхом↘ пай→ кон↘','tip':'Естественное завершение разговора, когда нужно уйти с праздника.'},
 ],
 'course_l_11_l7':[
  {'kind':'phrase','ru':'С праздником!','thai':'สุขสันต์วันเทศกาล','phonetic':'сук→ сан→ ван→ тхет→ са→ кан→','tip':'Evergreen-фраза для любого фестивального сезона; год и дату лучше держать в metadata, не в карточке.'},
  {'kind':'phrase','ru':'Где проходит праздник?','thai':'งานจัดที่ไหน','phonetic':'нган→ джат↘ тхи↘ най↗','tip':'Универсальный вопрос для ежегодного события: уточни место перед поездкой.'},
 ],
 'course_l_15_l6':[
  {'kind':'phrase','ru':'Спасибо, но я откажусь','thai':'ขอบคุณครับ แต่ขอไม่ดีกว่า','phonetic':'кхоп→ кхун→ кхрап↗ тээ↘ кхо̌о↘ май↘ ди→ ква̀а↘','tip':'Мягкий отказ без конфликта: поблагодари, затем ясно обозначь решение.'},
  {'kind':'phrase','ru':'Можно просто посидеть?','thai':'นั่งเฉยๆได้ไหม','phonetic':'нанг↘ чхёй̌ чхёй̌ дай→ май↗','tip':'Полезно в баре или компании, когда хочешь остаться рядом без заказа или флирта.'},
 ],
 'course_l_15_l7':[
  {'kind':'phrase','ru':'Я не хочу фотографироваться','thai':'ไม่อยากถ่ายรูปครับ','phonetic':'май↘ я̀ак↘ тай→ руп↘ кхрап↗','tip':'Граница должна быть короткой и ясной; не нужно оправдываться.'},
  {'kind':'casual','ru':'Давай просто поболтаем','thai':'คุยกันเฉยๆก็ได้','phonetic':'кхуй→ кан→ чхёй̌ чхёй̌ ко̂→ дай→','tip':'casual: дружелюбно переводит разговор из флирта в обычный small talk.'},
 ],
}

def add_unique(items, additions):
    keys={(i.get('ru'),i.get('phonetic')) for i in items}
    for item in additions:
        if (item['ru'],item['phonetic']) in keys: continue
        item=dict(item); item['order']=len(items)+1; items.append(item); keys.add((item['ru'],item['phonetic']))

def main():
    lessons=json.loads(LESSONS.read_text(encoding='utf-8'))
    steps=json.loads(STEPS.read_text(encoding='utf-8'))
    sm={s['lesson_id']:s for s in steps['stepsets']}
    added=0
    for lesson_id, additions in ADDITIONS.items():
        before=len(sm[lesson_id]['items']); add_unique(sm[lesson_id]['items'], additions); added += len(sm[lesson_id]['items'])-before
    for course in lessons['courses']:
        if course['course_id'] not in TARGET: continue
        for lesson in course['lessons']:
            lesson['card_count']=len(sm[lesson['lesson_id']]['items'])
            if lesson['lesson_id']=='course_l_11_l7':
                lesson['title']='Праздники круглый год'
                lesson['subtitle']='Поздравить, уточнить место и закончить разговор'
    LESSONS.write_text(json.dumps(lessons,ensure_ascii=False,indent=2)+'\n',encoding='utf-8')
    STEPS.write_text(json.dumps(steps,ensure_ascii=False,indent=2)+'\n',encoding='utf-8')
    print('updated_lessons',len(ADDITIONS),'added_cards',added,'target_courses',sorted(TARGET))
if __name__=='__main__': main()
