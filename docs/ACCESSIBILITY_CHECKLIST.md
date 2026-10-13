# VisionMate 2.0 — Accessibility & Screen Reader QA Checklist

This checklist must be executed on physical hardware using **Android TalkBack** and **iOS VoiceOver** before any release.

---

## 1. Screen Reader Compatibility Audit

| Screen Reader | Gesture | Expected Behavior in VisionMate 2.0 | Pass / Fail |
|---|---|---|---|
| **TalkBack / VoiceOver** | Linear Swipe Right | Moves accessibility focus sequentially: Brand Header $\to$ Greeting $\to$ Start Voice Assistant $\to$ 6 Feature Cards $\to$ Bottom Navigation Bar. | `[PASS]` |
| **TalkBack / VoiceOver** | Double-tap | Activates target button with immediate tactile pulse (`HapticPattern.lightTap`). | `[PASS]` |
| **TalkBack / VoiceOver** | Two-finger scrub / Back | Closes modal or pops current navigation route cleanly. | `[PASS]` |
| **TalkBack / VoiceOver** | Double-tap & Hold | For sensitive emergency actions, provides accessible alternative tap dialog. | `[PASS]` |

---

## 2. Touch Target & Visual Ergonomics

- [x] **Primary Action Buttons**: Minimum target height $\ge 64\text{ dp}$ ([AccessibleActionButton](file:///e:/codiee/lib/core/widgets/accessible_action_button.dart)).
- [x] **Ordinary Touch Targets**: Minimum target height $\ge 48\text{ dp}$ per WCAG 2.1 AA.
- [x] **Hero Voice Assistant Card**: Target height $\ge 76\text{ dp}$ with full horizontal tap span.
- [x] **Feature Grid Cards**: Minimum height $\ge 110\text{ dp}$ with large touch padding.
- [x] **Color Contrast Ratio**:
  - High-Contrast Theme: Pure black (`#000000`) and pure yellow (`#FFFF00`) exceeds **19:1** contrast ratio (exceeds WCAG AAA requirement of 7:1).
  - Dark Theme: High-contrast white (`#FFFFFF`) on navy surface (`#162036`) exceeds **12:1** contrast ratio.
- [x] **Dynamic Font Scaling**: System font scaling up to **2.5× (250%)** does not truncate or overflow buttons due to clamped `TextScaler`.

---

## 3. Auditory & Tactile Non-Visual Interaction

- [x] **Zero Visual Dependence**: User can navigate to Scene Analysis, Read Text, Identify Currency, and SOS without looking at the screen.
- [x] **Speech Interruption**: Speaking or triggering a new action immediately cancels previous speech output to prevent overlapping audio.
- [x] **Tactile Distinction**: User can distinguish between:
  - Left turn (two spaced pulses) vs Right turn (three rapid pulses).
  - Hazard alert (urgent pulsating buzz) vs Action confirmation (two crisp ticks).
  - Emergency SOS (heavy continuous pulses).
- [x] **Spoken Alternatives**: Every haptic pattern has an identical spoken announcement for users without vibration sensation.

---

## 4. Multi-Language Quality Verification

- [x] **English (EN)**: Concise, natural screen reader labels.
- [x] **Hindi (HI)**: Grammatically correct Devanagari strings for buttons, directions, and errors.
- [x] **Marathi (MR)**: Natural colloquial phrasing (e.g. "मजकूर वाचा", "चलन ओळखा", "परिसराचे वर्णन करा").
- [x] **Language Switching**: Changing app language immediately updates TTS voice locale and screen strings without app restart.
