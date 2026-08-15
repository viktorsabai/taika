# Curriculum iteration 1 — cards quality

Phases A–C (partial): canon, P0 correctness, phonetics, gloss, within-lesson dups.

## Metrics

| Metric | Before | After |
|---|---:|---:|
| Learnable cards | 2140 | 2121 |
| Unique Thai | 1808 | 1808 |
| Phonetic conflicts | 28 | 0 |
| Lessons with within-Thai dups | 16 | 0 |
| Gloss-inflation (thanks/bye) | 23 | 0 |

Phonetic canon entries: **33** → `curriculum_lemma_canon.json`

## Changelog

- A: wrote lemma canon (33 phonetic entries)
- P0: l_7 drop «Тень»/ร่ม (оставить Зонт; тень = ที่ร่ม)
- P0: l_7 «Сок»/น้ำ → «Вода»
- P0: course_l_10_l1 บัตร/абонемент → บัตรสมาชิก
- P0: course_l_10_l1 ซื้อบัตร → ซื้อบัตรสมาชิก
- P0: course_l_12_l3 drop «Массаж головы»/สระผม (это мытьё)
- P0: course_l_12_l4 หนวด — убрать «Борода» / оставить «Усы»
- P0/B: phonetic canon applied to 37 cards
- P0/B: gloss canon on สวัสดี-family thanks/bye: 23 cards
- C: course_l_4_l7 removed 1 within-lesson Thai dup card(s)
- C: course_l_5_l1 removed 1 within-lesson Thai dup card(s)
- C: course_l_13_l1 removed 1 within-lesson Thai dup card(s)
- C: course_e_1_l3 removed 1 within-lesson Thai dup card(s)
- C: course_e_5_l1 removed 1 within-lesson Thai dup card(s)
- C: course_e_5_l2 removed 2 within-lesson Thai dup card(s)
- C: course_s_3_l1 removed 1 within-lesson Thai dup card(s)
- C: course_s_3_l4 removed 3 within-lesson Thai dup card(s)
- C: course_s_4_l2 removed 1 within-lesson Thai dup card(s)
- C: course_s_5_l5 removed 1 within-lesson Thai dup card(s)
- C: course_s_6_l1 removed 1 within-lesson Thai dup card(s)
- C: course_s_6_l3 removed 1 within-lesson Thai dup card(s)
- C: course_s_6_l4 removed 1 within-lesson Thai dup card(s)
- C: total within-lesson cards removed: 16
- A/B/C: synced card_count for all courses

## Next iteration

- Phase C continued: cross-track course role splits (e_1/e_6, e_3↔l_6, s_2↔l_10, s_3↔long_7)
- Phase D: intro/outline/apply for non-База lessons; review flags for scene finales
- Phase E: tips pass

## Polish after gate
- l_12_l4: все หนวด с «борода» → «усы» + tip
- e_5: tip с именем кода (крэнг-джай / джай-йен)
- Gate script: `scripts/audit_curriculum_cards.py` (exit 0 = pass)

## Scorecard after iteration 1 (cards only)

| Parameter | Was | Now | Note |
|---|---:|---:|---|
| Phonetic consistency | 6 | **10** | 0 conflicts |
| Within-lesson Thai dups | 6 | **10** | 0 lessons |
| Thanks/bye gloss integrity | 5 | **10** | scene → tip |
| Known semantic P0 | 6 | **9** | fixed list; more may appear |
| Cross-track role clarity | 6 | 6 | **next iteration** |
| Intro shells non-База | 4 | 4 | **next iteration** |
| Overall cards quality | ~7 | **~8.5** | A/B/C done; D/E pending |
