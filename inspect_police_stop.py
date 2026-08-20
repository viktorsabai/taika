import json
from pathlib import Path

lessons_payload = json.loads(Path('lessons.json').read_text())
steps_payload = json.loads(Path('steps.json').read_text())

course_id = 'course_l_1'
course_lessons = []
for course in lessons_payload.get('courses', []):
    if course.get('course_id') == course_id or course.get('courseId') == course_id:
        course_lessons.extend(course.get('lessons', []))

lesson_ids = {lesson.get('lesson_id') for lesson in course_lessons}
course_steps = [
    item | {'_lesson_id': step_set.get('lesson_id')}
    for step_set in steps_payload.get('stepsets', [])
    if step_set.get('lesson_id') in lesson_ids
    for item in step_set.get('items', [])
]

print('LESSONS', len(course_lessons))
for lesson in course_lessons:
    lesson_id = lesson.get('lesson_id')
    print(f"\nLESSON {lesson_id} | {lesson.get('title')} | {lesson.get('subtitle')}")
    for step in [item for item in course_steps if item.get('_lesson_id') == lesson_id]:
        print(
            '  STEP', step.get('order'), '|', step.get('kind'), '|',
            step.get('ru') or step.get('text'), '|', step.get('thai'), '|',
            step.get('phonetic')
        )

print('\nTOTAL STEPS', len(course_steps))
