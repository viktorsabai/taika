import json
import re
from pathlib import Path

lessons_data = json.loads(Path('lessons.json').read_text())
steps_data = json.loads(Path('steps.json').read_text())

courses = lessons_data.get('courses', [])
course_ids = {course.get('course_id') for course in courses if course.get('course_id')}
lesson_ids = set()
course_lesson_map = {}
for course in courses:
    cid = course.get('course_id')
    course_lesson_map[cid] = []
    for lesson in course.get('lessons', []):
        lid = lesson.get('lesson_id')
        if lid:
            lesson_ids.add(lid)
            course_lesson_map[cid].append(lid)
step_lesson_ids = {s.get('lesson_id') for s in steps_data.get('stepsets', []) if s.get('lesson_id')}
step_course_ids = {s.get('course_id') for s in steps_data.get('stepsets', []) if s.get('course_id')}

print(f'courses={len(course_ids)} lessons={len(lesson_ids)} stepsets={len(step_lesson_ids)}')
print('missing_steps_for_lessons=', sorted(lesson_ids - step_lesson_ids))
print('orphan_stepsets=', sorted(step_lesson_ids - lesson_ids))
print('missing_courses_in_steps=', sorted(course_ids - step_course_ids))
print('orphan_step_courses=', sorted(step_course_ids - course_ids))

contract_errors = []
for course in courses:
    cid = course.get('course_id')
    prereqs = course.get('prerequisites') or []
    for p in prereqs:
        if p not in course_ids:
            contract_errors.append((cid, 'missing_course_prerequisite', p))
    orders = [lesson.get('order') for lesson in course.get('lessons', [])]
    if orders != list(range(1, len(orders) + 1)):
        contract_errors.append((cid, 'non_contiguous_lesson_order', orders))
    for lesson in course.get('lessons', []):
        lid = lesson.get('lesson_id')
        if not lesson.get('outcomes'):
            contract_errors.append((lid, 'empty_outcomes', ''))
        if 'card_count' not in lesson:
            contract_errors.append((lid, 'missing_card_count', ''))
print('contract_errors=', len(contract_errors))
for item in contract_errors[:100]:
    print(item)

swift_refs = []
for path in Path('taika').rglob('*.swift'):
    for line_no, line in enumerate(path.read_text(errors='ignore').splitlines(), 1):
        for cid in re.findall(r'course_[A-Za-z0-9_]+', line):
            if cid in {'course_id', 'course_title', 'course_progress'}:
                continue
            swift_refs.append((str(path), line_no, cid))
print('swift_course_id_refs=', len(swift_refs))
for path, line_no, cid in sorted(set(swift_refs)):
    if cid not in course_ids and not cid.startswith('course_b_1_l') and cid not in {'course_demo', 'course_test'}:
        print('unexpected_missing_swift_course_id=', path, line_no, cid)

print('hub_card_ids=', ['course_b_1' in course_ids, 'course_l_2' in course_ids, 'course_l_3' in course_ids, 'course_l_5' in course_ids])
