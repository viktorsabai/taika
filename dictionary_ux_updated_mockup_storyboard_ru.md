# Обновлённый storyboard Dictionary UX

## Кадр 1 — Home: нативный блок «Мой словарь»

На Main нет боковой закладки. После voice-orb и основного CTA появляется компактный горизонтальный блок:

**Мой словарь** — «Твои фразы для жизни в Таиланде» — `3 фразы` — кнопка `Открыть`.

Блок не конкурирует с «Продолжить курс» и не выглядит вторым главным CTA. При нулевом состоянии он показывает короткую полезную подсказку: «Сохраняй свои фразы в Speaker — они будут здесь». Header shortcut остаётся единственным быстрым входом.

## Кадр 2 — Quick Drawer

Тап по единой dictionary icon в header или по Home block открывает right-side drawer поверх текущего экрана. Drawer закрывает app header полностью, имеет собственный close button, показывает последние личные фразы и CTA `Все фразы`. Внутри нет bookmark icon и нет Favorites terminology.

## Кадр 3 — Full Dictionary

`Все фразы` открывает отдельный экран **«Мой словарь»**, а не Favorites с фильтром. На экране есть только личные фразы, собственный navigation title и единая dictionary icon. Favorites остаётся отдельным tab и не смешивается с dictionary data.

## Кадр 4 — Favorites

Favorites остаётся экраном **«Избранное»**: сохранённые карточки из курсов, фильтры «Карточки / В Speaker / В игры». На нём нет переключателя `Словарь` и нет dictionary edge-tab.

## Visual rules

Одна dictionary icon во всех состояниях; bookmark означает только Favorites. Main uses current Taika voice-orb and course carousel. Drawer uses opaque dark glass with one accent edge, no visible underlying header. Full Dictionary is calm, dense and readable, without oversized empty state or duplicated navigation controls.
