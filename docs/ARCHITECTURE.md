# VisionMate 2.0 — Architecture & Design Document

## 1. Executive Summary

VisionMate 2.0 is an assistive mobile application designed to foster spatial autonomy, literacy, and financial independence for blind and visually impaired people. The application is built using **Flutter and Dart** with null safety, adhering strictly to **Clean Architecture** with a voice-first, touch-responsive, and accessibility-enforced user experience.

---

## 2. Architectural Layers

VisionMate 2.0 is structured into 6 decoupled horizontal layers and cross-cutting subsystems:

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

### Layer Responsibilities

1. **User Interface Layer (`lib/features/`, `lib/core/widgets/`)**:
   - Contains feature screens and reusable atomic design components.
   - Enforces minimum touch target constraints:
     - Primary actions: $\ge 64$ logical pixels.
     - Secondary actions: $\ge 48$ logical pixels.
     - Hero voice button: $76$ logical pixels.
   - Includes semantic headers, labels, and roles on every interactive widget.

2. **Application & State Layer (`lib/app/`, `lib/core/coordinator/`)**:
   - Uses **Riverpod** for dependency injection and state isolation.
   - Uses **GoRouter** for declarative deep-linking and state restoration across 11 routes.
   - Hosts `UnifiedVoiceController`, preventing competing audio threads.

3. **AI / ML Services Layer (`lib/features/*/services/`)**:
   - Decoupled interfaces: `SceneUnderstandingService`, `OcrService`, `CurrencyDetectionService`, `ObjectDetectionService`, `ImageQaService`.
   - Never fakes outputs: returns real confidence values and un-faked status diagnostics.

4. **Data Layer (`lib/core/storage/`)**:
   - `PreferencesService`: Stores theme modes, speech pace, and haptic preferences.
   - `HistoryRepository`: Persists up to 50 user activity records locally for offline recall.
   - `SavedPlacesRepository`: Persists bookmarked navigation destinations.

5. **Device Capabilities Layer (`lib/core/haptics/`, `lib/core/camera/`, `location_service.dart`)**:
   - Interfaces hardware devices (vibrator, camera, microphone, GPS).
   - Graceful degradation: apps never crash on devices missing vibration or physical cameras.

---

## 3. Unified Voice Coordinator Flow

```
[ User Taps Mic / Speaks ]
           │
           ▼
[ UnifiedVoiceController.startListening() ]
   ├──> 1. ttsService.stop() (Silences speaker to avoid mic feedback)
   ├──> 2. hapticService.trigger(listeningStarted) (Tactile acknowledgment)
   └──> 3. speechService.startListening()
           │
           ▼
[ Live Transcription & Confidence Scoring ]
           │
           ▼
[ VoiceCommandRouter.parse(transcript, confidence) ]
   ├── If confidence < 0.50: Prompts user to repeat command
   ├── If Action == Emergency: Requests vocal/touch confirmation
   └── If Action Valid:
           ├──> hapticService.trigger(actionSuccess)
           └──> Dispatches GoRouter navigation (/scene, /ocr, /navigation, etc.)
```

---

## 4. Safety & Hazard Debouncing Engine

To prevent user overwhelm or battery exhaustion during continuous camera or GPS streams:
- `SafetyAlertManager` implements a **4-second suppression window** per unique hazard identifier.
- If an obstacle is detected in consecutive video frames, a single haptic pulse (`hazardDetected`) and spoken warning are dispatched.
- Once the user moves or a different hazard is recognized, new alerts trigger immediately.
