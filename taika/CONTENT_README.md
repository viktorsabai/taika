

//
//  CONTENT_README.swift
//
//  Taika Content Standard v1.0
//  Official rules for creating, validating and scaling educational content
//
//  This document reflects CURRENT project architecture.
//  No theoretical models. Only what matches existing parsers,
//  managers and JSON structure.
//

// ============================================================
// 1. CORE PRINCIPLE
// ============================================================
//
// In Taika:
// Content = structured data for engines.
//
// A Step is not text.
// A Step must work simultaneously in:
//
// - StepView
// - Speaker
// - RecallGame
// - MatchGame
// - ProgressManager
//
// If a Step breaks one of those — it is INVALID.
//

// ============================================================
// 2. STEP DATA REQUIREMENTS
// ============================================================
//
// Each Step (based on existing StepData + JSON):
//
// Required fields:
// - thai (original)
// - transcript_ru (syllable-based transcript)
// - meaning
// - type
//
// Optional but recommended:
// - audio reference
//
// ------------------------------------------------------------
// 2.1 Transcript Rules (CRITICAL)
// ------------------------------------------------------------
//
// Transcript MUST be syllable-explicit.
// Syllables must be separated by "-".
//
// Example (valid):
// са-ват-ди↘
//
// Invalid:
// саватди
// са ват ди
//
// Tone marks remain inside syllable.
// They are NOT separators.
//
// Reason:
// RecallGame and Speaker rely on explicit syllable structure.
//

// ============================================================
// 3. SYLLABLE LIMITATIONS
// ============================================================
//
// For RecallGame:
//
// - Max recommended syllables: 6
// - Steps with >6 syllables are excluded from RecallGame
// - Filtering happens in Manager, not in JSON
//
// StepData stays full.
// GameManager decides applicability.
//

// ============================================================
// 4. STEP TYPE SYSTEM
// ============================================================
//
// Every Step must contain valid `type`.
//
// Allowed types (based on current project usage):
//
// - word
// - phrase
// - dialog
// - interjection
// - grammar
// - pattern
//
// Type is used for:
// - Game filtering
// - Speaker queue building
// - Lesson structuring
//

// ============================================================
// 5. LESSON RULES
// ============================================================
//
// Lesson = structured learning unit.
//
// Constraints:
//
// - 8–20 Steps max
// - Must contain mix of:
//     * at least 3 words
//     * at least 2 phrases
//     * at least 1 dialog construct
//
// A lesson consisting only of vocabulary is invalid.
// A lesson without contextual phrases is incomplete.
//

// ============================================================
// 6. COURSE RULES
// ============================================================
//
// Course must:
//
// - Progress logically in complexity
// - Not introduce grammar without prior lexical base
// - Avoid chaotic duplication
// - Maintain theme consistency
//
// CourseManager assumes ordered difficulty.
//

// ============================================================
// 7. GAME COMPATIBILITY RULES
// ============================================================
//
// RecallGame requires:
// - valid transcript_ru
// - predictable syllable count
//
// MatchGame requires:
// - short meaning
// - no long encyclopedic explanations
//
// If meaning > 60 characters → redesign.
//

// ============================================================
// 8. SPEAKER COMPATIBILITY
// ============================================================
//
// Transcript must match real pronunciation.
//
// Transcript != audio → breaks trust.
//
// Avoid artificial phonetics.
// Avoid academic notation.
//

// ============================================================
// 9. CONTENT QUALITY STANDARD
// ============================================================
//
// Forbidden:
// - textbook-like robotic phrases
// - encyclopedic tone
// - unnatural constructions
//
// Required:
// Each Step must answer:
//
// "Where and to whom would I say this?"
//
// If no clear scenario — Step is rejected.
//

// ============================================================
// 10. CONTENT PIPELINE (SOLO FOUNDER VERSION)
// ============================================================
//
// For every new Step:
//
// 1. Add to JSON
// 2. Validate transcript
// 3. Validate syllable split
// 4. Check in StepView
// 5. Check in RecallGame
// 6. Check in Speaker
// 7. Merge only after manual validation
//

// ============================================================
// 11. KNOWN RISKS
// ============================================================
//
// Risk 1: Incorrect syllable split → Game broken
// Risk 2: Transcript mismatch → Speaker broken
// Risk 3: Long phrases → Layout breaks
// Risk 4: Boring content → Retention collapse
//

// ============================================================
// 12. NEXT EVOLUTION (v1.1)
// ============================================================
//
// Potential fields:
//
// - difficulty
// - frequency weight
// - mastery score
// - revision priority
//
// Not implemented yet.
// Must align with existing managers before adding.

// ------------------------------------------------------------
// 12.1 Field: syllable_audio_map (PRO future-proofing)
// ------------------------------------------------------------
//
// Purpose:
// Required for detailed per-syllable pronunciation analytics in PRO.
//
// Problem:
// Current transcript_ru provides syllable segmentation,
// but audio playback and Speaker analysis do NOT know
// which time range corresponds to which syllable.
//
// Without this mapping, per-syllable feedback is technically fake.
//
// Proposed structure (v1.1):
//
// syllable_audio_map: [
//     {
//         "syllable": "са",
//         "start_ms": 0,
//         "end_ms": 180
//     },
//     {
//         "syllable": "ват",
//         "start_ms": 181,
//         "end_ms": 420
//     }
// ]
//
// Rules:
// - Order must match transcript_ru split.
// - Length must equal syllable count.
// - Optional for MVP.
// - Required for real PRO analytics.
//
// Implementation note:
// This field must be consumed by SpeakerManager only.
// No UI logic should parse timing data.
//

// ------------------------------------------------------------
// 12.2 Field: distractors (Recall Builder Advanced)
// ------------------------------------------------------------
//
// Purpose:
// Enable higher-difficulty RecallGame with intelligent traps.
//
// Problem:
// Current RecallGame only shuffles correct syllables.
// This limits difficulty ceiling.
//
// Proposed structure:
//
// distractors: [
//     "ватт",
//     "ди↗",
//     "сав"
// ]
//
// Rules:
// - Distractors must be phonetically similar.
// - Must NOT introduce unrelated vocabulary.
// - Should not exceed +3 distractors per Step.
// - Used only in PRO difficulty modes.
//
// Manager responsibility:
// - HomeTaskManager merges real syllables + distractors.
// - Validation still checks only correct ordered sequence.
// - JSON must remain content-driven, not game-driven.
//
//
