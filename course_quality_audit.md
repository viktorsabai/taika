# Quality audit: «На одной волне» и «Тайский для души»

## Scope

Проверяются каталог `taika/Resourses/taika_basa_course.json`, фактические уроки из корневого `lessons.json`, `LESSONS(README).txt`, LessonsManager/LessonsView, StepView, HomeTask/Game flow и Speaker handoff.

## Catalog map

Категория «На одной волне»: 6 PRO-курсов, по 6 уроков и 22 минуты каждый: `course_e_1` «Понятный тайский», `course_e_2` «Работа с тайцами», `course_e_3` «Сервис и персонал», `course_e_4` «Разговоры без конфликта», `course_e_5` «Коды Таиланда», `course_e_6` «Мягкий тайский твой».

Категория «Тайский для души»: 6 PRO-курсов, по 6 уроков и 22 минуты каждый: `course_s_1` «Тайский для блогинга», `course_s_2` «Хобби и движ по-тайски», `course_s_3` «О чём говорят на самом деле», `course_s_4` «Ретрит и внутренний сабай», `course_s_5` «Романтика по-тайски», `course_s_6` «Тай кидс».

## Confirmed data findings

Каждый проверенный lesson содержит 3 content blocks (`intro`, `outline`, `apply`), карточки и step/home-task refs. У курсов `course_e_*` outcomes заполнены. У курсов `course_s_*` поле `outcomes` пустое во всех проверенных уроках, хотя `content.apply` и тема урока присутствуют. Это методический и UI-контентный разрыв: LessonsView может показывать пустую outcome-часть, а программа не формулирует измеримый результат урока.

В lessons JSON links представлены как `steps_ref` и `hometask_ref`; отдельные `speaker`/`games` поля не являются частью этого schema. Методика Lessons README требует, чтобы Lessons оставался proxy layer, а progression/mastery вычислялись через managers и ProgressManager, без бизнес-логики в DS.

## Confirmed fixes in this pass

`CourseNavigator.advance` теперь выбирает следующий курс внутри текущей категории, а не просто следующий record глобального каталога. Это сохраняет последовательность отдельной образовательной программы: «На одной волне» не перескакивает в «Тайский для души», и наоборот.

Для всех 36 уроков категории «Тайский для души» заполнены lesson-level outcomes. Формулировки извлечены из уже существующих `content.apply`: каждая цель фиксирует одну и ту же методическую дугу — произнести конкретную сцену сначала медленно со стрелками, затем естественно. Новые темы или факты не добавлялись.

## Validation results

Все 72 урока двух категорий имеют уникальные IDs, последовательность `1…6`, непустой content, рабочие `steps_ref` и `hometask_ref`, а также phonetic data. Steps audit подтвердил отсутствие missing/zero lesson sets и отсутствие пустой phonetic строки у word/phrase карточек. Arrow-friendly phonetic material присутствует в каждой программе.

Route audit подтвердил canonical переходы LessonsView → StepView, lesson → game и lesson → Speaker с сохранением `courseId/lessonId`. `CourseNavigator` теперь ограничивает `nextCourse` текущей категорией. PRO gating остаётся в manager/view contract, а completed/in-progress treatment разделён на уровне `isCompletedCourse`.

`git diff --check`, JSON parsing и category assertions пройдены. Полный Xcode/iOS Simulator build требует macOS и остаётся финальным device gate.
