# Curriculum iteration 3 — card tips (Taika FM)

`item.tip` на карточках word/phrase/casual = короткая подсказка в Taika FM:
фан-факт, ловушка тона, как сказать в ситуации.

## Результат

| Метрика | Было | Стало |
|---|---:|---:|
| Карточки с tip | 5% (103) | **100% (2121)** |
| Уникальных текстов tip | — | **~496** |
| Bank lemma tips | 0 | **185** (покрывают ~18% карточек, самые частые) |
| Meta standalone tips | много | вычищены / переписаны |
| Catalog descriptions | частично | sync с lessons.json |

## Правила tip

1. Одно короткое предложение (~20–90 символов)
2. Польза: как сказать / ловушка / фан-факт / культурный код
3. Можно `[[акцент]]` для FM
4. Нельзя: editor-meta, «В сцене:», коды курсов b_5

## Артефакты

- `scripts/curriculum_iteration3_tips.py`
- `docs/curriculum_lemma_canon.json` → `card_tip_bank`
- Gate: `scripts/audit_curriculum_cards.py` (карточки)

## Дальше (итерация 4, optional)

- Расширять tip bank до 400–500 lemma вручную (long-tail Life/Long)
- Spot-check FM на Базе и топ Life в симуляторе
