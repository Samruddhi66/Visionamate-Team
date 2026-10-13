# VisionMate 2.0 — AI-Powered Assistive Navigation & Accessibility Platform

> **"See Beyond • Live Independently"**

VisionMate 2.0 is an accessibility-first, modular mobile application built with Flutter, Dart, Riverpod, and Clean Architecture. Designed specifically for blind and visually impaired individuals, VisionMate empowers users to understand their physical surroundings, read text, identify Indian currency notes, and navigate with spoken guidance and tactile haptic feedback.

---

## 🏛 System Architecture Overview

VisionMate 2.0 implements Clean Architecture separated into 6 horizontal tiers and cross-cutting services:

```
┌────────────────────────────────────────────────────────────────────────┐
│                   1. USER INTERFACE LAYER (Flutter UI)                 │
│  Home Dashboard • Voice Assistant Modal • Viewfinder • Route Guidance  │
├────────────────────────────────────────────────────────────────────────┤
│                   2. APPLICATION & STATE LAYER (Riverpod)              │
│  UnifiedVoiceController • ThemeNotifier • LocaleNotifier • GoRouter    │
├────────────────────────────────────────────────────────────────────────┤
│                   3. AI / ML SERVICES LAYER (Inference)                │
│  Scene Description • ML Kit OCR • INR Currency Model • Object Detector │
├────────────────────────────────────────────────────────────────────────┤
│                   4. DATA & LOCAL STORAGE LAYER                        │
│  PreferencesService • HistoryRepository • SavedPlacesRepository        │
├────────────────────────────────────────────────────────────────────────┤
│                   5. DEVICE CAPABILITIES LAYER                         │
│  Microphone (STT) • Audio Output (TTS) • Camera • Haptic Engine • GPS  │
├────────────────────────────────────────────────────────────────────────┤
│                   6. CROSS-CUTTING SERVICES                            │
│  Accessibility (TalkBack/VoiceOver) • Multilingual (EN/HI/MR) • Safety │
└────────────────────────────────────────────────────────────────────────┘
```

---

## 🚀 Implemented Features (Phase 1 through Phase 5)

1. **Voice-First Hero Interface**: Large primary target (`>76dp`) for immediate tap-to-talk voice interactions.
2. **Unified Voice Coordinator**: Coordinates speech recognition (STT), text-to-speech (TTS), and tactile pulses without audio overlapping or audio-feedback loops.
3. **Tactile Haptic Engine**: 10 distinct vibration profiles for turn directions, obstacle warnings, confirmation, and emergency status.
4. **Natural Command NLP Router**: Maps recognized English, Hindi, and Marathi commands to structured application actions with confidence gating.
5. **AI Vision & Perception Subsystems**:
   - 📸 **Describe Surroundings**: Scene description & obstacle awareness with concise and detailed modes.
   - 📍 **Navigate to a Place**: Turn-by-turn walking guidance with GPS accuracy checks and haptic turn cues (left vs right vs arrival).
   - 📄 **Read Text (OCR)**: Scans documents, signboards, labels with audio playback controls (play/pause/stop/repeat).
   - 💵 **Identify Currency**: Un-faked Indian Rupee (₹) banknote classification pipeline with confidence scores and disclaimer.
   - 📦 **Identify an Object**: Identifies obstacles, doors, vehicles, people, and furniture with relative position descriptions ("on your left", "ahead").
   - 💬 **Image Question Answering**: Ask questions like "What is on the table?" or "What color is this?" with spoken answers.
   - 🆘 **Emergency Assistance (SOS)**: Prominent emergency workflow with live GPS coordinates dispatch to saved emergency contacts.
6. **Multi-Language Support**: Complete localization for **English (EN)**, **Hindi (HI)**, and **Marathi (MR)**.
7. **Accessibility Standards**: WCAG 2.1 AAA high-contrast theme, minimum 48–64dp touch targets, semantic labels, screen-reader reading order, and non-visual alternatives.
8. **Data Persistence & Privacy**: Local storage with SharedPreferences for activity history (auto-pruned to 50 items) and saved places.

---

## 🛠 Local Setup & Running

### Prerequisites
- Flutter SDK 3.47+ & Dart SDK 3.13+
- Android Studio / Xcode for mobile deployment
- Physical Android/iOS device recommended for testing vibration motors and microphone hardware.

### Quick Commands

```bash
# 1. Fetch dependencies
flutter pub get

# 2. Run static analysis (0 errors, 0 warnings)
dart analyze

# 3. Run automated test suite (21 unit & widget tests)
flutter test

# 4. Launch app on connected device / emulator
flutter run
```

---

## 🧪 Automated QA Test Results

```
00:00 +0: MockHapticService records triggered patterns when enabled
00:00 +1: MockHapticService suppresses triggers when disabled by settings
00:00 +2: All HapticPatterns have spoken alternatives for accessible fallback
00:00 +3: All HapticPatterns have non-empty vibration timing profiles
00:00 +4: HistoryRepository Persists new history entries and maintains recent order
00:00 +5: HistoryRepository Deletes individual history entry
00:00 +6: HistoryRepository Clears all history entries
00:00 +7: Pedestrian RoutingService Calculates walking route with turn directions
00:00 +8: SafetyAlertManager Dispatches hazard alert with haptic cue and spoken warning
00:01 +9: SafetyAlertManager Suppresses duplicate alerts within 4-second window
00:01 +10: SafetyAlertManager Allows distinct alerts without duplicate suppression
00:01 +11: MockTtsService records spoken prompts and repeats last
00:01 +12: MockTtsService ignores blank or empty text
00:01 +13: VoiceCommandRouter maps describe surroundings in English and Marathi
00:01 +14: VoiceCommandRouter maps read text and OCR intent
00:01 +15: VoiceCommandRouter maps Indian currency identification intent
00:01 +16: VoiceCommandRouter maps navigation with destination argument extraction
00:01 +17: VoiceCommandRouter flags emergency SOS with high priority & confirmation
00:01 +18: VoiceCommandRouter handles low confidence speech safely
00:01 +19: VoiceCommandRouter handles stop and repeat instructions
00:01 +20: VisionMate 2.0 Dashboard renders brand header, voice hero card, and 6 feature cards
00:02 +21: All tests passed!
```
