# MASTERY_MODEL.md
Taika Learning Mastery System v1.0

---

# 1. Purpose

This document defines how Taika measures real learning progress.

Core principle:
Completion ≠ Mastery.

A user finishing a Step does NOT mean they can:
- recall it,
- pronounce it,
- use it in context.

Mastery is earned through reinforcement and production.

---

# 2. Learning Atom: Step

Step is the atomic learning unit.

Each Step contains:
- thai_text
- transcript_ru (syllable-separated)
- translation
- type (word / phrase / dialogue)
- audio

Every learning mechanic (Match, Recall, Speaker) operates on Step.

---

# 3. Mastery Dimensions

Each Step has three independent dimensions:

1. Exposure
2. Reinforcement
3. Production

These map to product mechanics.

---

## 3.1 Exposure

Triggered when:
- User opens Step
- User plays audio
- User scrolls content

Metric:
exposureCount

Goal:
Initial familiarization.

Exposure does NOT increase mastery score significantly.

---

## 3.2 Reinforcement (Games)

Triggered in:
- Match Game (free)
- Recall Builder (PRO)

Metrics:
- reinforcementScore
- attemptCount
- mistakeCount

Logic:

Match:
+1 reinforcementScore on full success
No penalty on failure

Recall:
+2 reinforcementScore on correct phrase
+1 if corrected after retry
No negative mastery reduction

Reinforcement validates memory and structure.

---

## 3.3 Production (Speaker)

Triggered when:
- User records voice for Step
- API returns pronunciation score

Metrics:
- pronunciationScore
- bestPronunciationScore
- speakerAttempts

Logic:

If pronunciationScore ≥ threshold (e.g. 75):
Production considered successful.

If pronunciationScore ≥ 85:
Boost mastery multiplier.

Production is highest-weight mastery input.

---

## 3.4 Production Stability

Mastery must reflect consistent pronunciation performance.

Production considered successful only if:

- pronunciationScore ≥ 75

Stability rule (v1):

- At least 2 successful attempts required
- Only then does production contribute to masteryScore

Metrics added:
- successfulPronunciationAttempts
- recentPronunciationScores (optional for future averaging logic)

This prevents accidental mastery inflation from a single high score.

---

# 4. Mastery Formula

```
productionScore =
if successfulPronunciationAttempts >= 2:
    bestPronunciationScore / 20
else:
    0

masteryScore =
( exposureCount * 0.1 ) +
( reinforcementScore * 1.0 ) +
productionScore
```

Mastery tiers:

0 – 2   → New  
2 – 5   → Learning  
5 – 8   → Stable  
8+      → Mastered  

Only “Stable” and above count toward Course completion quality.

---

## 4.1 Mastery Gating Logic

Navigation policy:

If:
- lessonCompleted = true
- lessonMastery < masteryThreshold

Then:
- Allow navigation to next Lesson
- Mark current Lesson as `completed_low_mastery`

Lesson states:

- completed
- completed_low_mastery
- mastered

UI behavior:
- Amber indicator for low mastery
- Encourage reinforcement before progressing

No hard lock is applied in v1.

---

# 5. Completion vs Mastery

Completion:
User has opened all Steps in Lesson.

Mastery:
User reached minimum masteryScore threshold on Steps.

Lesson completion state:

if 100% Steps opened → lessonCompleted = true  
if 70% Steps Stable → lessonMastered = true  

Course completion requires:
- All lessons completed
- At least 60% of Steps Stable

---

## 5.1 Minimum Reinforcement Requirement

A Step cannot reach "Stable" tier based on exposure alone.

Rule:

To reach Stable:
- reinforcementScore ≥ 1
OR
- successfulPronunciationAttempts ≥ 1

Exposure-only interaction cannot elevate Step beyond "Learning".

This prevents artificial mastery inflation.

---


# 6. Mastery Decay Model (Retention Loop v2)

Purpose:
Introduce spaced repetition behavior and create a measurable retention loop.

Decay affects ONLY effectiveMasteryScore.
Raw masteryScore is never deleted.

---

## 6.1 Decay Trigger

If:
- No interaction (exposure, reinforcement, production)
- For 14 consecutive days

Then:
effectiveMasteryScore = masteryScore * 0.9

If:
- No interaction for 30 days

Then:
effectiveMasteryScore = masteryScore * 0.75

Decay applies progressively but never drops below "Learning" tier automatically.
Hard drop to "New" is forbidden.

---

## 6.2 Mastery Decay Notification (Retention Trigger)

When:
effectiveMasteryScore crosses tier boundary
(e.g. Stable → Learning)

System must:

- Flag Step as `needs_review`
- Surface this in:
    - Main Dashboard
    - LessonsView badge
    - Optional push notification (future)

User Story:
"As a user, I want to be notified when my Stable Step drops to Learning so I can restore my knowledge."

This is primary retention loop metric.

---

## 6.3 Decay Recovery

If user:
- Plays Match OR Recall successfully
OR
- Achieves successful Speaker attempt

Then:
effectiveMasteryScore instantly recalculated from raw masteryScore.

Decay does NOT permanently damage progress.
It only reduces confidence until revalidated.

---

# 6.4 Recovery & Persistence Rules

Mastery must survive:

- App restart
- Device reboot
- App update

If cloud sync implemented (future):
- Mastery restored from server
- Local-only data must not override higher remote mastery

User Story:
"As a system, I must restore Mastery state from UserSession on launch to prevent data loss."

Guardrail:
Mastery computation must be deterministic from stored metrics.
Never store masteryScore directly.
Always compute from underlying counters.

---

---

# 7. PRO Impact

Free users:
- Exposure
- Match reinforcement

PRO users:
- Recall reinforcement
- Speaker production

Therefore:
Mastery ceiling for Free is lower than PRO.

This supports monetization logic.

---

# 8. Data Storage

Stored in:

- ProgressManager
- UserSession

Per Step:
- exposureCount
- reinforcementScore
- bestPronunciationScore
- attemptCount
- speakerAttempts

No mastery calculation inside DS.
All computed inside Manager layer.

---

# 9. Guardrails

1. No mastery logic inside View.
2. No mastery logic inside DS.
3. Speaker must not directly mutate Lesson completion.
4. HomeTask must not mark Step completed.
5. Only ProgressManager updates mastery state.

---

# 9.1 User Intensity Classification (Future)

To support personalization and monetization:

Users classified based on activity:

- Passive → Mostly exposure, low reinforcement
- Active → Regular reinforcement usage
- Intensive → Frequent Speaker attempts + high mastery growth

Future use:
- Personalized reminders
- PRO upgrade triggers
- Adaptive difficulty

Not implemented in v1.

---

# 10. Why This Matters

Without Mastery Model:
App becomes content browser.

With Mastery Model:
App becomes learning engine.

Mastery Model connects:
Step → Game → Speaker → Progress → Monetization.

This is Taika’s structural advantage over generic apps.
