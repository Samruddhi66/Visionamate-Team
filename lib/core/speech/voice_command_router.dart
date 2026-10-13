/// Enumeration of all recognized application intents for VisionMate 2.0
enum VoiceActionType {
  wake,
  describeSurroundings,
  readText,
  identifyCurrency,
  identifyObject,
  navigateToPlace,
  stopSpeaking,
  repeatLast,
  cancelOperation,
  openSettings,
  emergencySos,
  imageQa,
  help,
  unknown,
}

class ParsedVoiceCommand {
  final VoiceActionType actionType;
  final String rawSpokenText;
  final double confidence;
  final String? argument; // e.g. destination name for navigation
  final bool requiresConfirmation;
  final String? confirmationPrompt;

  const ParsedVoiceCommand({
    required this.actionType,
    required this.rawSpokenText,
    required this.confidence,
    this.argument,
    this.requiresConfirmation = false,
    this.confirmationPrompt,
  });
}

/// Robust NLP command parser mapping spoken input to actionable intents
class VoiceCommandRouter {
  static const double minimumConfidenceThreshold = 0.50;

  static ParsedVoiceCommand parse(String input, {double confidence = 0.90}) {
    final cleaned = input.toLowerCase().trim();

    if (confidence < minimumConfidenceThreshold) {
      return ParsedVoiceCommand(
        actionType: VoiceActionType.unknown,
        rawSpokenText: input,
        confidence: confidence,
        requiresConfirmation: true,
        confirmationPrompt: 'I heard "$input", but speech was unclear. Please repeat your command.',
      );
    }

    // Emergency Intent (High Priority)
    if (cleaned.contains('emergency') ||
        cleaned.contains('sos') ||
        cleaned.contains('help me') ||
        cleaned.contains('call for help') ||
        cleaned.contains('मदत करा') ||
        cleaned.contains('मदद करो')) {
      return ParsedVoiceCommand(
        actionType: VoiceActionType.emergencySos,
        rawSpokenText: input,
        confidence: confidence,
        requiresConfirmation: true,
        confirmationPrompt: 'Trigger emergency assistance and notify your contacts?',
      );
    }

    // Stop Intent
    if (cleaned.contains('stop') ||
        cleaned.contains('quiet') ||
        cleaned.contains('shut up') ||
        cleaned.contains('थांबा') ||
        cleaned.contains('रुकिए') ||
        cleaned.contains('शांत')) {
      return ParsedVoiceCommand(
        actionType: VoiceActionType.stopSpeaking,
        rawSpokenText: input,
        confidence: confidence,
      );
    }

    // Repeat Intent
    if (cleaned.contains('repeat') ||
        cleaned.contains('say again') ||
        cleaned.contains('पुन्हा सांगा') ||
        cleaned.contains('फिर से बोलिए')) {
      return ParsedVoiceCommand(
        actionType: VoiceActionType.repeatLast,
        rawSpokenText: input,
        confidence: confidence,
      );
    }

    // Describe Surroundings / Scene Understanding
    if (cleaned.contains('describe') ||
        cleaned.contains('surrounding') ||
        cleaned.contains('scene') ||
        cleaned.contains('analyze scene') ||
        cleaned.contains('what is in front of me') ||
        cleaned.contains('what is around') ||
        cleaned.contains('view surroundings') ||
        cleaned.contains('आसपास काय आहे') ||
        cleaned.contains('सामने क्या है')) {
      return ParsedVoiceCommand(
        actionType: VoiceActionType.describeSurroundings,
        rawSpokenText: input,
        confidence: confidence,
      );
    }

    // Read Text / OCR
    if (cleaned.contains('read') ||
        cleaned.contains('sign') ||
        cleaned.contains('text') ||
        cleaned.contains('document') ||
        cleaned.contains('ocr') ||
        cleaned.contains('वाचा') ||
        cleaned.contains('पढ़ो') ||
        cleaned.contains('बोर्ड वाचा')) {
      return ParsedVoiceCommand(
        actionType: VoiceActionType.readText,
        rawSpokenText: input,
        confidence: confidence,
      );
    }

    // Currency Identification
    if (cleaned.contains('currency') ||
        cleaned.contains('rupee') ||
        cleaned.contains('note') ||
        cleaned.contains('money') ||
        cleaned.contains('cash') ||
        cleaned.contains('detect cash') ||
        cleaned.contains('cash detector') ||
        cleaned.contains('पैसे') ||
        cleaned.contains('रुपये') ||
        cleaned.contains('नोट')) {
      return ParsedVoiceCommand(
        actionType: VoiceActionType.identifyCurrency,
        rawSpokenText: input,
        confidence: confidence,
      );
    }

    // Identify Object / Object Detection
    if (cleaned.contains('object') ||
        cleaned.contains('detect object') ||
        cleaned.contains('detect objects') ||
        cleaned.contains('identify object') ||
        cleaned.contains('identify objects') ||
        cleaned.contains('what is this') ||
        cleaned.contains('what object is this') ||
        cleaned.contains('find object') ||
        cleaned.contains('find objects') ||
        cleaned.contains('scan object') ||
        cleaned.contains('recognize object') ||
        cleaned.contains('ही वस्तू काय आहे') ||
        cleaned.contains('यह वस्तु क्या है') ||
        cleaned.contains('वस्तू शोधा') ||
        cleaned.contains('वस्तु पहचानो')) {
      return ParsedVoiceCommand(
        actionType: VoiceActionType.identifyObject,
        rawSpokenText: input,
        confidence: confidence,
      );
    }

    // Image Question Answering Intent
    if (cleaned.contains('ask about') ||
        cleaned.contains('question') ||
        cleaned.contains('what color') ||
        cleaned.contains('what is on the') ||
        cleaned.contains('कशाबद्दल आहे')) {
      return ParsedVoiceCommand(
        actionType: VoiceActionType.imageQa,
        rawSpokenText: input,
        confidence: confidence,
      );
    }

    // Navigation Intent
    if (cleaned.contains('navigate to') ||
        cleaned.contains('take me to') ||
        cleaned.contains('directions to') ||
        cleaned.contains('रस्ता दाखवा') ||
        cleaned.contains('रास्ता दिखाओ')) {
      String destination = '';
      if (cleaned.contains('navigate to')) {
        destination = input.substring(cleaned.indexOf('navigate to') + 11).trim();
      } else if (cleaned.contains('take me to')) {
        destination = input.substring(cleaned.indexOf('take me to') + 10).trim();
      } else if (cleaned.contains('directions to')) {
        destination = input.substring(cleaned.indexOf('directions to') + 13).trim();
      }

      return ParsedVoiceCommand(
        actionType: VoiceActionType.navigateToPlace,
        rawSpokenText: input,
        confidence: confidence,
        argument: destination.isNotEmpty ? destination : null,
      );
    }

    if (cleaned == 'navigate' || cleaned == 'navigation') {
      return ParsedVoiceCommand(
        actionType: VoiceActionType.navigateToPlace,
        rawSpokenText: input,
        confidence: confidence,
      );
    }

    // Settings
    if (cleaned.contains('setting') ||
        cleaned.contains('settings') ||
        cleaned.contains('सेटअप') ||
        cleaned.contains('सेटिंग्ज')) {
      return ParsedVoiceCommand(
        actionType: VoiceActionType.openSettings,
        rawSpokenText: input,
        confidence: confidence,
      );
    }

    // Help
    if (cleaned.contains('help') || cleaned.contains('मदत') || cleaned.contains('सहायता')) {
      return ParsedVoiceCommand(
        actionType: VoiceActionType.help,
        rawSpokenText: input,
        confidence: confidence,
      );
    }

    // Wake / Greeting
    if (cleaned.contains('visionmate') || cleaned.contains('hello') || cleaned.contains('hey')) {
      return ParsedVoiceCommand(
        actionType: VoiceActionType.wake,
        rawSpokenText: input,
        confidence: confidence,
      );
    }

    // Unknown command
    return ParsedVoiceCommand(
      actionType: VoiceActionType.unknown,
      rawSpokenText: input,
      confidence: confidence,
      requiresConfirmation: true,
      confirmationPrompt: 'Command "$input" not recognized. Say "Help" for options.',
    );
  }
}
