import 'package:flutter/material.dart';

class AppStrings {
  // Brand & Header
  final String appTitle;
  final String appTagline;
  final String greetingPrefix;
  final String helpPrompt;
  final String userGreetingName;

  // Splash & Onboarding
  final String splashTapToStart;
  final String splashVoiceGuide;

  // Core Actions & Dashboard
  final String startVoiceAssistant;
  final String voiceSubtitle;
  final String navigation;
  final String navigationSubtitle;
  final String aiVision;
  final String aiVisionSubtitle;
  final String cashDetector;
  final String cashSubtitle;
  final String objectRecognition;
  final String objectSubtitle;
  final String settings;
  final String settingsSubtitle;
  final String moreFeatures;
  final String moreSubtitle;
  final String readText;
  final String readTextSubtitle;
  final String emergencyAssistance;
  final String emergencySubtitle;

  // Bottom Navigation
  final String navHome;
  final String navHistory;
  final String navSos;
  final String navProfile;

  // Voice Assistant
  final String voiceAssistantTitle;
  final String tapToSpeak;
  final String listening;
  final String processing;
  final String stopSpeaking;
  final String repeatLast;
  final String quickPromptReadText;
  final String quickPromptDetectCurrency;
  final String quickPromptWhatsAround;
  final String quickPromptOpenCamera;

  // Scene Analysis
  final String liveAnalysis;
  final String aiAnalysisTitle;
  final String capture;
  final String listen;
  final String analyzingSurroundings;

  // Cash Detector
  final String cashDetectorTitle;
  final String tapToScan;
  final String noteDetected;
  final String totalValue;
  final String notesFound;

  // Object Recognition
  final String objectRecognitionTitle;
  final String tapToHear;
  final String clear;
  final String leftSide;
  final String ahead;

  // AI Image Q&A
  final String aiImageQaTitle;
  final String askAssistant;
  final String yourQuestionHint;

  // Navigation Mode
  final String turnRightIn;
  final String meters;
  final String walk;
  final String pauseGuidance;
  final String resumeGuidance;

  // Safety Alerts / SOS
  final String sosTitle;
  final String hold5Seconds;
  final String holdToActivate;
  final String locationSharing;
  final String emergencyContacts;
  final String liveAudio;
  final String youAreSafe;

  // Settings
  final String accessibilitySection;
  final String generalSection;
  final String voiceLanguage;
  final String voiceSpeed;
  final String highContrastMode;
  final String largeText;
  final String haptics;
  final String audioCues;
  final String speechRate;
  final String testVoice;
  final String obstacleTrafficScanner;
  final String obstacleTrafficSubtitle;
  final Locale locale;

  const AppStrings({
    this.locale = const Locale('en'),
    this.obstacleTrafficScanner = 'Obstacle & Traffic Scanner',
    this.obstacleTrafficSubtitle = 'Stairs, obstacles, vehicles & signals',
    required this.appTitle,
    required this.appTagline,
    required this.greetingPrefix,
    required this.helpPrompt,
    required this.userGreetingName,
    required this.splashTapToStart,
    required this.splashVoiceGuide,
    required this.startVoiceAssistant,
    required this.voiceSubtitle,
    required this.navigation,
    required this.navigationSubtitle,
    required this.aiVision,
    required this.aiVisionSubtitle,
    required this.cashDetector,
    required this.cashSubtitle,
    required this.objectRecognition,
    required this.objectSubtitle,
    required this.settings,
    required this.settingsSubtitle,
    required this.moreFeatures,
    required this.moreSubtitle,
    required this.readText,
    required this.readTextSubtitle,
    required this.emergencyAssistance,
    required this.emergencySubtitle,
    required this.navHome,
    required this.navHistory,
    required this.navSos,
    required this.navProfile,
    required this.voiceAssistantTitle,
    required this.tapToSpeak,
    required this.listening,
    required this.processing,
    required this.stopSpeaking,
    required this.repeatLast,
    required this.quickPromptReadText,
    required this.quickPromptDetectCurrency,
    required this.quickPromptWhatsAround,
    required this.quickPromptOpenCamera,
    required this.liveAnalysis,
    required this.aiAnalysisTitle,
    required this.capture,
    required this.listen,
    required this.analyzingSurroundings,
    required this.cashDetectorTitle,
    required this.tapToScan,
    required this.noteDetected,
    required this.totalValue,
    required this.notesFound,
    required this.objectRecognitionTitle,
    required this.tapToHear,
    required this.clear,
    required this.leftSide,
    required this.ahead,
    required this.aiImageQaTitle,
    required this.askAssistant,
    required this.yourQuestionHint,
    required this.turnRightIn,
    required this.meters,
    required this.walk,
    required this.pauseGuidance,
    required this.resumeGuidance,
    required this.sosTitle,
    required this.hold5Seconds,
    required this.holdToActivate,
    required this.locationSharing,
    required this.emergencyContacts,
    required this.liveAudio,
    required this.youAreSafe,
    required this.accessibilitySection,
    required this.generalSection,
    required this.voiceLanguage,
    required this.voiceSpeed,
    required this.highContrastMode,
    required this.largeText,
    required this.haptics,
    required this.audioCues,
    required this.speechRate,
    required this.testVoice,
  });

  // English Strings
  static const AppStrings en = AppStrings(
    locale: Locale('en'),
    appTitle: 'VisionMate 2.0',
    appTagline: 'See Beyond • Live Independently',
    greetingPrefix: 'Hello Yogeshh 👋',
    helpPrompt: 'How can I help you today?',
    userGreetingName: 'Yogeshh',
    splashTapToStart: 'Tap to Start',
    splashVoiceGuide: 'Double tap to continue (Voice will guide you)',
    startVoiceAssistant: 'Start Voice Assistant',
    voiceSubtitle: "Tap or say 'Hey VisionMate'",
    navigation: 'Navigation',
    navigationSubtitle: 'Turn-by-turn guidance',
    aiVision: 'AI Vision',
    aiVisionSubtitle: 'Scene & obstacles check',
    cashDetector: 'Cash Detector',
    cashSubtitle: 'Indian Rupee notes (₹)',
    objectRecognition: 'Object Recognition',
    objectSubtitle: 'Detect & identify objects',
    settings: 'Settings',
    settingsSubtitle: 'Voice & accessibility',
    moreFeatures: 'More',
    moreSubtitle: 'Q&A, OCR, Saved & SOS',
    readText: 'Read Text',
    readTextSubtitle: 'Scan & Listen (OCR)',
    emergencyAssistance: 'Emergency Assistance',
    emergencySubtitle: 'One-touch SOS alert',
    navHome: 'Home',
    navHistory: 'History',
    navSos: 'SOS',
    navProfile: 'Profile',
    voiceAssistantTitle: 'Voice Assistant',
    tapToSpeak: 'Tap to speak',
    listening: 'Listening now...',
    processing: 'Processing request...',
    stopSpeaking: 'Stop Speaking',
    repeatLast: 'Repeat Last',
    quickPromptReadText: 'Read nearby text',
    quickPromptDetectCurrency: 'Detect currency',
    quickPromptWhatsAround: "What's around me?",
    quickPromptOpenCamera: 'Open camera',
    liveAnalysis: 'Live Analysis',
    aiAnalysisTitle: 'AI Analysis',
    capture: 'Camera',
    listen: 'Listen',
    analyzingSurroundings: 'Analyzing surroundings...',
    cashDetectorTitle: 'Cash Detector',
    tapToScan: 'Tap to scan',
    noteDetected: 'Detected',
    totalValue: 'Total Value',
    notesFound: '1 note found',
    objectRecognitionTitle: 'Object Recognition',
    tapToHear: 'Tap to hear',
    clear: 'Clear',
    leftSide: 'Left side',
    ahead: 'ahead',
    aiImageQaTitle: 'AI Image Q&A',
    askAssistant: 'Ask Visual Assistant',
    yourQuestionHint: 'Your question about the scene...',
    turnRightIn: 'Turn right in',
    meters: 'meters',
    walk: 'walk',
    pauseGuidance: 'Pause Guidance',
    resumeGuidance: 'Resume Guidance',
    sosTitle: 'Safety Alerts (SOS)',
    hold5Seconds: 'Press and hold for 5 seconds to send alert',
    holdToActivate: 'Hold to Activate',
    locationSharing: 'Location Sharing',
    emergencyContacts: 'Emergency Contacts',
    liveAudio: 'Live Audio',
    youAreSafe: 'You are safe. I am here to help.',
    accessibilitySection: 'Accessibility',
    generalSection: 'General',
    voiceLanguage: 'Voice Language',
    voiceSpeed: 'Voice Speed',
    highContrastMode: 'High Contrast',
    largeText: 'Large Text',
    haptics: 'Haptic Feedback',
    audioCues: 'Audio Cues',
    speechRate: 'Speech Pace Rate',
    testVoice: 'Test Spoken Voice',
  );

  // Hindi (हिन्दी) Strings
  static const AppStrings hi = AppStrings(
    locale: Locale('hi'),
    appTitle: 'VisionMate 2.0',
    appTagline: 'सीमाओं से परे देखें • स्वतंत्र जीवन जिएं',
    greetingPrefix: 'नमस्ते योगेश 👋',
    helpPrompt: 'आज मैं आपकी क्या सहायता करूँ?',
    userGreetingName: 'योगेश',
    splashTapToStart: 'शुरू करने के लिए टैप करें',
    splashVoiceGuide: 'आगे बढ़ने के लिए दो बार टैप करें (आवाज आपका मार्गदर्शन करेगी)',
    startVoiceAssistant: 'वॉइस सहायक शुरू करें',
    voiceSubtitle: "टैप करें या 'हे VisionMate' कहें",
    navigation: 'नेविगेशन',
    navigationSubtitle: 'रास्ता मार्गदर्शन',
    aiVision: 'एआई विज़न',
    aiVisionSubtitle: 'दृश्य और बाधा जांच',
    cashDetector: 'कैश डिटेक्टर',
    cashSubtitle: 'भारतीय रुपया नोट (₹)',
    objectRecognition: 'वस्तु पहचान',
    objectSubtitle: 'वस्तुओं को पहचानें',
    settings: 'सेटिंग्स',
    settingsSubtitle: 'आवाज और सुगमता',
    moreFeatures: 'अन्य सुविधाएं',
    moreSubtitle: 'प्रश्नोत्तर, OCR, SOS',
    readText: 'टेक्स्ट पढ़ें',
    readTextSubtitle: 'स्कैन करें और सुनें (OCR)',
    emergencyAssistance: 'आपातकालीन सहायता',
    emergencySubtitle: 'त्वरित SOS चेतावनी',
    navHome: 'होम',
    navHistory: 'इतिहास',
    navSos: 'SOS',
    navProfile: 'प्रोफ़ाइल',
    voiceAssistantTitle: 'वॉइस सहायक',
    tapToSpeak: 'बोलने के लिए टैप करें',
    listening: 'सुन रहा हूं...',
    processing: 'प्रोसेसिंग हो रही है...',
    stopSpeaking: 'बोलना बंद करें',
    repeatLast: 'फिर से बोलें',
    quickPromptReadText: 'आसपास का टेक्स्ट पढ़ें',
    quickPromptDetectCurrency: 'मुद्रा पहचानें',
    quickPromptWhatsAround: 'मेरे आसपास क्या है?',
    quickPromptOpenCamera: 'कैमरा खोलें',
    liveAnalysis: 'लाइव विश्लेषण',
    aiAnalysisTitle: 'एआई विश्लेषण',
    capture: 'कैमरा',
    listen: 'सुनें',
    analyzingSurroundings: 'आसपास का विश्लेषण हो रहा है...',
    cashDetectorTitle: 'कैश डिटेक्टर',
    tapToScan: 'स्कैन करने के लिए टैप करें',
    noteDetected: 'पहचाना गया',
    totalValue: 'कुल मूल्य',
    notesFound: '1 नोट मिला',
    objectRecognitionTitle: 'वस्तु पहचान',
    tapToHear: 'सुनने के लिए टैप करें',
    clear: 'साफ',
    leftSide: 'बाईं ओर',
    ahead: 'आगे',
    aiImageQaTitle: 'एआई छवि प्रश्नोत्तर',
    askAssistant: 'सहायक से पूछें',
    yourQuestionHint: 'दृश्य के बारे में आपका प्रश्न...',
    turnRightIn: 'दाएं मुड़ें',
    meters: 'मीटर में',
    walk: 'पैदल',
    pauseGuidance: 'मार्गदर्शन रोकें',
    resumeGuidance: 'मार्गदर्शन पुनः शुरू करें',
    sosTitle: 'आपातकालीन सहायता (SOS)',
    hold5Seconds: 'अलर्ट भेजने के लिए 5 सेकंड दबाए रखें',
    holdToActivate: 'सक्रिय करने के लिए दबाए रखें',
    locationSharing: 'स्थान साझा',
    emergencyContacts: 'आपातकालीन संपर्क',
    liveAudio: 'लाइव ऑडियो',
    youAreSafe: 'आप सुरक्षित हैं। मैं सहायता के लिए यहाँ हूँ।',
    accessibilitySection: 'सुगमता',
    generalSection: 'सामान्य',
    voiceLanguage: 'आवाज की भाषा',
    voiceSpeed: 'आवाज की गति',
    highContrastMode: 'हाई कंट्रास्ट',
    largeText: 'बड़ा टेक्स्ट',
    haptics: 'स्पर्श कंपन (Haptics)',
    audioCues: 'ऑडियो संकेत',
    speechRate: 'बोलने की गति',
    testVoice: 'आवाज का परीक्षण करें',
    obstacleTrafficScanner: 'बाधा और ट्रैफिक स्कैनर',
    obstacleTrafficSubtitle: 'सीढ़ियां, गड्ढे, गाड़ियां और सिग्नल',
  );

  // Marathi (मराठी) Strings
  static const AppStrings mr = AppStrings(
    locale: Locale('mr'),
    appTitle: 'VisionMate 2.0',
    appTagline: 'मर्यादांपलीकडे पहा • स्वावलंबी जगा',
    greetingPrefix: 'नमस्कार योगेश 👋',
    helpPrompt: 'आज मी तुम्हाला कशी मदत करू?',
    userGreetingName: 'योगेश',
    splashTapToStart: 'सुरू करण्यासाठी टॅप करा',
    splashVoiceGuide: 'पुढे जाण्यासाठी दोनदा टॅप करा (आवाज मार्गदर्शन करेल)',
    startVoiceAssistant: 'व्हॉइस असिस्टंट सुरू करा',
    voiceSubtitle: "टॅप करा किंवा 'हे VisionMate' म्हणा",
    navigation: 'नेव्हिगेशन',
    navigationSubtitle: 'वळण मार्गदर्शन',
    aiVision: 'एआय व्हिजन',
    aiVisionSubtitle: 'दृश्य आणि अडथळा तपासणी',
    cashDetector: 'कॅश डिटेक्टर',
    cashSubtitle: 'भारतीय रुपया नोटा (₹)',
    objectRecognition: 'वस्तू ओळख',
    objectSubtitle: 'वस्तू ओळखा आणि शोधा',
    settings: 'सेटिंग्ज',
    settingsSubtitle: 'आवाज आणि सुलभता',
    moreFeatures: 'इतर पर्याय',
    moreSubtitle: 'प्रश्नोत्तरे, OCR, SOS',
    readText: 'मजकूर वाचा',
    readTextSubtitle: 'स्कॅन करा आणि ऐका (OCR)',
    emergencyAssistance: 'तातडीची मदत (SOS)',
    emergencySubtitle: 'त्वरित आणीबाणी संदेश',
    navHome: 'होम',
    navHistory: 'इतिहास',
    navSos: 'SOS',
    navProfile: 'प्रोफाइल',
    voiceAssistantTitle: 'व्हॉइस असिस्टंट',
    tapToSpeak: 'बोलण्यासाठी टॅप करा',
    listening: 'ऐकत आहे...',
    processing: 'प्रक्रिया सुरू आहे...',
    stopSpeaking: 'बोलणे थांबवा',
    repeatLast: 'पुन्हा सांगा',
    quickPromptReadText: 'जवळचा मजकूर वाचा',
    quickPromptDetectCurrency: 'चलन ओळखा',
    quickPromptWhatsAround: 'माझ्या आजूबाजूला काय आहे?',
    quickPromptOpenCamera: 'कॅमेरा उघडा',
    liveAnalysis: 'थेट विश्लेषण',
    aiAnalysisTitle: 'एआय विश्लेषण',
    capture: 'कॅमेरा',
    listen: 'ऐका',
    analyzingSurroundings: 'परिसराचे विश्लेषण सुरू आहे...',
    cashDetectorTitle: 'कॅश डिटेक्टर',
    tapToScan: 'स्कॅन करण्यासाठी टॅप करा',
    noteDetected: 'ओळखले',
    totalValue: 'एकूण मूल्य',
    notesFound: '१ नोट सापडली',
    objectRecognitionTitle: 'वस्तू ओळख',
    tapToHear: 'ऐकण्यासाठी टॅप करा',
    clear: 'मोकळा मार्ग',
    leftSide: 'डाव्या बाजूला',
    ahead: 'पुढे',
    aiImageQaTitle: 'एआय प्रतिमा प्रश्नोत्तरे',
    askAssistant: 'असिस्टंटला विचारा',
    yourQuestionHint: 'दृश्याबद्दल तुमचा प्रश्न...',
    turnRightIn: 'उजवीकडे वळा',
    meters: 'मीटरमध्ये',
    walk: 'पायी',
    pauseGuidance: 'मार्गदर्शन थांबवा',
    resumeGuidance: 'मार्गदर्शन पुन्हा सुरू करा',
    sosTitle: 'तातडीची मदत (SOS)',
    hold5Seconds: 'अलर्ट पाठवण्यासाठी ५ सेकंद दाबून ठेवा',
    holdToActivate: 'सक्रिय करण्यासाठी दाबून ठेवा',
    locationSharing: 'स्थान सामायिकरण',
    emergencyContacts: 'तातडीचे संपर्क',
    liveAudio: 'थेट ऑडिओ',
    youAreSafe: 'तुम्ही सुरक्षित आहात. मी मदतीसाठी येथे आहे.',
    accessibilitySection: 'सुलभता',
    generalSection: 'सामान्य',
    voiceLanguage: 'आवाजाची भाषा',
    voiceSpeed: 'आवाजाचा वेग',
    highContrastMode: 'हाय कॉन्ट्रास्ट',
    largeText: 'मोठा मजकूर',
    haptics: 'स्पर्श कंपन (Haptics)',
    audioCues: 'ऑडिओ संकेत',
    speechRate: 'बोलण्याचा वेग',
    testVoice: 'आवाजाची चाचणी घ्या',
    obstacleTrafficScanner: 'अडथळा आणि ट्रॅफिक स्कॅनर',
    obstacleTrafficSubtitle: 'पायऱ्या, खड्डे, वाहने आणि सिग्नल',
  );

  static AppStrings of(BuildContext context) {
    final locale = Localizations.localeOf(context);
    return fromCode(locale.languageCode);
  }

  static AppStrings fromCode(String code) {
    switch (code) {
      case 'hi':
        return hi;
      case 'mr':
        return mr;
      case 'en':
      default:
        return en;
    }
  }
}
